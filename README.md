# DSBalance

A lightweight macOS menu bar app that shows your **DeepSeek API balance** and **Grok Build credit usage** in real time.

Built entirely in Swift with native AppKit — no Dock icon, minimal footprint.

## Features

- 🐳 **DeepSeek balance** — total / granted / topped-up (official API)
- 🤖 **Grok Build usage** — remaining monthly credits via the same billing API as Grok CLI `/usage`
- 🪟 **Menu bar only** — `LSUIElement`, no Dock icon
- 🔄 **Auto refresh** — every 60 seconds, plus manual refresh
- 🔀 **Display modes** — DeepSeek only / Grok only / both side by side
- ⚙️ **Settings** — DeepSeek API key + Grok login status (reads `~/.grok/auth.json`)

## Prerequisites

- macOS 14.0 (Sonoma) or later
- Optional: a [DeepSeek](https://platform.deepseek.com/) API key
- Optional: [Grok CLI](https://grok.com) installed and signed in (`grok login`)

You can use either service alone, or both.

## Download

Pre-built `.app` bundles are available on the [Releases](https://github.com/MineonStudio/DSBalance/releases) page.

> ⚠️ **Known issue: macOS Gatekeeper**
>
> The app is signed with an ad-hoc signature (not an Apple Developer certificate), so macOS may show:
> *"DSBalance"已损坏，无法打开。你应该将它移到废纸篓。*
>
> This does **not** mean the app is actually damaged. Workaround:
>
> ```bash
> xattr -dr com.apple.quarantine /Applications/DSBalance.app
> ```
>
> Or Control-click → **Open** → **Open**.

## Build from Source

```bash
git clone https://github.com/MineonStudio/DSBalance.git
cd DSBalance
./run.sh
```

Or manually:

```bash
swift build -c release
# binary: .build/<arch>-apple-macosx/release/DSBalance
```

`run.sh` builds a release binary, packs `DSBalance.app`, ad-hoc signs it, and launches it.

## Usage

1. Launch the app — icons appear in the menu bar
2. Click the icon:
   - **DeepSeek** row shows API balance
   - **Grok** row shows remaining / monthly credits
3. **Settings…**
   - Paste DeepSeek API key (stored in UserDefaults)
   - Grok status is read from `~/.grok/auth.json` (no key to paste)
4. If Grok shows “未登录”, run `grok login` in Terminal, then **刷新数据**

### Grok credits

DSBalance does **not** shell out to `grok`. It:

1. Reads the OAuth access token from `~/.grok/auth.json`
2. Calls `https://cli-chat-proxy.grok.com/v1/billing` (same source as CLI `/usage`)

When the CLI refreshes the token, this app picks it up on the next refresh. If the token is expired, run `grok login` again (or open Grok once so it can refresh).

## Project Structure

```
DSBalance/
├── Sources/DSBalance/
│   ├── main.swift
│   ├── AppDelegate.swift           # Menu bar UI & refresh
│   ├── BalanceServiceProtocol.swift
│   ├── BalanceService.swift        # DeepSeek
│   ├── GrokUsageService.swift      # Grok billing
│   ├── ConfigManager.swift
│   └── SettingsViewController.swift
├── Package.swift
├── run.sh
└── icon.png
```

## Troubleshooting

### Gatekeeper “已损坏”

```bash
xattr -dr com.apple.quarantine /Applications/DSBalance.app
open /Applications/DSBalance.app
```

### Grok shows auth error

```bash
grok login
```

Then click **刷新数据** in the menu.

### DeepSeek shows missing key

Open **设置…**, paste a key from https://platform.deepseek.com/api_keys

## License

MIT
