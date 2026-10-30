<#
.SYNOPSIS
    用 Rojo 把工程打包成 .rbxlx（可以直接在 Studio 里打开）

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build.ps1
#>

[CmdletBinding()]
param(
    [string]$Out = "build/DoorsTextureChaos.rbxlx"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command rojo -ErrorAction SilentlyContinue)) {
    Write-Host "没找到 rojo。" -ForegroundColor Yellow
    Write-Host "装一个："
    Write-Host "  cargo install rojo"
    Write-Host "  或从 https://github.com/rojo-rbx/rojo/releases 下 rojo-x.x.x-windows.zip，解压后加进 PATH"
    exit 1
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $root $Out)) | Out-Null

Write-Host "==> rojo build $Out" -ForegroundColor Cyan
rojo build default.project.json -o $Out

if ($LASTEXITCODE -ne 0) {
    Write-Host "打包失败" -ForegroundColor Red
    exit 1
}

$full = Join-Path $root $Out
Write-Host "OK -> $full" -ForegroundColor Green
Write-Host "在 Studio 里 File -> Open from File 打开它；或者 rojo serve 连实时同步。"
