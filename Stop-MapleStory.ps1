#requires -Version 5.1
<#
.SYNOPSIS
    结束 MapleStory 和 BlackCipher 的后台进程。
.PARAMETER CheckOnly
    只查看进程，不结束进程。
#>
[CmdletBinding()]
param(
    [switch]$CheckOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    Write-Host '此脚本适用于 Windows。' -ForegroundColor Red
    exit 2
}

$targetNames = @('MapleStory', 'BlackCipher64.aes')
$stoppedCount = 0
$failedCount = 0

Write-Host 'MapleStory 后台进程清理' -ForegroundColor Cyan
if ($CheckOnly) {
    Write-Host '查看模式：只列出进程。'
} else {
    Write-Host '将强制关闭 MapleStory 游戏及 BlackCipher 反作弊进程。'
}
Write-Host ''

foreach ($targetName in $targetNames) {
    $candidates = @(Get-Process -Name $targetName -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 0) {
        Write-Host ('[未运行] {0}' -f $targetName)
        continue
    }

    foreach ($candidate in $candidates) {
        # 重新查询并核对名称，避免对已经退出的旧进程编号操作。
        $current = Get-Process -Id $candidate.Id -ErrorAction SilentlyContinue
        if ($null -eq $current -or $current.ProcessName -ne $targetName) {
            Write-Host ('[已退出] {0}，PID {1}' -f $targetName, $candidate.Id)
            continue
        }

        if ($CheckOnly) {
            Write-Host ('[正在运行] {0}，PID {1}' -f $targetName, $current.Id)
            continue
        }

        try {
            # 固定这个进程的句柄，再核对创建时间，防止 PID 被其他进程复用。
            $expectedStartTime = $current.StartTime.ToUniversalTime().Ticks
            $pinnedHandle = $current.Handle
            if ($null -eq $pinnedHandle -or $pinnedHandle -eq [IntPtr]::Zero) {
                throw '无法获取进程句柄，未执行终止操作。'
            }
            $current.Refresh()
            if ($current.HasExited) {
                Write-Host ('[已退出] {0}，PID {1}' -f $targetName, $candidate.Id)
                continue
            }
            if ($current.StartTime.ToUniversalTime().Ticks -ne $expectedStartTime) {
                throw '进程身份已变化，为安全起见跳过。'
            }
            if ($current.ProcessName -ne $targetName) {
                throw '进程名称已变化，为安全起见跳过。'
            }
            Stop-Process -InputObject $current -Force -ErrorAction Stop
            if (-not $current.WaitForExit(3000)) {
                throw '已请求结束，但进程在 3 秒内没有退出。'
            }
            $stoppedCount++
            Write-Host ('[已结束] {0}，PID {1}' -f $targetName, $candidate.Id) -ForegroundColor Green
        } catch {
            $failureMessage = $_.Exception.Message
            $remaining = Get-Process -Id $candidate.Id -ErrorAction SilentlyContinue
            if ($null -eq $remaining -or $remaining.ProcessName -ne $targetName) {
                $stoppedCount++
                Write-Host ('[已退出] {0}，PID {1}' -f $targetName, $candidate.Id) -ForegroundColor Green
            } else {
                $failedCount++
                Write-Host ('[失败] {0}，PID {1}：{2}' -f $targetName, $candidate.Id, $failureMessage) -ForegroundColor Red
            }
        } finally {
            $current.Dispose()
        }
    }
}

Write-Host ''
if ($CheckOnly) {
    Write-Host '查看完成。'
    exit 0
}
if ($failedCount -gt 0) {
    Write-Host ('已结束 {0} 个进程；{1} 个进程未能结束。' -f $stoppedCount, $failedCount) -ForegroundColor Yellow
    Write-Host '如果提示拒绝访问，请右键 Stop-MapleStory.cmd，选择“以管理员身份运行”后重试。'
    exit 1
}

Write-Host ('清理完成，已结束 {0} 个进程。可以回到 Nexon Launcher 再点 Play。' -f $stoppedCount) -ForegroundColor Green
exit 0
