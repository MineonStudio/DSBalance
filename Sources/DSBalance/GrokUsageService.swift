import Foundation

// MARK: - 周限额 API（与官网「每周 SuperGrok 限额」一致）
// GET /v1/billing?format=credits

struct GrokCreditsBillingResponse: Codable {
    let config: GrokCreditsConfig
}

struct GrokCreditsConfig: Codable {
    let currentPeriod: GrokUsagePeriod?
    let creditUsagePercent: Double
    let onDemandCap: GrokBillingValue?
    let onDemandUsed: GrokBillingValue?
    let productUsage: [GrokProductUsage]?
    let isUnifiedBillingUser: Bool?
    let prepaidBalance: GrokBillingValue?
    let billingPeriodStart: String?
    let billingPeriodEnd: String?
}

struct GrokUsagePeriod: Codable {
    let type: String?
    let start: String
    let end: String
}

struct GrokProductUsage: Codable {
    let product: String
    let usagePercent: Double
}

struct GrokBillingValue: Codable {
    let val: Int
}

// MARK: - 月额度（仅用于套餐名推断，可选）

struct GrokMonthlyBillingResponse: Codable {
    let config: GrokMonthlyBillingConfig
}

struct GrokMonthlyBillingConfig: Codable {
    let monthlyLimit: GrokBillingValue?
    let used: GrokBillingValue?
}

// MARK: - 本地 auth.json 登录态

struct GrokAuthStatus: Sendable {
    let isLoggedIn: Bool
    let email: String?
    let displayName: String?
    let expiresAt: Date?
    let isExpired: Bool
    let token: String?
    let jwtTier: Int?

    static let loggedOut = GrokAuthStatus(
        isLoggedIn: false,
        email: nil,
        displayName: nil,
        expiresAt: nil,
        isExpired: false,
        token: nil,
        jwtTier: nil
    )

    var statusLine: String {
        if !isLoggedIn { return "未登录 — 请运行 grok login" }
        if isExpired { return "登录过期 — 请重新 grok login" }
        if let email { return "已登录: \(email)" }
        return "已登录"
    }
}

struct GrokSubscriptionSummary: Sendable {
    let isLoggedIn: Bool
    let planName: String
    let email: String?
    /// 例：当前套餐：SuperGrok （wesley@…）
    let line: String

    static let loggedOut = GrokSubscriptionSummary(
        isLoggedIn: false,
        planName: "—",
        email: nil,
        line: "当前套餐：—（未登录）"
    )
}

// MARK: - Grok 用量服务

/// 使用 `?format=credits` 拉取与官网一致的**每周**限额数据。
final class GrokUsageService: BalanceServiceProtocol, @unchecked Sendable {
    let serviceName = "Grok"
    private let creditsEndpoint = "https://cli-chat-proxy.grok.com/v1/billing?format=credits"
    private let monthlyEndpoint = "https://cli-chat-proxy.grok.com/v1/billing"

    // MARK: - Auth

    func readAuthStatus() -> GrokAuthStatus {
        let authPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".grok/auth.json")

        guard let data = try? Data(contentsOf: authPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .loggedOut
        }

        for (_, value) in json {
            guard let entry = value as? [String: Any],
                  let token = entry["key"] as? String,
                  !token.isEmpty else {
                continue
            }

            let email = entry["email"] as? String
            let first = entry["first_name"] as? String
            let last = entry["last_name"] as? String
            let displayName: String? = {
                let parts = [first, last].compactMap { $0 }.filter { !$0.isEmpty }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }()

            var expiresAt: Date?
            if let expiresStr = entry["expires_at"] as? String {
                expiresAt = Self.parseISO8601(expiresStr)
            }
            let isExpired = expiresAt.map { $0 <= Date() } ?? false
            let jwtTier = Self.decodeJWTTier(token)

            return GrokAuthStatus(
                isLoggedIn: true,
                email: email,
                displayName: displayName,
                expiresAt: expiresAt,
                isExpired: isExpired,
                token: token,
                jwtTier: jwtTier
            )
        }
        return .loggedOut
    }

    func fetchSubscriptionSummary() async -> GrokSubscriptionSummary {
        let auth = readAuthStatus()
        guard auth.isLoggedIn, let token = auth.token, !token.isEmpty else {
            return .loggedOut
        }
        let emailSuffix = auth.email.map { "（\($0)）" } ?? ""
        if auth.isExpired {
            return GrokSubscriptionSummary(
                isLoggedIn: true,
                planName: "—",
                email: auth.email,
                line: "当前套餐：—（登录过期）\(emailSuffix)"
            )
        }

        // 套餐：优先月额度推断；失败则用 JWT tier
        var plan = Self.planName(monthlyLimit: nil, jwtTier: auth.jwtTier)
        if let monthly = try? await fetchMonthlyBilling(token: token),
           let limit = monthly.config.monthlyLimit?.val {
            plan = Self.planName(monthlyLimit: limit, jwtTier: auth.jwtTier)
        }
        return GrokSubscriptionSummary(
            isLoggedIn: true,
            planName: plan,
            email: auth.email,
            line: "当前套餐：\(plan) \(emailSuffix)"
        )
    }

    // MARK: - 周限额用量

    func fetchUsage() async throws -> UsageResult {
        let auth = readAuthStatus()
        guard auth.isLoggedIn, let token = auth.token, !token.isEmpty else {
            throw BalanceError.missingGrokAuth
        }

        let credits = try await fetchCreditsBilling(token: token)
        let cfg = credits.config
        let usedPercent = max(0, min(100, cfg.creditUsagePercent))
        let remainingPercent = max(0, 100 - usedPercent)

        let periodEndISO = cfg.currentPeriod?.end ?? cfg.billingPeriodEnd ?? ""
        let periodStartISO = cfg.currentPeriod?.start ?? cfg.billingPeriodStart ?? ""
        let resetText = Self.formatResetDateTime(periodEndISO)

        var productLines: [String] = []
        if let products = cfg.productUsage {
            for p in products {
                let name: String
                switch p.product {
                case "GrokBuild": name = "Grok Build"
                case "GrokChat": name = "聊天"
                default: name = p.product
                }
                productLines.append("\(name) \(Int(p.usagePercent.rounded()))%")
            }
        }

        var lines: [String] = [
            "每周 SuperGrok 限额",
            "已用 \(String(format: "%.0f", usedPercent))% · 余量 \(String(format: "%.0f", remainingPercent))%",
            "下次重置 \(resetText)",
        ]
        if !productLines.isEmpty {
            lines.append(productLines.joined(separator: " · "))
        }
        if let email = auth.email {
            lines.append("账号: \(email)")
        }
        if !periodStartISO.isEmpty {
            lines.append("本周 \(Self.formatResetDateTime(periodStartISO)) 起")
        }

        // used/limit 用百分制，便于 UI 算余量 = (limit-used)/limit
        return UsageResult(
            displayValue: "\(Int(remainingPercent.rounded()))%",
            detailDescription: lines.joined(separator: "\n"),
            used: usedPercent,
            limit: 100,
            rawSummary: resetText
        )
    }

    // MARK: - HTTP

    private func fetchCreditsBilling(token: String) async throws -> GrokCreditsBillingResponse {
        try await fetchJSON(urlString: creditsEndpoint, token: token)
    }

    private func fetchMonthlyBilling(token: String) async throws -> GrokMonthlyBillingResponse {
        try await fetchJSON(urlString: monthlyEndpoint, token: token)
    }

    private func fetchJSON<T: Decodable>(urlString: String, token: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw BalanceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("DSBalance/1.2", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw BalanceError.invalidResponse
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                throw BalanceError.unauthorized
            }
            guard (200 ... 299).contains(http.statusCode) else {
                throw BalanceError.invalidResponse
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as BalanceError {
            throw error
        } catch is DecodingError {
            throw BalanceError.invalidResponse
        } catch {
            throw BalanceError.networkError(error)
        }
    }

    // MARK: - Helpers

    static func planName(monthlyLimit: Int?, jwtTier: Int?) -> String {
        if let monthlyLimit {
            switch monthlyLimit {
            case 0: return "Grok Build"
            case 1 ..< 5000: return "Grok Build"
            case 5000 ..< 20000: return "SuperGrok"
            case 20000...: return "SuperGrok Heavy"
            default: break
            }
        }
        if let jwtTier, jwtTier >= 2 { return "SuperGrok Heavy" }
        if let jwtTier, jwtTier >= 1 { return "SuperGrok" }
        return "SuperGrok"
    }

    private static func decodeJWTTier(_ token: String) -> Int? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - b64.count % 4) % 4
        b64 += String(repeating: "=", count: pad)
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let t = obj["tier"] as? Int { return t }
        if let t = obj["tier"] as? String { return Int(t) }
        return nil
    }

    static func parseISO8601(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    /// 例：2026年7月30日 10:25（本地时区）
    static func formatResetDateTime(_ isoDate: String) -> String {
        guard let date = parseISO8601(isoDate) else {
            return isoDate
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy年M月d日 HH:mm"
        return df.string(from: date)
    }
}
