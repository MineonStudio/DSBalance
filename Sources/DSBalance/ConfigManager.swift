import Foundation

/// 菜单栏显示：固定 DeepSeek / Grok，或轮播
enum DisplayMode: String, CaseIterable {
    case deepseek = "DeepSeek"
    case grok = "Grok"
    case rotate = "Rotate"

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .grok: return "Grok"
        case .rotate: return "轮播"
        }
    }

    static func parse(_ raw: String?) -> DisplayMode {
        guard let raw else { return .deepseek }
        if raw == "Both" { return .rotate }
        return DisplayMode(rawValue: raw) ?? .deepseek
    }
}

/// 用户偏好
final class ConfigManager {
    private static let suiteName = "com.dsbalance.app"
    private let apiKeyStorageKey = "DSBalance_APIKey"
    private let displayModeKey = "DSBalance_DisplayMode"
    private let lastFixedModeKey = "DSBalance_LastFixedMode"
    private let rotateSecondsKey = "DSBalance_RotateSeconds"
    private let refreshSecondsKey = "DSBalance_RefreshSeconds"

    private let userDefaults: UserDefaults

    init() {
        if let suite = UserDefaults(suiteName: Self.suiteName) {
            userDefaults = suite
        } else {
            userDefaults = .standard
        }
        migrateAPIKeyIfNeeded()
    }

    // MARK: - DeepSeek API Key

    /// 明文 Key（仅内存使用，勿日志输出）
    var deepSeekAPIKey: String? {
        // 运行中 App 的 standard 与 bundle id 一致，优先读它
        if let v = normalized(UserDefaults.standard.string(forKey: apiKeyStorageKey)) {
            return v
        }
        if let v = normalized(userDefaults.string(forKey: apiKeyStorageKey)) {
            return v
        }
        return nil
    }

    var apiKey: String? { deepSeekAPIKey }

    /// 掩码展示：保留前缀 sk- 与末 4 位，中间用 •
    /// 例：sk-••••••••••••8053
    var maskedDeepSeekAPIKey: String? {
        guard let key = deepSeekAPIKey, !key.isEmpty else { return nil }
        return Self.maskAPIKey(key)
    }

    static func maskAPIKey(_ key: String) -> String {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard k.count > 8 else {
            return String(repeating: "•", count: max(k.count, 4))
        }
        let prefix: String
        if k.hasPrefix("sk-") {
            prefix = "sk-"
        } else {
            prefix = String(k.prefix(3))
        }
        let suffix = String(k.suffix(4))
        let middleCount = max(8, min(16, k.count - prefix.count - 4))
        return prefix + String(repeating: "•", count: middleCount) + suffix
    }

    func saveDeepSeekAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 若用户未改掩码串，不要把掩码写回
        if trimmed.contains("•") { return }

        UserDefaults.standard.set(trimmed, forKey: apiKeyStorageKey)
        UserDefaults.standard.synchronize()
        userDefaults.set(trimmed, forKey: apiKeyStorageKey)
        userDefaults.synchronize()
    }

    func saveAPIKey(_ key: String) { saveDeepSeekAPIKey(key) }

    func clearDeepSeekAPIKey() {
        userDefaults.removeObject(forKey: apiKeyStorageKey)
        userDefaults.synchronize()
        UserDefaults.standard.removeObject(forKey: apiKeyStorageKey)
        UserDefaults.standard.synchronize()
    }

    private func normalized(_ value: String?) -> String? {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else {
            return nil
        }
        return v
    }

    private func migrateAPIKeyIfNeeded() {
        if deepSeekAPIKey != nil { return }

        let candidates: [String?] = [
            UserDefaults.standard.string(forKey: apiKeyStorageKey),
            userDefaults.string(forKey: apiKeyStorageKey),
            UserDefaults(suiteName: Self.suiteName)?.string(forKey: apiKeyStorageKey),
            UserDefaults(suiteName: "com.wesley.dsbalance")?.string(forKey: apiKeyStorageKey),
            UserDefaults(suiteName: "com.wesley.deepseekbalance")?.string(forKey: "deepseek_api_key"),
            UserDefaults(suiteName: "com.wesley.deepseekbalance")?.string(forKey: apiKeyStorageKey),
        ]
        for candidate in candidates {
            if let key = normalized(candidate) {
                saveDeepSeekAPIKey(key)
                return
            }
        }
    }

    // MARK: - 显示模式

    var displayMode: DisplayMode {
        get { DisplayMode.parse(userDefaults.string(forKey: displayModeKey)) }
        set {
            if newValue != .rotate {
                userDefaults.set(newValue.rawValue, forKey: lastFixedModeKey)
            }
            userDefaults.set(newValue.rawValue, forKey: displayModeKey)
            userDefaults.synchronize()
        }
    }

    /// 关闭轮播时回到的固定模式
    var lastFixedMode: DisplayMode {
        get {
            let m = DisplayMode.parse(userDefaults.string(forKey: lastFixedModeKey))
            return m == .rotate ? .deepseek : m
        }
        set {
            let v = newValue == .rotate ? .deepseek : newValue
            userDefaults.set(v.rawValue, forKey: lastFixedModeKey)
            userDefaults.synchronize()
        }
    }

    var isRotateEnabled: Bool {
        get { displayMode == .rotate }
        set {
            if newValue {
                displayMode = .rotate
            } else {
                displayMode = lastFixedMode
            }
        }
    }

    /// 轮播切换间隔（秒）
    var rotateSeconds: Double {
        get {
            let v = userDefaults.double(forKey: rotateSecondsKey)
            return v > 0 ? v : 8
        }
        set {
            userDefaults.set(max(3, newValue), forKey: rotateSecondsKey)
            userDefaults.synchronize()
        }
    }

    /// 自动刷新间隔（秒），默认 60；最小 15
    var refreshSeconds: Double {
        get {
            let v = userDefaults.double(forKey: refreshSecondsKey)
            return v > 0 ? v : 60
        }
        set {
            userDefaults.set(max(15, newValue), forKey: refreshSecondsKey)
            userDefaults.synchronize()
        }
    }

}
