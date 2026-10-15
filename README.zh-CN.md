<a id="synapse-blade-blocker"></a>

# Synapse Blade Blocker

[English](README.md) | 简体中文 | [Русский](README.ru-RU.md)

你可以继续用 Razer Synapse 管理鼠标、键盘和其他外设，同时把 Razer Blade 笔记本电脑从 Synapse 的设备列表中排除。这样便可使用 OpenBlade 控制笔记本电脑。

此补丁仍处于实验阶段，可以还原。它能识别 40 个经过审查的 Blade 产品 ID；实际测试使用的是一台 Blade 16 和一个 Pro Click V2 鼠标。详情见[已测试的配置和限制](docs/zh-CN/VALIDATION.md)。此补丁不提供安全隔离。

<a id="experimental-openblade-models"></a>
## OpenBlade 实验型号

现有排除策略包含 OpenBlade 支持的五个实验型号：

| 笔记本电脑 | 型号 | USB 标识 |
| --- | --- | --- |
| Blade 16 (2023) | RZ09-0483 | `1532:029F` |
| Blade 14 (2023) | RZ09-0482 | `1532:029D` |
| Blade 14 (2025) | RZ09-0530 | `1532:02C5` |
| Blade 15 Base (Early 2020) | RZ09-0328 | `1532:0255` |
| Blade 18 (2023) | RZ09-0484 | `1532:02A0` |

这些 ID 已列入经过审查的注册表，Synapse Blade Blocker 0.3.1 已包含它们。按照下文相同的 **Patch** 步骤操作，无需选择型号。自动化检查覆盖了这些型号的排除路径。尚未在这五个型号上完成阻止功能的实际测试；OpenBlade 的[实验支持限制](https://github.com/OpenBladeProject/openblade-core/blob/main/docs/zh-CN/experimental-blade-support.md)仍然适用。

<a id="download"></a>
## 下载

下载并解压[最新版本](https://github.com/OpenBladeProject/synapse-blade-blocker/releases/latest)的 ZIP 文件。

需要准备：

- 已安装 Razer Synapse 的 Windows 系统。
- Windows PowerShell 5.1 或 PowerShell 7。
- Node.js 22 或更高版本。

默认情况下，备份保存在 **Documents > Synapse Blade Blocker > Backups**。在窗口的 **Backups** 行中，选择 **Open folder** 可打开备份文件夹，选择 **Choose location…** 可把新备份保存到其他位置。阻止工具会记住所选位置。即使移动或替换了程序包，它也会检查以前用过的位置。

<a id="patch-synapse"></a>
## 修补 Synapse

1. 退出 Synapse，并确保其更新程序保持关闭。如果 OpenBlade 正在运行，请选择 **Settings > Shut down OpenBlade**。
2. 双击解压目录中的 **Start-BladeBlocker.cmd**。窗口会检查当前安装，并说明缺少的要求。
3. 选择 **Patch**。阻止工具会检查文件，并在需要时保存原始文件。出现 Windows 管理员权限提示时，接受该提示。
4. 等待工具确认成功，再正常启动 Synapse。启动 OpenBlade 前，确认外设可以使用，并确认设备列表中没有这台 Blade。

请使用[最新的 OpenBlade 版本](https://github.com/OpenBladeProject/openblade-core/releases/latest)获得当前的共存修复。OpenBlade 会先检查补丁是否已经应用，并确认 Synapse 在应用补丁后重新启动，然后才允许两者同时运行。

Synapse 更新后，重新打开阻止工具并刷新状态。再次应用补丁前，应针对更新后的安装重新执行准备步骤，并保留新的原始文件。旧备份不能还原不同的 Synapse 版本。

<a id="restore-synapse"></a>
## 还原 Synapse

退出 Synapse，确保其更新程序保持关闭，并关闭 OpenBlade。打开阻止工具并选择 **Restore**。工具会自动查找与当前安装匹配的备份。接受管理员权限提示，并等待工具确认完成，再重新启动 Synapse。

如果补丁由较早版本的阻止工具创建，请打开 **Backups and diagnostics > Choose preparation…**，选择包含 `preparation.json` 和 `original.asar` 的旧准备目录。旧版本把备份保存在解压后的程序包旁边，请保留该目录。

<a id="if-something-goes-wrong"></a>
## 出现问题时

打开 **Backups and diagnostics**，按其中的恢复说明操作。如果工具无法验证替换文件，请保留备份，并让 Synapse 保持关闭，直到恢复完成。

选择 **Copy diagnostic details** 或 **Open saved reports**，然后把经过清理的报告附到[兼容性问题](https://github.com/OpenBladeProject/synapse-blade-blocker/issues/new/choose)中，并说明当时要执行的操作。不要上传 Synapse 存档或原始捕获文件。

[技术指南](docs/zh-CN/TECHNICAL.md)介绍 PowerShell 命令、兼容性检查、备份、诊断和 OpenBlade 集成。[VALIDATION.md](docs/zh-CN/VALIDATION.md)记录了测试结果。

项目许可证仍由仓库所有者决定。本仓库不包含 Razer 组件，也不授予这些组件的许可证。
