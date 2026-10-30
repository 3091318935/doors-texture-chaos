#Requires -Version 5.1
<#
  push-api.ps1  (ASCII only - safe for PowerShell 5.1)

  Publish this folder to GitHub using the contents API. No git required.

    - creates the repo if it does not exist
    - uploads every file listed in $Manifest (or all tracked text files with -All)
    - overwrites existing files by sending their sha
    - verifies the raw URL afterwards

  Credentials are resolved in this order:
    1. -Token / $env:GITHUB_TOKEN / $env:GH_TOKEN
    2. gh auth token (if the GitHub CLI is installed)
    3. git credential fill (if git has a stored credential)
    4. masked prompt

  Usage:
      powershell -ExecutionPolicy Bypass -File tools\push-api.ps1
      powershell -ExecutionPolicy Bypass -File tools\push-api.ps1 -Repo doors-texture-chaos
      powershell -ExecutionPolicy Bypass -File tools\push-api.ps1 -Owner someone -Private
      $env:GITHUB_TOKEN = "ghp_xxx"
      powershell -ExecutionPolicy Bypass -File tools\push-api.ps1
#>
[CmdletBinding()]
param(
    [string]$Owner = '3091318935',
    [string]$Repo = 'doors-texture-chaos',
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$Description = 'DOORS entity texture / mesh swapper for Roblox: one-file Lua, Studio plugin, Rojo project. Four shuffle modes, one-click restore.',
    [switch]$Private,
    [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$Api = 'https://api.github.com'
$Root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Token)) { $Token = $env:GH_TOKEN }

function Step($m) { Write-Host "[..] $m" -ForegroundColor DarkCyan }
function Ok($m) { Write-Host "[ok] $m" -ForegroundColor Green }
function Warn2($m) { Write-Host "[!!] $m" -ForegroundColor Yellow }

function Resolve-Exe {
    param([string]$Name, [string[]]$Fallbacks)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in $Fallbacks) {
        $expanded = [System.Environment]::ExpandEnvironmentVariables($p)
        if (Test-Path -LiteralPath $expanded) { return $expanded }
    }
    return $null
}

$GhExe = Resolve-Exe -Name 'gh' -Fallbacks @(
    'C:\Program Files\GitHub CLI\gh.exe',
    "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"
)
$GitExe = Resolve-Exe -Name 'git' -Fallbacks @(
    "$env:LOCALAPPDATA\Programs\MinGit\cmd\git.exe",
    'C:\Program Files\Git\cmd\git.exe',
    'C:\Program Files (x86)\Git\cmd\git.exe'
)

if ([string]::IsNullOrWhiteSpace($Token) -and $GhExe) {
    try {
        $t = & $GhExe auth token 2>$null
        if ($LASTEXITCODE -eq 0 -and $t) { $Token = ([string]$t).Trim() }
    }
    catch { }
}

if ([string]::IsNullOrWhiteSpace($Token) -and $GitExe) {
    try {
        $probe = "protocol=https`nhost=github.com`n`n"
        $out = $probe | & $GitExe credential fill 2>$null
        foreach ($line in ($out -split "`n")) {
            if ($line -like 'password=*') { $Token = $line.Substring(9).Trim(); break }
        }
    }
    catch { }
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    $sec = Read-Host -AsSecureString 'Paste GitHub token (ghp_... or github_pat_...), input is masked'
    $cred = New-Object System.Management.Automation.PSCredential('token', $sec)
    $Token = $cred.GetNetworkCredential().Password
}

$Token = ([string]$Token).Trim()
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw 'No token. Create one at https://github.com/settings/tokens (repo scope, or Contents: Read and write).'
}

$Headers = @{
    Authorization          = "Bearer $Token"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'doors-texture-chaos-publisher'
}

function Invoke-Gh {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        $Body
    )
    $req = @{
        Method      = $Method
        Uri         = "$Api$Path"
        Headers     = $Headers
        ErrorAction = 'Stop'
        TimeoutSec  = 60
    }
    if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 10 -Compress
        $req.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
        $req.ContentType = 'application/json; charset=utf-8'
    }
    try { return Invoke-RestMethod @req }
    catch {
        $resp = $_.Exception.Response
        $code = 0
        $text = $_.Exception.Message
        if ($resp) {
            $code = [int]$resp.StatusCode
            try {
                $stream = $resp.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $text = $reader.ReadToEnd()
                }
            }
            catch { }
        }
        throw ("GitHub API {0} {1} failed ({2}): {3}" -f $Method, $Path, $code, $text)
    }
}

function ConvertTo-ApiPath($relative) {
    (($relative -split '/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
}

# ---------------------------------------------------------------- identity
$me = Invoke-Gh -Method GET -Path '/user'
Ok ("authenticated as {0}" -f $me.login)
if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = $me.login }

# ---------------------------------------------------------------- repo
$info = $null
try {
    $info = Invoke-Gh -Method GET -Path "/repos/$Owner/$Repo"
    Ok ("repo exists: https://github.com/{0}/{1}" -f $Owner, $Repo)
}
catch {
    $body = @{
        name        = $Repo
        description = $Description
        private     = [bool]$Private
        has_issues  = $true
        has_wiki    = $false
        auto_init   = $false
    }
    $info = Invoke-Gh -Method POST -Path '/user/repos' -Body $body
    Ok ("repo created: https://github.com/{0}/{1}" -f $Owner, $Repo)
}

$Branch = 'main'
if ($info -and $info.default_branch) { $Branch = [string]$info.default_branch }

$empty = $false
try { $null = Invoke-Gh -Method GET -Path "/repos/$Owner/$Repo/contents/" }
catch { $empty = $true }
if ($empty) { Step 'empty repo: first commit will create the branch' }

# ---------------------------------------------------------------- manifest
$Manifest = @(
    'README.md',
    'PUBLISH.md',
    'LICENSE',
    '.gitignore',
    'default.project.json',
    'standalone/DoorsTextureChaos.lua',
    'plugin/DoorsTextureChaos.plugin.lua',
    'src/ReplicatedStorage/DoorsTextureChaos/init.lua',
    'src/ReplicatedStorage/DoorsTextureChaos/Config.lua',
    'src/ReplicatedStorage/DoorsTextureChaos/Rng.lua',
    'src/ReplicatedStorage/DoorsTextureChaos/Units.lua',
    'src/ReplicatedStorage/DoorsTextureChaos/Shuffle.lua',
    'src/ReplicatedStorage/DoorsTextureChaos/Registry.lua',
    'src/ServerScriptService/TextureChaosServer.server.lua',
    'src/StarterPlayer/ChaosHud.client.lua',
    'docs/models.md',
    'docs/entities.md',
    'docs/assets-manifest.md',
    'docs/field-notes.md',
    'docs/asset-inventory.md',
    'assets.lua',
    'assets-report.txt',
    'models/README.md',
    'models/FigureRig.build.lua',
    'models/RushTextures.build.lua',
    'models/EntityRigs.build.lua',
    'models/ALL-IN-ONE.build.lua',
    'models/SHOP-PACK.build.lua',
    'models/ElGoblino.build.lua',
    'models/Bob.build.lua',
    'models/Timothy.build.lua',
    'models/FigureWelded.build.lua',
    'models/FigureFull.build.lua',
    'models/Figure2.build.lua',
    'tools/push-api.ps1',
    'tools/push-to-github.ps1',
    'tools/build.ps1',
    'tools/extract-assets.ps1',
    'tools/rig-to-lua.ps1',
    'tools/fetch-and-extract.ps1'
)

$uploaded = 0
foreach ($name in $Manifest) {
    $full = Join-Path $Root ($name -replace '/', '\')
    if (-not (Test-Path -LiteralPath $full)) {
        Warn2 "$name missing, skipped"
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($full)
    $content = [Convert]::ToBase64String($bytes)
    $apiPath = ConvertTo-ApiPath $name

    $sha = $null
    if (-not $empty) {
        try {
            $existing = Invoke-Gh -Method GET -Path ("/repos/{0}/{1}/contents/{2}" -f $Owner, $Repo, $apiPath)
            if ($existing -and $existing.sha) { $sha = [string]$existing.sha }
        }
        catch { }
    }

    $payload = @{
        message = "sync: $name"
        content = $content
    }
    if ($sha) { $payload.sha = $sha }
    if (-not $empty) { $payload.branch = $Branch }

    $null = Invoke-Gh -Method PUT -Path ("/repos/{0}/{1}/contents/{2}" -f $Owner, $Repo, $apiPath) -Body $payload
    $empty = $false
    $uploaded++
    Ok "uploaded $name"
}

# ---------------------------------------------------------------- metadata
try {
    $null = Invoke-Gh -Method PATCH -Path "/repos/$Owner/$Repo" -Body @{
        description = $Description
        homepage    = "https://github.com/$Owner/$Repo"
    }
    Ok 'description updated'
}
catch { Warn2 'description update skipped' }

try {
    $final = Invoke-Gh -Method GET -Path "/repos/$Owner/$Repo"
    if ($final -and $final.default_branch) { $Branch = [string]$final.default_branch }
}
catch { }

# ---------------------------------------------------------------- summary
$repoUrl = "https://github.com/$Owner/$Repo"
$rawStandalone = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/standalone/DoorsTextureChaos.lua"

Write-Host ''
Write-Host ("uploaded : {0} file(s)" -f $uploaded) -ForegroundColor Green
Write-Host ("repo     : {0}" -f $repoUrl)
Write-Host ("raw      : {0}" -f $rawStandalone)
Write-Host ''
Write-Host 'Roblox one-liner:' -ForegroundColor Cyan
Write-Host ('loadstring(game:HttpGet("{0}"))()' -f $rawStandalone) -ForegroundColor Cyan
try { Set-Clipboard -Value $rawStandalone; Write-Host '(raw url copied to clipboard)' } catch { }

if (-not $NoVerify) {
    Step 'waiting for the CDN, then checking the raw url'
    for ($i = 1; $i -le 6; $i++) {
        Start-Sleep -Seconds 3
        try {
            $head = Invoke-WebRequest -Uri $rawStandalone -Method Head -UseBasicParsing -TimeoutSec 20
            if ($head.StatusCode -eq 200) { Ok 'raw url is live'; break }
        }
        catch {
            if ($i -eq 6) { Warn2 'raw not answering yet, refresh in a minute' }
        }
    }
}
