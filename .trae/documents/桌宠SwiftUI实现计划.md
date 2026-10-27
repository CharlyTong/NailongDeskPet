# 桌宠（DeskPet）实现计划 — Swift/SwiftUI 原生 macOS 应用

## Context

用户想从零做一个 macOS 桌宠：桌宠在屏幕底部走动、有待机/走路序列帧动画、可拖拽、单击有反应、右键菜单退出，后续接 DeepSeek API 实现 AI 聊天（回复显示在头顶气泡）。用户是 Swift 零基础初学者，希望在开发中理解架构与代码逻辑，因此方案强调**每个里程碑结束应用都可运行**、分层清晰、逐处讲解设计意图。

**环境**：macOS 26.6 (arm64)，Swift 6.3.3，仅有 Command Line Tools（无 Xcode）→ 必须用 **Swift Package Manager**（`swift build` / `swift run`），不依赖 .xcodeproj。无 Info.plist 的限制全部用运行时 API 等价解决。

## 技术选型结论（含理由）

| 决策点 | 选择 | 理由 |
|---|---|---|
| 项目组织 | SPM executable target | 无 Xcode 也能构建；项目结构 = Package.swift + Sources，对初学者最透明 |
| 窗口实现 | AppKit `NSPanel` 子类 + `NSHostingView` 桥接 SwiftUI 内容 | 桌宠要求 borderless/透明/置顶/nonactivating 四件事必须用 AppKit 精确控制；纯 SwiftUI App lifecycle 做不到 |
| 动画引擎 | 单个 30Hz `Timer` 挂 `RunLoop .common` + `ObservableObject`（PetEngine） | 逻辑集中在一个可理解的游戏循环里（类似 pygame 主循环）；`.common` mode 保证拖拽期间动画不冻结 |
| 帧率控制 | 不改 Timer 频率，每个动作配 fps，用时间累加器推进帧号 | Timer 抖动不影响动画节奏 |
| 拖拽 | SwiftUI `DragGesture`，位移量换算后 `setFrameOrigin` 移动窗口本身 | AppKit mouseDown 会与 SwiftUI 事件体系打架 |
| 单击/拖拽区分 | `onTapGesture` + `DragGesture(minimumDistance: 4)` 并存 | SwiftUI 手势消歧天然处理 |
| 右键菜单 | 自定义 `PetHostingView` 重写 `rightMouseDown` + 手动弹 `NSMenu` | SwiftUI `.contextMenu` 在非激活 borderless panel 里不可靠 |
| 聊天输入焦点 | 独立 ChatPanel + 打开时 `NSApp.activate(ignoringOtherApps: true)` + `makeKeyAndOrderFront`，关闭时 `NSApp.deactivate()` | accessory + nonactivating 窗口收不到键盘事件是已知坑，独立窗口职责单一 |
| 气泡 | 独立 `BubblePanel`，`ignoresMouseEvents = true` 全窗穿透 | 若画在主窗口内，加高的透明区域会挡住下层 App 点击 |
| 聊天 API | 非流式 OpenAI 兼容格式（DeepSeek `https://api.deepseek.com`），配置读 `~/.config/deskpet/config.json` | MVP 复杂度低；换供应商只改 base_url/api_key/model 三字段；API key 不进代码仓库 |
| Swift 语言模式 | `swiftLanguageModes: [.v5]` | 避开 Swift 6 严格并发检查对初学者的劝退墙，编译器仍是 6.3 |

## 项目结构

```
桌宠/
├── Package.swift                  # platforms: .macOS(.v14)，resources 打包，v5 语言模式
├── config.example.json            # 配置模板（base_url/api_key/model/system_prompt/temperature）
└── Sources/DeskPet/
    ├── main.swift                 # 入口：NSApplication 装配 + .accessory 策略
    ├── AppDelegate.swift          # 总指挥：窗口创建、右键菜单、模块串联
    ├── Window/
    │   ├── PetPanel.swift         # 桌宠窗口：borderless/透明/置顶/nonactivating/.fullScreenAuxiliary
    │   ├── PetHostingView.swift   # NSHostingView 子类，截获右键事件
    │   ├── BubblePanel.swift      # 气泡窗口（ignoresMouseEvents 全穿透）
    │   └── ChatPanel.swift        # 聊天窗口（重写 canBecomeKey = true）
    ├── Views/
    │   ├── PetView.swift          # 精灵渲染 + tap/drag 手势
    │   ├── BubbleView.swift       # 气泡外观
    │   └── ChatPanelView.swift    # 聊天历史 + TextField + 发送/思考中状态
    ├── Model/
    │   ├── PetState.swift         # enum PetState: idle/happy/dragging/falling/walk(left|right)
    │   └── PetEngine.swift        # 30Hz tick：帧推进/走动/重力/随机状态决策
    ├── Chat/
    │   ├── ChatConfig.swift       # 读 ~/.config/deskpet/config.json
    │   ├── ChatModels.swift       # 请求/响应 Codable 结构
    │   └── ChatService.swift      # OpenAI 兼容客户端（URLSession async/await）
    ├── Support/
    │   └── ScreenInfo.swift       # NSScreen.visibleFrame 地面/边界计算
    └── Resources/
        ├── SpriteConfig.json      # 素材元数据：各动作 frames/fps；缺动作回退 idle
        └── Sprites/               # idle_0.png, walk_0.png ...（用户自找 shimeji 风格素材）
```

分层规则：Model 层不 import SwiftUI 即可编译（纯逻辑可单测）；Views 不直接碰 NSWindow。

## 里程碑与实施步骤

### 里程碑 1：基础版（占位图形即可跑）
- **1a 透明窗口骨架**：Package.swift、main.swift、AppDelegate、PetPanel、PetView（先画 128×128 青色圆角矩形占位）、ScreenInfo。要点：`app.delegate` 必须强引用（弱引用陷阱注释标明）；`setActivationPolicy(.accessory)`；`orderFrontRegardless()` 显示不激活。
- **1b 序列帧动画**：PetEngine（帧累加器）、SpriteConfig.json、Sprites/idle 帧。NSImage 启动时预加载全部帧。素材就位前用占位色块不同尺寸模拟各动作。
- **1c 走动+随机行为**：tick 加移动分支与随机决策（idle 2–6 秒 → walk 4–8 秒/idle/反向），边界用 visibleFrame，`setFrameOrigin` 同步。
- **1d 拖拽**：DragGesture(minimumDistance: 4)，SwiftUI→AppKit 坐标系 y 取反换算；本步松手先原地回 idle。
- **1e 右键菜单退出**：PetHostingView 截获 rightMouseDown，NSMenu 强引用属性，`退出 → NSApp.terminate`。

### 里程碑 2：交互反馈
- **2a 单击反应**：`petClicked()` → happy 状态 1.5 秒回 idle（到期时间戳判断）。
- **2b 气泡**：BubblePanel + BubbleView + `showBubble(_:duration:)`（时长 max(3s, 字数×0.08)），内置随机卖萌文案；每 tick 跟随桌宠头顶。
- **2c 重力掉落**：dragEnded 空中判定 → falling，`vy += 900*dt`，落地回 idle；物理常数集中一个 Config enum 方便调参。

### 里程碑 3：AI 聊天（DeepSeek）
- **3a 配置+服务层**：ChatConfig（缺配置时气泡提示+控制台打印教程）、ChatModels、ChatService；右键菜单加「测试 API」项，curl 对照排错；必测错误路径：错 key 401、断网、超时。
- **3b 聊天窗口**：ChatPanel（canBecomeKey 重写）+ ChatPanelView（ScrollView 历史 + TextField + isBusy 防重发）；打开时激活三连，关闭时 deactivate 还焦点；回复写入桌宠头顶气泡并存历史；发送用 `Task { @MainActor in }`。

## 关键代码骨架（已验证设计，执行时按此实现）

```swift
// main.swift：delegate 强引用 + accessory 策略
let app = NSApplication.shared
let delegate = AppDelegate()          // 强引用！NSApplication.delegate 是 weak
app.delegate = delegate
app.setActivationPolicy(.accessory)  // 等价 Info.plist LSUIElement：无 Dock 图标
app.run()

// PetPanel 关键属性
styleMask = [.borderless, .nonactivatingPanel]   // 无边框 + 点击不抢焦点
isOpaque = false; backgroundColor = .clear       // 全透明
level = .floating                                 // 置顶
collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
contentView = PetHostingView(rootView: PetView(...))

// 拖拽坐标系换算（SwiftUI y 向下 → AppKit y 向上）
origin = NSPoint(x: dragBase.x + translation.width,
                 y: dragBase.y - translation.height)

// 聊天键盘焦点（accessory app 收键盘的唯一正确姿势）
NSApp.activate(ignoringOtherApps: true)
chatPanel.makeKeyAndOrderFront(nil)
// 关闭时 NSApp.deactivate()

// 动画 Timer 必须挂 .common mode（否则拖拽期间冻结）
RunLoop.main.add(timer, forMode: .common)
```

## 验证方式（每里程碑结束在终端执行）

```bash
cd /Users/charly-tong/Desktop/桌宠 && swift build && swift run DeskPet
```

- **M1**：透明背景（能看见壁纸）、Dock/Cmd+Tab 无图标、访达窗口盖不住它、点它后文本编辑仍能连续打字（不抢焦点）、切桌面空间跟随
- **M2**：单击切 happy 动画+气泡，气泡区域点击穿透到底层 App，半空松手重力掉落落地回 idle，拖拽不误触单击
- **M3**：右键「和我聊天」窗口直接可打中文（不用先点一下）；回复气泡弹出且上下文连贯；关聊天窗后浏览器/输入法焦点正常归还；错 key/断网有友好气泡报错
- 素材接入后：Dock 移到屏幕左侧重跑，桌宠不走进 Dock 区域（visibleFrame 自动适应）

## 风险与规避

| 风险 | 规避 |
|---|---|
| SPM 裸可执行文件极少数环境下 TextField 收不到键盘 | 3b 第一步先验证；中招则 20 行脚本包 .app bundle + ad-hoc 签名（`codesign -s -`），这本来就是最终交付形态 |
| App Nap 节流动画 | 启动时 `ProcessInfo.beginActivity` 一行保险 |
| 关终端杀进程 | 开发期正常；日常使用走 .app 打包 |
| 素材不规范/缺失 | SpriteConfig 显式声明 + 缺动作回退 idle + 控制台警告 |
| 多显示器/改分辨率 | MVP 锁主屏 + 监听 didChangeScreenParametersNotification 重新夹取 |
| AppKit 引用陷阱（delegate/NSMenu/Timer 循环引用） | 代码逐处注释讲解，PetEngine 对 panel 用 weak |

明确不需要：屏幕录制/辅助功能权限、开发者账号、第三方依赖（零依赖是刻意选择）。

## 给用户的学习配套

每写一个文件，向用户讲解：这个文件在架构里的位置、为什么这么设计、和 Python 里对应概念的类比（如 AppDelegate ≈ `if __name__ == "__main__"` 的装配层、PetEngine ≈ pygame 主循环、Codable ≈ dataclass + json 序列化）。

## 后续扩展（留好接口，不在本期）

流式回复（URLSession.bytes）、位置记忆（UserDefaults）、开机自启（.app + SMAppService）、爬墙/抓窗框等 shimeji 行为、菜单栏控制中心。
