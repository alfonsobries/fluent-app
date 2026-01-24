# TranslateTool

A lightweight macOS menu bar app that processes selected text using AI. Translate, improve writing, fix grammar, and more with customizable keyboard shortcuts.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Multiple Actions**: Define unlimited shortcuts with custom AI instructions
- **Global Shortcuts**: Trigger actions from any application
- **Custom Instructions**: Tailor AI behavior for each shortcut
- **Shortcut Recorder**: Capture keyboard shortcuts visually
- **Privacy First**: API key stored locally, no data collection
- **Native Performance**: Built with Swift, minimal resource usage

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

# Or build a release DMG
./build_dmg.sh
```

## Setup

1. **Grant Permissions**
   - On first launch, macOS will ask for Accessibility permissions
   - Go to System Settings > Privacy & Security > Accessibility
   - Enable TranslateTool

2. **Add API Key**
   - Click the globe icon in your menu bar
   - Enter your [OpenAI API key](https://platform.openai.com/api-keys)

3. **Configure Shortcuts** (Optional)
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

## Creating Releases

For maintainers:

```bash
# Create a new release
VERSION=1.0.0 ./build_dmg.sh

# Or use the release script (includes git tag and GitHub release)
./scripts/release.sh 1.0.0
```

## Website

The project website is in the `expo/` directory, built with Astro.

```bash
cd expo
npm install
npm run dev      # Development server
npm run build    # Build for production
```

## Project Structure

```
translate-tool/
├── Sources/TranslateTool/
│   ├── TranslateToolApp.swift      # App entry point
│   ├── Model/
│   │   ├── AppSettings.swift       # Settings persistence
│   │   └── ShortcutAction.swift    # Action model
│   ├── Services/
│   │   ├── AppController.swift     # Main controller
│   │   ├── HotKeyManager.swift     # Global shortcuts
│   │   ├── ClipboardService.swift  # Text manipulation
│   │   └── OpenAIService.swift     # API integration
│   └── UI/
│       ├── SettingsView.swift      # Main settings UI
│       ├── ShortcutEditView.swift  # Action editor
│       └── ShortcutRecorderView.swift  # Shortcut capture
├── Resources/
│   ├── AppIcon.svg                 # App icon source
│   └── generate_icon.sh            # Icon generator
├── expo/                           # Project website (Astro)
├── scripts/
│   └── release.sh                  # Release automation
├── build_dmg.sh                    # Build script
└── Package.swift                   # Swift package config
```

## Requirements

- **macOS**: 13.0 (Ventura) or later
- **OpenAI API Key**: Required for AI processing

## Privacy

TranslateTool respects your privacy:

- Your API key is stored only on your device
- Text is sent directly to OpenAI's API
- No analytics or tracking
- Fully open source

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Made by [Alfonso Bribiesca](https://github.com/alfonsobries)
