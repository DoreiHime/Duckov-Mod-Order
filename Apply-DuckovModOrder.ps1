<#
.SYNOPSIS
  一键应用《逃离鸭科夫》合集 MOD 的启用状态与加载顺序（无需打开游戏）。

.DESCRIPTION
  只修改两个本地文件：
    * Saves\Mods.ES3     —— 每个 mod 的加载优先级（数字越小越先加载）
    * Saves\Global.json  —— 每个 mod 的启用开关（ModActive_*）以及 AllowLoadingMod
  不改 mod 文件、不改游戏文件、不联网；写入前自动备份到 Saves\ModOrderBackup-<时间>。

  用法：
    powershell -ExecutionPolicy Bypass -File .\Apply-DuckovModOrder.ps1
    powershell -ExecutionPolicy Bypass -File .\Apply-DuckovModOrder.ps1 -DryRun     # 只预览，不写入
    powershell -ExecutionPolicy Bypass -File .\Apply-DuckovModOrder.ps1 -Restore    # 还原最近一次备份

  运行前请完全退出游戏（脚本会检查 Duckov.exe）。运行后直接启动游戏即可，不需要额外重启。
#>
[CmdletBinding()]
param(
    [string]$SavesDir = "",
    [switch]$Restore,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$orderPath = Join-Path $scriptDir 'mod-order.json'

if (-not $SavesDir -or $SavesDir.Trim() -eq '') {
    $SavesDir = Join-Path $env:USERPROFILE 'AppData\LocalLow\TeamSoda\Duckov\Saves'
}
$modsFile   = Join-Path $SavesDir 'Mods.ES3'
$globalFile = Join-Path $SavesDir 'Global.json'

function Stop-WithError([string]$Message) {
    Write-Host ""
    Write-Host "[错误] $Message" -ForegroundColor Red
    exit 1
}

function Write-JsonFile([string]$Path, $Object) {
    $json = $Object | ConvertTo-Json -Depth 100
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json + "`n", $utf8NoBom)
}

function Read-JsonFile([string]$Path) {
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return ($text | ConvertFrom-Json)
}

# 把 ConvertFrom-Json 的 PSCustomObject 递归转成有序 Hashtable，便于保留原有键值再写回。
function ConvertTo-OrderedDictionary($Object) {
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Management.Automation.PSCustomObject]) {
        $result = [ordered]@{}
        foreach ($prop in $Object.PSObject.Properties) {
            $result[$prop.Name] = ConvertTo-OrderedDictionary $prop.Value
        }
        return $result
    }
    if ($Object -is [System.Array]) {
        $list = New-Object System.Collections.ArrayList
        foreach ($item in $Object) {
            [void]$list.Add((ConvertTo-OrderedDictionary $item))
        }
        return ,$list.ToArray()
    }
    return $Object
}

# ---------------------------------------------------------------- 检查游戏
$running = Get-Process -Name Duckov -ErrorAction SilentlyContinue
if ($running) {
    Stop-WithError '检测到游戏正在运行。请先完全退出游戏（任务管理器确认 Duckov.exe 已结束）后再运行本脚本。'
}

# ---------------------------------------------------------------- 还原
if ($Restore) {
    if (-not (Test-Path $SavesDir)) {
        Stop-WithError "找不到存档目录：$SavesDir"
    }
    $backups = @(Get-ChildItem $SavesDir -Directory -Filter 'ModOrderBackup-*' -ErrorAction SilentlyContinue |
                 Sort-Object Name -Descending)
    if ($backups.Count -eq 0) {
        Stop-WithError '没有找到备份目录（ModOrderBackup-*），无法还原。'
    }
    $source = $backups[0].FullName
    $restored = @()
    foreach ($name in @('Mods.ES3', 'Global.json')) {
        $from = Join-Path $source $name
        if (Test-Path $from) {
            Copy-Item -LiteralPath $from -Destination (Join-Path $SavesDir $name) -Force
            $restored += $name
        }
    }
    if ($restored.Count -eq 0) {
        Stop-WithError "备份目录里没有可还原的文件：$source"
    }
    Write-Host "[完成] 已从备份还原：$source" -ForegroundColor Green
    Write-Host "已还原：$($restored -join '、')"
    Write-Host "启动游戏即可生效（无需额外重启）。"
    exit 0
}

# ---------------------------------------------------------------- 读取顺序表
if (-not (Test-Path $orderPath)) {
    Stop-WithError "找不到 mod-order.json：$orderPath（请把整个仓库文件夹解压完整）"
}
$orderData = $null
try {
    $orderData = Read-JsonFile $orderPath
} catch {
    Stop-WithError "mod-order.json 解析失败：$($_.Exception.Message)"
}
$order = @($orderData.order | Where-Object { $_ -and $_.Trim() -ne '' })
if ($order.Count -lt 1) {
    Stop-WithError 'mod-order.json 里的 order 列表为空。'
}

if (-not (Test-Path $SavesDir)) {
    Write-Host "[提示] 未找到存档目录，将创建：$SavesDir" -ForegroundColor Yellow
    if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $SavesDir | Out-Null }
}

# ---------------------------------------------------------------- 读取旧数据
$oldPriorities = @{}   # name -> old priority
if (Test-Path $modsFile) {
    try {
        $old = Read-JsonFile $modsFile
        foreach ($prop in $old.PSObject.Properties) {
            if ($prop.Name -like 'priority_*') {
                $n = $prop.Name.Substring('priority_'.Length)
                $v = 0
                try { $v = [int]$prop.Value.value } catch { }
                $oldPriorities[$n] = $v
            }
        }
    } catch {
        Stop-WithError "现有 Mods.ES3 解析失败（为避免破坏，已中止）：$($_.Exception.Message)"
    }
}

$global = $null
if (Test-Path $globalFile) {
    try {
        $global = ConvertTo-OrderedDictionary (Read-JsonFile $globalFile)
    } catch {
        Stop-WithError "现有 Global.json 解析失败（为避免破坏，已中止）：$($_.Exception.Message)"
    }
} else {
    $global = [ordered]@{}
}

# ---------------------------------------------------------------- 生成新顺序
$newPriorities = [ordered]@{}
$known = @{}
$index = 0
foreach ($name in $order) {
    $newPriorities["priority_$name"] = [ordered]@{ '__type' = 'int'; 'value' = $index }
    $known[$name] = $true
    $index++
}

# 顺序表以外的旧 mod 保留，排到列表之后（按它们原来的先后）
$extras = @()
foreach ($name in $oldPriorities.Keys) {
    if (-not $known.ContainsKey($name)) {
        $extras += [pscustomobject]@{ Name = $name; Value = $oldPriorities[$name] }
    }
}
$extras = @($extras | Sort-Object Value)
foreach ($e in $extras) {
    $newPriorities["priority_$($e.Name)"] = [ordered]@{ '__type' = 'int'; 'value' = $index }
    $index++
}

# 启用状态
$global['AllowLoadingMod'] = [ordered]@{ '__type' = 'bool'; 'value' = $true }
foreach ($name in $order) {
    $global["ModActive_$name"] = [ordered]@{ '__type' = 'bool'; 'value' = $true }
}

# ---------------------------------------------------------------- 写入
Write-Host "游戏版本（记录）：$($orderData.gameVersionTested)    mod 数量：$($order.Count)"
if ($DryRun) {
    Write-Host ""
    Write-Host "[DryRun] 将以如下顺序写入（不实际修改文件）：" -ForegroundColor Cyan
    $i = 0
    foreach ($name in $order) { Write-Host ("  {0,2}. {1}" -f $i, $name); $i++ }
    if ($extras.Count -gt 0) {
        Write-Host "  —— 以下为列表外、会被排到最后的 mod ——"
        foreach ($e in $extras) { Write-Host ("  {0,2}. {1}" -f $i, $e.Name); $i++ }
    }
    Write-Host ""
    Write-Host "[DryRun] 未写入任何文件。"
    exit 0
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $SavesDir "ModOrderBackup-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$backedUp = @()
foreach ($file in @($modsFile, $globalFile)) {
    if (Test-Path $file) {
        Copy-Item -LiteralPath $file -Destination (Join-Path $backupDir (Split-Path -Leaf $file)) -Force
        $backedUp += (Split-Path -Leaf $file)
    }
}

try {
    Write-JsonFile $modsFile $newPriorities
    Write-JsonFile $globalFile $global
} catch {
    Stop-WithError "写入失败：$($_.Exception.Message)（备份在 $backupDir，可手动还原）"
}

# ---------------------------------------------------------------- 校验
try {
    $check = Read-JsonFile $modsFile
    $count = @($check.PSObject.Properties).Count
} catch {
    Stop-WithError "写入后校验失败：$($_.Exception.Message)（备份在 $backupDir）"
}

Write-Host ""
Write-Host "[完成] 已写入 $($order.Count) 个 mod 的加载顺序与启用状态。" -ForegroundColor Green
if ($extras.Count -gt 0) {
    Write-Host "        另有 $($extras.Count) 个不在合集列表里的 mod 被排到列表之后（未改动其启用状态）。"
}
if ($backedUp.Count -gt 0) {
    Write-Host "        修改前备份：$backupDir（含 $($backedUp -join '、')）"
}
Write-Host ""
Write-Host "接下来：直接启动游戏即可生效，不需要额外重启。"
Write-Host "如需还原：powershell -ExecutionPolicy Bypass -File .\Apply-DuckovModOrder.ps1 -Restore"
