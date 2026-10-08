# CalendarClick · 日历打勾

给苹果日历的日程加上“已完成”标记。**保留苹果原来的右键菜单，在旁边增加完成按钮**，做完一件事，就让日程标题显示 `✓`。

目前提供**简体中文版**，适用于 **macOS 14 及以上的 Apple Silicon Mac（M 系列芯片）**。

## 下载

- **[下载安装包 DMG](https://github.com/DavidSi123456/CalendarClick/releases/download/v0.1.0/CalendarClick-v0.1.0-macOS-arm64-zh-CN.dmg)**
- [下载 ZIP 压缩包](https://github.com/DavidSi123456/CalendarClick/releases/download/v0.1.0/CalendarClick-v0.1.0-macOS-arm64-zh-CN.zip)
- [查看版本说明](https://github.com/DavidSi123456/CalendarClick/releases/latest)

## 安装

1. 打开 DMG，把 **日历打勾.app** 拖到 **应用程序**；使用 ZIP 时，先解压再移动应用。
2. 打开应用，在设置窗口允许“日历访问”。需要**完全访问**，用于读取和修改已有日程。
3. 在 **系统设置 → 隐私与安全性 → 辅助功能** 中打开“日历打勾”。如果列表没有显示，点击 `+` 添加应用程序里的 app。
4. 打开苹果日历，右键一个日程。原菜单旁会出现 **标记为已完成** 按钮；也支持 Control + 单击。

当前安装包使用固定的本地证书签名，尚未使用 Apple Developer ID 签名或 Apple 公证。首次从网上下载后，macOS 可能要求手动确认。请核对下载来源，按 [Apple 官方说明](https://support.apple.com/zh-cn/102445) 在“隐私与安全性”中允许打开。

建议先把应用放到固定位置，再进行授权。后续发布复用相同签名身份；自行更换签名身份构建的版本需要重新授权。

## 使用

- **完成**：右键日程，点击 **标记为已完成**，标题变为 **✓ 原标题**。
- **取消完成**：再次右键，点击 **取消完成**，恢复原标题。
- **重复日程**：完成动作只修改本次日程。
- **试用**：设置窗口里的示例日程可以直接右键体验，不会修改真实日历，也不需要授权。
- **暂停和退出**：在菜单栏图标中操作。关闭设置窗口后应用继续运行，目前没有开机自启。

## 完成标记如何保存

苹果日历的日程没有提醒事项那样的完成状态字段。本工具在日程标题最前面加上 `✓ `，因此退出工具后勾号仍然可见，也会随日历账户同步到其他设备。手动添加这个前缀也会被识别为已完成。

应用使用公开的 EventKit 和辅助功能接口。右键监听不会阻止苹果原来的菜单；完成按钮以独立浮层显示在旁边。点击完成时修改日程标题，时间、提醒、备注等字段保持原值。

## 当前限制

- 只读日历不能修改；带参与者的会议暂不支持，以免更改标题引发会议更新。
- 按钮是原生菜单旁的独立浮层，不是原生菜单内部的扩展项。
- 目前针对简体中文和美式数字日期做了识别，其他语言及系统版本仍需实机验证。
- 此次安装包只提供 Apple Silicon 版本，不适用于 Intel Mac。
- 多个日程候选会逐项列出供选择；保存之前重新读取并检查日程，已变化或已删除的记录不会直接覆盖。

## 隐私

日程操作在本机通过 Apple 框架完成，不上传日历数据，也不保存日程副本。不需要提醒事项、屏幕录制或键盘输入监控权限。

## 从源码构建

需要 macOS Command Line Tools，已使用 Swift 6.1 工具链构建。

```sh
git clone https://github.com/DavidSi123456/CalendarClick.git
cd CalendarClick
./build.sh
./test.sh
./package.sh
```

构建输出为 `日历打勾.app`，安装包输出到 `dist/`。签名机制、目录结构和发布检查见 [开发说明](docs/开发说明.md)。

已在 macOS 15.8.1 实机验证完成打勾和应用重启后的授权保留；24 项核心逻辑检查通过。重复日程采用 `EKSpan.thisEvent` 保存，不同日历账户的同步行为仍需进一步验证。

## 参考

- [Apple EventKit](https://developer.apple.com/documentation/eventkit)
- [创建和修改日程](https://developer.apple.com/documentation/eventkit/creating-events-and-reminders)
- [AppKit 事件监控](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)
