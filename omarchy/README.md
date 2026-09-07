# Fluent for Omarchy

AI text shortcuts in the Omarchy bar. Select text in any app, trigger an action, and Fluent translates, rewrites, fixes grammar, summarizes, or changes the tone — then pastes the result back in place.

Same job as the [macOS app](https://github.com/alfonsobries/fluent-app). The panel is built for Omarchy Quattro: `PanelHero`, action rows, provider pills, keyboard navigation.

API keys stay in `~/.config/fluent-app/omarchy.json` (mode 0600). Text goes to the provider you picked. No telemetry, no Fluent backend.

## Install

```sh
omarchy plugin add https://github.com/alfonsobries/fluent-omarchy.git --enable
```

Pick a bar section when prompted (`right` is the default). Then:

1. Click the Fluent icon in the bar.
2. Paste an OpenAI, Anthropic, Gemini, or xAI API key and press Save.
3. Optionally click **Install Ctrl+Alt+Shift shortcuts**.

## Update

Omarchy updates git-installed plugins in place. There is no separate Fluent
release artifact for Linux — `main` on this repository *is* the release:

```sh
omarchy plugin update io.github.alfonsobries.fluent
```

Source of truth is `omarchy/` in [alfonsobries/fluent-app](https://github.com/alfonsobries/fluent-app). A GitHub Action copies that folder here on every merge to main.

Listed on the marketplace after review: https://github.com/omacom/omarchy-plugin-marketplace/issues/5445

## Usage

- **Left-click** the bar icon to open or close the panel. The panel is for settings: API key, provider, and each action's prompt.
- Click an action (or press **Enter**) to edit its name, key, prompt, or to disable it. **+** adds a new action.
- Rewrite happens with the global shortcuts, so the original app keeps focus and the selection can be replaced in place.
- **j / k** move. **h / l** walk providers. Escape closes.
- Global shortcuts (after install):

| Shortcut | Action |
| --- | --- |
| Ctrl+Alt+Shift+T | Translate |
| Ctrl+Alt+Shift+O | Improve writing |
| Ctrl+Alt+Shift+G | Fix grammar |
| Ctrl+Alt+Shift+S | Summarize |
| Ctrl+Alt+Shift+P | Make professional |
| Ctrl+Alt+Shift+F | Open the Fluent panel |

Those letters match the actions. The chord is `Ctrl+Alt+Shift` because Omarchy already uses Super+T/O/G/S/P for tiling, Super+Shift+O/G/S/P for preinstalled apps, and Super+Ctrl+T/O/S/P for shell panels. Every shortcut is editable from the panel.

## Remove

```sh
omarchy plugin remove io.github.alfonsobries.fluent
```

If you installed shortcuts, remove them from the panel first, or delete the `fluent-app:begin` / `fluent-app:end` block in `~/.config/hypr/bindings.lua`.

## Develop

```sh
python3 tests/test_fluent.py
node tests/test_model.js
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Panel.qml FluentIcon.qml
```

The helper CLI is `bin/fluent.py`. It owns config, providers, capture/paste, and Hyprland binds so the QML stays a panel.

## License

MIT. See [LICENSE](LICENSE).
