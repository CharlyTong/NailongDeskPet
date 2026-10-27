import AppKit
import SwiftUI

// ============================================================
// AppDelegate —— 总指挥：负责"装配"（创建窗口和引擎、互相连线），
// 以及全局事件（右键菜单、打开聊天窗口）。不参与每帧的逻辑。
// ============================================================
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: PetEngine!
    private var petPanel: PetPanel!
    private var bubblePanel: BubblePanel!
    private var chatPanel: ChatPanel?
    private var menu: NSMenu?                 // NSMenu 必须强引用（见 showMenu）
    private var napActivity: Any?             // 防 App Nap 的凭证（释放即失效，必须持有）
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 防 App Nap：桌宠长期处于"非激活"状态，系统可能合并/暂停我们的定时器
        // 导致动画卡顿。登记一个"我在干活"的凭证，系统就不动我们了。
        napActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep], reason: "桌宠动画")

        // ---- 装配：先造大脑和窗口，再互相注入引用 ----
        engine = PetEngine()
        bubblePanel = BubblePanel(engine: engine)
        petPanel = PetPanel(engine: engine)
        engine.panel = petPanel
        engine.bubblePanel = bubblePanel
        petPanel.hostingView.onRightClick = { [weak self] point in
            self?.showMenu(at: point)
        }

        // orderFrontRegardless = 显示窗口但【不激活 App】。
        // 若用 makeKeyAndOrderFront 会尝试抢焦点，违反桌宠"不打扰"原则。
        petPanel.orderFrontRegardless()
        engine.start()

        // 屏幕分辨率/Dock 位置变化 → 把桌宠夹回屏幕内
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.engine.clampToScreen()
            }

        // ---- 聊天配置（API key 不进代码仓库，是安全习惯）----
        if let cfg = ChatConfig.load() {
            engine.chatService = ChatService(config: cfg)
        } else {
            print(ChatConfig.missingConfigHint)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    // MARK: - 右键菜单

    private func showMenu(at point: NSPoint) {
        let menu = NSMenu()
        let items: [(String, Selector)] = [
            ("和我聊天…", #selector(openChat)),
            ("测试 API", #selector(testAPI)),
            ("回到屏幕底部", #selector(sendHome)),
        ]
        for (title, sel) in items {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        // ⚠️ 经典陷阱：NSMenu 用局部变量弹出后会被立即释放（菜单闪一下就没了），
        // 弹出期间必须有人强引用它。
        self.menu = menu
        menu.popUp(positioning: nil, at: point, in: petPanel.contentView)
        self.menu = nil   // popUp 是阻塞调用，返回时菜单已关闭，可释放
    }

    // MARK: - 菜单动作

    @objc private func openChat() {
        if chatPanel == nil {
            chatPanel = ChatPanel(engine: engine, onClose: { [weak self] in
                self?.chatPanel?.close()   // close() 会触发 windowWillClose → 还焦点
            })
        }
        guard let chatPanel else { return }

        // ★ 键盘焦点三连（桌宠 App 收键盘输入的唯一正确姿势）★
        // accessory App 平时"不是活跃应用"，而 macOS 只把键盘事件投递给活跃应用。
        // 所以：1) 程序激活自己 → 2) 聊天窗口成为 key window → 键盘事件流向输入框。
        NSApp.activate()

        // 定位在桌宠右上侧，并夹取在屏幕内
        let petFrame = petPanel.frame
        let f = ScreenInfo.visibleFrame
        let size = chatPanel.frame.size
        var x = petFrame.maxX + 12
        var y = petFrame.minY + 80
        x = min(max(x, f.minX), f.maxX - size.width)
        y = min(max(y, f.minY), f.maxY - size.height)
        chatPanel.setFrameOrigin(NSPoint(x: x, y: y))
        chatPanel.makeKeyAndOrderFront(nil)
    }

    @objc private func testAPI() {
        engine.testAPI()
    }

    @objc private func sendHome() {
        engine.resetToGround()
    }
}
