# TranslateTool

A lightweight macOS menu bar app that processes selected text using AI. Translate, improve writing, fix grammar, and more with customizable keyboard shortcuts.

![CI](https://github.com/alfonsobries/translate-tool/actions/workflows/ci.yml/badge.svg)
![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Multiple AI Providers**: Choose between OpenAI, Claude, Gemini, or Grok
- **Multiple Actions**: Define unlimited shortcuts with custom AI instructions
- **Global Shortcuts**: Trigger actions from any application
- **Custom Instructions**: Tailor AI behavior for each shortcut
- **Shortcut Recorder**: Capture keyboard shortcuts visually
- **Privacy First**: API keys stored locally, no data collection
- **Native Performance**: Built with Swift, minimal resource usage

## Supported AI Providers

| Provider | Model | Get API Key |
|----------|-------|-------------|
| **OpenAI** | GPT-4o-mini | [platform.openai.com](https://platform.openai.com/api-keys) |
| **Anthropic** | Claude 3 Haiku | [console.anthropic.com](https://console.anthropic.com/api-keys) |
| **Google** | Gemini 1.5 Flash | [aistudio.google.com](https://aistudio.google.com/apikey) |
| **xAI** | Grok | [console.x.ai](https://console.x.ai) |

## Default Shortcuts

| Shortcut | Action | Description |
|----------|--------|-------------|
| `Cmd+Shift+O` | Translate | Detect language and translate |
| `Cmd+Shift+I` | Improve Writing | Enhance grammar, clarity, style |
| `Cmd+Shift+G` | Fix Grammar | Correct spelling and grammar (disabled by default) |

All shortcuts are fully customizable in the app settings.

## Installation

### Download (Recommended)

1. Download the latest release from [GitHub Releases](https://github.com/alfonsobries/translate-tool/releases)
2. Open the DMG file
3. Drag TranslateTool to your Applications folder
4. Open TranslateTool from Applications
5. Grant Accessibility permissions when prompted

### Build from Source

**Requirements:**
- macOS 13.0 or later
- Xcode Command Line Tools (`xcode-select --install`)

```bash
# Clone the repository
git clone https://github.com/alfonsobries/translate-tool.git
cd translate-tool

# Run in development mode
swift run

# Run tests
swift test

# Build a release DMG
./build_dmg.sh
```

## Setup

1. **Grant Permissions**
   - On first launch, macOS will ask for Accessibility permissions
   - Go to System Settings > Privacy & Security > Accessibility
   - Enable TranslateTool

2. **Select AI Provider**
   - Click the globe icon in your menu bar
   - Choose your preferred AI provider from the dropdown

3. **Add API Key**
   - Click "Add" or "Edit" next to your chosen provider
   - Enter your API key
   - Keys are stored securely on your device

4. **Configure Shortcuts** (Optional)
   - Click the + button to add new shortcuts
   - Click the pencil icon to edit existing ones
   - Record custom keyboard combinations
   - Write your own AI instructions

## Creating Custom Actions

Each action consists of:

- **Name**: Descriptive name shown in the menu
- **Shortcut**: Keyboard combination to trigger the action
- **Instructions**: AI prompt that defines the behavior

### Example: Summarize Text

```
Name: Summarize
Shortcut: Cmd+Shift+S
Instructions: Summarize the following text in 2-3 concise bullet points. Keep the same language as the original.
```

### Example: Make Formal

```
Name: Make Formal
Shortcut: Cmd+Shift+F
Instructions: Rewrite the following text in a formal, professional tone. Maintain the original meaning and language.
```

## Architecture

TranslateTool uses a **Contract/Provider pattern** (similar to Laravel's Service Container) for AI services:

```
┌─────────────────────────────────────────────────────┐
│                  AIProvider Protocol                │
│  (Contract defining processText interface)          │
└─────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ OpenAI      │  │ Claude      │  │ Gemini      │ ...
│ Provider    │  │ Provider    │  │ Provider    │
└─────────────┘  └─────────────┘  └─────────────┘
         │               │               │
         └───────────────┼───────────────┘
                         ▼
              ┌─────────────────────┐
              │ AIProviderFactory   │
              │ (Dependency Resolver)│
              └─────────────────────┘
```

This makes it easy to add new AI providers by implementing the `AIProvider` protocol.

## Project Structure

```
translate-tool/
├── Sources/TranslateTool/
│   ├── TranslateToolApp.swift      # App entry point
│   ├── Contracts/
│   │   ├── AIProvider.swift        # Provider protocol
│   │   └── AIProviderFactory.swift # Dependency resolver
│   ├── Providers/
│   │   ├── OpenAIProvider.swift    # OpenAI implementation
│   │   ├── ClaudeProvider.swift    # Claude implementation
│   │   ├── GeminiProvider.swift    # Gemini implementation
│   │   └── GrokProvider.swift      # Grok implementation
│   ├── Model/
│   │   ├── AppSettings.swift       # Settings persistence
│   │   └── ShortcutAction.swift    # Action model
│   ├── Services/
│   │   ├── AppController.swift     # Main controller
│   │   ├── HotKeyManager.swift     # Global shortcuts
│   │   └── ClipboardService.swift  # Text manipulation
│   └── UI/
│       ├── SettingsView.swift           # Main settings UI
│       ├── AIProviderSettingsView.swift # Provider config
│       ├── ShortcutEditView.swift       # Action editor
│       └── ShortcutRecorderView.swift   # Shortcut capture
├── Tests/TranslateToolTests/       # Unit tests
├── Resources/
│   ├── AppIcon.svg                 # App icon source
│   └── generate_icon.sh            # Icon generator
├── expo/                           # Project website (Astro)
├── .github/workflows/              # CI/CD pipelines
├── scripts/
│   └── release.sh                  # Release automation
├── build_dmg.sh                    # Build script
└── Package.swift                   # Swift package config
```

## Creating Releases

For maintainers:

```bash
# Create a new release manually
VERSION=1.0.0 ./build_dmg.sh

# Or push a tag to trigger automated release
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will automatically build and publish the release.

## Website

The project website is in the `expo/` directory, built with Astro.

```bash
cd expo
npm install
npm run dev      # Development server
npm run build    # Build for production
```

## Requirements

- **macOS**: 13.0 (Ventura) or later
- **API Key**: From any supported AI provider

## Privacy

TranslateTool respects your privacy:

- All API keys are stored only on your device
- Text is sent directly to your chosen AI provider's API
- No analytics or tracking
- No data collection
- Fully open source

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Adding a New AI Provider

1. Create a new file in `Sources/TranslateTool/Providers/`
2. Implement the `AIProvider` protocol
3. Add the provider type to `AIProviderType` enum
4. Register in `AIProviderFactory`

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Made by [Alfonso Bribiesca](https://github.com/alfonsobries)
