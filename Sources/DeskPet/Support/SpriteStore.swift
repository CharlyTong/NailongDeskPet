import AppKit

// ============================================================
// 物理与行为常数表 —— 想调"手感"就改这里，不用翻逻辑代码
// ============================================================
enum PetConfig {
    /// 桌宠显示尺寸（素材会被缩放到这个大小）
    static let petSize = CGSize(width: 96, height: 96)
    /// 游戏主循环频率（30 次/秒，和主机游戏一个量级，足够流畅）
    static let tickInterval: TimeInterval = 1.0 / 30.0
    /// 走路速度（点/秒）
    static let walkSpeed: CGFloat = 40
    /// 重力加速度（点/秒²）——调大掉得更猛
    static let gravity: CGFloat = 900
    /// 判定"在空中"的地面容差（点）
    static let groundGap: CGFloat = 2
}

// ============================================================
// 素材库：加载 SpriteConfig.json + 各动作的序列帧 PNG
//
// 设计要点：
// 1. 启动时把配置读进内存；图片用"名字 → NSImage"字典做缓存，
//    第一次用到才加载（懒加载），避免启动卡顿；
// 2. 某个动作的图片缺失时返回 nil，视图层自动退回占位色块，
//    所以"素材没找齐也能先跑通整个程序"。
// ============================================================
struct SpriteActionInfo: Decodable {
    let frames: Int   // 该动作有几帧
    let fps: Double   // 播放速度（帧/秒）
}

struct SpriteConfigFile: Decodable {
    let frameWidth: Int?
    let frameHeight: Int?
    let actions: [String: SpriteActionInfo]
}

final class SpriteStore {
    private let config: SpriteConfigFile?
    private var cache: [String: NSImage] = [:]

    /// 素材完全缺失时的兜底动画参数
    private static let fallback = SpriteActionInfo(frames: 4, fps: 6)

    init() {
        // Bundle.module = SPM 自动生成的"资源包"，声明在 Package.swift 里的
        // resources 都从它里面找（类比 Python 的 importlib.resources）
        if let url = Bundle.module.url(forResource: "SpriteConfig", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let cfg = try? JSONDecoder().decode(SpriteConfigFile.self, from: data) {
            config = cfg
        } else {
            config = nil
            print("⚠️ 未找到 SpriteConfig.json，动画使用占位色块。Bundle 路径：\(Bundle.module.bundlePath)")
        }
    }

    /// 查某动作的帧数/帧率；动作缺失时回退用 idle 的参数（再不行用内置兜底）
    func info(for action: String) -> SpriteActionInfo {
        config?.actions[action] ?? config?.actions["idle"] ?? Self.fallback
    }

    /// 取某动作某一帧的图片；没有素材返回 nil（视图层会画占位色块）
    func image(action: String, frame: Int) -> NSImage? {
        let key = "\(action)_\(frame)"
        if let cached = cache[key] { return cached }
        // 先按 Sprites/ 子目录找（.copy 打包的结构），再按 bundle 根目录找（双保险）
        let url = Bundle.module.url(forResource: key, withExtension: "png", subdirectory: "Sprites")
            ?? Bundle.module.url(forResource: key, withExtension: "png")
        guard let url, let img = NSImage(contentsOf: url) else { return nil }
        cache[key] = img
        return img
    }
}
