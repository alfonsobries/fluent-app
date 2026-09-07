# Fluent for Omarchy

Select text, press a shortcut, rewrite in place. Panel is for the API key, provider, and prompts.

```sh
omarchy plugin add https://github.com/alfonsobries/fluent-omarchy.git --enable
omarchy plugin update io.github.alfonsobries.fluent
omarchy plugin remove io.github.alfonsobries.fluent
```

| Shortcut | Action |
| --- | --- |
| Ctrl+Alt+Shift+T | Translate |
| Ctrl+Alt+Shift+O | Improve writing |
| Ctrl+Alt+Shift+G | Fix grammar |
| Ctrl+Alt+Shift+S | Summarize |
| Ctrl+Alt+Shift+P | Make professional |
| Ctrl+Alt+Shift+F | Open the panel |

Keys live in `~/.config/fluent-app/omarchy.json`. MIT. Tests: `bash tests/run.sh`.
