import AppKit
import ServiceManagement

// MARK: - 菜单栏

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var refreshTimer: Timer?
    private var rotateTimer: Timer?
    private let configManager = ConfigManager()

    private lazy var deepSeekService = DeepSeekBalanceService(configManager: configManager)
    private lazy var grokService = GrokUsageService()

    private var dsResult: UsageResult?
    private var grokResult: UsageResult?
    private var dsError: String?
    private var grokError: String?

    private var rotateIndex = 0

    private var deepSeekRow: ServiceRowView!
    private var grokRow: ServiceRowView!
    private var rotateRow: SwitchRowView!

    // MARK: - 启动

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.setupStatusBar()
                self.setupRefreshTimer()
                self.setupRotateTimer()
                self.refreshAll()
            }
        }
    }

    // MARK: - 菜单布局
    // 【图标】DeepSeek   数值   余额
    // 【图标】Grok       百分比  余量
    // 菜单栏轮播              [开关]
    // 设置
    // 退出

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.font = .menuBarFont(ofSize: 13)
            button.toolTip = "DSBalance"
        }

        menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        menu.minimumWidth = MenuMetrics.width

        // DeepSeek 行
        deepSeekRow = ServiceRowView(brand: .deepseek, name: "DeepSeek", kind: "余额")
        deepSeekRow.onClick = { [weak self] in self?.selectFixed(.deepseek) }
        menu.addItem(wrap(deepSeekRow))

        // Grok 行
        grokRow = ServiceRowView(brand: .grok, name: "Grok", kind: "余量")
        grokRow.onClick = { [weak self] in self?.selectFixed(.grok) }
        menu.addItem(wrap(grokRow))

        menu.addItem(.separator())

        // 轮播开关
        rotateRow = SwitchRowView(title: "菜单栏轮播")
        rotateRow.onToggle = { [weak self] on in
            self?.setRotate(on)
        }
        menu.addItem(wrap(rotateRow))

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        settings.image = symbol("gearshape")
        menu.addItem(settings)

        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        updateStatusBar()
        updateMenuRows()
    }

    private func wrap(_ view: NSView) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = view
        item.isEnabled = true
        return item
    }

    private func symbol(_ name: String) -> NSImage? {
        let img = NSImage(systemSymbolName: name, accessibilityDescription: name)
        img?.isTemplate = true
        return img
    }

    // MARK: - 当前状态栏展示

    private var activeService: DisplayMode {
        switch configManager.displayMode {
        case .deepseek: return .deepseek
        case .grok: return .grok
        case .rotate: return rotateIndex % 2 == 0 ? .deepseek : .grok
        }
    }

    private func selectFixed(_ mode: DisplayMode) {
        configManager.displayMode = mode
        rotateIndex = mode == .grok ? 1 : 0
        setupRotateTimer()
        updateStatusBar()
        updateMenuRows()
    }

    private func setRotate(_ on: Bool) {
        configManager.isRotateEnabled = on
        setupRotateTimer()
        updateStatusBar()
        updateMenuRows()
    }

    private func updateStatusBar() {
        guard statusItem != nil else { return }
        let active = activeService
        statusItem.button?.image = LogoAssets.image(
            active == .grok ? .grok : .deepseek,
            pointSize: 16
        )
        if active == .deepseek {
            statusItem.button?.title = " \(dsStatusValue())"
        } else {
            statusItem.button?.title = " \(grokStatusValue())"
        }
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.toolTip = "DSBalance"
        updateMenuRows()
    }

    private func dsStatusValue() -> String {
        if let v = dsResult?.displayValue { return v }
        if dsError != nil { return "!" }
        return "…"
    }

    /// 余量百分比 = 剩余 / 总额（不是已用占比）
    private func grokStatusValue() -> String {
        if let r = grokResult, let used = r.used, let limit = r.limit, limit > 0 {
            let remainingPct = max(0, (limit - used) / limit * 100)
            return "\(Int(remainingPct.rounded()))%"
        }
        if grokError != nil { return "!" }
        return "…"
    }

    private func updateMenuRows() {
        guard deepSeekRow != nil else { return }

        // DeepSeek：数值 +「余额」
        deepSeekRow.apply(
            value: dsResult?.displayValue ?? (dsError != nil ? "—" : "…"),
            selected: configManager.displayMode == .deepseek
                || (configManager.displayMode == .rotate && activeService == .deepseek)
        )

        // Grok：周限额余量 % + 下次重置时间
        let grokValue: String = {
            if let r = grokResult, let used = r.used, let limit = r.limit, limit > 0 {
                let remainingPct = max(0, (limit - used) / limit * 100)
                return "\(Int(remainingPct.rounded()))%"
            }
            return grokError != nil ? "—" : "…"
        }()
        // rawSummary 存重置文案，如「2026年7月30日 10:25」
        let resetSubtitle: String? = {
            guard let raw = grokResult?.rawSummary, !raw.isEmpty else { return nil }
            return "重置 \(raw)"
        }()
        grokRow.apply(
            value: grokValue,
            selected: configManager.displayMode == .grok
                || (configManager.displayMode == .rotate && activeService == .grok),
            subtitle: resetSubtitle
        )

        rotateRow.setOn(configManager.isRotateEnabled)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuRows()
    }

    // MARK: - 定时器

    private func setupRefreshTimer() {
        refreshTimer?.invalidate()
        let interval = configManager.refreshSeconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAll()
            }
        }
    }

    private func setupRotateTimer() {
        rotateTimer?.invalidate()
        rotateTimer = nil
        guard configManager.isRotateEnabled else { return }
        let interval = max(3, configManager.rotateSeconds)
        rotateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rotateIndex = (self.rotateIndex + 1) % 2
                self.updateStatusBar()
            }
        }
    }

    // MARK: - 刷新

    @objc func refreshAll() {
        Task { @MainActor in
            async let ds: Void = fetchDeepSeek()
            async let grok: Void = fetchGrok()
            _ = await (ds, grok)
            updateStatusBar()
        }
    }

    private func fetchDeepSeek() async {
        do {
            dsResult = try await deepSeekService.fetchUsage()
            dsError = nil
        } catch {
            dsResult = nil
            dsError = error.localizedDescription
        }
    }

    private func fetchGrok() async {
        do {
            grokResult = try await grokService.fetchUsage()
            grokError = nil
        } catch {
            grokResult = nil
            grokError = error.localizedDescription
        }
    }

    @objc func openSettings() {
        SettingsWindowController.shared.showWindow { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.setupRefreshTimer()
                self.setupRotateTimer()
                self.refreshAll()
            }
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - 固定列宽

enum MenuMetrics {
    static let width: CGFloat = 320
    static let rowHeight: CGFloat = 36
    /// 双行：主行 + 重置时间，给足间距避免重叠
    static let rowHeightWithSubtitle: CGFloat = 54
    static let padL: CGFloat = 14
    static let padR: CGFloat = 14
    static let icon: CGFloat = 18
    static let iconGap: CGFloat = 10
    static let nameWidth: CGFloat = 78
    /// 足够显示 ¥1234.56 / 100%
    static let valueWidth: CGFloat = 88
    static let kindWidth: CGFloat = 36
    static let colGap: CGFloat = 8
}

// MARK: - 服务行：图标 名称 | 数值 | 类型（副标题单独一行）

@MainActor
final class ServiceRowView: NSView {
    var onClick: (() -> Void)?

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let kindLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private var tracking: NSTrackingArea?
    private var hovered = false
    private var selected = false
    private var hasSubtitle = false

    init(brand: LogoAssets.Brand, name: String, kind: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: MenuMetrics.width, height: MenuMetrics.rowHeight))
        wantsLayer = true
        // NSMenuItem 依赖 frame 高度，不用 Auto Layout 撑开
        autoresizingMask = []

        iconView.image = LogoAssets.image(brand, pointSize: 16)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        nameLabel.stringValue = name
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false
        addSubview(nameLabel)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .right
        // 余额数字不截断；过长时略缩字号由 layout 处理
        valueLabel.lineBreakMode = .byClipping
        valueLabel.isEditable = false
        valueLabel.isBordered = false
        valueLabel.drawsBackground = false
        addSubview(valueLabel)

        kindLabel.stringValue = kind
        kindLabel.font = .systemFont(ofSize: 12)
        kindLabel.textColor = .secondaryLabelColor
        kindLabel.alignment = .right
        kindLabel.isEditable = false
        kindLabel.isBordered = false
        kindLabel.drawsBackground = false
        addSubview(kindLabel)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.isEditable = false
        subtitleLabel.isBordered = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.isHidden = true
        addSubview(subtitleLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: MenuMetrics.width,
            height: hasSubtitle ? MenuMetrics.rowHeightWithSubtitle : MenuMetrics.rowHeight
        )
    }

    func apply(value: String, selected: Bool, subtitle: String? = nil) {
        valueLabel.stringValue = value
        self.selected = selected
        nameLabel.font = .systemFont(ofSize: 13, weight: selected ? .semibold : .regular)

        if let subtitle, !subtitle.isEmpty {
            subtitleLabel.stringValue = subtitle
            subtitleLabel.isHidden = false
            hasSubtitle = true
        } else {
            subtitleLabel.stringValue = ""
            subtitleLabel.isHidden = true
            hasSubtitle = false
        }

        // 关键：NSMenu 用 view.frame.height，必须改 frame
        let h = hasSubtitle ? MenuMetrics.rowHeightWithSubtitle : MenuMetrics.rowHeight
        setFrameSize(NSSize(width: MenuMetrics.width, height: h))
        invalidateIntrinsicContentSize()
        needsLayout = true
        layout()
        refreshBackground()
    }

    override func layout() {
        super.layout()
        let m = MenuMetrics.self
        let w = max(bounds.width, m.width)
        let h = bounds.height

        // AppKit：y=0 在底部
        // 有副标题时：上行（名称/数值）靠上，下行（重置）靠下，中间留白
        let mainY: CGFloat
        let subY: CGFloat
        let iconY: CGFloat
        if hasSubtitle {
            mainY = h - 24          // 顶行
            subY = 8                // 底行
            iconY = mainY - 1
        } else {
            mainY = (h - 18) / 2
            subY = 0
            iconY = (h - m.icon) / 2
        }

        iconView.frame = NSRect(x: m.padL, y: iconY, width: m.icon, height: m.icon)

        let nameX = m.padL + m.icon + m.iconGap
        let kindX = w - m.padR - m.kindWidth
        let valueX = kindX - m.colGap - m.valueWidth

        // 主行：优先保证金额完整，名称可略缩
        let nameMaxW = max(48, valueX - nameX - 8)
        nameLabel.frame = NSRect(x: nameX, y: mainY, width: min(m.nameWidth, nameMaxW), height: 18)
        valueLabel.frame = NSRect(x: valueX, y: mainY, width: m.valueWidth, height: 18)
        kindLabel.frame = NSRect(x: kindX, y: mainY, width: m.kindWidth, height: 18)

        // 若金额仍偏长，略缩小字号（避免 ¥178.32 被裁成 ¥17…）
        let valueText = valueLabel.stringValue as NSString
        let valueFont = valueLabel.font ?? .systemFont(ofSize: 13)
        let needed = valueText.size(withAttributes: [.font: valueFont]).width
        if needed > m.valueWidth - 2 {
            valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        } else {
            valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        }

        if hasSubtitle {
            // 副标题从名称列起，到右边缘，不与上行重叠
            subtitleLabel.frame = NSRect(
                x: nameX,
                y: subY,
                width: w - nameX - m.padR,
                height: 15
            )
        }

        if tracking == nil || tracking?.rect != bounds {
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            tracking = area
        }
    }

    private func refreshBackground() {
        if hovered {
            layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.4).cgColor
        } else if selected {
            layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18).cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        refreshBackground()
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        refreshBackground()
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if bounds.contains(p) {
            onClick?()
        }
    }
}

// MARK: - 开关行：标题 左 · 开关 右

@MainActor
final class SwitchRowView: NSView {
    var onToggle: ((Bool) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let sw = NSSwitch()
    private var suppress = false

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: MenuMetrics.width, height: MenuMetrics.rowHeight))
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        addSubview(titleLabel)

        sw.controlSize = .small
        sw.target = self
        sw.action = #selector(changed)
        addSubview(sw)

        heightAnchor.constraint(equalToConstant: MenuMetrics.rowHeight).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func setOn(_ on: Bool) {
        suppress = true
        sw.state = on ? .on : .off
        suppress = false
    }

    @objc private func changed() {
        guard !suppress else { return }
        onToggle?(sw.state == .on)
    }

    override func layout() {
        super.layout()
        titleLabel.frame = NSRect(x: MenuMetrics.padL, y: 8, width: 160, height: 20)
        // 开关靠右
        let swSize = sw.fittingSize
        sw.frame = NSRect(
            x: bounds.width - MenuMetrics.padR - swSize.width,
            y: (bounds.height - swSize.height) / 2,
            width: swSize.width,
            height: swSize.height
        )
    }
}
