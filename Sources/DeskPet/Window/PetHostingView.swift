import AppKit
import SwiftUI

// ============================================================
// PetHostingView —— AppKit ↔ SwiftUI 的桥。
//
// NSHostingView 负责"把 SwiftUI 视图装进 AppKit 窗口"；
// 我们继承它只为了一件事：截获右键。
//
// 原理：SwiftUI 视图不处理 rightMouseDown，这个事件会沿着
// "响应链"（responder chain）一路上浮到宿主视图，我们在这里接住。
// （比 SwiftUI 的 .contextMenu 可靠：那种菜单在非激活的无边框
//  窗口里行为没有保证，时好时坏。）
// ============================================================
final class PetHostingView<Content: View>: NSHostingView<Content> {
    /// 右键回调（参数 = 点击位置在视图内的坐标，供菜单定位用）
    var onRightClick: ((NSPoint) -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        // 把"窗口坐标"换算成"视图坐标"（两者可能有偏移，不能直接用）
        onRightClick?(convert(event.locationInWindow, from: nil))
    }
}
