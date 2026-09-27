# QIAN YU 千语

> 一款支持 iOS 和 macOS 的千语陪伴应用。

---

## 核心功能

### 1. 提醒上课 (课程表与上课提醒)
* **智能周期提醒**：根据周一至周日的课程排期自动提醒上课，支持自定义提前推送。
* **千语专属通知语录**：
  > *「管理员！下节是【电路与电子学】在【T4502】，还有 15 分钟！课本和笔带齐没？走走走，冲冲冲！」*
* **首页动态倒计时横幅**：主界面随时显示下一门课程的距离时间、地点及快速打气入口。
* **课程管理**：可以手动添加、停用或删除课程，也支持导入 `.ics` 课表并同步到系统日历。

### 2. 每日定点推送
使用 UserNotifications 推送，提供预设四个智能陪伴问候：
* **🌅 清晨唤醒 (07:45)**：*「醒啦？我已经把剑擦过两遍了！下楼顺手抓个热包子，今天当破即破，冲冲冲！」*
* **🍱 午间干饭 (12:00)**：*「饭点到啦！吃好午饭下午才有劲头嘛！今天吃点啥好吃的？」*
* **💆 午后防困 (14:00)**：*「眼睛发酸了吧？来嘛来嘛，站起来转两圈！我教你按肩颈穴位，管用得很！」*
* **🌙 深夜就寝 (22:30)**：*「心事放一边，被窝钻进去！明天还要出任务呢，可不许熬夜，晚安啦！」*
* **推送测试**：内置「测试通知」按钮，点击后可收到横幅通知，方便快速验证权限与效果。

### 3. 闲聊与陪伴 
* **角色设定**：聊天会参考千语的人设与当前课程信息，角色档案可在应用设置中查看。
* **聊天支持**：
  * **云端 LLM 流式输出**：支持 OpenAI 兼容协议的 API Key，输出伴随触觉反馈。
  > 未配置 API Key 时，应用会使用内置语料回复，能力相对有限。
* **快捷胶囊话题**：
  * `💆 按按肩颈` · `🏫 下节什么课？` · `📖 讲讲大院故事` · `🗡️ 当破即破！` · `🧋 碰碰杯杯`

### 4. macOS 适配：MenuBarExtra 菜单栏常驻
* 在 macOS 顶部菜单栏常驻千语图标 “QIAN YU“。
* 轻点即可滑出浮窗：查看千语当前随行状态、下一门课倒计时、直接在状态栏进行迷你闲聊，无需切换工作流。

### 5. 专注与小组件
* 番茄钟支持专注和休息计时；iPhone 上可通过实时活动查看进度。
* 桌面和锁屏小组件会显示当前教学周与接下来的课程。

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
│   │   ├── CourseReminderService.swift # 课程周期性推送调度服务
│   │   ├── ICSParserService.swift # .ics 课表解析
│   │   └── CalendarSyncService.swift # 系统日历同步
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift # 对话与陪伴视图模型
│   │   ├── CourseScheduleViewModel.swift # 课程表管理与下一课计算
│   │   └── SettingsViewModel.swift # 偏好设置与通知权限
│   ├── Views/
│   │   ├── MainView.swift      # 跨平台主视图 (iOS TabView / macOS SplitView)
│   │   ├── Companion/          # 陪伴主界面、头像徽章、倒计时横幅、气泡、快捷胶囊
│   │   ├── Schedule/           # 课程表周视图、添加课程表单、课程卡片
│   │   ├── Reminders/          # 每日推送时间设置与测试
│   │   ├── Focus/              # 番茄钟
│   │   ├── Settings/           # 模型配置与陈千语完整人设档案查看器
│   │   └── MenuBar/            # macOS 菜单栏专用常驻浮窗
│   ├── Widgets/                # 桌面与锁屏小组件、实时活动
│   └── Resources/
│       ├── Assets.xcassets     # 应用图标与千语专属暖橙主题色
│       └── Info.plist          # 权限与应用属性
└── README.md
```

---

## 🚀 如何运行项目

1. **打开工程**：
   * 在 Finder 中找到并双击打开 `QIAN YU.xcodeproj`；
   * 或在终端执行：`open "QIAN YU.xcodeproj"`。

2. **选择运行平台**：
   * **运行在 Mac**：在 Xcode 顶部目标设备选择 **My Mac**，按下 `Cmd + R`；
   * **运行在 iPhone / iPad 模拟器**：在目标设备选择一台可用的模拟器，按下 `Cmd + R`。

3. **初次启动**：
   * 启动时 App 会请求通知权限；允许后才能收到每日问候与上课提醒。
   * 在「每日推送」页面，点击“立即发送一条测试通知”，3 秒内即可看到千语发来的测试横幅。
