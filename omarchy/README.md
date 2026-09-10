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

Keys live in `~/.config/fluent-app/omarchy.json` (mode 0600). They are not written to `shell.json` and they never travel in argv; the panel sends a key over stdin.

## Network

The helper POSTs only to these HTTPS origins and refuses redirects:

- `https://api.openai.com/v1/chat/completions`
- `https://api.anthropic.com/v1/messages`
- `https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent`
- `https://api.x.ai/v1/chat/completions`

## Limits

External input is streamed with a hard ceiling. Overflow is rejected, never truncated, and is not parsed or sent to a provider. Timeouts are unchanged (2s clipboard, 60s providers).

| Source | Ceiling |
| --- | --- |
| Clipboard (`wl-paste`) and `complete` stdin | 256 KiB |
| Provider success and error HTTP bodies | 1 MiB |
| Config file | 64 KiB |
| Helper stdout collected by the panel | 64 KiB |

## Remove

`omarchy plugin remove io.github.alfonsobries.fluent` deletes the plugin files.

It does **not** delete `~/.config/fluent-app/omarchy.json` (API keys) and it does **not** strip shortcuts from `~/.config/hypr/bindings.lua`. Remove the shortcuts from the panel first, or delete the marked `-- fluent-app:begin` … `-- fluent-app:end` block yourself.

MIT. Tests: `bash tests/run.sh`.
