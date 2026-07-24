import Foundation

// MARK: - DeepSeek 余额响应

struct BalanceResponse: Codable {
    let isAvailable: Bool
    let balanceInfos: [BalanceItem]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
}

struct BalanceItem: Codable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String

    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

// MARK: - DeepSeek 余额服务

final class DeepSeekBalanceService: BalanceServiceProtocol, @unchecked Sendable {
    let serviceName = "DeepSeek"
    private let endpoint = "https://api.deepseek.com/user/balance"
    private let configManager: ConfigManager

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    func fetchUsage() async throws -> UsageResult {
        guard let apiKey = configManager.deepSeekAPIKey, !apiKey.isEmpty else {
            throw BalanceError.missingAPIKey
        }

        let balance = try await fetchBalance(apiKey: apiKey)
        guard let info = balance.balanceInfos.first else {
            throw BalanceError.noData
        }

        let symbol = currencySymbol(for: info.currency)
        let displayValue = "\(symbol)\(info.totalBalance)"
        let status = balance.isAvailable ? "可用" : "余额不足"
        let detailDescription = """
        总余额: \(symbol)\(info.totalBalance) \(info.currency)
        赠送: \(symbol)\(info.grantedBalance) \(info.currency)
        充值: \(symbol)\(info.toppedUpBalance) \(info.currency)
        状态: \(status)
        """
        let rawSummary = "\(symbol)\(info.totalBalance) (\(symbol)\(info.grantedBalance) 赠送 / \(symbol)\(info.toppedUpBalance) 充值)"

        return UsageResult(
            displayValue: displayValue,
            detailDescription: detailDescription,
            used: nil,
            limit: Double(info.totalBalance),
            rawSummary: rawSummary
        )
    }

    private func currencySymbol(for currency: String) -> String {
        switch currency {
        case "CNY": return "¥"
        case "USD": return "$"
        default: return "\(currency) "
        }
    }

    private func fetchBalance(apiKey: String) async throws -> BalanceResponse {
        guard let url = URL(string: endpoint) else {
            throw BalanceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

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
            return try JSONDecoder().decode(BalanceResponse.self, from: data)
        } catch let error as BalanceError {
            throw error
        } catch {
            throw BalanceError.networkError(error)
        }
    }
}
