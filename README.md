# Fluent

Fluent is a native macOS menu bar app for AI-powered text shortcuts. Select text anywhere, trigger a global shortcut, and Fluent rewrites, translates, summarizes, or transforms the text and pastes the result back.

## What Changed

- Dedicated settings window instead of editing inside the menu bar popover.
- Shortcut management rebuilt around reusable templates and a persistent editor.
- Core logic moved into a testable `FluentCore` module.
- Build, release, signing, notarization, and coverage commands standardized.
- GitHub Actions prepared for CI, releases, and Apple-signed distribution.

## Product Goals

- Fast global shortcuts for text workflows.
- Simple path to add more actions later.
- Public open source release quality, not a one-off personal utility.
- Clean release artifacts for GitHub and Apple distribution.

## Current Shortcut Templates

- `Cmd+Shift+O`: Translate
- `Cmd+Shift+I`: Improve Writing
- `Cmd+Shift+G`: Fix Grammar
- `Cmd+Shift+S`: Summarize
- `Cmd+Shift+P`: Make Professional

You can add blank shortcuts or start from templates in the Shortcuts tab.

## Supported Providers

- OpenAI
- Anthropic
- Google Gemini
- xAI Grok

## Local Commands

```bash
make build
make test
make coverage
make dmg
make release VERSION=1.2.0
```

Equivalent scripts:

```bash
./scripts/test_coverage.sh
VERSION=1.2.0 ./build_dmg.sh
./scripts/release.sh 1.2.0
```

## Development Setup

Requirements:

- macOS 13 or newer
- Xcode Command Line Tools
- Optional for icon generation: `brew install librsvg`

Run locally:

```bash
swift run FluentApp
```

## Installation Flow

1. Download the latest DMG from GitHub Releases.
2. Drag `FluentApp.app` to `/Applications`.
3. Launch Fluent.
4. Grant Accessibility access in System Settings.
5. Add an API key for your preferred provider.
6. Configure or add shortcuts in the Settings window.

## Release Flow

Local maintainer flow:

```bash
make coverage
VERSION=1.2.0 ./build_dmg.sh
./scripts/release.sh 1.2.0
```

GitHub flow:

- `release-please.yml` manages changelog and version PRs.
- `release.yml` builds a DMG when a `v*` tag is pushed or when run manually.
- `ci.yml` validates build, tests, coverage, and website build.

## Apple Signing And Notarization

The repo is ready for signing and notarization, but you still need to provide the Apple credentials and certificates yourself.

Local environment variables:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export APPLE_APP_SPECIFIC_PASSWORD="app-specific-password"
export APPLE_TEAM_ID="TEAMID"
export NOTARIZE=1
```

GitHub secrets expected by `release.yml`:

- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `KEYCHAIN_PASSWORD`
- `DEVELOPER_ID_APPLICATION`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

What you still need to do manually outside this repo:

- Create/export the Developer ID Application certificate as `.p12`.
- Generate an app-specific password for notarization.
- Confirm the final bundle identifier you want to ship.
- Validate the release on a clean Mac before public launch.

## Architecture

The package is split intentionally:

- `FluentCore`: models, providers, settings logic, controller logic, testable contracts.
- `FluentMacSupport`: live macOS integrations for clipboard, hotkeys, launch at login.
- `FluentApp`: SwiftUI shell and settings UI.

This makes new shortcuts easy to add without touching the live platform adapters.

## Privacy

- API keys stay local on your Mac.
- Text goes directly from Fluent to the provider you selected.
- No analytics, telemetry, or remote app backend is included.

## Website

The landing site lives in `expo/`.

```bash
cd expo
npm ci
npm run build
```

## License

MIT. See [LICENSE](LICENSE).
