import Foundation

// ============================================================
// ChatService —— OpenAI 兼容 API 客户端（非流式）。
//
// 为什么按"OpenAI 兼容格式"写？
// 这个格式已成行业标准：DeepSeek、智谱 GLM、OpenAI、Ollama…
// 全都支持同一套 /chat/completions 接口结构，换供应商只改
// 配置文件里的 base_url / api_key / model 三个字段，代码零改动。
//
// async throws 的语义和 Python 的 asyncio 几乎一致：
//   async def send() → try await send()
// ============================================================

/// 我们自己定义的错误：附带"人话"描述，直接可给用户看
enum ChatError: LocalizedError {
    case badBaseURL
    case http(Int, String?)   // HTTP 状态码 + 服务端错误消息（如有）
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .badBaseURL:  return "base_url 无效，请检查配置文件"
        case .http(let code, let msg):
            return msg.map { "API 错误(\(code))：\($0)" } ?? "API 错误，HTTP \(code)"
        case .emptyReply:  return "API 没有返回内容"
        }
    }
}

final class ChatService {
    let config: ChatConfig   // engine 会读 pokeTemperature 等戳一戳参数

    init(config: ChatConfig) {
        self.config = config
    }

    /// 发送对话，返回桌宠的回复文本。
    /// temperatureOverride / maxTokens：给"戳一戳"这类特殊场景用的单次覆盖
    /// （戳一戳要高温、极短回复；正常聊天用配置文件里的默认值）
    func send(_ history: [ChatMessage],
              temperatureOverride: Double? = nil,
              maxTokens: Int? = nil) async throws -> String {
        // 1) 拼 URL：appendingPathComponent 自动处理末尾斜杠，
        //    base_url 带不带 "/" 都正确
        guard let base = URL(string: config.baseURL) else { throw ChatError.badBaseURL }
        let url = base.appendingPathComponent("chat").appendingPathComponent("completions")

        // 2) 组装请求体：桌宠人设放最前面，之后接对话历史
        var all = history
        if let sp = config.systemPrompt {
            all.insert(ChatMessage(role: "system", content: sp), at: 0)
        }
        let body = ChatRequestBody(model: config.model, messages: all,
                                    stream: false,
                                    temperature: temperatureOverride ?? config.temperature,
                                    maxTokens: maxTokens)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60   // 网络差时最多等 1 分钟
        request.httpBody = try JSONEncoder().encode(body)

        // 3) 发请求（await = 挂起等结果，不阻塞主线程、动画照常跑）
        let (data, response) = try await URLSession.shared.data(for: request)

        // 4) 非 2xx → 尽量把服务端的错误消息挖出来展示
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = try? JSONDecoder().decode(ChatErrorBody.self, from: data).error?.message
            throw ChatError.http(http.statusCode, msg)
        }

        // 5) 解析回复
        let decoded = try JSONDecoder().decode(ChatResponseBody.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw ChatError.emptyReply
        }
        return content
    }
}
