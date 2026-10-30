# 奶龙桌宠 · NailongDeskPet

> 一只在屏幕底部溜达的奶龙：能戳、能拖、能摔、能聊。
> **macOS 原生版**（Swift + SwiftUI），接 DeepSeek 等 OpenAI 兼容 API。

> 跨平台版（Python + PySide6，Windows / macOS / Linux）在姐妹仓库：
> **[NailongDeskPet-Python](https://github.com/CharlyTong/NailongDeskPet-Python)**
> 两版共用素材、配置格式与 AI 人设，架构镜像同构。

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

macOS 13+、Swift 5.9+（Xcode Command Line Tools）。
可选配 DeepSeek API Key（https://platform.deepseek.com），没有则无 AI 功能但桌宠照常运行。

## 快速开始

```bash
git clone https://github.com/CharlyTong/NailongDeskPet.git
cd NailongDeskPet
cp config.example.json config.json
# 编辑 config.json 填入你的 API Key
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

（Python 跨平台版的项目结构与设计要点见姐妹仓库 [NailongDeskPet-Python](https://github.com/CharlyTong/NailongDeskPet-Python)）

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

## 换皮肤

帧序列命名：`idle_0.png`、`walk_0.png`…，帧数与帧率在 `SpriteConfig.json` 里改。
素材在 `Sources/DeskPet/Resources/Sprites/`，改完 `swift run` 生效。

## 素材声明

奶龙与 oiiai 素材均来源于网络，本项目仅作个人学习与技术演示用途，不作任何商业分发，如有侵权请联系删除。

## 已知限制（Roadmap）

- [ ] 尚未打包独立 `.app`（双击运行 / 开机自启）
- [ ] 暂无菜单栏常驻图标
