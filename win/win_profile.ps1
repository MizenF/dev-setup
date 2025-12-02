# Windows PowerShell Profile
# This file is loaded automatically when PowerShell starts

# ============================================
# PSReadLine 配置（命令行体验增强）
# ============================================

if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    
    # 启用预测性 IntelliSense
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    
    # 历史搜索
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    
    # 自动补全
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    
    # 颜色配置
    Set-PSReadLineOption -Colors @{
        Command = 'Yellow'
        Parameter = 'Green'
        String = 'DarkCyan'
    }
}

# ============================================
# Oh-My-Posh 主题（如果已安装）
# ============================================

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    # 使用默认主题，可自定义
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression
}

# ============================================
# 常用别名（PowerShell 版本）
# ============================================

# 基础命令别名
function ll { Get-ChildItem -Force }
function la { Get-ChildItem -Force }

# Git 别名
function gs { git status }
function gc { git commit }
function gp { git push }
function gb { git branch }
function gco { git checkout }
function gl { git log --oneline --graph --all }

# Python 别名
function py { python $args }
function py3 { python $args }

# 快速导航
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

# Docker Compose 别名
function dcu { docker compose up -d }
function dcd { docker compose down }
function dcl { docker compose logs -f }

# 实用函数
function mkcd {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

function touch {
    param([string]$File)
    if (Test-Path $File) {
        (Get-Item $File).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $File | Out-Null
    }
}

function which {
    param([string]$Command)
    Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}

# 清屏增强
function cls-full {
    Clear-Host
    # 清除滚动缓冲区
    [System.Console]::Clear()
}
Set-Alias -Name clear -Value cls-full -Option AllScope -Force

# ============================================
# PATH 扩展（防重复）
# ============================================

function Add-ToPath {
    param([string]$Path)
    
    if (Test-Path $Path) {
        $currentPath = $env:Path
        if ($currentPath -notlike "*$Path*") {
            $env:Path = "$Path;$currentPath"
        }
    }
}

# Python Scripts 路径
$pythonScripts = "$env:LOCALAPPDATA\Programs\Python\Python*\Scripts"
Get-Item $pythonScripts -ErrorAction SilentlyContinue | ForEach-Object {
    Add-ToPath $_.FullName
}

# Node.js global modules
$nodeModules = "$env:APPDATA\npm"
Add-ToPath $nodeModules

# ============================================
# 自动加载 dotfiles aliases（如果存在）
# ============================================

$repoRoot = Split-Path -Parent $PSScriptRoot
$aliasesPath = Join-Path $repoRoot "dotfiles\aliases.sh"

if (Test-Path $aliasesPath) {
    # 读取 aliases.sh 并转换为 PowerShell 格式
    # 注意：这只是基础转换，复杂的 bash 函数需要手动转换
    Get-Content $aliasesPath | ForEach-Object {
        $line = $_.Trim()
        
        # 跳过注释和空行
        if ($line -match '^#' -or $line -eq '') {
            return
        }
        
        # 转换简单的 alias
        if ($line -match '^alias\s+(\w+)=(.+)$') {
            $aliasName = $matches[1]
            $aliasValue = $matches[2].Trim('"').Trim("'")
            
            # 某些别名在 PowerShell 中已定义，跳过
            $skipAliases = @('ll', 'ls', 'gs', 'gc', 'gp', 'gb', 'py')
            if ($skipAliases -contains $aliasName) {
                return
            }
            
            # 尝试创建别名
            try {
                Set-Alias -Name $aliasName -Value $aliasValue -Scope Global -ErrorAction SilentlyContinue
            } catch {
                # 忽略错误
            }
        }
    }
}

# ============================================
# 环境变量
# ============================================

# UTF-8 编码
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================
# 欢迎信息
# ============================================

function Show-Welcome {
    Write-Host ""
    Write-Host "  PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    Write-Host "  开发环境: dev-setup" -ForegroundColor Green
    Write-Host ""
    
    # 显示常用命令
    Write-Host "  常用别名: ll, gs, gc, gp, dcu, dcd" -ForegroundColor Gray
    Write-Host "  帮助: Get-Help <command>" -ForegroundColor Gray
    Write-Host ""
}

# 仅在交互式会话中显示欢迎信息
if ($Host.UI.RawUI.WindowSize.Width -gt 0) {
    Show-Welcome
}
