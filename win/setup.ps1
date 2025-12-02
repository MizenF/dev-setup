# Windows Development Environment Setup Script
# Must run as Administrator

#Requires -RunAsAdministrator

param(
    [bool]$enableWSL = $false  # Enable WSL2 initialization
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Windows development environment setup..." -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

# 1. Check and install winget
Write-Host "Checking winget..." -ForegroundColor Yellow
try {
    $wingetVersion = winget --version
    Write-Host "winget installed: $wingetVersion" -ForegroundColor Green
} catch {
    Write-Host "WARNING: winget not found, please install App Installer" -ForegroundColor Red
    Write-Host "   Install from Microsoft Store: https://aka.ms/getwinget" -ForegroundColor Yellow
    exit 1
}

# 2. Import and install winget packages
Write-Host ""
Write-Host "Installing packages (from setup.winget.json)..." -ForegroundColor Yellow

$wingetJsonPath = Join-Path $ScriptDir "setup.winget.json"
if (Test-Path $wingetJsonPath) {
    try {
        # Use winget import command
        Write-Host "Importing package manifest..." -ForegroundColor Gray
        winget import -i $wingetJsonPath --accept-package-agreements --accept-source-agreements --ignore-versions
        Write-Host "Package installation completed" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Some packages may have failed to install, please check logs" -ForegroundColor Yellow
    }
} else {
    Write-Host "WARNING: setup.winget.json not found, skipping package installation" -ForegroundColor Yellow
}

# 3. Refresh environment variables (no restart needed)
Write-Host ""
Write-Host "Refreshing environment variables..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 4. Detect and add common paths to PATH
Write-Host ""
Write-Host "Configuring PATH..." -ForegroundColor Yellow

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
            Write-Host "Added to PATH: $NewPath" -ForegroundColor Green
        } else {
            Write-Host "PATH already contains: $NewPath" -ForegroundColor Gray
        }
    }
}

# Python paths
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

# Node.js path
$nodePath = "$env:ProgramFiles\nodejs"
Add-ToPathIfNotExists $nodePath

# Git path
$gitPath = "$env:ProgramFiles\Git\cmd"
Add-ToPathIfNotExists $gitPath

# 5. Configure PowerShell Profile
Write-Host ""
Write-Host "Configuring PowerShell Profile..." -ForegroundColor Yellow

$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path -Parent $profilePath

# Create Profile directory if it doesn't exist
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Copy win_profile.ps1
$sourceProfile = Join-Path $ScriptDir "win_profile.ps1"
if (Test-Path $sourceProfile) {
    # Backup existing Profile if it exists
    if (Test-Path $profilePath) {
        $backupPath = "$profilePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $profilePath $backupPath
        Write-Host "Backed up existing Profile to: $backupPath" -ForegroundColor Gray
    }
    
    Copy-Item $sourceProfile $profilePath -Force
    Write-Host "PowerShell Profile configured" -ForegroundColor Green
    
    # Add dotfiles reference
    $aliasesPath = Join-Path $RepoRoot "dotfiles\aliases.sh"
    $aliasesLine = "# Load dev-setup aliases (converted for PowerShell)"
    
    if (-not (Select-String -Path $profilePath -Pattern "dev-setup aliases" -Quiet)) {
        Add-Content -Path $profilePath -Value "`n$aliasesLine"
        Write-Host "Added aliases reference to Profile" -ForegroundColor Green
    }
} else {
    Write-Host "WARNING: win_profile.ps1 not found" -ForegroundColor Yellow
}

# 6. Configure Git
Write-Host ""
Write-Host "Configuring Git..." -ForegroundColor Yellow

$gitconfigPath = Join-Path $env:USERPROFILE ".gitconfig"
$sourceGitconfig = Join-Path $RepoRoot "dotfiles\gitconfig"

if (-not (Test-Path $gitconfigPath)) {
    if (Test-Path $sourceGitconfig) {
        Copy-Item $sourceGitconfig $gitconfigPath
        Write-Host "Copied gitconfig" -ForegroundColor Green
        Write-Host "WARNING: Please run the following commands to set Git user info:" -ForegroundColor Yellow
        Write-Host "   git config --global user.name `"Your Name`"" -ForegroundColor Gray
        Write-Host "   git config --global user.email `"your.email@example.com`"" -ForegroundColor Gray
    } else {
        Write-Host "WARNING: dotfiles\gitconfig not found" -ForegroundColor Yellow
    }
} else {
    Write-Host ".gitconfig already exists" -ForegroundColor Gray
}

# 7. WSL2 initialization (optional)
if ($enableWSL) {
    Write-Host ""
    Write-Host "Initializing WSL2..." -ForegroundColor Yellow
    
    # Check if WSL is enabled
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    
    if ($wslFeature.State -ne "Enabled") {
        Write-Host "Enabling WSL feature..." -ForegroundColor Gray
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
        
        Write-Host "WARNING: Please restart your computer and then run WSL initialization script" -ForegroundColor Yellow
    } else {
        Write-Host "WSL is enabled" -ForegroundColor Green
        Write-Host "   You can run WSL setup script: wsl/setup.sh" -ForegroundColor Gray
    }
}

# 8. Refresh current session PATH
Write-Host ""
Write-Host "Refreshing current session environment variables..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 9. Complete
Write-Host ""
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "   1. Reopen PowerShell (or run: . `$PROFILE)" -ForegroundColor Gray
Write-Host "   2. Configure Git user info (if not already configured)" -ForegroundColor Gray
Write-Host "   3. If using WSL, restart computer and install Linux distribution" -ForegroundColor Gray
Write-Host ""
Write-Host "Checking installed tool versions:" -ForegroundColor Cyan
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
