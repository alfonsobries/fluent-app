#!/usr/bin/env python3
"""Fluent App for Omarchy — config, providers, capture/paste, and hotkeys.

Talks to OpenAI, Anthropic, Gemini, and xAI using the same prompts as the
macOS app. API keys stay in a 0600 file under ~/.config/fluent-app/.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

PLUGIN_ID = "io.github.alfonsobries.fluent"
BIND_BEGIN = "-- fluent-app:begin"
BIND_END = "-- fluent-app:end"
DEFAULT_CHORD = "CTRL + ALT + SHIFT"
DEFAULT_PANEL_KEY = "F"
CONFIG_DIR_NAME = "fluent-app"
CONFIG_FILE_NAME = "omarchy.json"

# Hyprland modmask bits (same as hyprctl binds -j).
MOD_SHIFT = 1
MOD_CTRL = 4
MOD_ALT = 8
MOD_SUPER = 64

PROVIDERS = {
    "openai": {
        "id": "openai",
        "displayName": "OpenAI (GPT)",
        "apiKeyURL": "https://platform.openai.com/api-keys",
        "apiKeyPlaceholder": "sk-...",
        "model": "gpt-4o-mini",
    },
    "claude": {
        "id": "claude",
        "displayName": "Anthropic (Claude)",
        "apiKeyURL": "https://console.anthropic.com/api-keys",
        "apiKeyPlaceholder": "sk-ant-...",
        "model": "claude-3-haiku-20240307",
    },
    "gemini": {
        "id": "gemini",
        "displayName": "Google (Gemini)",
        "apiKeyURL": "https://aistudio.google.com/apikey",
        "apiKeyPlaceholder": "AI...",
        "model": "gemini-1.5-flash",
    },
    "grok": {
        "id": "grok",
        "displayName": "xAI (Grok)",
        "apiKeyURL": "https://console.x.ai",
        "apiKeyPlaceholder": "xai-...",
        "model": "grok-beta",
    },
}

ERRORS = {
    "invalid_api_key": "Invalid API key. Please check your credentials.",
    "rate_limited": "Rate limited. Please wait and try again.",
    "invalid_response": "Invalid response from the AI service.",
    "no_content": "No content in response.",
    "no_selection": "No text selection was found.",
    "no_api_key": "Configure an API key for {provider}.",
    "unknown_action": "Unknown action.",
    "unknown_provider": "Unknown provider.",
    "busy": "Fluent is already running.",
    "server_error": "Server error (code: {status}). Please try again.",
    "collision": "Shortcut collision: {detail}",
}

DEFAULT_ACTIONS = [
    {
        "id": "translate",
        "actionId": "translate",
        "name": "Translate",
        "key": "T",
        "enabled": True,
        "prompt": (
            "Detect the language of the following text. If it is Spanish, translate it to English. "
            "If it is English, translate it to Spanish. Output only the translated text without any explanations."
        ),
    },
    {
        "id": "improve",
        "actionId": "improve",
        "name": "Improve writing",
        "key": "O",
        "enabled": True,
        "prompt": (
            "Improve the writing of the following text. Fix grammar, improve clarity, and make it more professional. "
            "Keep the same language. Output only the improved text without explanations."
        ),
    },
    {
        "id": "grammar",
        "actionId": "grammar",
        "name": "Fix grammar",
        "key": "G",
        "enabled": True,
        "prompt": (
            "Fix the grammar and spelling of the following text. Keep the same language and style. "
            "Output only the corrected text."
        ),
    },
    {
        "id": "summarize",
        "actionId": "summarize",
        "name": "Summarize",
        "key": "S",
        "enabled": True,
        "prompt": (
            "Summarize the following text in 3 concise bullet points. Keep the same language as the input."
        ),
    },
    {
        "id": "tone",
        "actionId": "tone",
        "name": "Make professional",
        "key": "P",
        "enabled": True,
        "prompt": (
            "Rewrite the following text in a polished professional tone. Preserve the meaning and keep the same language."
        ),
    },
]

TERMINAL_CLASSES = {
    "alacritty",
    "kitty",
    "foot",
    "footclient",
    "ghostty",
    "com.mitchellh.ghostty",
    "org.wezfurlong.wezterm",
    "wezterm",
    "org.gnome.console",
    "com.mitchellh.ghostty",
}


class FluentError(Exception):
    def __init__(self, code: str, message: str | None = None, status: int | None = None):
        self.code = code
        self.status = status
        self.message = message or ERRORS.get(code, code)
        super().__init__(self.message)

    def as_dict(self) -> dict:
        payload = {"ok": False, "error": self.code, "message": self.message}
        if self.status is not None:
            payload["status"] = self.status
        return payload


def config_path(env: dict | None = None) -> Path:
    env = env or os.environ
    override = env.get("FLUENT_CONFIG_PATH")
    if override:
        return Path(override)
    xdg = env.get("XDG_CONFIG_HOME")
    base = Path(xdg) if xdg else Path.home() / ".config"
    return base / CONFIG_DIR_NAME / CONFIG_FILE_NAME


def bindings_path(env: dict | None = None) -> Path:
    env = env or os.environ
    override = env.get("FLUENT_BINDINGS_PATH")
    if override:
        return Path(override)
    xdg = env.get("XDG_CONFIG_HOME")
    base = Path(xdg) if xdg else Path.home() / ".config"
    return base / "hypr" / "bindings.lua"


def default_config() -> dict:
    return {
        "provider": "openai",
        "apiKeys": {},
        "models": {pid: meta["model"] for pid, meta in PROVIDERS.items()},
        "actions": [dict(action) for action in DEFAULT_ACTIONS],
        "hotkeyChord": DEFAULT_CHORD,
        "panelKey": DEFAULT_PANEL_KEY,
    }


def _sanitize_action(raw: dict, fallback_id: str) -> dict:
    action_id = str(raw.get("actionId") or raw.get("id") or fallback_id).strip() or fallback_id
    key = str(raw.get("key") or "").strip().upper()
    if len(key) != 1 or not key.isalpha():
        key = ""
    return {
        "id": action_id,
        "actionId": action_id,
        "name": str(raw.get("name") or action_id).strip() or action_id,
        "key": key,
        "enabled": bool(raw.get("enabled", True)),
        "prompt": str(raw.get("prompt") or "").strip(),
    }


def normalize_config(raw: dict | None) -> dict:
    cfg = default_config()
    if not isinstance(raw, dict):
        return cfg

    provider = str(raw.get("provider") or cfg["provider"]).strip().lower()
    if provider in PROVIDERS:
        cfg["provider"] = provider

    keys = raw.get("apiKeys") if isinstance(raw.get("apiKeys"), dict) else {}
    cfg["apiKeys"] = {
        pid: str(value).strip()
        for pid, value in keys.items()
        if pid in PROVIDERS and str(value).strip()
    }

    models = raw.get("models") if isinstance(raw.get("models"), dict) else {}
    for pid, meta in PROVIDERS.items():
        value = str(models.get(pid) or "").strip()
        cfg["models"][pid] = value or meta["model"]

    actions = raw.get("actions")
    if isinstance(actions, list):
        normalized = []
        seen = set()
        for index, item in enumerate(actions):
            if not isinstance(item, dict):
                continue
            action = _sanitize_action(item, f"action-{index + 1}")
            if action["id"] in seen:
                action["id"] = f"{action['id']}-{index + 1}"
                action["actionId"] = action["id"]
            seen.add(action["id"])
            if action["prompt"]:
                normalized.append(action)
        cfg["actions"] = normalized

    chord = str(raw.get("hotkeyChord") or "").strip()
    if chord:
        cfg["hotkeyChord"] = normalize_chord(chord)

    panel_key = str(raw.get("panelKey") or "").strip().upper()
    if len(panel_key) == 1 and panel_key.isalpha():
        cfg["panelKey"] = panel_key

    return cfg


def load_config(path: Path | None = None) -> dict:
    target = path or config_path()
    if not target.exists():
        return default_config()
    try:
        raw = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return default_config()
    return normalize_config(raw)


def save_config(cfg: dict, path: Path | None = None) -> dict:
    target = path or config_path()
    normalized = normalize_config(cfg)
    target.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(normalized, indent=2, ensure_ascii=False) + "\n"
    fd, tmp_name = tempfile.mkstemp(prefix="fluent-", suffix=".json", dir=str(target.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(encoded)
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, target)
        os.chmod(target, 0o600)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise
    return normalized


def key_hint(value: str) -> str:
    text = str(value or "")
    if not text:
        return ""
    if len(text) <= 4:
        return "••••"
    return "••••" + text[-4:]


def public_config(cfg: dict, binds: dict | None = None) -> dict:
    keys = cfg.get("apiKeys") or {}
    snapshot = {
        "provider": cfg["provider"],
        "providers": [
            {
                "id": pid,
                "displayName": meta["displayName"],
                "apiKeyURL": meta["apiKeyURL"],
                "apiKeyPlaceholder": meta["apiKeyPlaceholder"],
                "model": (cfg.get("models") or {}).get(pid, meta["model"]),
                "hasKey": bool(keys.get(pid)),
                "keyHint": key_hint(keys.get(pid, "")),
            }
            for pid, meta in PROVIDERS.items()
        ],
        "actions": [dict(action) for action in cfg["actions"]],
        "hotkeyChord": cfg["hotkeyChord"],
        "panelKey": cfg["panelKey"],
        "hasCurrentKey": bool(keys.get(cfg["provider"])),
    }
    if binds is not None:
        snapshot["binds"] = binds
    return snapshot


def find_action(cfg: dict, action_id: str) -> dict | None:
    needle = str(action_id or "").strip()
    if not needle:
        return None
    for action in cfg["actions"]:
        if action.get("actionId") == needle or action.get("id") == needle:
            return action
    return None


def find_action_by_key(cfg: dict, key: str) -> dict | None:
    letter = str(key or "").strip().upper()
    for action in cfg["actions"]:
        if action.get("enabled") and action.get("key") == letter:
            return action
    return None


def upsert_action(cfg: dict, action: dict) -> dict:
    next_cfg = normalize_config(cfg)
    incoming = _sanitize_action(action, action.get("id") or "action")
    if not incoming["prompt"]:
        raise FluentError("invalid_response", "A prompt is required.")
    replaced = False
    actions = []
    for existing in next_cfg["actions"]:
        if existing["id"] == incoming["id"]:
            actions.append(incoming)
            replaced = True
        else:
            actions.append(existing)
    if not replaced:
        actions.append(incoming)
    next_cfg["actions"] = actions
    return next_cfg


def delete_action(cfg: dict, action_id: str) -> dict:
    next_cfg = normalize_config(cfg)
    remaining = [
        action
        for action in next_cfg["actions"]
        if action.get("actionId") != action_id and action.get("id") != action_id
    ]
    if len(remaining) == len(next_cfg["actions"]):
        raise FluentError("unknown_action")
    next_cfg["actions"] = remaining
    return next_cfg


def normalize_chord(chord: str) -> str:
    parts = [part.strip().upper() for part in str(chord).replace("+", " ").split() if part.strip()]
    names = []
    for part in parts:
        if part in {"SUPER", "MOD4", "WIN", "META"}:
            names.append("SUPER")
        elif part in {"CTRL", "CONTROL", "CTL"}:
            names.append("CTRL")
        elif part in {"ALT", "MOD1"}:
            names.append("ALT")
        elif part in {"SHIFT"}:
            names.append("SHIFT")
        elif part in {"MOD2", "MOD3", "MOD5"}:
            names.append(part)
    order = ["SUPER", "CTRL", "ALT", "SHIFT", "MOD2", "MOD3", "MOD5"]
    unique = [name for name in order if name in names]
    return " + ".join(unique) if unique else DEFAULT_CHORD


def chord_modmask(chord: str) -> int:
    mask = 0
    for part in normalize_chord(chord).split(" + "):
        if part == "SHIFT":
            mask |= MOD_SHIFT
        elif part == "CTRL":
            mask |= MOD_CTRL
        elif part == "ALT":
            mask |= MOD_ALT
        elif part == "SUPER":
            mask |= MOD_SUPER
    return mask


def format_hotkey(chord: str, key: str) -> str:
    letter = str(key or "").strip().upper()
    if not letter:
        return ""
    return f"{normalize_chord(chord)} + {letter}"


def lua_bind_line(chord: str, key: str, description: str, command: str) -> str:
    combo = format_hotkey(chord, key)
    escaped = command.replace("\\", "\\\\").replace('"', '\\"')
    return f'o.bind("{combo}", "{description}", "{escaped}")'


def bind_block(cfg: dict) -> str:
    chord = cfg["hotkeyChord"]
    lines = [BIND_BEGIN]
    lines.append(lua_bind_line(chord, cfg["panelKey"], "Fluent", f"omarchy-shell {PLUGIN_ID} toggle"))
    for action in cfg["actions"]:
        if not action.get("enabled") or not action.get("key"):
            continue
        lines.append(
            lua_bind_line(
                chord,
                action["key"],
                f"Fluent: {action['name']}",
                f"omarchy-shell {PLUGIN_ID} run {action['id']}",
            )
        )
    lines.append(BIND_END)
    return "\n".join(lines) + "\n"


def replace_bind_block(existing: str, block: str) -> str:
    pattern = re.compile(
        rf"{re.escape(BIND_BEGIN)}.*?{re.escape(BIND_END)}\n?",
        re.DOTALL,
    )
    text = existing or ""
    if not text.endswith("\n") and text:
        text += "\n"
    if pattern.search(text):
        return pattern.sub(block, text, count=1)
    if text and not text.endswith("\n"):
        text += "\n"
    if text and not text.endswith("\n\n"):
        text += "\n"
    return text + block


def strip_bind_block(existing: str) -> str:
    pattern = re.compile(
        rf"\n*{re.escape(BIND_BEGIN)}.*?{re.escape(BIND_END)}\n?",
        re.DOTALL,
    )
    return pattern.sub("\n", existing or "", count=1).rstrip() + ("\n" if existing else "")


def bind_installed(existing: str) -> bool:
    return BIND_BEGIN in (existing or "") and BIND_END in (existing or "")


def parse_hypr_binds(raw) -> list[dict]:
    if isinstance(raw, list):
        return [item for item in raw if isinstance(item, dict)]
    return []


def colliding_binds(binds: list[dict], chord: str, keys: list[str]) -> list[dict]:
    mask = chord_modmask(chord)
    wanted = {str(key).upper() for key in keys if key}
    collisions = []
    for bind in binds:
        key = str(bind.get("key") or "").upper()
        if key not in wanted:
            continue
        if int(bind.get("modmask") or 0) != mask:
            continue
        description = str(bind.get("description") or "")
        if description.startswith("Fluent"):
            continue
        collisions.append(
            {
                "key": key,
                "modmask": int(bind.get("modmask") or 0),
                "description": description or "(no description)",
            }
        )
    return collisions


def run_command(command: list[str], timeout: float = 8, input_text: str | None = None, env: dict | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        input=input_text,
        env=env,
    )


def which(name: str) -> str | None:
    return shutil.which(name)


def notify(title: str, body: str, urgency: str = "low") -> None:
    binary = which("notify-send")
    if not binary:
        return
    try:
        run_command([binary, "-a", "Fluent", "-u", urgency, title, body], timeout=3)
    except (OSError, subprocess.TimeoutExpired):
        return


def wl_paste(primary: bool = False) -> str:
    binary = which("wl-paste")
    if not binary:
        return ""
    command = [binary, "--type", "text", "--no-newline"]
    if primary:
        command.append("--primary")
    try:
        completed = run_command(command, timeout=2)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if completed.returncode != 0:
        return ""
    return completed.stdout or ""


def wl_copy(text: str, runner=None, binary: str | None = None) -> None:
    copy_bin = binary or which("wl-copy")
    if not copy_bin:
        raise FluentError("network_error", "wl-copy is not installed.")
    # Do not capture stdout/stderr: wl-copy daemonizes to serve the clipboard,
    # and holding those pipes makes it hang until our timeout.
    run = runner or subprocess.run
    try:
        completed = run(
            [copy_bin, "--type", "text/plain"],
            input=text.encode("utf-8"),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3,
            start_new_session=True,
        )
    except subprocess.TimeoutExpired:
        return
    except OSError as error:
        raise FluentError("network_error", "Could not write to the clipboard.") from error
    if getattr(completed, "returncode", 0) not in (0, None):
        raise FluentError("network_error", "Could not write to the clipboard.")


def active_window_is_terminal(fetcher=None) -> bool:
    fetch = fetcher or (lambda: run_command(["hyprctl", "activewindow", "-j"], timeout=2))
    try:
        completed = fetch()
    except (OSError, subprocess.TimeoutExpired):
        return False
    if completed.returncode != 0 or not completed.stdout:
        return False
    try:
        data = json.loads(completed.stdout)
    except json.JSONDecodeError:
        return False
    tags = data.get("tags") or []
    for tag in tags:
        if str(tag).rstrip("*") == "terminal":
            return True
    klass = str(data.get("class") or "").lower()
    return klass in TERMINAL_CLASSES


def send_shortcut(mods: str, key: str, dispatcher=None) -> None:
    if dispatcher:
        dispatcher(mods, key)
        return
    # Same down/up split Omarchy uses for Super+C/V. wtype merges physically
    # held modifiers (our Ctrl+Alt+Shift chord) into the injected keys.
    lua = (
        "hl.dispatch(hl.dsp.send_key_state({ mods = %s, key = %s, state = \"down\" })); "
        "hl.timer(function() hl.dispatch(hl.dsp.send_key_state({ mods = %s, key = %s, state = \"up\" })) "
        "end, { timeout = 50, type = \"oneshot\" })"
        % (json.dumps(mods), json.dumps(key), json.dumps(mods), json.dumps(key))
    )
    try:
        completed = run_command(["hyprctl", "eval", lua], timeout=2)
        if completed.returncode == 0:
            time.sleep(0.07)
            return
    except (OSError, subprocess.TimeoutExpired, FluentError):
        pass
    wtype = which("wtype")
    if not wtype:
        return
    tokens = [part.strip().lower() for part in mods.split() if part.strip()]
    command = [wtype]
    for token in tokens:
        command.extend(["-M", token])
    command.append(key.lower())
    for token in reversed(tokens):
        command.extend(["-m", token])
    try:
        run_command(command, timeout=2)
    except (OSError, subprocess.TimeoutExpired):
        return


def copy_shortcut(is_terminal: bool) -> tuple[str, str]:
    if is_terminal:
        return "CTRL", "Insert"
    return "CTRL", "C"


def paste_shortcut(is_terminal: bool) -> tuple[str, str]:
    if is_terminal:
        return "SHIFT", "Insert"
    return "CTRL", "V"


def capture_selection(
    *,
    delay: float = 0.35,
    sleeper=time.sleep,
    paste=wl_paste,
    window_is_terminal=active_window_is_terminal,
    shortcut=send_shortcut,
) -> str:
    # Let the triggering chord (Ctrl+Alt+Shift) come up first. If those keys
    # are still down, the copy/paste we inject becomes Ctrl+Alt+Shift+C/V and
    # browsers like Twitter silently ignore it.
    sleeper(delay)
    original = paste(False) or ""
    is_terminal = window_is_terminal()
    mods, key = copy_shortcut(is_terminal)
    shortcut(mods, key)
    sleeper(0.12)
    copied = paste(False) or ""
    if copied.strip() and copied != original:
        return copied
    primary = (paste(True) or "").strip()
    if primary and primary != original.strip():
        return paste(True)
    if copied.strip() and not original.strip():
        return copied
    raise FluentError("no_selection")


def paste_text(
    text: str,
    *,
    restore_after: float = 0.8,
    sleeper=time.sleep,
    paste=wl_paste,
    copy=wl_copy,
    window_is_terminal=active_window_is_terminal,
    shortcut=send_shortcut,
) -> None:
    original = paste(False)
    copy(text)
    sleeper(0.08)
    mods, key = paste_shortcut(window_is_terminal())
    shortcut(mods, key)
    if restore_after > 0:
        sleeper(restore_after)
        if original:
            copy(original)


def map_status_error(status: int, default: str = "server_error") -> FluentError:
    if status in (401, 403):
        return FluentError("invalid_api_key")
    if status == 400:
        return FluentError("invalid_api_key")
    if status == 429:
        return FluentError("rate_limited")
    if status == 200:
        return FluentError("invalid_response")
    return FluentError(default, ERRORS["server_error"].format(status=status), status=status)


def http_json(url: str, headers: dict, body: dict, timeout: float = 60, opener=None) -> tuple[int, dict | None, bytes]:
    encoded = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(url, data=encoded, headers=headers, method="POST")
    open_url = opener or urllib.request.urlopen
    try:
        with open_url(request, timeout=timeout) as response:
            raw = response.read()
            status = getattr(response, "status", 200)
    except urllib.error.HTTPError as error:
        raw = error.read() if error.fp else b""
        status = error.code
    except urllib.error.URLError as error:
        raise FluentError("network_error", f"Network error: {error.reason}") from error
    except TimeoutError as error:
        raise FluentError("network_error", "Network error: timed out") from error

    parsed = None
    if raw:
        try:
            parsed = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            parsed = None
    return status, parsed, raw


def complete_openai(text: str, api_key: str, prompt: str, model: str, opener=None) -> str:
    status, payload, raw = http_json(
        "https://api.openai.com/v1/chat/completions",
        {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        {
            "model": model,
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
            "temperature": 0.7,
        },
        opener=opener,
    )
    if status != 200:
        raise map_status_error(status)
    if not raw:
        raise FluentError("no_content")
    try:
        content = payload["choices"][0]["message"]["content"]
    except (TypeError, KeyError, IndexError):
        raise FluentError("invalid_response") from None
    content = str(content or "").strip()
    if not content:
        raise FluentError("no_content")
    return content


def complete_claude(text: str, api_key: str, prompt: str, model: str, opener=None) -> str:
    status, payload, raw = http_json(
        "https://api.anthropic.com/v1/messages",
        {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        },
        {
            "model": model,
            "max_tokens": 4096,
            "system": prompt,
            "messages": [{"role": "user", "content": text}],
        },
        opener=opener,
    )
    if status != 200:
        raise map_status_error(status)
    if not raw:
        raise FluentError("no_content")
    try:
        content = payload["content"][0]["text"]
    except (TypeError, KeyError, IndexError):
        raise FluentError("invalid_response") from None
    content = str(content or "").strip()
    if not content:
        raise FluentError("no_content")
    return content


def complete_gemini(text: str, api_key: str, prompt: str, model: str, opener=None) -> str:
    from urllib.parse import quote

    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={quote(api_key, safe='')}"
    )
    status, payload, raw = http_json(
        url,
        {"Content-Type": "application/json"},
        {
            "system_instruction": {"parts": [{"text": prompt}]},
            "contents": [{"parts": [{"text": text}]}],
            "generationConfig": {"temperature": 0.7, "maxOutputTokens": 4096},
        },
        opener=opener,
    )
    if status != 200:
        raise map_status_error(status)
    if not raw:
        raise FluentError("no_content")
    try:
        content = payload["candidates"][0]["content"]["parts"][0]["text"]
    except (TypeError, KeyError, IndexError):
        raise FluentError("invalid_response") from None
    content = str(content or "").strip()
    if not content:
        raise FluentError("no_content")
    return content


def complete_grok(text: str, api_key: str, prompt: str, model: str, opener=None) -> str:
    status, payload, raw = http_json(
        "https://api.x.ai/v1/chat/completions",
        {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        {
            "model": model,
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
            "temperature": 0.7,
        },
        opener=opener,
    )
    if status != 200:
        raise map_status_error(status)
    if not raw:
        raise FluentError("no_content")
    try:
        content = payload["choices"][0]["message"]["content"]
    except (TypeError, KeyError, IndexError):
        raise FluentError("invalid_response") from None
    content = str(content or "").strip()
    if not content:
        raise FluentError("no_content")
    return content


COMPLETERS = {
    "openai": complete_openai,
    "claude": complete_claude,
    "gemini": complete_gemini,
    "grok": complete_grok,
}


def complete_text(cfg: dict, text: str, prompt: str, opener=None) -> str:
    provider = cfg["provider"]
    if provider not in COMPLETERS:
        raise FluentError("unknown_provider")
    api_key = (cfg.get("apiKeys") or {}).get(provider, "")
    if not api_key:
        raise FluentError("no_api_key", ERRORS["no_api_key"].format(provider=PROVIDERS[provider]["displayName"]))
    model = (cfg.get("models") or {}).get(provider) or PROVIDERS[provider]["model"]
    return COMPLETERS[provider](text, api_key, prompt, model, opener=opener)


def load_hypr_binds(loader=None) -> list[dict]:
    load = loader or (lambda: run_command(["hyprctl", "binds", "-j"], timeout=3))
    try:
        completed = load()
    except (OSError, subprocess.TimeoutExpired):
        return []
    if completed.returncode != 0 or not completed.stdout:
        return []
    try:
        return parse_hypr_binds(json.loads(completed.stdout))
    except json.JSONDecodeError:
        return []


def bind_keys_for(cfg: dict) -> list[str]:
    keys = [cfg["panelKey"]]
    for action in cfg["actions"]:
        if action.get("enabled") and action.get("key"):
            keys.append(action["key"])
    return keys


def binds_status(cfg: dict, *, existing: str | None = None, hypr_binds: list[dict] | None = None) -> dict:
    text = existing if existing is not None else (
        bindings_path().read_text(encoding="utf-8") if bindings_path().exists() else ""
    )
    binds = hypr_binds if hypr_binds is not None else load_hypr_binds()
    keys = bind_keys_for(cfg)
    collisions = colliding_binds(binds, cfg["hotkeyChord"], keys)
    return {
        "installed": bind_installed(text),
        "chord": cfg["hotkeyChord"],
        "panelKey": cfg["panelKey"],
        "keys": keys,
        "collisions": collisions,
        "block": bind_block(cfg),
    }


def install_binds(cfg: dict, *, path: Path | None = None, hypr_binds: list[dict] | None = None, reload: bool = True) -> dict:
    target = path or bindings_path()
    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    status = binds_status(cfg, existing=existing, hypr_binds=hypr_binds)
    if status["collisions"] and not status["installed"]:
        detail = ", ".join(
            f"{format_hotkey(cfg['hotkeyChord'], item['key'])} is {item['description']}"
            for item in status["collisions"]
        )
        raise FluentError("collision", ERRORS["collision"].format(detail=detail))
    next_text = replace_bind_block(existing, status["block"])
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        shutil.copy2(target, target.with_suffix(target.suffix + ".bak"))
    target.write_text(next_text, encoding="utf-8")
    if reload:
        try:
            run_command(["hyprctl", "reload"], timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            pass
    status["installed"] = True
    return status


def remove_binds(*, path: Path | None = None, reload: bool = True) -> dict:
    target = path or bindings_path()
    if not target.exists():
        return {"installed": False}
    existing = target.read_text(encoding="utf-8")
    target.write_text(strip_bind_block(existing), encoding="utf-8")
    if reload:
        try:
            run_command(["hyprctl", "reload"], timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            pass
    return {"installed": False}


def run_action(
    cfg: dict,
    action_id: str,
    *,
    text: str | None = None,
    paste: bool = True,
    notify_errors: bool = True,
    opener=None,
    capture=capture_selection,
    paste_fn=paste_text,
) -> dict:
    action = find_action(cfg, action_id)
    if action is None:
        raise FluentError("unknown_action")
    if not action.get("enabled"):
        raise FluentError("unknown_action", f"{action['name']} is turned off.")

    source = text if text is not None else capture()
    if not str(source or "").strip():
        raise FluentError("no_selection")

    try:
        result = complete_text(cfg, source, action["prompt"], opener=opener)
    except FluentError as error:
        if notify_errors:
            notify("Fluent", error.message, urgency="normal")
        raise

    if paste:
        paste_fn(result)

    return {
        "ok": True,
        "state": "completed",
        "action": action["id"],
        "name": action["name"],
        "result": result,
    }


def emit(payload: dict, ok: bool = True) -> int:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    return 0 if ok else 1


def cmd_config_dump(args: argparse.Namespace) -> int:
    cfg = load_config()
    binds = binds_status(cfg)
    return emit(public_config(cfg, binds=binds))


def cmd_config_set(args: argparse.Namespace) -> int:
    cfg = load_config()
    if args.provider:
        if args.provider not in PROVIDERS:
            raise FluentError("unknown_provider")
        cfg["provider"] = args.provider
    if args.chord:
        cfg["hotkeyChord"] = args.chord
    if args.panel_key:
        cfg["panelKey"] = args.panel_key
    if args.model:
        if cfg["provider"] not in PROVIDERS:
            raise FluentError("unknown_provider")
        cfg["models"][cfg["provider"]] = args.model
    save_config(cfg)
    return emit(public_config(load_config(), binds=binds_status(load_config())))


def cmd_config_set_key(args: argparse.Namespace) -> int:
    cfg = load_config()
    provider = args.provider or cfg["provider"]
    if provider not in PROVIDERS:
        raise FluentError("unknown_provider")
    key = (args.key or "").strip()
    if key:
        cfg["apiKeys"][provider] = key
    else:
        cfg["apiKeys"].pop(provider, None)
    save_config(cfg)
    return emit(public_config(load_config(), binds=binds_status(load_config())))


def cmd_config_set_action(args: argparse.Namespace) -> int:
    cfg = load_config()
    payload = {
        "id": args.id,
        "name": args.name or args.id,
        "key": args.key or "",
        "prompt": args.prompt or "",
        "enabled": not args.disabled,
    }
    if args.update:
        existing = find_action(cfg, args.id)
        if existing is None:
            raise FluentError("unknown_action")
        payload = {**existing, **{k: v for k, v in payload.items() if v or k in {"enabled", "key"}}}
        if args.prompt:
            payload["prompt"] = args.prompt
        if args.name:
            payload["name"] = args.name
        if args.key is not None:
            payload["key"] = args.key
        if args.disabled:
            payload["enabled"] = False
        if args.enabled:
            payload["enabled"] = True
    save_config(upsert_action(cfg, payload))
    return emit(public_config(load_config(), binds=binds_status(load_config())))


def cmd_config_delete_action(args: argparse.Namespace) -> int:
    cfg = delete_action(load_config(), args.id)
    save_config(cfg)
    return emit(public_config(load_config(), binds=binds_status(load_config())))


def cmd_run(args: argparse.Namespace) -> int:
    cfg = load_config()
    result = run_action(
        cfg,
        args.action,
        text=args.text,
        paste=not args.no_paste,
        notify_errors=not args.quiet,
    )
    if args.quiet_result:
        result = {k: v for k, v in result.items() if k != "result"}
    return emit(result)


def cmd_complete(args: argparse.Namespace) -> int:
    cfg = load_config()
    if args.provider:
        cfg["provider"] = args.provider
    action = find_action(cfg, args.action) if args.action else None
    prompt = args.prompt or (action["prompt"] if action else "")
    if not prompt:
        raise FluentError("unknown_action", "A prompt is required.")
    text = args.text if args.text is not None else sys.stdin.read()
    result = complete_text(cfg, text, prompt)
    return emit({"ok": True, "result": result})


def cmd_capture(_args: argparse.Namespace) -> int:
    text = capture_selection()
    return emit({"ok": True, "text": text})


def cmd_binds_status(_args: argparse.Namespace) -> int:
    return emit(binds_status(load_config()))


def cmd_binds_install(_args: argparse.Namespace) -> int:
    return emit(install_binds(load_config()))


def cmd_binds_remove(_args: argparse.Namespace) -> int:
    return emit(remove_binds())


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="fluent", description="Fluent App for Omarchy")
    sub = parser.add_subparsers(dest="command", required=True)

    config = sub.add_parser("config", help="Read or write local Fluent settings")
    config_sub = config.add_subparsers(dest="config_command", required=True)
    config_sub.add_parser("dump").set_defaults(func=cmd_config_dump)

    setter = config_sub.add_parser("set")
    setter.add_argument("--provider")
    setter.add_argument("--chord")
    setter.add_argument("--panel-key")
    setter.add_argument("--model")
    setter.set_defaults(func=cmd_config_set)

    key = config_sub.add_parser("set-key")
    key.add_argument("--provider")
    key.add_argument("--key", default="")
    key.set_defaults(func=cmd_config_set_key)

    action = config_sub.add_parser("set-action")
    action.add_argument("--id", required=True)
    action.add_argument("--name")
    action.add_argument("--key")
    action.add_argument("--prompt")
    action.add_argument("--disabled", action="store_true")
    action.add_argument("--enabled", action="store_true")
    action.add_argument("--update", action="store_true")
    action.set_defaults(func=cmd_config_set_action)

    delete = config_sub.add_parser("delete-action")
    delete.add_argument("--id", required=True)
    delete.set_defaults(func=cmd_config_delete_action)

    run = sub.add_parser("run", help="Capture selection, transform it, and paste")
    run.add_argument("--action", required=True)
    run.add_argument("--text")
    run.add_argument("--no-paste", action="store_true")
    run.add_argument("--quiet", action="store_true")
    run.add_argument("--quiet-result", action="store_true")
    run.set_defaults(func=cmd_run)

    complete = sub.add_parser("complete", help="Transform text without touching the selection")
    complete.add_argument("--action")
    complete.add_argument("--provider")
    complete.add_argument("--prompt")
    complete.add_argument("--text")
    complete.set_defaults(func=cmd_complete)

    sub.add_parser("capture").set_defaults(func=cmd_capture)

    binds = sub.add_parser("binds", help="Install or remove Hyprland shortcuts")
    binds_sub = binds.add_subparsers(dest="binds_command", required=True)
    binds_sub.add_parser("status").set_defaults(func=cmd_binds_status)
    binds_sub.add_parser("install").set_defaults(func=cmd_binds_install)
    binds_sub.add_parser("remove").set_defaults(func=cmd_binds_remove)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except FluentError as error:
        return emit(error.as_dict(), ok=False)
    except KeyboardInterrupt:
        return emit({"ok": False, "error": "busy", "message": "Cancelled."}, ok=False)
    except Exception as error:
        return emit({"ok": False, "error": "unknown", "message": str(error) or error.__class__.__name__}, ok=False)


if __name__ == "__main__":
    sys.exit(main())
