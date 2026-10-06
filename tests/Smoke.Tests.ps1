#requires -Version 5.1
# Isolated process fixtures: these functions never query or terminate real processes.
$ErrorActionPreference = 'Stop'
$cleanerPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'Stop-MapleStory.ps1'
$global:mapleCleanerTestState = @{ Fixtures = @{}; StoppedIds = @(); QueryNames = @() }

function New-Fixture {
    param([int]$ProcessId, [string]$Name, [string]$Behavior = 'Success')
    $fixture = [pscustomobject]@{
        Id = $ProcessId
        ProcessName = $Name
        StartTime = [datetime]'2026-01-01'
        HasExited = $false
        Behavior = $Behavior
    }
    $fixture | Add-Member -MemberType ScriptProperty -Name Handle -Value {
        if ($this.Behavior -eq 'Reused') { $this.StartTime = $this.StartTime.AddSeconds(1) }
        if ($this.Behavior -eq 'Renamed') { $this.ProcessName = 'notepad' }
        if ($this.Behavior -eq 'DeniedHandle') { throw 'Access is denied.' }
        [IntPtr]1
    }
    $fixture | Add-Member -MemberType ScriptMethod -Name Refresh -Value { }
    $fixture | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
    $fixture | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
        param([int]$Timeout)
        return $this.Behavior -ne 'Timeout'
    }
    return $fixture
}

function Get-Process {
    [CmdletBinding()]
    param([string[]]$Name, [int[]]$Id)
    if ($PSBoundParameters.ContainsKey('Name')) {
        $global:mapleCleanerTestState.QueryNames += $Name
        foreach ($fixture in $global:mapleCleanerTestState.Fixtures.Values) {
            if ($Name -contains $fixture.ProcessName -and -not $fixture.HasExited) { $fixture }
        }
    } else {
        foreach ($processId in $Id) {
            if ($global:mapleCleanerTestState.Fixtures.ContainsKey($processId) -and -not $global:mapleCleanerTestState.Fixtures[$processId].HasExited) {
                $global:mapleCleanerTestState.Fixtures[$processId]
            }
        }
    }
}

function Stop-Process {
    [CmdletBinding()]
    param($InputObject, [switch]$Force)
    if ($InputObject.Behavior -eq 'Denied') { throw 'Access is denied.' }
    if ($InputObject.Behavior -eq 'SelfExited') {
        $InputObject.HasExited = $true
        throw 'Process already exited.'
    }
    $global:mapleCleanerTestState.StoppedIds += $InputObject.Id
    if ($InputObject.Behavior -ne 'Timeout') { $InputObject.HasExited = $true }
}

function Invoke-Case {
    param(
        [string]$Label,
        [object[]]$Processes,
        [int[]]$ExpectedStopped = @(),
        [int]$ExpectedExit = 0,
        [switch]$CheckOnly
    )
    $global:mapleCleanerTestState.Fixtures = @{}
    $global:mapleCleanerTestState.StoppedIds = @()
    $global:mapleCleanerTestState.QueryNames = @()
    foreach ($fixture in $Processes) { $global:mapleCleanerTestState.Fixtures[$fixture.Id] = $fixture }
    & $cleanerPath -CheckOnly:$CheckOnly | Out-Null
    if ($LASTEXITCODE -ne $ExpectedExit) {
        throw "$Label returned $LASTEXITCODE; expected $ExpectedExit."
    }
    $actual = (@($global:mapleCleanerTestState.StoppedIds | Sort-Object) -join ',')
    $expected = (@($ExpectedStopped | Sort-Object) -join ',')
    if ($actual -ne $expected) { throw "$Label stopped [$actual]; expected [$expected]." }
    if (($global:mapleCleanerTestState.QueryNames -join ',') -ne 'MapleStory,BlackCipher64.aes') {
        throw "$Label queried unexpected process names."
    }
    Write-Host "PASS: $Label" -ForegroundColor Green
}

Invoke-Case -Label 'No targets / repeatable cleanup' -Processes @()
Invoke-Case -Label 'Exact names, multiple instances, unrelated processes retained' -Processes @(
    (New-Fixture 101 'MapleStory'),
    (New-Fixture 102 'MapleStory'),
    (New-Fixture 103 'BlackCipher64.aes'),
    (New-Fixture 104 'MapleStoryHelper'),
    (New-Fixture 105 'BlackCipher64Helper.aes'),
    (New-Fixture 106 'nexon_client')
) -ExpectedStopped @(101, 102, 103)
Invoke-Case -Label 'CheckOnly performs no termination' -Processes @(
    (New-Fixture 101 'MapleStory'),
    (New-Fixture 103 'BlackCipher64.aes')
) -CheckOnly
Invoke-Case -Label 'Access denied is a failure' -Processes @(
    (New-Fixture 101 'MapleStory' 'Denied')
) -ExpectedExit 1
Invoke-Case -Label 'Cannot pin a handle: skip safely' -Processes @(
    (New-Fixture 101 'MapleStory' 'DeniedHandle')
) -ExpectedExit 1
Invoke-Case -Label 'PID identity changes before pinning: skip safely' -Processes @(
    (New-Fixture 101 'MapleStory' 'Reused')
) -ExpectedExit 1
Invoke-Case -Label 'PID is reused by an unrelated process: never terminate it' -Processes @(
    (New-Fixture 101 'MapleStory' 'Renamed')
)
Invoke-Case -Label 'Target exits during cleanup' -Processes @(
    (New-Fixture 101 'MapleStory' 'SelfExited')
)
Invoke-Case -Label 'Termination timeout is a failure' -Processes @(
    (New-Fixture 101 'MapleStory' 'Timeout')
) -ExpectedStopped @(101) -ExpectedExit 1

Write-Host 'All fixture tests passed; no real processes were stopped.' -ForegroundColor Cyan
exit 0
