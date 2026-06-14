# DSBalance

A lightweight macOS menu bar app that displays your DeepSeek API account balance in real time.

Built entirely in Swift with native AppKit, it runs quietly in your menu bar without a Dock icon.

## Features

- 🔍 **Real-time Balance** — Fetches your DeepSeek API balance on demand
- 💰 **Multi-currency Support** — Displays total, granted, and topped-up balances
- 🪟 **Menu Bar Only** — No Dock icon, minimal footprint
- 🔒 **Secure Storage** — API key stored via system UserDefaults
- ⚙️ **Settings Panel** — Configure and manage your API key

## Prerequisites

- macOS 14.0 (Sonoma) or later
- A [DeepSeek](https://platform.deepseek.com/) API key

## Build & Run

### Using Swift Package Manager

```bash
cd DSBalance
swift run
```

### Build release

```bash
swift build -c release
```

The built app will be at `.build/arm64-apple-macosx/release/DSBalance`.

## Usage

1. Launch the app — it appears as a 💰 icon in your menu bar
2. Click the icon and select **Settings**
3. Enter your DeepSeek API key
4. Click **Query Balance** to see your account balance instantly

## Project Structure

```
DSBalance/
├── Sources/
│   └── DSBalance/
│       ├── main.swift              # App entry point
│       ├── AppDelegate.swift       # Menu bar setup & lifecycle
│       ├── BalanceService.swift    # API client & data models
│       ├── ConfigManager.swift     # API key persistence
│       └── SettingsViewController.swift  # Settings UI
├── Package.swift                   # Swift Package Manager manifest
├── icon.png                        # App icon
├── run.sh                          # Quick run script
└── .gitignore
```

## License

This project is open source and available under the MIT License.
