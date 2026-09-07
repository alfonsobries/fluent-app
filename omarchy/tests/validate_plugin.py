#!/usr/bin/env python3
"""Mirror `omarchy plugin validate` so CI can check the folder without Omarchy."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

KIND_ENTRY = {
    "bar": "bar",
    "bar-widget": "barWidget",
    "menu": "menu",
    "overlay": "overlay",
    "panel": "panel",
    "service": "service",
}

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def fail(message: str) -> None:
    print(f"omarchy-plugin-validate: {message}", file=sys.stderr)
    sys.exit(1)


def main(argv: list[str]) -> int:
    if not argv:
        fail("plugin folder not found: <none>")
    plugin_dir = Path(argv[0])
    if not plugin_dir.is_dir():
        fail(f"plugin folder not found: {plugin_dir}")

    manifest_path = plugin_dir / "manifest.json"
    if not manifest_path.is_file():
        fail(f"missing manifest.json in {plugin_dir}")

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        fail(f"manifest.json is not valid JSON: {manifest_path}")

    if manifest.get("schemaVersion") != 1:
        fail("unsupported or missing schemaVersion (expected 1)")

    for field in ("id", "name", "version", "kinds", "entryPoints"):
        if field not in manifest:
            fail(f"manifest missing required field '{field}'")

    plugin_id = str(manifest.get("id") or "")
    if not plugin_id:
        fail("manifest 'id' is empty")
    if not ID_RE.match(plugin_id) or ".." in plugin_id:
        fail(f"invalid plugin id '{plugin_id}'")
    if plugin_id.startswith("omarchy."):
        fail(f"plugin id '{plugin_id}' uses the reserved omarchy.* namespace")

    kinds = manifest.get("kinds")
    if not isinstance(kinds, list) or not kinds:
        fail("'kinds' must be a non-empty array")

    entry_points = manifest.get("entryPoints")
    if not isinstance(entry_points, dict):
        fail("'entryPoints' must be an object")

    bar_widget = manifest.get("barWidget")
    if isinstance(bar_widget, dict) and "defaultSection" in bar_widget:
        if bar_widget["defaultSection"] not in ("left", "center", "right"):
            fail("'barWidget.defaultSection' must be left, center, or right")

    for value in entry_points.values():
        if not isinstance(value, str) or not value:
            fail("entry point path is empty")
        if "\n" in value:
            fail("entry point may not contain a newline")
        if value.startswith("/"):
            fail(f"entry point must be a relative path: '{value}'")
        if ".." in value:
            fail(f"entry point may not contain '..': '{value}'")
        if not (plugin_dir / value).is_file():
            fail(f"entry point file not found: '{value}'")

    for kind in kinds:
        key = KIND_ENTRY.get(kind)
        if key and key not in entry_points:
            fail(f"kind '{kind}' requires an 'entryPoints.{key}' to load")

    for dirpath, dirnames, filenames in os.walk(plugin_dir):
        dirnames[:] = [name for name in dirnames if name != ".git"]
        for name in dirnames + filenames:
            path = Path(dirpath) / name
            if path.is_symlink():
                fail(f"symlinks are not allowed inside a plugin folder: {path}")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
