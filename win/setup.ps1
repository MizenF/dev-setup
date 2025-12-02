# Windows 开发环境自动安装脚本
# 必须以管理员身份运行 PowerShell

#Requires -RunAsAdministrator

param(
    [bool]$enableWSL = $false  # 是否启用 WSL2 初始化
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 开始配置 Windows 开发环境..." -ForegroundColor Cyan
Write-Host ""

# 获取脚本所在目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

# 1. 检查并安装 winget
Write-Host "📦 检查 winget..." -ForegroundColor Yellow
try {
    $wingetVersion = winget --version
    Write-Host "✅ winget 已安装: $wingetVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️  winget 未找到，请先安装 App Installer" -ForegroundColor Red
    Write-Host "   从 Microsoft Store 安装: https://aka.ms/getwinget" -ForegroundColor Yellow
    exit 1
}

# 2. 导入并安装 winget 软件包
Write-Host ""
Write-Host "📦 安装软件包（根据 setup.winget.json）..." -ForegroundColor Yellow

$wingetJsonPath = Join-Path $ScriptDir "setup.winget.json"
if (Test-Path $wingetJsonPath) {
    try {
        # 使用 winget import 命令
        Write-Host "正在导入软件包清单..." -ForegroundColor Gray
        winget import -i $wingetJsonPath --accept-package-agreements --accept-source-agreements --ignore-versions
        Write-Host "✅ 软件包安装完成" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  部分软件包可能安装失败，请检查日志" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  未找到 setup.winget.json，跳过软件包安装" -ForegroundColor Yellow
}

# 3. 刷新环境变量（不需要重启）
Write-Host ""
Write-Host "🔄 刷新环境变量..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 4. 检测并添加常用路径到 PATH
Write-Host ""
Write-Host "⚙️  配置 PATH..." -ForegroundColor Yellow

function Add-ToPathIfNotExists {
    param([string]$NewPath)
    
    if (Test-Path $NewPath) {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$NewPath*") {
            [Environment]::SetEnvironmentVariable(
                "Path",
                $currentPath + ";" + $NewPath,
                "User"
            )
            Write-Host "✅ 已添加到 PATH: $NewPath" -ForegroundColor Green
        } else {
            Write-Host "✅ PATH 已包含: $NewPath" -ForegroundColor Gray
        }
    }
}

# Python 路径
$pythonPaths = @(
    "$env:LOCALAPPDATA\Programs\Python\Python*",
    "$env:LOCALAPPDATA\Programs\Python\Python*\Scripts"
)

foreach ($pattern in $pythonPaths) {
    $paths = Get-Item $pattern -ErrorAction SilentlyContinue
    foreach ($path in $paths) {
        Add-ToPathIfNotExists $path.FullName
    }
}

# Node.js 路径
$nodePath = "$env:ProgramFiles\nodejs"
Add-ToPathIfNotExists $nodePath

# Git 路径
$gitPath = "$env:ProgramFiles\Git\cmd"
Add-ToPathIfNotExists $gitPath

# 5. 配置 PowerShell Profile
Write-Host ""
Write-Host "⚙️  配置 PowerShell Profile..." -ForegroundColor Yellow

$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path -Parent $profilePath

# 创建 Profile 目录（如果不存在）
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# 复制 win_profile.ps1
$sourceProfile = Join-Path $ScriptDir "win_profile.ps1"
if (Test-Path $sourceProfile) {
    # 备份现有 Profile（如果存在）
    if (Test-Path $profilePath) {
        $backupPath = "$profilePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $profilePath $backupPath
        Write-Host "✅ 已备份现有 Profile 到: $backupPath" -ForegroundColor Gray
    }
    
    Copy-Item $sourceProfile $profilePath -Force
    Write-Host "✅ 已配置 PowerShell Profile" -ForegroundColor Green
    
    # 添加 dotfiles 引用
    $aliasesPath = Join-Path $RepoRoot "dotfiles\aliases.sh"
    $aliasesLine = "# Load dev-setup aliases (converted for PowerShell)"
    
    if (-not (Select-String -Path $profilePath -Pattern "dev-setup aliases" -Quiet)) {
        Add-Content -Path $profilePath -Value "`n$aliasesLine"
        Write-Host "✅ 已添加 aliases 引用到 Profile" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️  未找到 win_profile.ps1" -ForegroundColor Yellow
}

# 6. 配置 Git
Write-Host ""
Write-Host "⚙️  配置 Git..." -ForegroundColor Yellow

$gitconfigPath = Join-Path $env:USERPROFILE ".gitconfig"
$sourceGitconfig = Join-Path $RepoRoot "dotfiles\gitconfig"

if (-not (Test-Path $gitconfigPath)) {
    if (Test-Path $sourceGitconfig) {
        Copy-Item $sourceGitconfig $gitconfigPath
        Write-Host "✅ 已复制 gitconfig" -ForegroundColor Green
        Write-Host "⚠️  请运行以下命令设置 Git 用户信息：" -ForegroundColor Yellow
        Write-Host "   git config --global user.name `"Your Name`"" -ForegroundColor Gray
        Write-Host "   git config --global user.email `"your.email@example.com`"" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  未找到 dotfiles\gitconfig" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ .gitconfig 已存在" -ForegroundColor Gray
}

# 7. WSL2 初始化（可选）
if ($enableWSL) {
    Write-Host ""
    Write-Host "🐧 初始化 WSL2..." -ForegroundColor Yellow
    
    # 检查 WSL 是否已启用
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    
    if ($wslFeature.State -ne "Enabled") {
        Write-Host "正在启用 WSL 功能..." -ForegroundColor Gray
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
        
        Write-Host "⚠️  请重启计算机后再运行 WSL 初始化脚本" -ForegroundColor Yellow
    } else {
        Write-Host "✅ WSL 已启用" -ForegroundColor Green
        Write-Host "   可运行 WSL 设置脚本: wsl/setup.sh" -ForegroundColor Gray
    }
}

# 8. 刷新当前会话的 PATH
Write-Host ""
Write-Host "🔄 刷新当前会话环境变量..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 9. 完成
Write-Host ""
Write-Host "✨ 安装完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📌 下一步：" -ForegroundColor Cyan
Write-Host "   1. 重新打开 PowerShell（或运行: . `$PROFILE）" -ForegroundColor Gray
Write-Host "   2. 配置 Git 用户信息（如果尚未配置）" -ForegroundColor Gray
Write-Host "   3. 如需使用 WSL，请重启电脑后安装 Linux 发行版" -ForegroundColor Gray
Write-Host ""
Write-Host "📚 查看已安装工具版本：" -ForegroundColor Cyan
try {
    Write-Host "   Python: $(python --version 2>&1)" -ForegroundColor Gray
} catch {}
try {
    Write-Host "   Node:   $(node --version 2>&1)" -ForegroundColor Gray
} catch {}
try {
    Write-Host "   Git:    $(git --version 2>&1)" -ForegroundColor Gray
} catch {}
Write-Host ""
