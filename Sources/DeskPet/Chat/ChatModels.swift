import Foundation

// ============================================================
// ChatModels —— 与 API 对话的数据结构。
//
// Codable = Decodable + Encodable，相当于 Python 的
// dataclass + json.dumps/json.loads 二合一：结构体和 JSON
// 自动互转，字段名用 CodingKeys 映射蛇形命名。
// ============================================================

/// 一条消息（请求和响应里结构相同，所以一个类型两边复用）
struct ChatMessage: Codable {
    let role: String     // "system" | "user" | "assistant"
    let content: String
}

/// 请求体（只编码，不需要解码）
struct ChatRequestBody: Encodable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool          // false = 非流式：一次返回完整回复（MVP 选择）
    let temperature: Double?
    let maxTokens: Int?
    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case maxTokens = "max_tokens"
    }
}

/// 响应体（只需要解码）
struct ChatResponseBody: Decodable {
    struct Choice: Decodable {
        let message: ChatMessage
        let finishReason: String?
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    let choices: [Choice]
}

/// API 报错时的响应体（如 key 无效、余额不足）
struct ChatErrorBody: Decodable {
    struct APIError: Decodable {
        let message: String?
    }
    let error: APIError?
}
