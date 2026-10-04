# QIAN YU iPhone 安装指南

QIAN YU 提供 iPhone IPA 构建产物和项目源码。符合下列条件的用户可以使用自己的 Apple 账号重新签名安装；是否能够完成安装和续签，取决于设备、账号、网络及安装工具的支持情况。

安装包：[iPhone IPA 下载页](https://github.com/RealWR1D/QIAN-YU/releases/tag/ios-sideload)。本频道不是 TestFlight 或 App Store 分发，IPA 不能在「文件」应用中直接点击安装。应用不要求安装者购买开发者会员；使用免费账号签名时仍受 Apple 的有效期、能力及配额限制。

## 选择安装方式

| 方式 | 前置条件 | 更新与续签 |
| --- | --- | --- |
| Xcode 源码安装 | Mac、兼容的 Xcode、Apple 账号和 iPhone | 通过 Xcode 重新编译安装 |
| SideStore 安装 IPA | 首次设置需要兼容电脑；iPhone 上需完成 LocalDevVPN、设备配对及账号配置 | 完成设置后，可在满足网络条件时通过 SideStore 更新与续签 |
| AltStore Classic 安装 IPA | Windows 或 Mac 上运行 AltServer，完成设备和账号配置 | 通过 AltServer 配合 AltStore 更新与续签，仍需要电脑 |

免费签名一般有效 **7 天**，到期前需续签。SideStore 的手机续签能力不代表首次安装无需电脑，也不保证后台自动续签一定执行。具体兼容系统、工具安装及账号条件以各工具官方文档为准。

源码安装步骤见 [安装与分发](https://github.com/RealWR1D/QIAN-YU/blob/main/Docs/安装与分发.md)。AltStore Classic 用户参阅 [Windows 安装](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)及[官方说明](https://faq.altstore.io/altstore-classic/your-altstore)。以下介绍 SideStore 路线。

## SideStore 前置要求

- iPhone 运行 iOS 17 或更新版本，且满足所安装 SideStore 版本的要求。
- 准备一台兼容的 Windows、Mac 或 Linux 电脑、数据线和自己的 Apple 账号。
- 确认 App Store 所在地区可以下载 **LocalDevVPN**。若商店地区不提供该应用，此路线的前置条件尚未满足，应选择其他支持的安装方式。
- 按官方说明准备 iloader、设备配对及所需网络环境。

LocalDevVPN 使用的 Network Extensions 能力不向免费 Personal Team 开放，因此不能假定下载它的普通 IPA 再免费重签就能替代 App Store 安装。参见 [Apple 能力表](https://developer.apple.com/help/account/reference/supported-capabilities-ios)和 [SideStore 前置要求](https://docs.sidestore.io/docs/installation/prerequisites)。

## 首次安装 SideStore

1. 按 [官方准备指南](https://docs.sidestore.io/docs/installation/prerequisites)，在电脑安装 iloader，在 iPhone 安装 LocalDevVPN。
2. 用数据线连接 iPhone，解锁并确认「信任此电脑」。
3. 按 [官方安装指南](https://docs.sidestore.io/docs/installation/install)，使用 iloader 安装独立的 SideStore 并完成设备配对。
4. 根据系统提示开启开发者模式、信任对应开发者。使用自己的 Apple 账号登录 SideStore，完成首次刷新。

本项目使用独立安装方式，保留 QianYuWidgets 扩展。账号密码、验证码、设备配对文件和签名凭据应仅用于安装者自己的设备，不需要提交给项目维护者。

## 安装 QIAN YU

1. 在 SideStore 的 **Sources** 页面添加以下源：

```text
https://github.com/RealWR1D/QIAN-YU/releases/download/ios-sideload/sidestore.json
```

2. 刷新源，找到 **QIAN YU** 并安装。
3. 如询问是否保留扩展，保留 **QianYuWidgets**；移除扩展将无法使用课程小组件、锁屏专注和灵动岛展示。
4. 安装完成后打开应用，按 [千语使用指南](https://github.com/RealWR1D/QIAN-YU/blob/main/Docs/千语使用指南.md)配置学期、导入课表、设置提醒，并按需配置 AI。

也可从下载页获取 `QIAN-YU-iOS-SideStore.ipa`，通过 SideStore 的 **My Apps → +** 导入，或使用支持该包的其他安装工具。

更换安装方式或应用标识前，可在 **设置 → 关于应用 → 备份与恢复** 导出数据。不同安装标识可能形成独立的数据容器，原有 Xcode 安装版可能被替换或共存；新安装后需检查数据并重新配置 API。

## 日常更新与续签

- 免费账号用户应在到期前，在 SideStore 的 **My Apps** 中刷新 **SideStore 和 QIAN YU**，定期检查剩余有效期。
- 按当前 SideStore 流程，安装、更新和续签时需要 Wi-Fi 并开启 LocalDevVPN；完成后可断开该本地 VPN。
- 新版本通过相同源地址提供。安装前可查看发布页的源码提交、构建信息和校验文件。
- SideStore 本身到期无法启动时，可能需要电脑重新安装。不要把后台刷新视作持续可用的保证。
- 免费账号的侧载应用数量及 App ID 配额有限。SideStore 本身占用应用名额，QianYuWidgets 还需要相应 App ID；遇到配额错误时按安装工具的提示处理。

参考：[SideStore 常见问题](https://docs.sidestore.io/docs/faq)及[错误排查](https://docs.sidestore.io/docs/troubleshooting/error-codes)。

## 构建与验证范围

构建为设备 arm64 Release，包含主应用、QianYuWidgets、头像和应用图标。侧载版使用应用容器内的本地数据库，按安装后的 App Group 共享课程数据。

自动检查覆盖回归测试、设备 Release 编译、IPA 结构、版本一致性、可执行文件和本地签名完整性。它们不等于已在所有设备和安装工具上通过验收。首次安装后请检查启动、课表保存、通知、聊天、专注实时活动和小组件。

本项目为非官方同人应用，素材来源和授权情况见 [素材与权利说明](https://github.com/RealWR1D/QIAN-YU/blob/main/Docs/素材与权利说明.md)。
