import AppKit
import ServiceManagement

// MARK: - 设置（横版 · 左对齐 · Auto Layout 可拉伸）

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private let configManager = ConfigManager()
    private let grokService = GrokUsageService()

    private var apiKeyField: NSSecureTextField!
    private var grokStatusLabel: NSTextField!
    private var refreshPopup: NSPopUpButton!
    private var rotatePopup: NSPopUpButton!
    private var launchSwitch: NSSwitch!
    private var onSave: (() -> Void)?

    private let defaultSize = NSSize(width: 680, height: 420)
    private let minSize = NSSize(width: 560, height: 360)

    private let refreshOptions: [(title: String, seconds: Double)] = [
        ("15 秒", 15), ("30 秒", 30), ("1 分钟", 60),
        ("2 分钟", 120), ("5 分钟", 300), ("10 分钟", 600),
    ]
    private let rotateOptions: [(title: String, seconds: Double)] = [
        ("3 秒", 3), ("5 秒", 5), ("8 秒", 8), ("15 秒", 15), ("30 秒", 30),
    ]

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DSBalance 设置"
        window.isReleasedWhenClosed = false
        window.minSize = minSize
        window.setContentSize(defaultSize)
        super.init(window: window)

        let host = NSView()
        window.contentView = host
        installLayout(in: host)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow(onSave: (() -> Void)? = nil) {
        self.onSave = onSave
        loadAPIKeyIntoField()
        refreshGrokSubscriptionStatus()
        syncRefreshPopup()
        syncRotatePopup()
        syncLaunchSwitch()
        centerOnActiveScreen()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func loadAPIKeyIntoField() {
        apiKeyField?.stringValue = configManager.deepSeekAPIKey ?? ""
        apiKeyField?.window?.makeFirstResponder(nil)
    }

    private func refreshGrokSubscriptionStatus() {
        grokStatusLabel?.stringValue = "当前套餐：加载中…"
        grokStatusLabel?.textColor = .tertiaryLabelColor
        Task { @MainActor in
            let summary = await grokService.fetchSubscriptionSummary()
            grokStatusLabel?.stringValue = summary.line
            grokStatusLabel?.textColor = summary.isLoggedIn ? .secondaryLabelColor : .systemOrange
        }
    }

    private func centerOnActiveScreen() {
        guard let window else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            window.center()
            return
        }
        var frame = window.frame
        if frame.width < minSize.width || frame.height < minSize.height {
            frame.size = defaultSize
        }
        let visible = screen.visibleFrame
        frame.origin.x = floor(visible.midX - frame.width / 2)
        frame.origin.y = floor(visible.midY - frame.height / 2)
        window.setFrame(frame, display: true)
    }

    // MARK: - Layout

    private func installLayout(in host: NSView) {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(root)

        let body = NSStackView()
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 16
        body.translatesAutoresizingMaskIntoConstraints = false
        body.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        // 子视图横向拉满 body
        body.setHuggingPriority(.defaultLow, for: .horizontal)

        let footer = buildFooter()

        root.addSubview(body)
        root.addSubview(footer)

        body.addArrangedSubview(makeSection(
            title: "账号",
            rows: accountRows()
        ))
        body.addArrangedSubview(hairline())
        body.addArrangedSubview(makeSection(
            title: "通用",
            rows: dataRows() + generalRows()
        ))

        // 让每个 arrangedSubview 宽度 = body 宽度
        for view in body.arrangedSubviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        }

        let pad: CGFloat = 28
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            root.topAnchor.constraint(equalTo: host.topAnchor),
            root.bottomAnchor.constraint(equalTo: host.bottomAnchor),

            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 56),

            body.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: pad),
            body.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -pad),
            body.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            body.bottomAnchor.constraint(lessThanOrEqualTo: footer.topAnchor, constant: -12),
        ])

        syncRefreshPopup()
        syncRotatePopup()
        syncLaunchSwitch()
        loadAPIKeyIntoField()
        refreshGrokSubscriptionStatus()
    }

    // MARK: - Section factory

    private func makeSection(title: String, rows: [NSView]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(12, after: titleLabel)

        for row in rows {
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        titleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return stack
    }

    /// 左：可选品牌图标 + 标签(固定宽) · 右：控件弹性
    private func formRow(label: String, icon: LogoAssets.Brand? = nil, control: NSView) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        if let icon {
            iconView.image = LogoAssets.image(icon, pointSize: 16)
        }

        let lab = NSTextField(labelWithString: label)
        lab.font = .systemFont(ofSize: 13)
        lab.textColor = .secondaryLabelColor
        lab.alignment = .left
        lab.translatesAutoresizingMaskIntoConstraints = false

        control.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(iconView)
        row.addSubview(lab)
        row.addSubview(control)

        let labelLeading: CGFloat = icon != nil ? 26 : 0
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 32),

            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            lab.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: labelLeading),
            lab.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            lab.widthAnchor.constraint(equalToConstant: 110),

            control.leadingAnchor.constraint(equalTo: lab.trailingAnchor, constant: 12),
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        return row
    }

    // MARK: - Rows content
    // [icon] DeepSeek [API Key]  [•••• sk 掩码]  获取帮助
    // [icon] Grok     [订阅]     SuperGrok · 周期至 08/01  获取帮助

    private func accountRows() -> [NSView] {
        // DeepSeek：API Key 掩码输入
        apiKeyField = NSSecureTextField(string: "")
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        if let key = configManager.deepSeekAPIKey {
            apiKeyField.stringValue = key
        }
        apiKeyField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let dsHelp = linkButton("获取帮助", action: #selector(showDeepSeekHelp))
        let dsControl = NSView()
        dsControl.translatesAutoresizingMaskIntoConstraints = false
        dsControl.addSubview(apiKeyField)
        dsControl.addSubview(dsHelp)
        NSLayoutConstraint.activate([
            apiKeyField.leadingAnchor.constraint(equalTo: dsControl.leadingAnchor),
            apiKeyField.trailingAnchor.constraint(equalTo: dsHelp.leadingAnchor, constant: -10),
            apiKeyField.centerYAnchor.constraint(equalTo: dsControl.centerYAnchor),
            apiKeyField.heightAnchor.constraint(equalToConstant: 28),
            dsHelp.trailingAnchor.constraint(equalTo: dsControl.trailingAnchor),
            dsHelp.centerYAnchor.constraint(equalTo: dsControl.centerYAnchor),
            dsControl.heightAnchor.constraint(equalToConstant: 30),
        ])

        // Grok：当前套餐 + 用户名
        grokStatusLabel = NSTextField(labelWithString: "当前套餐：…")
        grokStatusLabel.font = .systemFont(ofSize: 13)
        grokStatusLabel.textColor = .secondaryLabelColor
        grokStatusLabel.lineBreakMode = .byTruncatingTail
        grokStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        grokStatusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        grokStatusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let grokHelp = linkButton("获取帮助", action: #selector(showGrokHelp))
        let grokControl = NSView()
        grokControl.translatesAutoresizingMaskIntoConstraints = false
        grokControl.addSubview(grokStatusLabel)
        grokControl.addSubview(grokHelp)
        NSLayoutConstraint.activate([
            grokStatusLabel.leadingAnchor.constraint(equalTo: grokControl.leadingAnchor),
            grokStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: grokHelp.leadingAnchor, constant: -10),
            grokStatusLabel.centerYAnchor.constraint(equalTo: grokControl.centerYAnchor),
            grokHelp.trailingAnchor.constraint(equalTo: grokControl.trailingAnchor),
            grokHelp.centerYAnchor.constraint(equalTo: grokControl.centerYAnchor),
            grokControl.heightAnchor.constraint(equalToConstant: 30),
        ])

        return [
            brandAccountRow(brand: .deepseek, name: "DeepSeek", tag: "API Key", control: dsControl, rowHeight: 36),
            brandAccountRow(brand: .grok, name: "Grok", tag: "订阅", control: grokControl, rowHeight: 36),
        ]
    }

    /// 图标 + 名称 + 类型标签（两行对齐）+ 右侧控件
    private func brandAccountRow(
        brand: LogoAssets.Brand,
        name: String,
        tag: String,
        control: NSView,
        rowHeight: CGFloat = 36
    ) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = LogoAssets.image(brand, pointSize: 18)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let tagLabel = NSTextField(labelWithString: tag)
        tagLabel.font = .systemFont(ofSize: 11, weight: .medium)
        tagLabel.textColor = .secondaryLabelColor
        tagLabel.alignment = .center
        tagLabel.translatesAutoresizingMaskIntoConstraints = false

        let tagBg = NSView()
        tagBg.translatesAutoresizingMaskIntoConstraints = false
        tagBg.wantsLayer = true
        tagBg.layer?.cornerRadius = 4
        tagBg.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.35).cgColor
        tagBg.addSubview(tagLabel)

        control.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(iconView)
        row.addSubview(nameLabel)
        row.addSubview(tagBg)
        row.addSubview(control)

        // 固定列：图标20 + 名88 + 标签72，保证「API Key / 订阅」对齐
        let nameCol: CGFloat = 88
        let tagCol: CGFloat = 72

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: rowHeight),

            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            iconView.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: nameCol),

            tagBg.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            tagBg.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            tagBg.widthAnchor.constraint(equalToConstant: tagCol),
            tagBg.heightAnchor.constraint(equalToConstant: 22),

            tagLabel.centerXAnchor.constraint(equalTo: tagBg.centerXAnchor),
            tagLabel.centerYAnchor.constraint(equalTo: tagBg.centerYAnchor),

            control.leadingAnchor.constraint(equalTo: tagBg.trailingAnchor, constant: 12),
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            control.topAnchor.constraint(equalTo: row.topAnchor),
            control.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])

        return row
    }

    private func dataRows() -> [NSView] {
        refreshPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        refreshPopup.translatesAutoresizingMaskIntoConstraints = false
        for opt in refreshOptions {
            refreshPopup.addItem(withTitle: opt.title)
            refreshPopup.lastItem?.representedObject = opt.seconds
        }
        refreshPopup.widthAnchor.constraint(equalToConstant: 160).isActive = true

        rotatePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        rotatePopup.translatesAutoresizingMaskIntoConstraints = false
        for opt in rotateOptions {
            rotatePopup.addItem(withTitle: opt.title)
            rotatePopup.lastItem?.representedObject = opt.seconds
        }
        rotatePopup.widthAnchor.constraint(equalToConstant: 160).isActive = true

        return [
            formRow(label: "自动刷新", control: leadingHost(refreshPopup)),
            formRow(label: "轮播间隔", control: leadingHost(rotatePopup)),
        ]
    }

    private func generalRows() -> [NSView] {
        let hint = NSTextField(labelWithString: "登录 macOS 时自动运行")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .tertiaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        launchSwitch = NSSwitch()
        launchSwitch.translatesAutoresizingMaskIntoConstraints = false
        launchSwitch.target = self
        launchSwitch.action = #selector(launchSwitchChanged(_:))

        let box = NSView()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(hint)
        box.addSubview(launchSwitch)
        NSLayoutConstraint.activate([
            hint.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            hint.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            launchSwitch.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            launchSwitch.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            hint.trailingAnchor.constraint(lessThanOrEqualTo: launchSwitch.leadingAnchor, constant: -12),
            box.heightAnchor.constraint(equalToConstant: 28),
        ])

        return [formRow(label: "开机自启动", control: box)]
    }

    private func leadingHost(_ view: NSView) -> NSView {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            view.centerYAnchor.constraint(equalTo: host.centerYAnchor),
            host.heightAnchor.constraint(equalToConstant: 28),
        ])
        return host
    }

    private func hairline() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return box
    }

    private func linkButton(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .inline
        b.isBordered = false
        b.font = .systemFont(ofSize: 13, weight: .medium)
        b.contentTintColor = .linkColor
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setContentHuggingPriority(.required, for: .horizontal)
        return b
    }

    private func buildFooter() -> NSView {
        let footer = NSView()
        footer.translatesAutoresizingMaskIntoConstraints = false

        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(line)

        let cancel = NSButton(title: "取消", target: self, action: #selector(closeWindow))
        cancel.bezelStyle = .rounded
        cancel.translatesAutoresizingMaskIntoConstraints = false

        let save = NSButton(title: "保存", target: self, action: #selector(saveAction))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.translatesAutoresizingMaskIntoConstraints = false

        footer.addSubview(cancel)
        footer.addSubview(save)

        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            line.topAnchor.constraint(equalTo: footer.topAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            save.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -24),
            save.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            save.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            cancel.trailingAnchor.constraint(equalTo: save.leadingAnchor, constant: -10),
            cancel.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            cancel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])
        return footer
    }

    // MARK: - Sync / Actions

    private func syncRefreshPopup() {
        selectClosest(popup: refreshPopup, options: refreshOptions, current: configManager.refreshSeconds)
    }

    private func syncRotatePopup() {
        selectClosest(popup: rotatePopup, options: rotateOptions, current: configManager.rotateSeconds)
    }

    private func selectClosest(
        popup: NSPopUpButton?,
        options: [(title: String, seconds: Double)],
        current: Double
    ) {
        guard let popup else { return }
        if let idx = options.firstIndex(where: { abs($0.seconds - current) < 0.5 }) {
            popup.selectItem(at: idx)
        } else {
            let nearest = options.enumerated().min(by: {
                abs($0.element.seconds - current) < abs($1.element.seconds - current)
            })?.offset ?? 0
            popup.selectItem(at: nearest)
        }
    }

    private func syncLaunchSwitch() {
        launchSwitch?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func saveAction() {
        // 保存 API Key（掩码串不写回）
        if let raw = apiKeyField?.stringValue {
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !key.contains("•") {
                configManager.saveDeepSeekAPIKey(key)
            }
        }
        if let sec = refreshPopup.selectedItem?.representedObject as? Double {
            configManager.refreshSeconds = sec
        }
        if let sec = rotatePopup.selectedItem?.representedObject as? Double {
            configManager.rotateSeconds = sec
        }
        onSave?()
        window?.close()
    }

    @objc private func closeWindow() { window?.close() }

    @objc private func showDeepSeekHelp() {
        HelpGuidePanel.present(
            brand: .deepseek,
            title: "DeepSeek API Key",
            body: """
            1. 打开 DeepSeek 开放平台
            2. 创建或复制 API Key（sk- 开头）
            3. 粘贴到下方并保存

            密钥仅保存在本机，不会上传。
            """,
            primaryTitle: "打开官网",
            secondaryTitle: "关闭",
            showsAPIKeyField: true,
            existingAPIKey: configManager.deepSeekAPIKey,
            onPrimary: {
                if let url = URL(string: "https://platform.deepseek.com/api_keys") {
                    NSWorkspace.shared.open(url)
                }
            },
            onSaveKey: { [weak self] key in
                self?.configManager.saveDeepSeekAPIKey(key)
            }
        )
    }

    @objc private func showGrokHelp() {
        HelpGuidePanel.present(
            brand: .grok,
            title: "Grok 订阅",
            body: """
            1. 打开终端
            2. 运行：grok login
            3. 浏览器完成授权
            4. 回到本应用查看用量

            凭据：~/.grok/auth.json
            """,
            primaryTitle: "复制命令",
            secondaryTitle: "好的",
            showsAPIKeyField: false,
            existingAPIKey: nil,
            onPrimary: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("grok login", forType: .string)
            },
            onSaveKey: nil
        )
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
}

// MARK: - 引导面板（图标顶部居中）

@MainActor
enum HelpGuidePanel {
    static func present(
        brand: LogoAssets.Brand,
        title: String,
        body: String,
        primaryTitle: String,
        secondaryTitle: String,
        showsAPIKeyField: Bool,
        existingAPIKey: String?,
        onPrimary: @escaping () -> Void,
        onSaveKey: ((String) -> Void)?
    ) {
        let width: CGFloat = 360
        let height: CGFloat = showsAPIKeyField ? 340 : 280

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.isFloatingPanel = true
        panel.level = .floating

        let root = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        panel.contentView = root

        // 图标：顶部水平居中
        let iconView = NSImageView()
        iconView.image = LogoAssets.image(brand, pointSize: 48)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.frame = NSRect(x: (width - 56) / 2, y: height - 78, width: 56, height: 56)
        root.addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 24, y: height - 108, width: width - 48, height: 22)
        root.addSubview(titleLabel)

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.alignment = .left
        bodyLabel.frame = NSRect(x: 28, y: showsAPIKeyField ? 118 : 64, width: width - 56, height: showsAPIKeyField ? 100 : 120)
        root.addSubview(bodyLabel)

        var keyField: NSSecureTextField?
        if showsAPIKeyField {
            let field = NSSecureTextField(frame: NSRect(x: 28, y: 78, width: width - 56, height: 30))
            field.placeholderString = "sk-..."
            field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            if let existingAPIKey, !existingAPIKey.isEmpty {
                field.stringValue = existingAPIKey // SecureField 显示圆点掩码
            }
            root.addSubview(field)
            keyField = field
        }

        let secondary = NSButton(
            frame: NSRect(x: width - 28 - 72 - 84, y: 20, width: 72, height: 30)
        )
        secondary.title = secondaryTitle
        secondary.bezelStyle = .rounded
        root.addSubview(secondary)

        let primary = NSButton(
            frame: NSRect(x: width - 28 - 72, y: 20, width: 72, height: 30)
        )
        primary.title = primaryTitle
        primary.bezelStyle = .rounded
        primary.keyEquivalent = "\r"
        root.addSubview(primary)

        // 用局部持有避免过早释放
        @MainActor
        final class Handler: NSObject {
            let panel: NSPanel
            let onPrimary: () -> Void
            let onSaveKey: ((String) -> Void)?
            weak var keyField: NSSecureTextField?
            let showsKey: Bool

            init(
                panel: NSPanel,
                onPrimary: @escaping () -> Void,
                onSaveKey: ((String) -> Void)?,
                keyField: NSSecureTextField?,
                showsKey: Bool
            ) {
                self.panel = panel
                self.onPrimary = onPrimary
                self.onSaveKey = onSaveKey
                self.keyField = keyField
                self.showsKey = showsKey
            }

            @objc func primaryTapped() {
                onPrimary()
            }

            @objc func secondaryTapped() {
                if showsKey, let raw = keyField?.stringValue {
                    let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !key.isEmpty, !key.contains("•") {
                        onSaveKey?(key)
                    }
                }
                panel.close()
            }
        }

        let handler = Handler(
            panel: panel,
            onPrimary: onPrimary,
            onSaveKey: onSaveKey,
            keyField: keyField,
            showsKey: showsAPIKeyField
        )
        // 挂到 panel 防止释放（用 retarget 的 representedObject 代替 associated object）
        primary.target = handler
        primary.action = #selector(Handler.primaryTapped)
        secondary.target = handler
        secondary.action = #selector(Handler.secondaryTapped)
        // 保持 handler 生命周期与 panel 一致
        panel.delegate = handler as? NSWindowDelegate
        // 额外强引用：放进 panel 的 identifier 无法持有对象，用同步关联到 contentView
        panel.contentView?.identifier = NSUserInterfaceItemIdentifier("help-\(brand.resourceName)")
        HelpGuidePanel.retainHandler(handler, for: panel)

        // 有 Key 时次按钮为「保存」
        if showsAPIKeyField {
            secondary.title = "保存"
            primary.title = primaryTitle
            primary.frame = NSRect(x: width - 28 - 88, y: 20, width: 88, height: 30)
            secondary.frame = NSRect(x: width - 28 - 88 - 10 - 72, y: 20, width: 72, height: 30)
        }

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 避免 handler 被提前释放
    nonisolated(unsafe) private static var retained: [ObjectIdentifier: AnyObject] = [:]

    private static func retainHandler(_ handler: AnyObject, for panel: NSPanel) {
        let id = ObjectIdentifier(panel)
        retained[id] = handler
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { _ in
            retained.removeValue(forKey: id)
        }
    }
}

