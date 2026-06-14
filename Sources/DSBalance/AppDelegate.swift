import AppKit
import ServiceManagement

// MARK: - 菜单栏应用代理

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var launchItem: NSMenuItem!
    private var launchSwitch: NSSwitch!
    private var refreshTimer: Timer?
    private let configManager = ConfigManager()
    private let balanceService = BalanceService()

    // MARK: - 启动

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            setupStatusBar()
            setupRefreshTimer()
            syncLaunchSwitch()

            if configManager.apiKey != nil {
                refreshBalance()
            } else {
                openSettings()
            }
        }
    }

    // MARK: - 菜单栏

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: "")
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐳"
        statusItem.button?.toolTip = "DeepSeek 余额查询"

        let menu = NSMenu()

        // 自启开关 —— 置顶
        let (launchItem, sw) = buildLaunchToggleItem()
        self.launchItem = launchItem
        self.launchSwitch = sw
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(menuItem("刷新余额", action: #selector(refreshBalance)))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(menuItem("设置 API Key…", action: #selector(openSettings)))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(menuItem("退出 DSBalance", action: #selector(quitApp)))
        statusItem.menu = menu
    }

    /// 构建带有 NSSwitch 的自启菜单项（左对齐文字 + 右侧开关）
    private func buildLaunchToggleItem() -> (NSMenuItem, NSSwitch) {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 24))

        // 标签（左对齐）
        let label = NSTextField(labelWithString: "开启自启")
        label.font = .systemFont(ofSize: 13)
        label.frame = NSRect(x: 14, y: 3, width: 100, height: 18)
        label.lineBreakMode = .byTruncatingTail
        view.addSubview(label)

        // NSSwitch（右侧）
        let sw = NSSwitch(frame: NSRect(x: 145, y: 2, width: 44, height: 20))
        sw.target = self
        sw.action = #selector(launchSwitchChanged(_:))
        view.addSubview(sw)

        item.view = view
        item.isEnabled = true
        return (item, sw)
    }

    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshBalance()
            }
        }
    }

    // MARK: - 刷新余额

    @objc func refreshBalance() {
        guard let apiKey = configManager.apiKey else {
            updateTitle("🐳")
            return
        }

        updateTitle("🐳 : …")

        Task { @MainActor in
            do {
                let balance = try await balanceService.fetchBalance(apiKey: apiKey)
                applyBalance(balance)
            } catch {
                updateTitle("🐳 : ⚠️")
            }
        }
    }

    private func applyBalance(_ balance: BalanceResponse) {
        guard let info = balance.balanceInfos.first else {
            updateTitle("🐳 : --")
            return
        }

        let display = "🐳 : \(info.totalBalance) \(info.currency)"
        updateTitle(display)

        let tooltip = """
        总余额: \(info.totalBalance) \(info.currency)
        赠送余额: \(info.grantedBalance) \(info.currency)
        充值余额: \(info.toppedUpBalance) \(info.currency)
        状态: \(balance.isAvailable ? "可用" : "余额不足")
        """
        statusItem.button?.toolTip = tooltip
    }

    private func updateTitle(_ title: String) {
        statusItem.button?.title = title
    }

    // MARK: - 设置

    @objc func openSettings() {
        SettingsWindowController.shared.showWindow { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshBalance()
            }
        }
    }

    // MARK: - 开机自启

    private func syncLaunchSwitch() {
        launchSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func launchSwitchChanged(_ sender: NSSwitch) {
        do {
            if sender.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
            let alert = NSAlert()
            alert.messageText = "自启设置失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - 退出

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
