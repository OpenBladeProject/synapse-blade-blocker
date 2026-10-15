<a id="technical-guide"></a>

# 技术指南

[English](../../TECHNICAL.md) | 简体中文 | [Русский](../ru-RU/TECHNICAL.md)

窗口操作流程见 [README](../../README.zh-CN.md)。
以下命令可在 PowerShell 中准备、应用和恢复补丁。

<a id="compatibility-and-status"></a>

## 兼容性与状态

离线检查工具版本可运行以下命令。
它不需要 Synapse、Node.js、安装位置发现或管理员权限：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Version
```

工具使用每个已安装版本自身的原始归档准备补丁，不使用 Synapse 版本或可执行文件哈希白名单。
每个结构化修改位置都必须恰好匹配一次。
准备过程会检查 JavaScript 语法，并逐字节验证未修改的打包文件。
布局有变化或不完整时，准备会停止并生成脱敏问题报告。

窗口在检查和准备期间保持响应，并说明缺少的前置条件、正在运行的控制程序、
缺失备份和已变化的安装。取消管理员权限提示不会更改已安装归档。
Apply 和 Restore 不会停止或重启应用。
只有所选操作以提升权限运行，窗口仍保持普通用户权限。

Synapse 更新后，请刷新状态并为更新后的构建重新准备。
不要将旧备份用于已变化的安装。
操作失败时，展开 **Backups and diagnostics**。
使用 **Copy diagnostic details** 获取脱敏状态，或使用 **Open saved reports**
获取准备或归档替换的兼容性报告。按照界面恢复说明操作。
无法验证替换结果时，请保留备份；在安装状态核实并恢复一致前，不要启动 Synapse。

即使没有应用标记或准备目录，窗口也会检查归档内容以发现旧补丁。
它会报告已识别补丁、不完整或未知的 Blocker 痕迹，或未发现可识别的修改。
无法读取的归档保持未知。备份哈希匹配会单独报告，
但这不能证明保存的原始文件从未被修改。
Restore 始终要求匹配且已验证的原始文件。

<a id="prepare-the-patch"></a>

## 准备补丁

在解压目录打开 PowerShell。准备和应用期间，退出 Synapse 并保持其更新程序关闭。

```powershell
npm test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Prepare.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Apply -WhatIf
```

本地模块检查前，将 `BLOCKER_PREPARATION_DIRECTORY` 设为 Prepare 返回的目录，
再运行 `npm run test:local`。

发现逻辑优先使用活动 AppEngine 进程的精确目录；
不可用时，使用 `%ProgramFiles%\Razer\RazerAppEngine` 下最新的 `app-VERSION` 目录。
两个脚本均接受 `-InstallDirectory`，显式指定该标准布局中的目录。
有歧义的活动安装和含重解析点的安装路径会被拒绝。

每次准备默认在 **Documents > Synapse Blade Blocker > Backups**
中新建 `<timestamp>-<id>` 目录。
它使用 Windows 的 Documents 位置，包括重定向目录。
在窗口 **Backups** 行使用 **Open folder** 打开目录，
或用 **Choose location…** 将新备份保存在其他位置。旧备份留在原处。
**Use Documents default** 可切回 Documents 默认位置。
Blocker 将选择和旧位置原子保存到 `%LOCALAPPDATA%\SynapseBladeBlocker\settings.json`。

每个目录包含 `original.asar`、`blocked.asar`、提取后的补丁模块和 `preparation.json`。
清单记录实际来源、可执行文件和输出的哈希，以及内嵌 Blade 注册表 ID 和补丁源码指纹。
已有准备目录、备份和旧版本地 `original.asar` 都会保留。
准备过程只读取已安装文件。

自动查找会搜索所选目录、先前选择的位置、Documents 默认位置、
旧的 `%LOCALAPPDATA%\SynapseBladeBlocker\Backups` 位置，以及包中旧的 `prepared/` 目录。
它要求安装的可执行文件和归档哈希匹配某份准备记录，
并优先选择完整的原始备份，而非同样匹配但已损坏的备份。
显式指定 `-PreparationDirectory` 时，绝不会回退到其他备份。
其他旧准备目录仍可手动选择。

桌面 Patch 仅在验证准备目录与当前补丁源码一致后复用，否则会重新准备。
Apply 在写入前检查补丁源码指纹，以及已验证原始归档的确定性转换结果，
因此过时或被修改的预制补丁不能当作当前补丁复用。
旧原始文件仍可用于 Restore。
Apply 和 Restore 始终显式接收解析后的准备路径，包括跨越管理员权限提示时；
可执行文件/归档完整性和控制程序已停止的检查仍然必需。

Apply 和 Restore 查找归档与可执行文件哈希匹配所选安装的准备记录。
使用 `-PreparationDirectory` 可显式选择。
本地模块测试要求 `BLOCKER_PREPARATION_DIRECTORY` 指向用当前源码制作并验证过的准备目录。

相对 `-InstallDirectory` 和 `-PreparationDirectory` 路径按当前 PowerShell 位置解析。
临时文件操作测试覆盖 Windows PowerShell 5.1 和 PowerShell 7，
包括非 UTC 本地时区和 UTC 标记验证。未来日期的标记会被拒绝。
早期发现失败会在脱敏诊断中保留 PowerShell 版本；没有匹配准备目录会报告缺少输入。

<a id="apply-the-patch"></a>

## 应用补丁

退出 Synapse，并通过 OpenBlade 的设置页面关闭它。在管理员 PowerShell 窗口运行 Apply：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Apply
```

确认 `Success: True`，且 `ToolVersion` 匹配所用程序包，然后正常启动 Synapse。
Status、准备、Apply 和 Restore 的成功输出均报告来自同一包的工具版本。
辅助程序验证原始回滚归档、暂存补丁、检查并发更新、原子替换 `app.asar`、
保留唯一安装备份、验证结果，再写入 `resources/synapse-blade-blocker.json`。

等待 Synapse 完成加载，打开外设页面，确认外设可用且 Blade 不在设备列表中。
如果使用 OpenBlade，再启动它。遇到非预期行为时，请恢复原始归档并按下文报告问题。

<a id="using-openblade"></a>

## 使用 OpenBlade

[OpenBlade 0.21.0 或更新版本](https://github.com/OSSBlade/openblade-core/releases/latest)
会检查实际已安装文件，以及 Synapse 是否在应用补丁后重启，以识别已应用补丁。
补丁缺失、已变化或过时时，常规冲突检查继续生效。
后续共存修复请使用最新版本。

Synapse 界面加载后可能启动 Windows 灯光辅助程序 `razerwdl`。
仅当该辅助程序的身份及已打补丁的 Synapse 父进程均已验证，
且最新 Windows 设备检查未发现被排除的 Blade 灯光接口时，OpenBlade 才接受它。
未知设备身份、枚举失败、独立辅助程序和其他竞争控制程序仍受原有检查限制。
这不会禁用 Windows 灯光或外设功能。

OpenBlade 0.24.3 还允许在已知 Synapse 服务别名存在时，凭已验证的 Blocker 补丁使用 HyperBoost。
已验证的 RGS 服务不阻止 HyperBoost；身份未验证但使用 RGS 或更新程序名称的进程仍会阻止。
具有已验证 Razer 身份的 Windows 灯光辅助程序也不会阻止 HyperBoost；
其他控制程序检查、精确设备检查和供电要求仍然适用。
完整规则见[核心共存指南](https://github.com/OpenBladeProject/openblade-core/blob/v0.24.3/docs/synapse-blade-blocker.md)。

2026 年 9 月的安装试验使用 Synapse AppEngine 4.0.823 并通过，
当时延迟启动的辅助程序正在运行，Pro Click V2 可见且工作正常，Blade 则未出现在列表中。
OpenBlade 未显示冲突警告。精确测试版本和限制见 [VALIDATION.md](VALIDATION.md)，
也欢迎报告其他配置的结果。

<a id="restore-the-original"></a>

## 恢复原始状态

撤销时，退出 Synapse，关闭 OpenBlade，并在管理员 PowerShell 中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Restore
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\BladeBlocker.ps1 -Mode Status
```

Restore 验证并恢复匹配的原始文件，然后移除已应用标记；不需要补丁归档仍然存在。
重复 Apply 或 Restore 与运行一次效果相同；
Apply 可在验证已打补丁的归档后重建缺失元数据。
请保留每份本地原始文件和安装备份。
工具会保留未知归档和可执行文件更新，不会用旧构建覆盖它们。
更新后请为新的原始构建重新准备。重新应用补丁需要用户操作。
进程控制由用户负责，工具不安装服务或驱动。

替换期间保持更新程序关闭。
最终哈希检查能检测已经发生的更新，但无法阻止更新程序随后立即更改文件。
替换验证失败时，请保留报告中列出的备份；在安装状态核实并恢复一致前，不要启动 Synapse。

<a id="if-a-patch-fails"></a>

## 补丁失败时

准备、Apply 和 Restore 失败时，会打印可复制的 Markdown 诊断，
并尝试保存到被 Git 忽略的 `diagnostics/`。
其中包括工具和运行时版本、补丁契约、发现的 AppEngine 版本、可用的完整哈希、
失败阶段/类别，以及可用时缺失或有歧义的锚点标签/数量。
原始异常、本地路径、用户名、序列号、归档内容和本机代码均会省略。
报告保存失败不会隐藏原始错误。

将报告粘贴到[兼容性议题](https://github.com/OSSBlade/synapse-blade-blocker/issues/new/choose)，
并说明尝试的操作。不要上传厂商归档或原始采集文件。工具绝不会自动提交议题。

<a id="applied-metadata"></a>

## 已应用元数据

```json
{
  "schemaVersion": 1,
  "patchId": "OSSBlade/synapse-blade-blocker",
  "archiveSha256": "<full installed patched app.asar SHA-256>",
  "executableSha256": "<actual RazerAppEngine.exe SHA-256>",
  "appliedAtUtc": "<UTC ISO timestamp after verified replacement>",
  "bladeProductIds": [563, 736]
}
```

上述 ID 仅为示例；实际标记包含内嵌注册表中所有被排除的数字 PID。
标记不存储路径。OpenBlade 集成可对照相邻归档、父级可执行文件、当前进程和内嵌注册表验证标记。
标记缺失或不匹配时，必须禁用识别。
没有该集成的历史 OpenBlade 版本仍执行常规冲突检查。

<a id="evidence-and-limits"></a>

## 证据与限制

- 历史 Blade 16 `1532:02E0` 试验抑制了启动/退出轨迹中观察到的 90 字节和 374 字节报告。
  短的 System 上下文请求仍然存在。
- 用户报告在 Blade 不出现在列表中时，Pro Click V2 `1532:00D1` 的发现、普通输入和所要求的自定义检查均正常。
  这是用户报告的证据。
- 共享本机/主机路由仍可访问。完整隔离、其他外设、睡眠/恢复，以及未来构建的硬件行为仍未验证。

产物和测试范围见 [VALIDATION.md](VALIDATION.md)。
`npm test` 运行纯源码的策略、兼容性和诊断检查。
`npm run test:operations` 使用可丢弃的合成文件测试发现和可逆替换。
运行 `npm run test:local` 前，将 `BLOCKER_PREPARATION_DIRECTORY` 设为本次新准备返回的目录；
它会先验证准备内容匹配当前补丁源码，再使用不调用真实本机功能的模拟运行模块检查。
绝不要提交生成的归档、提取的厂商代码或原始诊断采集文件。

项目许可证仍由仓库所有者选择。本仓库不包含 Razer 组件，也不授予其许可证。
