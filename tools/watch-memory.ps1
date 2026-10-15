# 内存看护：盯住 moe-kill 进程，内存涨过上限就击毙；目标没了再等一会儿自己也退
#
#   tools/watch-memory.ps1                     盯所有叫 moe-kill 的进程，超 1 GB 击毙
#   tools/watch-memory.ps1 -LimitGB 4          换上限
#   tools/watch-memory.ps1 -Id 12345           只盯一个进程号
#   tools/watch-memory.ps1 -Metric Private     按「私有内存」判（默认按工作集）
#   tools/watch-memory.ps1 -MaxSeconds 30      不管目标死活，跑满这么久就自己收工（0 = 不限）
#   tools/watch-memory.ps1 -ExitDelaySeconds 0 目标一走自己也走

[CmdletBinding()]
param(
    [string] $Name = 'moe-kill',
    [int]    $Id = 0,
    [double] $LimitGB = 1,
    [ValidateSet('WorkingSet', 'Private')]
    [string] $Metric = 'WorkingSet',
    [double] $IntervalSeconds = 1,
    [double] $ExitDelaySeconds = 10,
    [double] $MaxSeconds = 0,
    [string] $LogPath = 'server/tmp/watch-memory.log'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($LogPath)) {
    $LogPath = Join-Path $root $LogPath
}
$logDir = Split-Path -Parent $LogPath
if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

$limitMB = [int64] ($LimitGB * 1024)
$target  = if ($Id -ne 0) { "PID $Id" } else { "名叫 $Name 的进程" }

function Write-Line {
    param([string] $Text)
    $line = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line -Encoding utf8
}

function Get-MemoryMB {
    param([System.Diagnostics.Process] $Process)
    $bytes = if ($Metric -eq 'Private') { $Process.PrivateMemorySize64 } else { $Process.WorkingSet64 }
    return [int64] [math]::Round($bytes / 1MB)
}

Write-Line "看护开始：$target，上限 $LimitGB GB（$Metric），每 $IntervalSeconds 秒查一次"

$peaks    = @{}
$shown    = @{}
$goneAt   = $null
$startedAt = Get-Date

while ($true) {
    if ($MaxSeconds -gt 0 -and ((Get-Date) - $startedAt).TotalSeconds -ge $MaxSeconds) {
        Write-Line '到点了，收工'
        exit 0
    }

    if ($Id -ne 0) {
        $procs = @(Get-Process -Id $Id -ErrorAction SilentlyContinue)
    } else {
        $procs = @(Get-Process -Name $Name -ErrorAction SilentlyContinue)
    }

    if ($procs.Count -eq 0) {
        if (-not $goneAt) {
            $goneAt = Get-Date
            Write-Line "目标不见了，等 $ExitDelaySeconds 秒后自己也退"
        } elseif (((Get-Date) - $goneAt).TotalSeconds -ge $ExitDelaySeconds) {
            Write-Line '收工'
            exit 0
        }
        Start-Sleep -Milliseconds 200
        continue
    }
    $goneAt = $null

    $alive = @{}
    foreach ($process in $procs) {
        $procId = $process.Id
        $alive[$procId] = $true

        try {
            $mb = Get-MemoryMB -Process $process
        } catch {
            continue
        }

        if (-not $peaks.ContainsKey($procId)) {
            $peaks[$procId] = $mb
            $shown[$procId] = $mb
            Write-Line "+ PID $procId 起来了（$mb MB）"
        } elseif ($mb -gt $peaks[$procId]) {
            $peaks[$procId] = $mb
        }

        if ($mb -ge $limitMB) {
            Write-Line "! PID $procId 到 $mb MB（峰值 $($peaks[$procId]) MB），超上限，击毙"
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
            continue
        }

        $last = $shown[$procId]
        if ($mb -ge ($limitMB / 2) -or ($mb - $last) -ge 128) {
            $shown[$procId] = $mb
            Write-Line "  PID $procId 内存 $mb MB（峰值 $($peaks[$procId]) MB）"
        }
    }

    foreach ($procId in @($peaks.Keys)) {
        if (-not $alive.ContainsKey($procId)) {
            Write-Line "- PID $procId 走了（峰值 $($peaks[$procId]) MB）"
            $peaks.Remove($procId)
            $shown.Remove($procId)
        }
    }

    Start-Sleep -Seconds $IntervalSeconds
}
