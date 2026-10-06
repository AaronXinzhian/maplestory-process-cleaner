# MapleStory Process Cleaner

Windows 上双击清理 MapleStory 和 BlackCipher 后台进程的小工具。MIT 开源。

当点击 Nexon Launcher 的 **Play** 后，按钮先置灰、启动器最小化，随后又变回 Play 且没有游戏窗口时，可以检查是否有上次游戏残留的进程。Nexon 官方记录过 [BlackCipher 卡在后台导致客户端崩溃的情况](https://support-maplestory.nexon.com/hc/en-us/articles/211274023-NGS-Initialization-Error-0xe1600301)。清理残留进程是排查这类问题的一步，并不能解决所有启动错误。

## 使用

1. 下载仓库 ZIP（**Code → Download ZIP**）并解压，或下载 Releases 中的压缩包。
2. 双击 **`Stop-MapleStory.cmd`**。
3. 查看窗口中的清理结果，回到 Nexon Launcher 再点 **Play**。

**运行会强制关闭当前正在运行的 MapleStory，包括正常游戏中的客户端。请在准备关闭游戏或处理启动失败时使用。**

把 `Stop-MapleStory.cmd` 和 `Stop-MapleStory.ps1` 放在同一个文件夹。如果想放到桌面，可以为 `.cmd` 创建快捷方式。

如果显示“拒绝访问”，右键 `Stop-MapleStory.cmd`，选择 **以管理员身份运行** 后重试。双击入口会保留窗口，按任意键关闭。

## 只查看进程

在脚本文件夹打开 PowerShell，执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Stop-MapleStory.ps1 -CheckOnly
```

查看模式列出进程名称及 PID。正常运行按名称精确匹配以下两个进程，支持同时存在的多个实例：

- `MapleStory.exe`（PowerShell 中的进程名是 `MapleStory`）
- `BlackCipher64.aes`

脚本每次运行执行一次清理，然后退出。入口使用的 `ExecutionPolicy Bypass` 只作用于这次 PowerShell 子进程。

## 环境与返回码

需要 Windows 和 PowerShell 5.1 或更高版本。Windows 10/11 自带 Windows PowerShell 5.1，无需安装依赖。

| 返回码 | 含义 |
| --- | --- |
| `0` | 清理成功、目标未运行，或查看模式完成 |
| `1` | 至少一个目标进程未能结束 |
| `2` | 系统不支持，或双击入口缺少配套 `.ps1` 文件 |

如果两个进程已经清理，但游戏仍无法打开，可按 Nexon 官方建议尝试 [Repair Installation](https://support-maplestory.nexon.com/hc/en-us/articles/360036594351-Launch-Error-This-product-cannot-be-installed)。

## 开发验证

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Smoke.Tests.ps1
```

测试在独立 PowerShell 子进程中模拟进程查询和终止结果，不操作真实游戏进程。

## License

[MIT](LICENSE)。本项目是社区工具。
