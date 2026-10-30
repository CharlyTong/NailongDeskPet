# 奶龙桌宠 · NailongDeskPet

> 一只在屏幕底部溜达的奶龙：能戳、能拖、能摔、能聊。
> **双平台实现**：macOS 原生版（Swift + SwiftUI）+ Windows 版（Python + PySide6），
> 共用素材、配置格式与 AI 人设，接 DeepSeek 等 OpenAI 兼容 API。

## 功能

| 交互 | 效果 |
|---|---|
| 什么都不做 | 待机摸肚皮，偶尔自己溜达两步 |
| **左键戳一戳** | 弹出对话气泡，AI 生成一句 ≤10 字的抽象短句（可配置温度） |
| **按住拖动** | 被拎起来淡定玩手，拖到半空松手会**边笑边掉落**（重力模拟） |
| **右键菜单** | 和我聊天（AI 对话窗）/ 测试 API / 回到屏幕底部 / 退出 |
| AI 聊天 | 完整上下文记忆，人设可自定义（system prompt） |

- 桌宠不抢键盘焦点：你打字时点它，输入法纹丝不动
- 聊天记忆持久化：重启/被 kill 后不失忆（最近 60 条）
- 无网 / 未配置 Key 时自动降级为本地趣味文案，离线也能戳

## 环境要求

**macOS 版**：macOS 13+、Swift 5.9+（Xcode Command Line Tools）
**Windows 版**：Windows 10+、Python 3.9+
（均可选配 DeepSeek API Key，没有则无 AI 功能但桌宠照常运行）

## 快速开始

### macOS（Swift 原生版）

```bash
git clone https://github.com/CharlyTong/NailongDeskPet.git
cd NailongDeskPet
cp config.example.json config.json
# 编辑 config.json 填入你的 API Key（https://platform.deepseek.com）
swift run DeskPet
```

### Windows（Python + PySide6 版）

```powershell
git clone https://github.com/CharlyTong/NailongDeskPet.git
cd NailongDeskPet\windows
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt   # 只需装 PySide6 一个包
copy config.example.json config.json
# 编辑 config.json 填入你的 API Key
.venv\Scripts\python main.py
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

**Windows 版**（`windows/`，与 macOS 版镜像同构，逻辑逐段翻译）：

```
windows/
├── main.py           # 装配入口：创建部件、信号连线、启动（≈ AppDelegate）
├── pet_engine.py     # 大脑：33ms 主循环 + 状态机 + 物理 + AI 调度 + 记忆持久化
├── pet_window.py     # 桌宠窗：透明置顶无边框 + 帧动画 + 鼠标交互
├── bubble.py         # 气泡窗：漫画气泡 + 尾巴 + 点击穿透 + 淡入
├── chat_window.py    # 聊天窗：历史渲染 + 输入发送
├── ai_client.py      # OpenAI 兼容客户端（纯标准库 urllib，零额外依赖）
├── sprites/          # 帧图 + SpriteConfig.json（与 macOS 版共用素材）
└── requirements.txt  # 唯一依赖 PySide6
```

**macOS 版**（`Sources/DeskPet/`）：

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

两版共用同一套帧序列命名：`idle_0.png`、`walk_0.png`…，帧数与帧率在 `SpriteConfig.json` 里改。
- macOS 版素材在 `Sources/DeskPet/Resources/Sprites/`，改完 `swift run` 生效
- Windows 版素材在 `windows/sprites/`，改完重启 `main.py` 生效

## 素材声明

奶龙与 oiiai 素材均来源于网络，本项目仅作个人学习与技术演示用途，不作任何商业分发，如有侵权请联系删除。

## 已知限制（Roadmap）

- [ ] 尚未打包独立可执行文件（macOS 的 `.app` / Windows 的 `.exe`）
- [ ] 暂无开机自启与菜单栏/托盘常驻图标
- [ ] Windows 版尚未在真机验证（开发于 macOS，理论兼容，待实测）
