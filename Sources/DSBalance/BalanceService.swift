import Foundation

// MARK: - 余额响应模型

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

// MARK: - 查询错误

enum BalanceError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: "无效的 API 地址"
        case .networkError(let e): "网络错误: \(e.localizedDescription)"
        case .invalidResponse: "服务器返回异常"
        case .unauthorized: "API Key 无效或已过期"
        }
    }
}

// MARK: - 余额服务

final class BalanceService: @unchecked Sendable {
    private let endpoint = "https://api.deepseek.com/user/balance"

    nonisolated func fetchBalance(apiKey: String) async throws -> BalanceResponse {
        guard let url = URL(string: endpoint) else {
            throw BalanceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BalanceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw BalanceError.unauthorized
        }

        guard (200 ... 299).contains(http.statusCode) else {
            throw BalanceError.invalidResponse
        }

        return try JSONDecoder().decode(BalanceResponse.self, from: data)
    }
}
