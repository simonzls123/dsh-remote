# install.ps1 — 安装 remote-dsh 技能（纯说明文档, 无脚本依赖）
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
if (-not $projectRoot) { $projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

$dshHome  = $env:DSH_HOME ?? (Join-Path $env:USERPROFILE '.dsh')
$skillDir = Join-Path $dshHome 'skills\dsh-remote'
New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
Copy-Item (Join-Path $projectRoot 'SKILL.md') (Join-Path $skillDir 'SKILL.md') -Force

# 清理旧版脚本(若有)
Get-ChildItem $skillDir -Filter 'remote-dsh.mjs' -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "已安装技能: $skillDir\SKILL.md" -ForegroundColor Green
Write-Host "纯说明技能, 无脚本依赖 — 新会话/重启 dsh web 后在技能列表可见。"