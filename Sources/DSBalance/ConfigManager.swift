import Foundation

/// 使用用户偏好设置存储 API Key（无签名菜单栏应用的最佳实践）
final class ConfigManager {
    private let userDefaults = UserDefaults.standard
    private let key = "DSBalance_APIKey"

    var apiKey: String? {
        userDefaults.string(forKey: key)
    }

    func saveAPIKey(_ key: String) {
        userDefaults.set(key, forKey: self.key)
        userDefaults.synchronize()
    }

    func clearAPIKey() {
        userDefaults.removeObject(forKey: self.key)
        userDefaults.synchronize()
    }
}
