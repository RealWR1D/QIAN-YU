# iPhone 免费安装 QIAN YU

不需要购买 Apple Developer Program。首次安装 SideStore 需要借用一台 Windows、Mac 或 Linux 电脑，后续可在 iPhone 上安装、更新和续签。支持 iOS 17 及以上。

## 首次设置 SideStore

1. 按 [SideStore 官方准备指南](https://docs.sidestore.io/docs/installation/prerequisites) 在电脑安装 iloader，在 iPhone 安装 LocalDevVPN。
2. 用数据线连接 iPhone，解锁并确认“信任此电脑”。
3. 按 [SideStore 官方安装指南](https://docs.sidestore.io/docs/installation/install) 使用 iloader 安装独立的 SideStore，完成设备配对。请使用官方发布的软件。
4. 按系统提示开启开发者模式、信任自己的开发者账号。在 SideStore 中登录自己的 Apple 账号，完成首次刷新。密码、设备配对文件和签名凭据只在你自己的设备中使用，不需要发给项目维护者。

本项目提供的是独立安装包，使用独立 SideStore 安装；不使用 LiveContainer 容器，以保留小组件与灵动岛扩展的安装机会。

## 安装 QIAN YU

在 SideStore 的 Sources 页面点击添加源，粘贴：

```text
https://github.com/RealWR1D/QIAN-YU/releases/download/ios-sideload/sidestore.json
```

刷新源，找到 **QIAN YU** 并安装。若询问是否保留扩展，请保留 `QianYuWidgets`，否则桌面小组件、锁屏专注和灵动岛界面无法显示。

也可从 [iPhone 侧载下载页](https://github.com/RealWR1D/QIAN-YU/releases/tag/ios-sideload) 下载 `QIAN-YU-iOS-SideStore.ipa`，在 SideStore 的 My Apps 中使用“+”导入。

IPA 是用于个人重新签名的构建产物，不是 App Store 安装包，也不能在“文件”应用中直接点击安装。实际安装由 SideStore 使用你自己的账号签名。原有 Xcode 安装版可能被替换，也可能因为安装标识不同而共存；新安装版需要重新填写 API 配置。

## 续签与更新

- 免费签名有效期为 **7 天**。到期前在 SideStore 的 My Apps 中刷新 **SideStore 和 QIAN YU**；建议每隔几天手动检查一次，不要仅依赖后台自动刷新。
- 安装、更新和续签时需要连接 **Wi-Fi** 并开启 **LocalDevVPN**，只连蜂窝网络不满足要求。完成后可断开该本地 VPN。
- 新版会出现在 SideStore 的更新列表。仓库 main 的相关源码更新通过检查后，自动生成新版 IPA 并更新相同的源地址。
- 如果 SideStore 自己过期而无法启动，可能需要再次借电脑重新安装它。持续保持续签可以避免通常情况下每周接电脑。
- 免费账号最多同时安装 3 个侧载应用，SideStore 自己占一个；扩展还会占用 App ID 配额。遇到配额错误时，按 SideStore 提示处理。保留 QianYuWidgets 需要额外的 App ID。

参考：[SideStore 常见问题](https://docs.sidestore.io/docs/faq)、[错误排查](https://docs.sidestore.io/docs/troubleshooting/error-codes)。

## 本包的检查范围

构建使用 Release 配置，包含聊天与性能修复，并保留 `QianYuWidgets`、头像和图标。侧载版课程与聊天数据库存放在应用自己的容器内；共享课表读取安装后的 App Group，后台提醒使用安装后的任务标识。

自动检查覆盖原标识及个人签名标识映射、课程规则、聊天、数据库保存、IPA 中的主应用与扩展结构、版本一致性、arm64 可执行文件和本地签名完整性。**这些检查不等于已在你的 iPhone 上通过 SideStore 安装验收。**首次安装后请检查启动、课表保存、通知、聊天、专注灵动岛和桌面小组件。

这是非官方同人应用，素材来源和授权情况见 [素材与权利说明](素材与权利说明.md)。
