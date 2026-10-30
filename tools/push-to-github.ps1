<#
.SYNOPSIS
    把本项目建成一个全新的 GitHub 仓库并推送上去。

.DESCRIPTION
    两条路自动选：
      1) 装了 GitHub CLI（gh）且已 gh auth login  -> 用 gh repo create
      2) 没装 gh                                    -> 用 GITHUB_TOKEN 走 REST API

.EXAMPLE
    $env:GITHUB_TOKEN = "ghp_xxx"
    powershell -ExecutionPolicy Bypass -File tools\push-to-github.ps1 -Repo doors-texture-chaos

.EXAMPLE
    # 指定账号、私有仓
    powershell -ExecutionPolicy Bypass -File tools\push-to-github.ps1 -Owner yourname -Repo doors-texture-chaos -Visibility private
#>

[CmdletBinding()]
param(
    [string]$Repo = "doors-texture-chaos",
    [string]$Owner = "",
    [ValidateSet("public", "private")]
    [string]$Visibility = "public",
    [string]$Message = "feat: DOORS 贴图乱斗 v1.0.0",
    [string]$Branch = "main",
    [string]$Token = $env:GITHUB_TOKEN
)

$ErrorActionPreference = "Stop"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

function Write-Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Write-Ok($text) { Write-Host "  OK  $text" -ForegroundColor Green }
function Fail($text) { Write-Host "  !! $text" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 定位仓库根
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path (Join-Path $root "default.project.json"))) {
    Fail "这里看起来不是项目根目录：$root"
}
Write-Step "仓库根目录：$root"

# ---------------------------------------------------------------- 检查 git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "没找到 git。先装 Git for Windows：https://git-scm.com/download/win"
}
Write-Ok ("git " + (git --version))

# ---------------------------------------------------------------- 初始化 / 提交
if (-not (Test-Path (Join-Path $root ".git"))) {
    Write-Step "初始化本地仓库"
    git init -b $Branch | Out-Null
    if ($LASTEXITCODE -ne 0) {
        git init | Out-Null
        git checkout -b $Branch 2>$null
    }
    Write-Ok "git init"
}
else {
    Write-Step "已有 .git，沿用"
}

# 本地身份（全局没配的话临时配一个，避免 commit 失败）
$hasName = git config user.name
if (-not $hasName) {
    git config user.name "YG"
    Write-Ok "设置本地 user.name = YG"
}
$hasMail = git config user.email
if (-not $hasMail) {
    git config user.email "yg@users.noreply.github.com"
    Write-Ok "设置本地 user.email"
}

Write-Step "暂存 + 提交"
git add -A
$staged = git diff --cached --name-only
if ($staged) {
    git commit -m $Message | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "commit 失败" }
    Write-Ok ("提交了 " + (@($staged).Count) + " 个文件")
}
else {
    Write-Ok "没有新改动，跳过提交"
}

# ---------------------------------------------------------------- 找账号名
$login = $Owner
if (-not $login) {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $login = (gh api user --jq .login 2>$null)
    }
    if (-not $login -and $Token) {
        $headers = @{
            Authorization          = "Bearer $Token"
            Accept                 = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }
        try {
            $me = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get
            $login = $me.login
        }
        catch {
            Fail "令牌无效或网络不通：$($_.Exception.Message)"
        }
    }
}
if (-not $login) { Fail "拿不到 GitHub 账号名。加 -Owner yourname，或先 gh auth login / 设 GITHUB_TOKEN" }
Write-Ok "账号：$login"

$fullName = "$login/$Repo"
$htmlUrl = "https://github.com/$fullName"

# ---------------------------------------------------------------- 建远程仓库
$originUrl = git remote get-url origin 2>$null
$created = $false

if (-not $originUrl) {
    if (($login -eq $Owner) -and (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Step "用 gh 建仓库 $fullName（$Visibility）"
        gh repo create $fullName "--$Visibility" --source . --remote origin --push
        if ($LASTEXITCODE -eq 0) {
            $created = $true
            Write-Ok $htmlUrl
        }
        else {
            Write-Host "  gh 建仓失败，回退到 REST API" -ForegroundColor Yellow
        }
    }

    if (-not $created) {
        if (-not $Token) {
            Fail "需要 GITHUB_TOKEN 才能通过 API 建仓：`$env:GITHUB_TOKEN = 'ghp_xxx'"
        }
        Write-Step "用 REST API 建仓库 $fullName（$Visibility）"
        $headers = @{
            Authorization          = "Bearer $Token"
            Accept                 = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }
        $body = @{
            name        = $Repo
            description = "DOORS 生物贴图 / 建模随机互搬工具（Roblox）"
            private     = ($Visibility -eq "private")
            has_issues  = $true
            has_wiki    = $false
        } | ConvertTo-Json

        try {
            $repoObj = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers -Method Post -Body $body -ContentType "application/json"
            Write-Ok $repoObj.html_url
        }
        catch {
            $detail = $_.ErrorDetails.Message
            if ($detail -match "already exists") {
                Write-Host "  仓库已存在，直接推" -ForegroundColor Yellow
            }
            else {
                Fail "建仓失败：$($_.Exception.Message) $detail"
            }
        }

        git remote add origin "https://github.com/$fullName.git"
        Write-Ok "remote origin -> $fullName"
        $created = $true
    }
}
else {
    Write-Step "已有 remote origin：$originUrl"
}

# ---------------------------------------------------------------- 推送
Write-Step "推送到 $Branch"
if ($Token) {
    # 一次性带令牌推，不把令牌写进 .git/config
    $play = git ls-remote "https://x-access-token:$Token@github.com/$fullName.git" 2>&1
    if ($LASTEXITCODE -eq 0 -and $play -notmatch "fatal") {
        git push "https://x-access-token:$Token@github.com/$fullName.git" "HEAD:refs/heads/$Branch" --force-with-lease 2>&1 | ForEach-Object { Write-Host "    $_" }
        if ($LASTEXITCODE -ne 0) {
            git push "https://x-access-token:$Token@github.com/$fullName.git" "HEAD:refs/heads/$Branch" 2>&1 | ForEach-Object { Write-Host "    $_" }
        }
    }
    else {
        git push -u origin $Branch 2>&1 | ForEach-Object { Write-Host "    $_" }
    }
}
else {
    git push -u origin $Branch 2>&1 | ForEach-Object { Write-Host "    $_" }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "推送没成功。常见原因：" -ForegroundColor Yellow
    Write-Host "  · 没登录：gh auth login"
    Write-Host "  · 没令牌：`$env:GITHUB_TOKEN = 'ghp_xxx'"
    Write-Host "  · 远程已有内容：git pull --rebase origin $Branch"
    exit 1
}

Write-Host ""
Write-Host "搞定：$htmlUrl" -ForegroundColor Green
Write-Host "仓库页： $htmlUrl"
Write-Host "克隆：   git clone https://github.com/$fullName.git"
