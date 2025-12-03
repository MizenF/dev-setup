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

# ===== Virtualization Detection Functions =====

function Test-VirtualizationEnabled {
    <#
    .SYNOPSIS
    Checks if hardware virtualization is enabled in BIOS/UEFI
    #>
    try {
        $hypervisorPresent = (Get-CimInstance -ClassName Win32_ComputerSystem).HypervisorPresent
        if ($hypervisorPresent) {
            return $true
        }

        # Additional check via systeminfo
        $systemInfo = systeminfo
        $virtualizationLine = $systemInfo | Select-String "Hyper-V Requirements"

        if ($virtualizationLine) {
            $nextLines = $systemInfo | Select-String "A hypervisor has been detected"
            if ($nextLines) {
                return $true
            }

            # Check for VM extensions
            $vmExtensions = $systemInfo | Select-String "VM Monitor Mode Extensions: Yes"
            if ($vmExtensions) {
                return $true
            }
        }

        return $false
    } catch {
        Write-Host "WARNING: Could not determine virtualization status" -ForegroundColor Yellow
        return $null
    }
}

function Test-VirtualMachinePlatformEnabled {
    <#
    .SYNOPSIS
    Checks if VirtualMachinePlatform feature is enabled
    #>
    try {
        $vmPlatform = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue

        if ($null -eq $vmPlatform) {
            return $false
        }

        return $vmPlatform.State -eq "Enabled"
    } catch {
        Write-Host "WARNING: Could not check VirtualMachinePlatform status" -ForegroundColor Yellow
        return $false
    }
}

function Test-HyperVEnabled {
    <#
    .SYNOPSIS
    Checks if Hyper-V feature is enabled
    #>
    try {
        $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue

        if ($null -eq $hyperv) {
            return $false
        }

        return $hyperv.State -eq "Enabled"
    } catch {
        return $false
    }
}

function Test-PendingReboot {
    <#
    .SYNOPSIS
    Checks if system has pending reboot for Windows features
    #>
    try {
        # Check Windows Update reboot flag
        $updateKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
        $cbsKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        $fileRenameKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"

        if ((Test-Path $updateKey) -or (Test-Path $cbsKey)) {
            return $true
        }

        # Check for pending file rename operations
        if (Test-Path $fileRenameKey) {
            $pendingFileRename = Get-ItemProperty -Path $fileRenameKey -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
            if ($null -ne $pendingFileRename) {
                return $true
            }
        }

        return $false
    } catch {
        return $false
    }
}

function Enable-RequiredVirtualizationFeatures {
    <#
    .SYNOPSIS
    Enables required virtualization features for Docker
    #>
    param(
        [ref]$RebootRequired
    )

    Write-Host ""
    Write-Host "Checking virtualization requirements for Docker..." -ForegroundColor Yellow

    $needsReboot = $false
    $featuresEnabled = $false

    # Check VirtualMachinePlatform
    $vmPlatformEnabled = Test-VirtualMachinePlatformEnabled
    if (-not $vmPlatformEnabled) {
        Write-Host "Enabling VirtualMachinePlatform feature..." -ForegroundColor Gray
        try {
            dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
            $featuresEnabled = $true
            $needsReboot = $true
            Write-Host "VirtualMachinePlatform enabled" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: Failed to enable VirtualMachinePlatform" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "VirtualMachinePlatform is already enabled" -ForegroundColor Green
    }

    # Check Hyper-V (optional but recommended)
    $hypervEnabled = Test-HyperVEnabled
    if (-not $hypervEnabled) {
        Write-Host "Note: Hyper-V is not enabled (optional for Docker Desktop)" -ForegroundColor Gray
    } else {
        Write-Host "Hyper-V is enabled" -ForegroundColor Green
    }

    if ($needsReboot) {
        $RebootRequired.Value = $true
    }

    return (-not $needsReboot)
}

# ===== End Virtualization Detection Functions =====

# Initialize reboot tracking variable
$script:RebootRequired = $false

# Early virtualization check
Write-Host "Checking system virtualization status..." -ForegroundColor Yellow
$virtEnabled = Test-VirtualizationEnabled

if ($null -eq $virtEnabled) {
    Write-Host "Unable to determine virtualization status, continuing with caution..." -ForegroundColor Yellow
} elseif ($virtEnabled) {
    Write-Host "Hardware virtualization: Enabled" -ForegroundColor Green
} else {
    Write-Host "WARNING: Hardware virtualization appears to be DISABLED in BIOS/UEFI" -ForegroundColor Red
    Write-Host "   Docker Desktop requires hardware virtualization to be enabled" -ForegroundColor Yellow
    Write-Host "   Please enable VT-x (Intel) or AMD-V (AMD) in your BIOS/UEFI settings" -ForegroundColor Yellow
}

# Check if system already has pending reboot
$pendingReboot = Test-PendingReboot
if ($pendingReboot) {
    Write-Host ""
    Write-Host "WARNING: System has a pending reboot from previous updates" -ForegroundColor Yellow
    Write-Host "   It is recommended to restart before continuing" -ForegroundColor Yellow
    $script:RebootRequired = $true
}

Write-Host ""

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

# 1.5. Upgrade PowerShell to latest version
Write-Host ""
Write-Host "Checking PowerShell version..." -ForegroundColor Yellow
$currentPSVersion = $PSVersionTable.PSVersion
Write-Host "Current PowerShell version: $currentPSVersion" -ForegroundColor Gray

if ($currentPSVersion.Major -lt 7) {
    Write-Host "Upgrading PowerShell to version 7..." -ForegroundColor Yellow
    try {
        winget install --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements
        Write-Host "PowerShell upgraded successfully" -ForegroundColor Green
        Write-Host "NOTE: Please restart your terminal to use PowerShell 7" -ForegroundColor Cyan
    } catch {
        Write-Host "WARNING: PowerShell upgrade failed, continuing with current version" -ForegroundColor Yellow
    }
} else {
    Write-Host "PowerShell 7+ is already installed" -ForegroundColor Green
}

# 2. Import and install winget packages
Write-Host ""
Write-Host "Installing packages (from setup.winget.json)..." -ForegroundColor Yellow

$wingetJsonPath = Join-Path $ScriptDir "setup.winget.json"
if (Test-Path $wingetJsonPath) {
    # Check if Docker is in the package list
    $wingetContent = Get-Content $wingetJsonPath -Raw | ConvertFrom-Json
    $hasDocker = $false
    foreach ($source in $wingetContent.Sources) {
        foreach ($package in $source.Packages) {
            if ($package.PackageIdentifier -like "*Docker*") {
                $hasDocker = $true
                break
            }
        }
        if ($hasDocker) { break }
    }

    # If Docker is present, check virtualization requirements
    $skipDocker = $false
    if ($hasDocker) {
        Write-Host ""
        Write-Host "Docker Desktop detected in package list" -ForegroundColor Cyan

        # Enable virtualization features if needed
        $canInstallDocker = Enable-RequiredVirtualizationFeatures -RebootRequired ([ref]$script:RebootRequired)

        if (-not $canInstallDocker -or $script:RebootRequired) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Red
            Write-Host "DOCKER INSTALLATION BLOCKED" -ForegroundColor Red
            Write-Host "========================================" -ForegroundColor Red
            Write-Host "Reason: System requires restart for virtualization features to take effect" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "What was done:" -ForegroundColor Cyan
            Write-Host "   - VirtualMachinePlatform feature has been enabled" -ForegroundColor Gray
            Write-Host "   - A system restart is required for changes to take effect" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "   1. Restart your computer" -ForegroundColor Yellow
            Write-Host "   2. Run this setup script again to install Docker Desktop" -ForegroundColor Yellow
            Write-Host ""
            $skipDocker = $true
        } else {
            Write-Host "All virtualization requirements are met" -ForegroundColor Green
        }
    }

    # Create modified winget JSON if we need to skip Docker
    $finalWingetPath = $wingetJsonPath
    if ($skipDocker) {
        Write-Host ""
        Write-Host "Creating temporary package list without Docker..." -ForegroundColor Gray

        # Remove Docker from package list
        foreach ($source in $wingetContent.Sources) {
            $source.Packages = @($source.Packages | Where-Object { $_.PackageIdentifier -notlike "*Docker*" })
        }

        # Save to temporary file
        $tempWingetPath = Join-Path $env:TEMP "setup.winget.temp.json"
        $wingetContent | ConvertTo-Json -Depth 10 | Set-Content $tempWingetPath -Encoding UTF8
        $finalWingetPath = $tempWingetPath

        Write-Host "Docker will be skipped in this installation" -ForegroundColor Yellow
    }

    try {
        # Use winget import command
        Write-Host ""
        Write-Host "Importing package manifest..." -ForegroundColor Gray
        winget import -i $finalWingetPath --accept-package-agreements --accept-source-agreements --ignore-versions
        Write-Host "Package installation completed" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Some packages may have failed to install, please check logs" -ForegroundColor Yellow
    } finally {
        # Clean up temporary file if created
        if ($skipDocker -and (Test-Path $tempWingetPath)) {
            Remove-Item $tempWingetPath -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "WARNING: setup.winget.json not found, skipping package installation" -ForegroundColor Yellow
}

# 2.5. Install Claude Code
Write-Host ""
Write-Host "Installing Claude Code..." -ForegroundColor Yellow
try {
    Invoke-Expression (Invoke-RestMethod -Uri "https://claude.ai/install.ps1")
    Write-Host "Claude Code installed successfully" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Claude Code installation failed" -ForegroundColor Yellow
    Write-Host "   You can manually install it later with: irm https://claude.ai/install.ps1 | iex" -ForegroundColor Gray
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

# User local bin path
$localBinPath = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $localBinPath)) {
    New-Item -ItemType Directory -Path $localBinPath -Force | Out-Null
    Write-Host "Created .local\bin directory" -ForegroundColor Gray
}
Add-ToPathIfNotExists $localBinPath

# 5. Configure PowerShell Profile
Write-Host ""
Write-Host "Configuring PowerShell Profile..." -ForegroundColor Yellow

$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path -Parent $profilePath

# Create Profile directory if it doesn't exist
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Copy win_profile.ps1 with UTF-8 BOM encoding
$sourceProfile = Join-Path $ScriptDir "win_profile.ps1"
if (Test-Path $sourceProfile) {
    # Backup existing Profile if it exists
    if (Test-Path $profilePath) {
        $backupPath = "$profilePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $profilePath $backupPath
        Write-Host "Backed up existing Profile to: $backupPath" -ForegroundColor Gray
    }
    
    # Read source with UTF-8 and write with UTF-8 BOM to ensure proper encoding
    $content = Get-Content $sourceProfile -Raw -Encoding UTF8
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($profilePath, $content, $utf8Bom)
    Write-Host "PowerShell Profile configured (UTF-8 BOM)" -ForegroundColor Green
    
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

        $script:RebootRequired = $true
        Write-Host "WSL features enabled (restart required)" -ForegroundColor Yellow
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

# Display reboot status if required
if ($script:RebootRequired) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "SYSTEM RESTART REQUIRED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Why restart is needed:" -ForegroundColor Cyan
    Write-Host "   - VirtualMachinePlatform feature was enabled" -ForegroundColor Gray
    Write-Host "   - Windows features require a restart to take effect" -ForegroundColor Gray
    Write-Host "   - Docker Desktop installation was skipped" -ForegroundColor Gray
    Write-Host ""
    Write-Host "After restarting:" -ForegroundColor Cyan
    Write-Host "   1. System virtualization features will be active" -ForegroundColor Yellow
    Write-Host "   2. Run this setup script again to install Docker Desktop" -ForegroundColor Yellow
    Write-Host "   3. Docker Desktop will then install successfully" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To restart now, run: Restart-Computer" -ForegroundColor Red
    Write-Host ""
} else {
    Write-Host "Installation completed!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
if ($script:RebootRequired) {
    Write-Host "   1. RESTART YOUR COMPUTER (Required!)" -ForegroundColor Red
    Write-Host "   2. Run this setup script again to complete Docker installation" -ForegroundColor Yellow
    Write-Host "   3. Configure Git user info (if not already configured)" -ForegroundColor Gray
} else {
    Write-Host "   1. Reopen PowerShell (or run: . `$PROFILE)" -ForegroundColor Gray
    Write-Host "   2. Configure Git user info (if not already configured)" -ForegroundColor Gray
    Write-Host "   3. If using WSL, restart computer and install Linux distribution" -ForegroundColor Gray
}
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
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Docker: $dockerVersion" -ForegroundColor Gray
    } else {
        if ($script:RebootRequired) {
            Write-Host "   Docker: Not installed (will be installed after restart)" -ForegroundColor Yellow
        } else {
            Write-Host "   Docker: Not found" -ForegroundColor Gray
        }
    }
} catch {
    if ($script:RebootRequired) {
        Write-Host "   Docker: Not installed (will be installed after restart)" -ForegroundColor Yellow
    }
}
Write-Host ""
