import AppKit

// ============================================================
// 程序入口 —— 类比 Python 脚本的 if __name__ == "__main__":
// 只做"装配"，不含任何业务逻辑。
//
// 为什么不用 SwiftUI 的 @main App？
// 桌宠窗口需要 AppKit 级别的精确控制（borderless/不抢焦点/无 Dock 图标），
// 自己装配 NSApplication 是最透明的路径，每一行都看得见。
// ============================================================

let app = NSApplication.shared
let delegate = AppDelegate()
// ⚠️ 经典陷阱：NSApplication.delegate 是【weak】引用。
// 如果上面写成 weak，下一行之后 delegate 就没人持有、立即被释放，
// applicationDidFinishLaunching 永远不会被调用（程序看起来"启动了但啥都没有"）。
// 这里的局部常量会在 app.run() 阻塞期间一直存活，所以是安全的。
app.delegate = delegate

// .accessory = 运行时等价于 Info.plist 的 LSUIElement：
// 不显示 Dock 图标、不进 Cmd+Tab 切换列表。
// （SPM 没有 Info.plist，所以我们用运行时 API 达成同样效果）
app.setActivationPolicy(.accessory)

app.run()   // 进入事件循环，阻塞在这里直到 App 退出
