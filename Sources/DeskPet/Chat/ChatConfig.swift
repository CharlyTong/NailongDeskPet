import Foundation

// ============================================================
// ChatConfig —— 聊天配置：从项目根目录 config.json 读取。
//
// 路径定位技巧：#filePath 是【编译期常量】，值为本源文件的绝对路径。
// 从它出发往上走 4 级（Chat → DeskPet → Sources → 项目根）就是根目录，
// 无需硬编码 /Users/xxx——换机器、改用户名、挪项目位置都不受影响。
// 注意：这只适合个人项目。发布给别人用的 App 应该放 ~/Library/
// Application Support/（每个用户自己的配置，互不覆盖）。
//
// ⚠️ 里面有 API Key：项目根的 .gitignore 已把 config.json 挡在
// git 之外，没有那张保护网它不能进任何 git 仓库。
// ============================================================
struct ChatConfig: Decodable {
    let baseURL: String          // API 入口，换供应商只改这一行
    let apiKey: String
    let model: String
    let systemPrompt: String?     // 桌宠的"人设"
    let temperature: Double?      // 聊天随机性 0~2，越高回答越发散
    let pokeTemperature: Double? // 戳一戳专用温度（短句要抽象，可以调得更疯）

    // JSON 里的下划线命名 ↔ Swift 的驼峰命名，手动映射
    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case apiKey = "api_key"
        case model
        case systemPrompt = "system_prompt"
        case temperature
        case pokeTemperature = "poke_temperature"
    }

    /// 读配置文件；文件不存在/格式错误都返回 nil（调用方负责友好提示）
    static func load() -> ChatConfig? {
        // #filePath = 本文件编译时的绝对路径；上走 4 级到项目根
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/Chat
            .deletingLastPathComponent()   // …/DeskPet
            .deletingLastPathComponent()   // …/Sources
            .deletingLastPathComponent()   // 项目根（桌宠/）
        let path = root.appendingPathComponent("config.json").path
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(ChatConfig.self, from: data)
    }

    /// 启动时没读到配置，把教程打到终端里
    static let missingConfigHint = """
        ⚠️ 未找到 config.json（项目根目录），AI 聊天暂不可用。配置方法（两步）：
          1. cp config.example.json config.json
          2. 编辑 config.json，填入你的 API Key（DeepSeek Key 申请：https://platform.deepseek.com）

        """
}
