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

## Download

Pre-built `.app` bundles are available on the [Releases](https://github.com/MineonStudio/DSBalance/releases) page.

> ⚠️ **Known issue: macOS Gatekeeper**
>
> The app is signed with an ad-hoc signature (not an Apple Developer certificate), so macOS may show:
> *"DSBalance"已损坏，无法打开。你应该将它移到废纸篓。*
>
> This does **not** mean the app is actually damaged. It's macOS's built-in security check rejecting a Gatekeeper-untested app. To work around:
>
> 1. **Option A** — Remove the quarantine attribute in Terminal:
>    ```bash
>    xattr -dr com.apple.quarantine /Applications/DSBalance.app
>    ```
>    Then launch the app normally.
>
> 2. **Option B** — Control-click (right-click) the app → **Open** → click **Open** in the dialog. The app will be remembered as an exception afterward.
>
> This is a known limitation for open-source macOS apps without a paid Apple Developer membership. See [Troubleshooting](#troubleshooting) for details.

## Build from Source

### Using Swift Package Manager

```bash
git clone https://github.com/MineonStudio/DSBalance.git
cd DSBalance
swift run
```

### Build release binary

```bash
swift build -c release
```

The built app will be at `.build/arm64-apple-macosx/release/DSBalance`. You can copy it into `/Applications` and run directly — apps built locally are not affected by the Gatekeeper issue.

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

## Troubleshooting

### "DSBalance 已损坏，无法打开"

This is **not** actual damage — it's **macOS Gatekeeper** rejecting an ad-hoc signed app downloaded from the internet.

**Why it happens**

1. You downloaded `DSBalance-v1.0.0.zip` from GitHub
2. macOS marks the extracted `.app` with a quarantine attribute
3. Gatekeeper checks the code signature and finds only an ad-hoc (local-only) signature
4. Since the app was not signed with an Apple Developer certificate nor notarized, macOS treats it as untrusted and shows the "damaged" error

**Fix**

```bash
# Remove the quarantine attribute and run
xattr -dr com.apple.quarantine /Applications/DSBalance.app
open /Applications/DSBalance.app
```

Or right-click the app → **Open** → click **Open** in the prompt. This adds a one-time exception.

> If you built the app yourself from source, this issue does not apply.

## License

This project is open source and available under the MIT License.
