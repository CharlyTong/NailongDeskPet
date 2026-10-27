import AppKit
import Combine

// ============================================================
// PetEngine —— 桌宠的"大脑"（游戏主循环 + 状态机）
//
// 架构类比：这就是一个 pygame 游戏的 main loop。
//   每 1/30 秒 tick() 一次，每次干三件事：
//     1. 推进动画帧号（序列帧播放）
//     2. 按当前状态执行行为逻辑（走动 / 重力下落 / 到点换状态）
//     3. 气泡跟随 + 到点隐藏
//
// 分层规则：视图层（PetView）只"看数据画图"，从不改逻辑；
// 所有决策都在这里，所以想改桌宠性格只需读这个文件。
//
// @Published 的含义：这些属性一变，SwiftUI 视图自动刷新，
// 类似"订阅-推送"模式，我们不用手写任何刷新代码。
// ============================================================
final class PetEngine: ObservableObject {

    // MARK: - 对外连接（都由 AppDelegate 装配后注入，weak 防循环引用）
    weak var panel: PetPanel?          // 桌宠窗口（引擎要移动它）
    weak var bubblePanel: BubblePanel? // 气泡窗口（引擎要定位它）
    var chatService: ChatService?      // AI 聊天客户端（配置好了才有）

    let sprites = SpriteStore()

    // MARK: - 视图要观察的数据（变了 SwiftUI 自动重画）
    @Published private(set) var state: PetState = .idle
    @Published private(set) var frameIndex = 0
    @Published private(set) var bubbleText: String?
    @Published private(set) var messages: [ChatMessage] = []   // 聊天历史
    @Published private(set) var isBusy = false                 // 正在等 API 回复

    // MARK: - 私有运行状态
    private var timer: Timer?
    private var lastTick: TimeInterval = 0
    private var frameAccum = 0.0        // 帧时间累加器（见 tick 注释）
    private var nextDecision = 0.0      // 下次"随机换行为"的绝对时刻
    private var happyUntil = 0.0        // happy 状态的到期时刻
    private var bubbleHideAt = 0.0      // 气泡的隐藏时刻
    private var origin = NSPoint.zero   // 窗口左下角位置（AppKit 坐标系：y 向上）
    private var dragBase = NSPoint.zero // 拖拽起点的窗口位置
    private var dragStartMouse = NSPoint.zero // 拖拽起点的光标位置（系统全局坐标）
    private var vy: CGFloat = 0         // 下落速度

    /// 戳一戳的本地兜底文案（API 没配/失败时随机蹦一句）
    private static let pokeLines = [
        "我在。", "戳我干嘛？", "你有事吗", "牛来！", "我是奶龙",
        "别戳肚皮！", "再戳要收费了", "戳坏了赔钱哦", "嗯？",
    ]

    /// 戳一戳的专属人设：要求模型每次现编一句极短、抽象、贱萌的回应
    private static let pokePrompt = """
    你是桌宠奶龙，一只圆滚滚的黄色小恐龙。用户戳了你一下。
    现编一句【15字以内】的贱萌抽象短句回应，越抽象越好风格参考（禁止照抄）：
    "我在"、"戳我干嘛？"、"你有事吗"、"牛来"、"我是奶龙"。
    直接输出那一句话。禁止解释，禁止重复之前的回复。
    """
    private var pokeTask: Task<Void, Never>?   // 挂起的戳一戳请求（可取消）
    /// 气泡窗口尺寸（BubblePanel 同步使用）
    static let bubbleSize = CGSize(width: 250, height: 76)

    private static var now: TimeInterval { Date.timeIntervalSinceReferenceDate }

    // ============================================================
    // 生命周期
    // ============================================================

    func start() {
        origin = panel?.frame.origin ?? origin   // 以 AppDelegate 摆好的初始位置为准
        scheduleNextDecision(2...6)
        let t = Timer(timeInterval: PetConfig.tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // 必须挂 .common mode：默认 mode 下，用户拖拽窗口/菜单期间
        // 系统进入"事件追踪模式"，Timer 会被暂停 → 动画冻住。
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // ============================================================
    // 主循环：每 1/30 秒一次
    // ============================================================
    private func tick() {
        let now = Self.now
        // dt = 距上次 tick 的真实秒数；封顶 0.1 秒，防止系统休眠/卡顿后
        // 一次性"补"出一大段位移把桌宠瞬移出屏幕
        let dt = lastTick == 0 ? 0 : min(now - lastTick, 0.1)
        lastTick = now

        // ---- 1) 动画帧推进（时间累加器）----
        // 不直接"每次 tick 帧号+1"：Timer 总有 ±几毫秒抖动，
        // 累加器保证"每帧该占多少秒"是精确的，动画节奏永远稳定。
        let info = sprites.info(for: currentAction)
        frameAccum += dt
        let frameDuration = 1.0 / info.fps
        while frameAccum >= frameDuration {
            frameAccum -= frameDuration
            frameIndex = (frameIndex + 1) % max(info.frames, 1)
        }

        // ---- 2) 状态机行为逻辑 ----
        switch state {
        case .idle, .walk:
            moveIfWalking(dt: dt)
            if now >= nextDecision { decideNextBehavior() }
        case .happy:
            if now >= happyUntil { setState(.idle); scheduleNextDecision(2...6) }
        case .falling:
            applyGravity(dt: dt)
        case .dragging:
            break   // 拖拽中位置完全由 dragMoved 回调控制，tick 不插手
        }

        // ---- 3) 气泡：跟随桌宠移动，到点隐藏 ----
        if bubbleText != nil {
            if now >= bubbleHideAt {
                bubbleText = nil
                bubblePanel?.orderOut(nil)
            } else {
                positionBubble()
            }
        }
    }

    // ============================================================
    // 交互入口（由视图层调用）
    // ============================================================

    /// 单击桌宠 = 戳一戳：happy 反应 + 一句短气泡。
    /// 走独立的轻通道：先冒"……"，AI 回复到达后覆盖；不进聊天历史。
    /// 没配 API / 失败 / 连点太快 → 本地随机文案兜底，保证手感和离线可用。
    func petClicked() {
        guard state != .dragging, state != .falling else { return }
        setState(.happy)
        happyUntil = Self.now + 1.5
        poke()
    }

    private func poke() {
        guard let service = chatService else {
            showBubble(Self.pokeLines.randomElement()!)
            return
        }
        // 手速快过网速：新戳取消旧请求，避免"迟到的回复"盖掉新气泡
        pokeTask?.cancel()
        showBubble("……", duration: 10)   // 思考占位，回复到达即被覆盖
        let temp = service.config.pokeTemperature ?? 1.5
        pokeTask = Task { @MainActor in
            do {
                let reply = try await service.send(
                    [ChatMessage(role: "system", content: Self.pokePrompt),
                     ChatMessage(role: "user", content: "（戳了一下你的肚皮）")],
                    temperatureOverride: temp,
                    maxTokens: 24
                )
                guard !Task.isCancelled else { return }
                self.showBubble(reply)
            } catch is CancellationError {
                // 被新的一戳取消：静默退场
            } catch {
                guard !Task.isCancelled else { return }
                self.showBubble(Self.pokeLines.randomElement()!)   // 网络失败：本地兜底
            }
        }
    }

    /// 拖拽中。⚠️ 不用 DragGesture 报的 translation，改读 NSEvent.mouseLocation：
    ///
    /// translation 是"视图坐标系里的相对位移"，而拖拽时窗口被我们不断移动、
    /// 视图跟着动，于是光标每走 10pt、视图自己又挪 5pt，SwiftUI 只报 5pt——
    /// 桌宠恰好以一半速度跟跑，永远追不上光标（这就是"鼠标比桌宠快"的原因）。
    ///
    /// NSEvent.mouseLocation 是系统级全局光标坐标，且与 setFrameOrigin
    /// 同一坐标系（原点在主屏左下、y 向上），不需要任何换算，
    /// 窗口怎么动都不影响它 —— 位移 = 当前光标 - 起点光标。
    func dragMoved() {
        let mouse = NSEvent.mouseLocation
        if state != .dragging {
            setState(.dragging)
            dragBase = origin          // 记住起点窗口位置
            dragStartMouse = mouse     // 记住起点光标位置
        }
        origin = NSPoint(x: dragBase.x + mouse.x - dragStartMouse.x,
                         y: dragBase.y + mouse.y - dragStartMouse.y)
        syncPanel()
    }

    /// 拖拽/按压松手：按总位移判定是"戳"还是"拖"
    func dragEnded() {
        // 距按下起点 <6pt：这不是拖拽，是手抖的点击 → 当戳一戳处理
        let mouse = NSEvent.mouseLocation
        let dist = hypot(mouse.x - dragStartMouse.x, mouse.y - dragStartMouse.y)
        if dist < 6 {
            origin = dragBase          // 弹回按下前的位置（抖动只有几pt，肉眼无感）
            syncPanel()
            // 修 bug：如果是在半空（比如下落途中被点）"戳"到，
            // 不能 setState(.idle) 否则桌宠会冻在半空——让它继续掉
            if origin.y > groundY + PetConfig.groundGap {
                vy = 0
                setState(.falling)
            } else {
                setState(.idle)        // 先解除 dragging，否则 petClicked 的 guard 会拦
                petClicked()
            }
            return
        }
        // ≥6pt：真拖拽。在半空 → 掉落；贴地 → 落回站立
        if origin.y > groundY + PetConfig.groundGap {
            vy = 0
            setState(.falling)
        } else {
            origin.y = groundY
            setState(.idle)
            scheduleNextDecision(2...6)
        }
        syncPanel()
    }

    /// 右键菜单"回到屏幕底部"
    func resetToGround() {
        let f = ScreenInfo.visibleFrame
        origin = NSPoint(x: f.midX - PetConfig.petSize.width / 2, y: f.minY)
        setState(.idle)
        scheduleNextDecision(2...6)
        syncPanel()
    }

    /// 屏幕分辨率/Dock 位置变化时，把桌宠夹回可见区域内
    func clampToScreen() {
        let f = ScreenInfo.visibleFrame
        origin.x = min(max(origin.x, f.minX), f.maxX - PetConfig.petSize.width)
        origin.y = min(max(origin.y, f.minY), f.maxY - PetConfig.petSize.height)
        syncPanel()
    }

    // ============================================================
    // 气泡
    // ============================================================

    /// 在桌宠头顶显示气泡，时长默认"够读完"（3 秒起，字多自动加时）
    func showBubble(_ text: String, duration: Double? = nil) {
        bubbleText = text
        bubbleHideAt = Self.now + (duration ?? max(10, Double(text.count) * 0.08))
        bubblePanel?.orderFrontRegardless()
        positionBubble()
    }

    /// 气泡定位：桌宠头顶居中，水平方向夹取在屏幕内
    private func positionBubble() {
        guard let bubblePanel else { return }
        let size = Self.bubbleSize
        let f = ScreenInfo.visibleFrame
        var x = origin.x + PetConfig.petSize.width / 2 - size.width / 2
        x = min(max(x, f.minX), f.maxX - size.width)
        let y = origin.y + PetConfig.petSize.height + 8
        bubblePanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // ============================================================
    // AI 聊天
    // ============================================================

    /// 发送一条用户消息（聊天窗口调用）；回复会同时进历史 + 头顶气泡
    func sendChat(_ text: String) {
        guard !isBusy else { return }
        guard let service = chatService else {
            showBubble("还没配置 API 哦，启动终端里有教程～", duration: 6)
            return
        }
        messages.append(ChatMessage(role: "user", content: text))
        isBusy = true
        let history = messages
        // Task = Swift 的轻量线程任务；@MainActor 保证回调后回到主线程改 UI 数据。
        // async/await 和 Python 的 asyncio 语义几乎一样。
        Task { @MainActor in
            defer { self.isBusy = false }
            do {
                let reply = try await service.send(history)
                self.messages.append(ChatMessage(role: "assistant", content: reply))
                self.showBubble(reply)
            } catch {
                let msg = "呜…出错了：\(error.localizedDescription)"
                self.messages.append(ChatMessage(role: "assistant", content: msg))
                self.showBubble(msg, duration: 6)
            }
        }
    }

    /// 右键菜单"测试 API"：发一条固定的测试消息，不进聊天历史
    func testAPI() {
        guard !isBusy else { showBubble("上一条还在路上呢…"); return }
        guard let service = chatService else {
            showBubble("还没配置 API 哦，启动终端里有教程～", duration: 6)
            return
        }
        isBusy = true
        showBubble("测试中…", duration: 60)
        Task { @MainActor in
            defer { self.isBusy = false }
            do {
                let reply = try await service.send([
                    ChatMessage(role: "user", content: "你好！请用一句话自我介绍。")
                ])
                self.showBubble("API 正常：\(reply)")
            } catch {
                self.showBubble("失败：\(error.localizedDescription)", duration: 8)
            }
        }
    }

    // ============================================================
    // 内部行为逻辑
    // ============================================================

    /// 状态统一从这里切：同时重置帧号，避免"6 帧走路动画的第 5 帧"
    /// 直接显示成"4 帧 happy 动画"造成画面跳变
    private func setState(_ s: PetState) {
        state = s
        frameIndex = 0
        frameAccum = 0
    }

    private var groundY: CGFloat { ScreenInfo.visibleFrame.minY }

    /// 走路状态下的位移 + 边界检测
    private func moveIfWalking(dt: TimeInterval) {
        guard case .walk(let dir) = state else { return }
        let v = PetConfig.walkSpeed * CGFloat(dt)
        origin.x += dir == .right ? v : -v
        let f = ScreenInfo.visibleFrame
        let minX = f.minX
        let maxX = f.maxX - PetConfig.petSize.width
        if origin.x <= minX {
            origin.x = minX
            setState(.idle); scheduleNextDecision(2...6)   // 撞到屏幕边缘：停下
        } else if origin.x >= maxX {
            origin.x = maxX
            setState(.idle); scheduleNextDecision(2...6)
        }
        syncPanel()
    }

    /// 行为决策定时器到点：决定接下来干嘛（桌宠"性格"就在这个函数里）
    private func decideNextBehavior() {
        var wasWalking: Direction?
        if case .walk(let d) = state { wasWalking = d }

        if let dir = wasWalking {
            // 走累了：60% 停下发呆，40% 掉头继续走
            if Double.random(in: 0...1) < 0.6 {
                setState(.idle); scheduleNextDecision(2...6)
            } else {
                setState(.walk(dir == .left ? .right : .left))
                scheduleNextDecision(4...8)
            }
        } else {
            // 发呆够了：50% 开始走，否则继续发呆
            if Double.random(in: 0...1) < 0.5 {
                origin.y = groundY
                setState(.walk(.random))
                scheduleNextDecision(4...8)
            } else {
                scheduleNextDecision(2...6)
            }
        }
        syncPanel()
    }

    /// 重力下落：vy += g*dt; y -= vy*dt（速度越来越快 = 加速下落）
    private func applyGravity(dt: TimeInterval) {
        vy += PetConfig.gravity * CGFloat(dt)
        origin.y -= vy * CGFloat(dt)
        if origin.y <= groundY {
            origin.y = groundY
            vy = 0
            setState(.idle)
            scheduleNextDecision(2...6)
        }
        syncPanel()
    }

    /// 随机决定下一次行为决策的时机（2~6 秒 = 发呆间隔，4~8 秒 = 走路时长）
    private func scheduleNextDecision(_ range: ClosedRange<Double>) {
        nextDecision = Self.now + Double.random(in: range)
    }

    /// 把逻辑层算出的位置同步到真实窗口
    private func syncPanel() {
        panel?.setFrameOrigin(origin)
    }

    // ============================================================
    // 视图层要读的数据
    // ============================================================

    /// 当前状态对应的动作名（= 素材文件名前缀）
    var currentAction: String {
        switch state {
        case .idle:    return "idle"
        case .walk:    return "walk"
        case .happy:   return "happy"
        case .dragging: return "drag"
        case .falling: return "fall"
        }
    }

    /// 当前应显示的素材帧；没有素材返回 nil（视图画占位色块）
    var currentFrameImage: NSImage? {
        sprites.image(action: currentAction, frame: frameIndex)
    }

    /// 是否面朝左（视图据此做镜像翻转，左右共用一套素材）
    var facingLeft: Bool {
        if case .walk(.left) = state { return true }
        return false
    }
}
