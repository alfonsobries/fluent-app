# TranslateTool

A macOS Menu Bar app that allows you to process selected text in any application using ChatGPT.

## Features
- **Global Shortcut**: Trigger the app from anywhere (Default: `Cmd + Shift + O`).
- **Context Aware**: Copies selected text, sends it to ChatGPT, and replaces the selection with the response.
- **Configurable**: Set your own OpenAI API Key and Custom Instructions.

## Installation

### Download
[Download the latest release](https://github.com/yourusername/TranslateTool/releases) (Coming soon)

### Build from Source
1.  Clone the repository:
    ```bash
    git clone https://github.com/yourusername/TranslateTool.git
    cd TranslateTool
    ```
2.  Build and Run:
    ```bash
    swift run
    ```
3.  **Create DMG Installer**:
    ```bash
    ./build_dmg.sh
    ```
    This will create `TranslateTool.dmg` in the project root.

## Usage
1.  **Permissions**: On first run, grant **Accessibility Permissions** when prompted (or in System Settings -> Privacy & Security -> Accessibility).
2.  **Setup**: Click the Menu Bar icon (Globe) -> Enter OpenAI API Key.
3.  **Translate**: Select text in any app -> Press `Cmd + Shift + O`.

## Development
- Built with **Swift** and **SwiftUI**.
- Uses **Carbon** for global hotkeys.
- Uses **Accessibility API** for clipboard manipulation.

## License
MIT
