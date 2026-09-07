#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from urllib.error import URLError

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("fluent", ROOT / "bin" / "fluent.py")
fluent = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fluent)


class FakeResponse:
    def __init__(self, payload, status=200):
        self._payload = json.dumps(payload).encode("utf-8") if not isinstance(payload, bytes) else payload
        self.status = status

    def read(self):
        return self._payload

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeHTTPError(Exception):
    def __init__(self, status, payload):
        super().__init__(status)
        self.code = status
        self.fp = io.BytesIO(json.dumps(payload).encode("utf-8") if payload is not None else b"")

    def read(self):
        return self.fp.read()


def opener_for(status, payload):
    def opener(request, timeout=60):
        if status >= 400:
            raise fluent.urllib.error.HTTPError(request.full_url, status, "err", hdrs=None, fp=io.BytesIO(
                json.dumps(payload).encode("utf-8") if payload is not None else b""
            ))
        return FakeResponse(payload if payload is not None else b"", status=status)
    return opener


class ConfigTests(unittest.TestCase):
    def test_default_actions_and_keys(self):
        cfg = fluent.default_config()
        self.assertEqual(cfg["provider"], "openai")
        self.assertEqual([a["id"] for a in cfg["actions"]], ["translate", "improve", "grammar", "summarize", "tone"])
        self.assertEqual([a["key"] for a in cfg["actions"]], ["T", "O", "G", "S", "P"])
        self.assertEqual(cfg["hotkeyChord"], "CTRL + ALT + SHIFT")
        self.assertEqual(cfg["panelKey"], "F")

    def test_normalize_drops_unknown_provider_and_blank_keys(self):
        cfg = fluent.normalize_config({
            "provider": "nope",
            "apiKeys": {"openai": "  sk-live  ", "other": "x", "claude": ""},
            "actions": [{"id": "translate", "name": "T", "key": "tt", "prompt": "p"}],
        })
        self.assertEqual(cfg["provider"], "openai")
        self.assertEqual(cfg["apiKeys"], {"openai": "sk-live"})
        self.assertEqual(cfg["actions"][0]["key"], "")

    def test_round_trip_config_file_is_0600(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "omarchy.json"
            cfg = fluent.default_config()
            cfg["apiKeys"]["openai"] = "sk-secret"
            fluent.save_config(cfg, path)
            self.assertEqual(oct(path.stat().st_mode & 0o777), "0o600")
            loaded = fluent.load_config(path)
            self.assertEqual(loaded["apiKeys"]["openai"], "sk-secret")

    def test_public_config_redacts_keys(self):
        cfg = fluent.default_config()
        cfg["apiKeys"]["openai"] = "sk-123456789"
        snapshot = fluent.public_config(cfg)
        self.assertTrue(snapshot["hasCurrentKey"])
        self.assertEqual(snapshot["providers"][0]["keyHint"], "••••6789")
        self.assertNotIn("sk-123456789", json.dumps(snapshot))

    def test_upsert_and_delete_action(self):
        cfg = fluent.default_config()
        cfg = fluent.upsert_action(cfg, {"id": "joke", "name": "Joke", "key": "J", "prompt": "Make it funny."})
        self.assertEqual(cfg["actions"][-1]["id"], "joke")
        cfg = fluent.delete_action(cfg, "joke")
        self.assertIsNone(fluent.find_action(cfg, "joke"))
        with self.assertRaises(fluent.FluentError):
            fluent.delete_action(cfg, "missing")


class HotkeyTests(unittest.TestCase):
    def test_chord_normalization_and_modmask(self):
        self.assertEqual(fluent.normalize_chord("ctrl+alt+shift"), "CTRL + ALT + SHIFT")
        self.assertEqual(fluent.chord_modmask("CTRL + ALT + SHIFT"), 13)
        self.assertEqual(fluent.chord_modmask("SUPER + SHIFT"), 65)
        self.assertEqual(fluent.format_hotkey("CTRL + ALT + SHIFT", "t"), "CTRL + ALT + SHIFT + T")

    def test_bind_block_covers_panel_and_enabled_actions(self):
        block = fluent.bind_block(fluent.default_config())
        self.assertIn("CTRL + ALT + SHIFT + F", block)
        self.assertIn("CTRL + ALT + SHIFT + T", block)
        self.assertIn("omarchy-shell io.github.alfonsobries.fluent run translate", block)
        self.assertIn(fluent.BIND_BEGIN, block)

    def test_replace_and_strip_bind_block_are_idempotent(self):
        original = "-- Keep only your personal keybinding overrides here.\n"
        block = fluent.bind_block(fluent.default_config())
        once = fluent.replace_bind_block(original, block)
        twice = fluent.replace_bind_block(once, block)
        self.assertEqual(once.count(fluent.BIND_BEGIN), 1)
        self.assertEqual(twice, once)
        stripped = fluent.strip_bind_block(once)
        self.assertNotIn(fluent.BIND_BEGIN, stripped)
        self.assertIn("Keep only your personal", stripped)

    def test_collisions_ignore_fluent_and_other_modmasks(self):
        binds = [
            {"key": "T", "modmask": 13, "description": "Something else"},
            {"key": "T", "modmask": 64, "description": "Toggle window floating/tiling"},
            {"key": "O", "modmask": 13, "description": "Fluent: Improve writing"},
        ]
        collisions = fluent.colliding_binds(binds, "CTRL + ALT + SHIFT", ["T", "O", "G"])
        self.assertEqual(len(collisions), 1)
        self.assertEqual(collisions[0]["key"], "T")

    def test_install_refuses_collisions_then_writes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bindings.lua"
            path.write_text("-- user\n", encoding="utf-8")
            cfg = fluent.default_config()
            with self.assertRaises(fluent.FluentError) as raised:
                fluent.install_binds(
                    cfg,
                    path=path,
                    hypr_binds=[{"key": "T", "modmask": 13, "description": "Taken"}],
                    reload=False,
                )
            self.assertEqual(raised.exception.code, "collision")
            self.assertEqual(path.read_text(encoding="utf-8"), "-- user\n")

            status = fluent.install_binds(cfg, path=path, hypr_binds=[], reload=False)
            self.assertTrue(status["installed"])
            self.assertIn("Fluent: Translate", path.read_text(encoding="utf-8"))
            self.assertTrue((path.with_suffix(".lua.bak")).exists() or Path(str(path) + ".bak").exists())
            fluent.remove_binds(path=path, reload=False)
            self.assertNotIn(fluent.BIND_BEGIN, path.read_text(encoding="utf-8"))


class ClipboardTests(unittest.TestCase):
    def test_wl_copy_does_not_hold_pipes(self):
        calls = []

        def runner(*args, **kwargs):
            calls.append(kwargs)
            return SimpleNamespace(returncode=0)

        fluent.wl_copy("hello", runner=runner)
        self.assertEqual(len(calls), 1)
        self.assertIs(calls[0]["stdout"], __import__("subprocess").DEVNULL)
        self.assertIs(calls[0]["stderr"], __import__("subprocess").DEVNULL)
        self.assertNotIn("capture_output", calls[0])
        self.assertIsInstance(calls[0]["input"], (bytes, bytearray))
        self.assertTrue(calls[0]["start_new_session"])

    def test_wl_copy_timeout_is_success(self):
        def runner(*args, **kwargs):
            raise subprocess.TimeoutExpired(cmd="wl-copy", timeout=3)

        fluent.wl_copy("hello", runner=runner)


class CaptureTests(unittest.TestCase):
    def test_primary_selection_wins(self):
        def paste(primary=False):
            return "highlighted" if primary else "clipboard"

        text = fluent.capture_selection(
            delay=0,
            sleeper=lambda _s: None,
            paste=paste,
            window_is_terminal=lambda: False,
            shortcut=lambda *_a: self.fail("should not send a shortcut"),
        )
        self.assertEqual(text, "highlighted")

    def test_copy_fallback_and_no_selection(self):
        state = {"clipboard": "old", "sent": []}

        def paste(primary=False):
            if primary:
                return ""
            return state["clipboard"]

        def shortcut(mods, key):
            state["sent"].append((mods, key))
            state["clipboard"] = "copied"

        text = fluent.capture_selection(
            delay=0,
            sleeper=lambda _s: None,
            paste=paste,
            window_is_terminal=lambda: False,
            shortcut=shortcut,
        )
        self.assertEqual(text, "copied")
        self.assertEqual(state["sent"], [("CTRL", "C")])

        state["clipboard"] = "old"
        def shortcut_noop(mods, key):
            state["sent"].append((mods, key))

        with self.assertRaises(fluent.FluentError) as raised:
            fluent.capture_selection(
                delay=0,
                sleeper=lambda _s: None,
                paste=lambda primary=False: "" if primary else "old",
                window_is_terminal=lambda: True,
                shortcut=shortcut_noop,
            )
        self.assertEqual(raised.exception.code, "no_selection")

    def test_terminal_uses_insert_chords(self):
        self.assertEqual(fluent.copy_shortcut(True), ("CTRL", "Insert"))
        self.assertEqual(fluent.paste_shortcut(True), ("SHIFT", "Insert"))
        self.assertTrue(fluent.active_window_is_terminal(lambda: SimpleNamespace(
            returncode=0, stdout='{"class":"Alacritty","tags":["terminal"]}'
        )))
        self.assertFalse(fluent.active_window_is_terminal(lambda: SimpleNamespace(
            returncode=0, stdout='{"class":"google-chrome","tags":[]}'
        )))


class ProviderTests(unittest.TestCase):
    def test_empty_key_and_unknown_provider(self):
        cfg = fluent.default_config()
        with self.assertRaises(fluent.FluentError) as raised:
            fluent.complete_text(cfg, "hola", "inst")
        self.assertEqual(raised.exception.code, "no_api_key")
        self.assertIn("OpenAI (GPT)", raised.exception.message)

        cfg["provider"] = "nope"
        with self.assertRaises(fluent.FluentError) as raised:
            fluent.complete_text(cfg, "hola", "inst")
        self.assertEqual(raised.exception.code, "unknown_provider")

    def test_openai_success_and_errors(self):
        cfg = fluent.default_config()
        cfg["apiKeys"]["openai"] = "key"
        result = fluent.complete_text(
            cfg, "hola", "inst",
            opener=opener_for(200, {"choices": [{"message": {"content": " hello "}}]}),
        )
        self.assertEqual(result, "hello")

        with self.assertRaises(fluent.FluentError) as raised:
            fluent.complete_text(cfg, "hola", "inst", opener=opener_for(200, {"choices": []}))
        self.assertEqual(raised.exception.code, "invalid_response")

        with self.assertRaises(fluent.FluentError) as raised:
            fluent.complete_text(cfg, "hola", "inst", opener=opener_for(200, b""))
        self.assertEqual(raised.exception.code, "no_content")

        with self.assertRaises(fluent.FluentError) as raised:
            fluent.complete_text(cfg, "hola", "inst", opener=opener_for(401, {}))
        self.assertEqual(raised.exception.code, "invalid_api_key")

        with self.assertRaises(fluent.FluentError) as raised:
            fluent.complete_text(cfg, "hola", "inst", opener=opener_for(429, {}))
        self.assertEqual(raised.exception.code, "rate_limited")

        with self.assertRaises(fluent.FluentError) as raised:
            fluent.complete_text(cfg, "hola", "inst", opener=opener_for(503, {}))
        self.assertEqual(raised.exception.code, "server_error")
        self.assertEqual(raised.exception.status, 503)

    def test_claude_gemini_grok_parsers(self):
        cfg = fluent.default_config()
        cfg["apiKeys"]["claude"] = "key"
        cfg["provider"] = "claude"
        self.assertEqual(
            fluent.complete_text(cfg, "hola", "inst", opener=opener_for(200, {"content": [{"text": " bonjour "}]})),
            "bonjour",
        )

        cfg["provider"] = "gemini"
        cfg["apiKeys"]["gemini"] = "key"
        self.assertEqual(
            fluent.complete_text(cfg, "hola", "inst", opener=opener_for(200, {
                "candidates": [{"content": {"parts": [{"text": " resumen "}]}}]
            })),
            "resumen",
        )

        cfg["provider"] = "grok"
        cfg["apiKeys"]["grok"] = "key"
        self.assertEqual(
            fluent.complete_text(cfg, "hola", "inst", opener=opener_for(200, {
                "choices": [{"message": {"content": " rewrite "}}]
            })),
            "rewrite",
        )

    def test_network_error(self):
        cfg = fluent.default_config()
        cfg["apiKeys"]["openai"] = "key"

        def opener(request, timeout=60):
            raise URLError("boom")

        with self.assertRaises(fluent.FluentError) as raised:
            fluent.complete_text(cfg, "hola", "inst", opener=opener)
        self.assertEqual(raised.exception.code, "network_error")
        self.assertIn("boom", raised.exception.message)


class RunActionTests(unittest.TestCase):
    def test_run_action_pastes_on_success(self):
        cfg = fluent.default_config()
        cfg["apiKeys"]["openai"] = "key"
        pasted = []
        result = fluent.run_action(
            cfg,
            "translate",
            text="Hola",
            paste=True,
            notify_errors=False,
            opener=opener_for(200, {"choices": [{"message": {"content": "Hello"}}]}),
            capture=lambda: self.fail("should use explicit text"),
            paste_fn=lambda value: pasted.append(value),
        )
        self.assertEqual(result["result"], "Hello")
        self.assertEqual(pasted, ["Hello"])

    def test_run_action_unknown_and_empty(self):
        cfg = fluent.default_config()
        with self.assertRaises(fluent.FluentError) as raised:
            fluent.run_action(cfg, "nope", text="x", paste=False, notify_errors=False)
        self.assertEqual(raised.exception.code, "unknown_action")

        cfg["apiKeys"]["openai"] = "key"
        with self.assertRaises(fluent.FluentError) as raised:
            fluent.run_action(cfg, "translate", text="   ", paste=False, notify_errors=False)
        self.assertEqual(raised.exception.code, "no_selection")


if __name__ == "__main__":
    unittest.main()
