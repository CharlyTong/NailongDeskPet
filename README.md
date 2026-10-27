# 奶龙桌宠 · NailongDeskPet

> 一只在 macOS 屏幕底部溜达的奶龙：能戳、能拖、能摔、能聊。
> Swift + SwiftUI 原生实现，无第三方依赖，接 DeepSeek API 会说抽象短句。

## 功能

| 交互 | 效果 |
|---|---|
| 什么都不做 | 待机摸肚皮，偶尔自己溜达两步 |
| **左键戳一戳** | 弹出对话气泡，AI 生成一句 ≤10 字的抽象短句（可配置温度） |
| **按住拖动** | 被拎起来淡定玩手，拖到半空松手会**边笑边掉落**（重力模拟） |
| **右键菜单** | 和我聊天（AI 对话窗）/ 测试 API / 回到屏幕底部 / 退出 |
| AI 聊天 | 完整上下文记忆，人设可自定义（system prompt） |

- 桌宠不抢键盘焦点：你打字时点它，输入法纹丝不动
- 无网 / 未配置 Key 时自动降级为本地趣味文案，离线也能戳

## 环境要求

- macOS 13+
- Swift 5.9+（Xcode Command Line Tools）
- DeepSeek API Key（可选，没有则无 AI 功能但桌宠照常运行）

## 快速开始

```bash
git clone https://github.com/CharlyTong/NailongDeskPet.git
cd NailongDeskPet
cp config.example.json config.json
# 编辑 config.json 填入你的 API Key（https://platform.deepseek.com）
swift run DeskPet
```

## 配置说明（config.json）

| 字段 | 作用 | 默认 |
|---|---|---|
| `base_url` | API 入口，OpenAI 兼容格式，换供应商只改这行 | DeepSeek |
| `api_key` | 你的密钥（**此文件已被 .gitignore 保护，不会进仓库**） | — |
| `model` | 模型名 | `deepseek-chat` |
| `system_prompt` | 聊天人设 | 奶龙性格 |
| `temperature` | 聊天随机度（0~2，越低越稳定） | 0.8 |
| `poke_temperature` | 戳一戳短句随机度（调高更抽象发疯） | 1.8 |

注意：配置只在启动时读取，改完需退出重启（右键 → 退出，再 `swift run DeskPet`）。

## 项目结构

```
Sources/DeskPet/
├── main.swift / AppDelegate.swift   # 入口与装配（窗口、右键菜单、生命周期）
├── Window/                          # NSPanel 三件套
│   ├── PetPanel                     #   桌宠窗：透明+置顶+不抢焦点
│   ├── BubblePanel                  #   气泡窗：点击穿透 + 不随 App 失活隐藏
│   └── ChatPanel                    #   聊天窗：唯一接收键盘焦点的窗口
├── Model/
│   ├── PetEngine                    #   30Hz 主循环：移动/重力/状态机/戳一戳编排
│   └── PetState                     #   idle / walk / happy / drag / fall 状态机
├── Views/                           # SwiftUI 渲染层（只读数据画图，不含业务逻辑）
│   ├── PetView / BubbleView / ChatPanelView
├── Chat/
│   ├── ChatConfig                   #   config.json 解析（#filePath 定位项目根）
│   ├── ChatService                  #   OpenAI 兼容 API 客户端
│   └── ChatModels                   #   请求/响应模型
└── Support/
    ├── SpriteStore                  #   帧动画加载（Codable 配置驱动）
    └── ScreenInfo                   #   屏幕可用区域查询
```

## 若干设计要点（踩坑实录）

1. **单一手势自判点击/拖拽**：真人点击必带几像素手抖，`onTapGesture` + `DragGesture` 并存时 tap 常被吞。解法是只挂一个 `minimumDistance: 0` 的拖拽手势，松手时按总位移 <6pt 判定为戳。
2. **气泡窗口两连坑**：`NSPanel` 默认 `hidesOnDeactivate`，而桌宠 App 永不活跃导致气泡秒隐藏；`NSHostingView` 默认按内容理想尺寸反向改窗口几何。前者补 `.nonactivatingPanel`，后者设 `sizingOptions = []`。
3. **拖拽跟手**：SwiftUI `DragGesture.translation` 是相对视图自身的位移，拖窗口时坐标系跟着动形成循环减速。改用 `NSEvent.mouseLocation` 全局坐标计算增量，与 `setFrameOrigin` 完全同系，无需 y 轴换算。
4. **深浅色半硬编码翻车**：背景写死白色而文字色跟随系统外观，深色模式下白字白底。凡一半硬编码一半跟随系统的组合，外观切换必翻车——两边必须一致。

## 换皮肤

帧序列在 `Sources/DeskPet/Resources/Sprites/`，命名 `idle_0.png`、`walk_0.png`…，帧数与帧率在 `SpriteConfig.json` 里改，重新 `swift run` 即可生效。

## 素材声明

奶龙与 oiiai 素材均来源于网络，本项目仅作个人学习与技术演示用途，不作任何商业分发，如有侵权请联系删除。

## 已知限制（Roadmap）

- [ ] 聊天记忆仅在内存中，重启失忆（计划持久化到本地 JSON）
- [ ] 尚未打包 `.app`，目前通过 `swift run` 运行
- [ ] 暂无开机自启与菜单栏常驻图标
