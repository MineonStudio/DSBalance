import AppKit

// MARK: - API Key 设置窗口

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private let configManager = ConfigManager()
    private var apiKeyField: NSSecureTextField!
    private var onSave: (() -> Void)?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DSBalance 设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let contentView = buildContentView()
        window.contentView = contentView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 显示

    func showWindow(onSave: (() -> Void)? = nil) {
        self.onSave = onSave
        // 每次打开时同步显示当前 Keychain 中存储的 key
        apiKeyField?.stringValue = configManager.apiKey ?? ""
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 视图构建  (macOS 26 风格)

    private func buildContentView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 220))
        view.wantsLayer = true

        // 图标
        let icon = NSImageView(frame: NSRect(x: 24, y: 170, width: 36, height: 36))
        icon.image = NSImage(named: NSImage.Name("NSApplicationIcon"))
        icon.imageScaling = .scaleProportionallyUpOrDown
        view.addSubview(icon)

        // 标题
        let title = NSTextField(labelWithString: "DeepSeek API Key")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.frame = NSRect(x: 72, y: 180, width: 200, height: 24)
        view.addSubview(title)

        // 副标题
        let subtitle = NSTextField(labelWithString: "配置您的 API Key 以查询账户余额")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 72, y: 164, width: 280, height: 16)
        view.addSubview(subtitle)

        // 输入框标签
        let fieldLabel = NSTextField(labelWithString: "API Key")
        fieldLabel.font = .systemFont(ofSize: 12, weight: .medium)
        fieldLabel.frame = NSRect(x: 24, y: 128, width: 100, height: 16)
        view.addSubview(fieldLabel)

        // 安全输入框
        apiKeyField = NSSecureTextField(frame: NSRect(x: 24, y: 100, width: 320, height: 26))
        apiKeyField.placeholderString = "sk-xxxxxxxxxxxxxxxxxxxxxxxx"
        apiKeyField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        apiKeyField.stringValue = configManager.apiKey ?? ""
        view.addSubview(apiKeyField)

        // "获取 Key" 链接
        let getKeyBtn = NSButton(frame: NSRect(x: 352, y: 98, width: 84, height: 28))
        getKeyBtn.title = "获取 Key"
        getKeyBtn.bezelStyle = .rounded
        getKeyBtn.controlSize = .small
        getKeyBtn.target = self
        getKeyBtn.action = #selector(openAPIKeysPage)
        view.addSubview(getKeyBtn)

        // 分割线
        let separator = NSBox(frame: NSRect(x: 24, y: 72, width: 412, height: 1))
        separator.boxType = .separator
        view.addSubview(separator)

        // 安全提示
        let hint = NSTextField(labelWithString: "🔐 API Key 将被安全存储在系统钥匙串中")
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor
        hint.frame = NSRect(x: 24, y: 44, width: 300, height: 14)
        view.addSubview(hint)

        // 取消按钮
        let cancelBtn = NSButton(frame: NSRect(x: 270, y: 14, width: 80, height: 28))
        cancelBtn.title = "取消"
        cancelBtn.bezelStyle = .rounded
        cancelBtn.controlSize = .small
        cancelBtn.target = self
        cancelBtn.action = #selector(closeWindow)
        view.addSubview(cancelBtn)

        // 保存按钮
        let saveBtn = NSButton(frame: NSRect(x: 356, y: 14, width: 80, height: 28))
        saveBtn.title = "保存"
        saveBtn.bezelStyle = .rounded
        saveBtn.controlSize = .small
        saveBtn.keyEquivalent = "\r"
        saveBtn.target = self
        saveBtn.action = #selector(saveAction)
        view.addSubview(saveBtn)

        return view
    }

    // MARK: - Actions

    @objc private func saveAction() {
        let key = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            shakeField()
            return
        }
        configManager.saveAPIKey(key)
        onSave?()
        window?.close()
    }

    @objc private func closeWindow() {
        window?.close()
    }

    @objc private func openAPIKeysPage() {
        if let url = URL(string: "https://platform.deepseek.com/api_keys") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 输入为空时抖动提示
    private func shakeField() {
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = 0.05
        animation.repeatCount = 3
        animation.autoreverses = true
        animation.fromValue = NSValue(point: NSPoint(x: apiKeyField.frame.origin.x - 6, y: apiKeyField.frame.origin.y))
        animation.toValue = NSValue(point: NSPoint(x: apiKeyField.frame.origin.x + 6, y: apiKeyField.frame.origin.y))
        apiKeyField.layer?.add(animation, forKey: "position")
    }
}
