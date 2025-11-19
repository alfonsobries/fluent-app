# TranslateTool

A macOS Menu Bar app that allows you to process selected text in any application using ChatGPT.

## Features
- **Global Shortcut**: Trigger the app from anywhere (Default: `Cmd + Shift + O`).
- **Context Aware**: Copies selected text, sends it to ChatGPT, and replaces the selection with the response.
- **Configurable**: Set your own OpenAI API Key and Custom Instructions.

## Installation & Usage

1. **Build the App**:
   ```bash
   swift build -c release
   ```
   The executable will be in `.build/release/TranslateTool`.

2. **Run the App**:
   Double-click the executable or run it from terminal.

3. **Permissions**:
   On first run, you must grant **Accessibility Permissions** to allow the app to simulate Copy/Paste (Cmd+C / Cmd+V).
   - Go to System Settings -> Privacy & Security -> Accessibility.
   - Enable `TranslateTool` (or the terminal app if running from terminal).

4. **Setup**:
   - Click the Menu Bar icon (Globe).
   - Enter your OpenAI API Key.
   - Customize the prompt if desired.

5. **Use**:
   - Select text in any app.
   - Press `Cmd + Shift + O`.
   - Wait for the text to be replaced.

## Troubleshooting
- **Permissions**: If the app beeps or doesn't copy/paste, check Accessibility permissions.
- **API Key**: Ensure your API key has credits and is valid.
