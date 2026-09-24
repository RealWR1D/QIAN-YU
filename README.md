# QIAN YU (千语伴行)

> **基于 Apple 现代技术栈（SwiftUI + SwiftData + UserNotifications + LLM Streaming）打造的跨平台（iOS & macOS）陈千语随身陪伴应用**

---

## 🌟 核心功能一览

### 1. 提醒我上课 (课程表与智能上课提醒)
* **智能周期提醒**：根据周一至周日的课程排期，支持自定义提前（5 / 10 / 15 / 20 / 30 / 45 / 60 分钟）推送。
* **千语专属通知语录**：
  > *「管理员！下节是【高等数学】在【正心楼 312】，还有 15 分钟！课本和笔带齐没？走走走，冲冲冲！」*
* **首页动态倒计时横幅**：主界面随时显示下一门课程的距离时间、地点及快速打气入口。
* **课程管理**：支持标签颜色、地点、教师、时间段自由编辑与实时通知同步。

### 2. 每日定点推送 (Daily Push Notifications)
严格遵循 Apple `UserNotifications` 原生框架，提供四定点智能陪伴问候：
* **🌅 清晨唤醒 (07:45)**：*「醒啦？我已经把剑擦过两遍了！下楼顺手抓个热包子，今天当破即破，冲冲冲！」*
* **🍱 午间干饭 (12:00)**：*「饭点到啦！吃好午饭下午才有劲头嘛！今天吃点啥好吃的？」*
* **💆 午后防困 (14:00)**：*「眼睛发酸了吧？来嘛来嘛，站起来转两圈！我教你按肩颈穴位，管用得很！」*
* **🌙 深夜就寝 (22:30)**：*「心事放一边，被窝钻进去！明天还要出任务呢，可不许熬夜，晚安啦！」*
* **推送测试**：内置「立即测试通知」按钮，3 秒后即可收到横幅通知，方便快速验证权限与效果。

### 3. 闲聊与陪伴 (Persona & Companionship)
* **深度遵循设定指南**：严格基于项目内《陈千语_完整人设设定.md》，恪守 **1~3 句话（30~80字，严禁超过100字）**，嘴甜机灵、给足情绪价值、绝对不说教。
* **双模支持**：
  * **开箱即用离线拟真库**：内置 50+ 句高质量情境语料，无需配置 API Key 亦可畅聊剑法日常、按穴位放松、大院趣事、下节课查询等。
  * **云端 LLM 流式输出**：支持 OpenAI 兼容协议（DeepSeek、小米 MiMo、OpenAI、硅基流动、本地 Ollama 等），打字机流畅响应并伴随触觉反馈。
* **快捷胶囊话题**：
  * `💆 按按肩颈` · `🏫 下节什么课？` · `📖 讲讲大院故事` · `🗡️ 当破即破！` · `🧋 碰碰杯杯`

### 4. macOS 独家适配：MenuBarExtra 菜单栏常驻
* 在 macOS 顶部菜单栏常驻千语图标 🐉。
* 轻点即可滑出浮窗：查看千语当前随行状态、下一门课倒计时、直接在状态栏进行迷你闲聊，无需切换工作流。

---

## 📁 项目目录结构

```text
QIAN_YU/
├── QIAN YU.xcodeproj/           # Xcode 工程文件 (双击即可直接在 Xcode 打开)
├── QIAN_YU/
│   ├── App/
│   │   └── QianYuApp.swift     # App 入口 (SwiftData 容器、macOS MenuBarExtra)
│   ├── Models/
│   │   ├── ChatMessage.swift   # 聊天记录数据模型 (@Model)
│   │   ├── CourseItem.swift    # 课程数据模型 (@Model, 计算倒计时与通知文案)
│   │   └── AppSettings.swift   # 用户设置 (称呼、每日推送时间、API 配置)
│   ├── Engine/
│   │   ├── PersonaEngine.swift # 动态上下文组装与人设提示词引擎
│   │   └── QianYuDialogueCorpus.swift # 离线高质量拟真语料库
│   ├── Services/
│   │   ├── LLMService.swift    # 原生 URLSession SSE 流式大模型连接器
│   │   ├── NotificationManager.swift # 每日四大定点通知管理器
│   │   └── CourseReminderService.swift # 课程周期性推送调度服务
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift # 对话与陪伴视图模型
│   │   ├── CourseScheduleViewModel.swift # 课程表管理与下一课计算
│   │   └── SettingsViewModel.swift # 偏好设置与通知权限
│   ├── Views/
│   │   ├── MainView.swift      # 跨平台主视图 (iOS TabView / macOS SplitView)
│   │   ├── Companion/          # 陪伴主界面、头像徽章、倒计时横幅、气泡、快捷胶囊
│   │   ├── Schedule/           # 课程表周视图、添加课程表单、课程卡片
│   │   ├── Reminders/          # 每日推送时间设置与测试
│   │   ├── Settings/           # 模型配置与陈千语完整人设档案查看器
│   │   └── MenuBar/            # macOS 菜单栏专用常驻浮窗
│   └── Resources/
│       ├── Assets.xcassets     # 应用图标与千语专属暖橙主题色
│       └── Info.plist          # 权限与应用属性
├── 千语伴行_iOS_macOS开发参考指南.md
└── 陈千语_完整人设设定.md
```

---

## 🚀 如何运行项目

1. **打开工程**：
   * 在 Finder 中找到并双击打开 `QIAN YU.xcodeproj`；
   * 或在终端执行：`open "QIAN YU.xcodeproj"`。

2. **选择运行平台**：
   * **运行在 Mac**：在 Xcode 顶部目标设备选择 **My Mac**，按下 `Cmd + R`；
   * **运行在 iPhone / iPad 模拟器**：在目标设备选择 **iPhone 16 Pro** 等模拟器，按下 `Cmd + R`。

3. **初次启动**：
   * 启动时 App 会提示授权通知权限，请点击“允许”，千语即可准时为你发送每日问候与上课提醒！
   * 在「每日推送」页面，点击“立即发送一条测试通知”，3 秒内即可看到千语发来的测试横幅。
