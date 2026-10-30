#Requires -Version 5.1
<#
  fetch-and-extract.ps1  (ASCII only - safe for PowerShell 5.1)

  Downloads DOORS save files through public mirrors (with retry + fallback),
  then extracts entity models and texture ids.

  Every step is written to fetch-log.txt so progress survives a closed window.

  Usage:
      powershell -ExecutionPolicy Bypass -File tools\fetch-and-extract.ps1
      powershell -ExecutionPolicy Bypass -File tools\fetch-and-extract.ps1 -All
      powershell -ExecutionPolicy Bypass -File tools\fetch-and-extract.ps1 -OnlyList
#>
[CmdletBinding()]
param(
    [string]$Dir = 'D:\DSH ROBLOX\doors_downloads',
    [string]$ProjectRoot = '',
    [int]$TimeoutSec = 120,
    [int]$Retries = 3,
    [switch]$All,
    [switch]$OnlyList,
    [switch]$NoExtract
)

$ErrorActionPreference = 'Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$LogPath = Join-Path $ProjectRoot 'fetch-log.txt'

# mirrors, tried in order
$Mirrors = @(
    'https://gh-proxy.com/https://raw.githubusercontent.com/Palayop7239/DoorsFiles/main/',
    'https://ghfast.top/https://raw.githubusercontent.com/Palayop7239/DoorsFiles/main/',
    'https://ghproxy.net/https://raw.githubusercontent.com/Palayop7239/DoorsFiles/main/'
)

# smallest entity-bearing files first
$Priority = @(
    'floor2/halt floor 2.rbxmx',
    'floor2/seek start f2.rbxmx',
    'floor2/sewers 5 + figure.rbxmx',
    'floor2/gaz + gloombats.rbxmx',
    'floor1/new halt floor 1.rbxlx',
    'floor2/figure 1st appear.rbxlx',
    'floor2/seek final 1.rbxmx',
    'floor1/jeff f1.rbxlx'
)

$Everything = @(
    'rooms/rooms 252.rbxlx',
    'floor1/door 0.rbxlx',
    'floor1/door 100.rbxlx',
    'floor1/door 50 f1.rbxlx',
    'floor1/door 50 v2.rbxlx',
    'floor1/f1 rooms.rbxlx',
    'floor1/greenhouse 1.rbxlx',
    'floor1/greenhouse 2.rbxlx',
    'floor1/greenhouse 3.rbxlx',
    'floor1/jeff f1.rbxlx',
    'floor1/new courtyard floor 1.rbxlx',
    'floor1/new halt floor 1.rbxlx',
    'floor2/+ room mines.rbxmx',
    'floor2/H mines room.rbxmx',
    'floor2/h room again.rbxmx',
    'floor2/halt floor 2.rbxmx',
    'floor2/figure 1st appear.rbxlx',
    'floor2/fuse room.rbxmx',
    'floor2/gaz + gloombats.rbxmx',
    'floor2/mines rooms 1.rbxlx',
    'floor2/mines rooms 2.rbxlx',
    'floor2/mines rooms 3.rbxlx',
    'floor2/door 101.rbxlx',
    'floor2/door 200 post seek.rbxmx',
    'floor2/seek 1 f2.rbxmx',
    'floor2/seek 2 f2.rbxmx',
    'floor2/seek before minecart f2.rbxmx',
    'floor2/seek final 1.rbxmx',
    'floor2/seek start f2.rbxmx',
    'floor2/sewers 3.rbxmx',
    'floor2/sewers 4.rbxmx',
    'floor2/sewers 5 + figure.rbxmx',
    'floor2/sewers 6.rbxmx',
    'floor2/sewers 7.rbxmx',
    'floor2/sewers 8.rbxmx',
    'floor2/thing mines room 3.rbxmx',
    'floor2/thing mines room.rbxmx'
)

function Log($m) {
    $line = ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m)
    try { Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 } catch { }
    Write-Host $m
}
function Step($m) { Write-Host "==> $m" -ForegroundColor Cyan; try { Add-Content -LiteralPath $LogPath -Value ("==> " + $m) -Encoding UTF8 } catch { } }
function Ok($m) { Write-Host "  OK  $m" -ForegroundColor Green; try { Add-Content -LiteralPath $LogPath -Value ("  OK  " + $m) -Encoding UTF8 } catch { } }
function Skip($m) { Write-Host "  --  $m" -ForegroundColor DarkGray }
function Fail($m) { Write-Host "  !!  $m" -ForegroundColor Red; try { Add-Content -LiteralPath $LogPath -Value ("  !!  " + $m) -Encoding UTF8 } catch { } }

function Encode-Path($relative) {
    $parts = $relative -split '/'
    $out = @()
    foreach ($p in $parts) { $out += [uri]::EscapeDataString($p) }
    return ($out -join '/')
}

# a Roblox XML save always ends with </roblox>; anything else is a cut-off download
function Test-Complete($filePath) {
    if (-not (Test-Path -LiteralPath $filePath)) { return $false }
    $fi = Get-Item -LiteralPath $filePath
    if ($fi.Length -lt 20480) { return $false }
    try {
        $fs = [IO.File]::OpenRead($filePath)
        $tailLen = [int][math]::Min(300, $fs.Length)
        $fs.Seek(-$tailLen, [IO.SeekOrigin]::End) | Out-Null
        $buf = New-Object byte[] $tailLen
        $fs.Read($buf, 0, $tailLen) | Out-Null
        $fs.Close()
        $s = [Text.Encoding]::UTF8.GetString($buf)
        return $s.Contains('</roblox>')
    }
    catch { return $false }
}

$list = if ($All) { $Everything } else { $Priority }

Step "target dir: $Dir"
try { Set-Content -LiteralPath $LogPath -Value ("fetch log " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Encoding UTF8 } catch { }

if (-not (Test-Path -LiteralPath $Dir)) {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    Ok 'created dir'
}

if ($OnlyList) {
    foreach ($f in $list) { Write-Host ($Mirrors[0] + (Encode-Path $f)) }
    return
}

$okCount = 0
$skipCount = 0
$failCount = 0

foreach ($relative in $list) {
    $fileName = Split-Path $relative -Leaf
    $target = Join-Path $Dir $fileName
    $rel = Encode-Path $relative

    if (Test-Path -LiteralPath $target) {
        if (Test-Complete $target) {
            $len = (Get-Item -LiteralPath $target).Length
            Skip ("have {0} ({1:N1} MB)" -f $fileName, ($len / 1MB))
            $skipCount++
            continue
        }
        else {
            Fail ("{0} is incomplete (cut off), re-downloading" -f $fileName)
            Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        }
    }

    Step ("download {0}" -f $relative)
    $done = $false

    for ($attempt = 1; $attempt -le $Retries -and -not $done; $attempt++) {
        foreach ($mirror in $Mirrors) {
            $url = $mirror + $rel
            $oldPref = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            $part = $target + '.part'
            try {
                if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue }
                Invoke-WebRequest -Uri $url -OutFile $part -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
                $size = (Get-Item -LiteralPath $part).Length
                if ($size -lt 20480) { throw ("too small: {0} bytes" -f $size) }
                if (-not (Test-Complete $part)) { throw 'download is truncated (no closing </roblox>)' }
                Move-Item -LiteralPath $part -Destination $target -Force -ErrorAction Stop
                Ok ("{0:N1} MB  <- {1}" -f ($size / 1MB), ([uri]$url).Host)
                $done = $true
                $okCount++
                break
            }
            catch {
                Fail ("attempt {0} via {1}: {2}" -f $attempt, ([uri]$url).Host, $_.Exception.Message)
                if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue }
            }
            finally {
                $ProgressPreference = $oldPref
            }
        }
    }

    if (-not $done) { $failCount++ }
}

Write-Host ''
Step ("download done: new {0}, skipped {1}, failed {2}" -f $okCount, $skipCount, $failCount)

if ($NoExtract) {
    Log 'ALL DONE (no extract)'
    return
}

$extractor = Join-Path $PSScriptRoot 'extract-assets.ps1'
if (-not (Test-Path -LiteralPath $extractor)) {
    Fail 'extract-assets.ps1 not found'
    Log 'ALL DONE (extract skipped)'
    return
}

Write-Host ''
Step 'extracting entity models and texture ids'
& $extractor -Path $Dir -Out (Join-Path $ProjectRoot 'assets.lua')

$reportPath = Join-Path $ProjectRoot 'assets-report.txt'
$assetsPath = Join-Path $ProjectRoot 'assets.lua'
Write-Host ''
Write-Host "report : $reportPath" -ForegroundColor Cyan
Write-Host "lua    : $assetsPath" -ForegroundColor Cyan

Log 'ALL DONE'
Write-Host ''
Write-Host 'ALL DONE - tell the agent, it will read the files.' -ForegroundColor Green
