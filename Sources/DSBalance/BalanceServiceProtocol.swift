import Foundation

// MARK: - 统一查询接口

protocol BalanceServiceProtocol {
    var serviceName: String { get }
    func fetchUsage() async throws -> UsageResult
}

// MARK: - 用量结果

struct UsageResult: Sendable {
    /// 菜单栏/列表主显示（如 "¥12.34" 或 "3418 / 15000"）
    let displayValue: String
    /// 详情（tooltip / 副标题）
    let detailDescription: String
    /// 已用量（百分比用，可选）
    let used: Double?
    /// 总量/上限（百分比用，可选）
    let limit: Double?
    /// 简短摘要
    let rawSummary: String
}

// MARK: - 查询错误

enum BalanceError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case missingAPIKey
    case missingGrokAuth
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API 地址"
        case .networkError(let e):
            return "网络错误: \(e.localizedDescription)"
        case .invalidResponse:
            return "服务器返回异常"
        case .unauthorized:
            return "认证失败，请检查登录状态或 API Key"
        case .missingAPIKey:
            return "未配置 DeepSeek API Key"
        case .missingGrokAuth:
            return "未找到 Grok 登录信息，请先运行 grok login"
        case .noData:
            return "无可用数据"
        }
    }
}
