import AppKit
import SwiftUI

// ============================================================
// BubblePanel —— 气泡窗口。
//
// 为什么气泡要单独开一个窗口，而不是画在桌宠窗口上方？
// 如果把桌宠窗口加高来放气泡，那块"透明但存在的窗口区域"
// 会挡住下面 App 的鼠标点击（窗口是矩形的，透明 ≠ 不存在）。
// 所以气泡独立成窗，并开启整窗点击穿透：
// ============================================================
final class BubblePanel: NSPanel {
    init(engine: PetEngine) {
        let size = PetEngine.bubbleSize
        super.init(contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
                   // .nonactivatingPanel：与 PetPanel 同款豁免——NSPanel 的
                   // hidesOnDeactivate 默认为 true（App 非活跃就自动隐藏面板），
                   // 而桌宠程序设计上永不成为活跃应用（不抢用户焦点）→
                   // 气泡窗口每次 orderFrontRegardless 后都被 AppKit 立即隐藏，
                   // 造成"幽灵窗口"：位置对、内容已渲染、但合成器永远不上屏。
                   // 这是气泡从项目第一天就不可见的真正原罪。
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false   // 双保险：显式关掉 NSPanel 的默认自动隐藏

        // ★ 整窗鼠标穿透：点击像穿过空气一样直达下层 App，气泡纯展示。
        //   （对比：桌宠窗口【不能】开这个，否则点不着桌宠了）
        ignoresMouseEvents = true

        // ★★ 踩坑修复：SwiftUI 默认会按内容"理想尺寸"反向改宿主窗口
        //  的 frame（本例 76pt 高的窗口被悄悄撑到 141pt），并在每次
        //  SwiftUI 布局时重设窗口位置 —— 跟引擎 tick 里的 setFrameOrigin
        //  拉锯，把气泡钉死在错误坐标、且被窗口服务器判为"不在屏"，
        //  用户永远看不见。sizingOptions = [] = 禁止 SwiftUI 碰窗口
        //  几何，窗口的大小位置只归 AppKit 管。
        let host = NSHostingView(rootView: BubbleView(engine: engine))
        host.sizingOptions = []                       // 关键一行
        host.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        host.autoresizingMask = [.width, .height]    // 跟随窗口伸缩
        contentView = host
        // 用显式 rect 锁回设计尺寸（直接写 contentRect 会被 Swift 解析成
        // NSWindow 的同名方法而不是 init 参数，编译报类型歧义）
        setFrame(NSRect(x: 0, y: 0, width: size.width, height: size.height), display: false)
    }
}
