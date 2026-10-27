import AppKit
import SwiftUI

// ============================================================
// ChatPanel —— 聊天窗口。
//
// 它是三个窗口里唯一"正常"的：需要接收键盘输入。
// 两个关键点：
// 1. borderless 窗口默认【永远当不了 key window】（macOS 硬规矩），
//    必须重写 canBecomeKey 放行 —— 没这一行，输入框永远打不进字；
// 2. 窗口关闭时要把键盘焦点礼貌地还给用户原来的 App
//    （NSApp.deactivate，配合 AppDelegate.openChat 里的 activate 成对出现）。
// ============================================================
final class ChatPanel: NSPanel, NSWindowDelegate {
    init(engine: PetEngine, onClose: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
                   styleMask: [.borderless],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = true   // 拖窗口空白处可移动
        contentView = NSHostingView(rootView: ChatPanelView(engine: engine, onClose: onClose))
        delegate = self   // 让自己接收 windowWillClose 事件
    }

    // ★ borderless 窗口默认返回 false，必须显式允许成为 key window，
    //   否则 TextField 收不到任何键盘事件（无焦点窗口项目的头号坑）。
    override var canBecomeKey: Bool { true }

    func windowWillClose(_ notification: Notification) {
        // 还焦点：我们打开聊天时激活了自己，关闭时应退出活跃状态，
        // 键盘焦点自动回到用户之前使用的 App。
        NSApp.deactivate()
    }
}
