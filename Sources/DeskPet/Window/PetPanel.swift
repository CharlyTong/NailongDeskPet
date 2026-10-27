import AppKit
import SwiftUI

// ============================================================
// PetPanel —— 桌宠窗口。
//
// 为什么继承 NSPanel 而不是直接用 SwiftUI 的 Window？
// "透明背景 + 无边框 + 置顶 + 点击不抢焦点"这四件事必须用
// AppKit 的窗口属性精确控制，SwiftUI 声明式接口做不到这个粒度。
// NSPanel 是 NSWindow 的子类，专用于"辅助面板"类窗口。
// ============================================================
final class PetPanel: NSPanel {
    let hostingView: PetHostingView<PetView>

    init(engine: PetEngine) {
        let size = PetConfig.petSize
        let visible = ScreenInfo.visibleFrame
        hostingView = PetHostingView(rootView: PetView(engine: engine))

        // 初始位置：屏幕"地面"（可见区底部）水平居中
        let frame = NSRect(x: visible.midX - size.width / 2,
                           y: visible.minY,
                           width: size.width, height: size.height)
        super.init(contentRect: frame,
                   // .borderless       无边框，连标题栏都没有，窗口就是精灵本身
                   // .nonactivatingPanel 点击它不会把我们的 App 变成"活跃应用"，
                   //                    用户正在写的文档不会突然失焦 —— 桌宠的灵魂属性
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear     // 全透明：窗口矩形里除精灵外都能透出桌面壁纸
        hasShadow = false             // 透明窗口配系统阴影会出现难看的方框，关掉
        level = .floating             // 置顶：浮在所有普通窗口之上（低于菜单栏）
        collectionBehavior = [
            .canJoinAllSpaces,        // 切换桌面空间时桌宠跟随
            .fullScreenAuxiliary     // 别人全屏看视频/写代码时桌宠仍可见
        ]
        contentView = hostingView     // 把 SwiftUI 视图装进 AppKit 窗口
    }
}
