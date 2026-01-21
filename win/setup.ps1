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

    # Check if Chrome is already installed
    $skipChrome = $false
    $chromePaths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    foreach ($chromePath in $chromePaths) {
        if (Test-Path $chromePath) {
            $skipChrome = $true
            Write-Host "Chrome is already installed, skipping..." -ForegroundColor Green
            break
        }
    }

    # Create modified winget JSON if we need to skip packages
    $finalWingetPath = $wingetJsonPath
    $packagesToSkip = @()
    if ($skipDocker) { $packagesToSkip += "*Docker*" }
    if ($skipChrome) { $packagesToSkip += "*Chrome*" }

    if ($packagesToSkip.Count -gt 0) {
        Write-Host ""
        Write-Host "Creating temporary package list..." -ForegroundColor Gray

        # Remove skipped packages from package list
        foreach ($source in $wingetContent.Sources) {
            $source.Packages = @($source.Packages | Where-Object {
                $pkg = $_.PackageIdentifier
                $skip = $false
                foreach ($pattern in $packagesToSkip) {
                    if ($pkg -like $pattern) {
                        $skip = $true
                        break
                    }
                }
                -not $skip
            })
        }

        # Save to temporary file
        $tempWingetPath = Join-Path $env:TEMP "setup.winget.temp.json"
        $wingetContent | ConvertTo-Json -Depth 10 | Set-Content $tempWingetPath -Encoding UTF8
        $finalWingetPath = $tempWingetPath

        if ($skipDocker) { Write-Host "   Docker will be skipped (needs reboot)" -ForegroundColor Yellow }
        if ($skipChrome) { Write-Host "   Chrome will be skipped (already installed)" -ForegroundColor Gray }
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
        if ($packagesToSkip.Count -gt 0 -and (Test-Path $tempWingetPath)) {
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
    & ([scriptblock]::Create((irm https://claude.ai/install.ps1))) latest
    Write-Host "Claude Code installed successfully" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Claude Code installation failed" -ForegroundColor Yellow
    Write-Host "   You can manually install it later with: & ([scriptblock]::Create((irm https://claude.ai/install.ps1))) latest" -ForegroundColor Gray
}

# 2.6. Install Codex CLI via npm
Write-Host ""
Write-Host "Installing Codex CLI (@openai/codex)..." -ForegroundColor Yellow
$npmCmd = $null

try {
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
} catch {}

# Fallback to default Node.js installation path if npm not yet in PATH
if (-not $npmCmd) {
    $defaultNpm = Join-Path $env:ProgramFiles "nodejs\npm.cmd"
    if (Test-Path $defaultNpm) {
        $npmCmd = Get-Item $defaultNpm
    }
}

if ($npmCmd) {
    try {
        & $npmCmd.Path install -g @openai/codex
        Write-Host "Codex CLI installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Codex CLI installation failed (npm error)" -ForegroundColor Yellow
        Write-Host "   You can manually install it later with: npm install -g @openai/codex" -ForegroundColor Gray
    }
} else {
    Write-Host "WARNING: npm not found; Codex CLI not installed" -ForegroundColor Yellow
    Write-Host "   Ensure Node.js/npm is installed and run: npm install -g @openai/codex" -ForegroundColor Gray
}

# 2.7. Configure Rust environment
Write-Host ""
Write-Host "Configuring Rust environment..." -ForegroundColor Yellow

# Add Cargo bin to PATH
$cargoBinPath = Join-Path $env:USERPROFILE ".cargo\bin"
if (Test-Path $cargoBinPath) {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$cargoBinPath*") {
        [Environment]::SetEnvironmentVariable(
            "Path",
            $currentPath + ";" + $cargoBinPath,
            "User"
        )
        Write-Host "Added Cargo bin to PATH: $cargoBinPath" -ForegroundColor Green
    } else {
        Write-Host "Cargo bin already in PATH" -ForegroundColor Gray
    }

    # Refresh PATH for current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # Set default toolchain to stable-msvc (Windows MSVC)
    $rustupCmd = Join-Path $cargoBinPath "rustup.exe"
    if (Test-Path $rustupCmd) {
        Write-Host "Setting default Rust toolchain to stable-msvc..." -ForegroundColor Gray
        try {
            & $rustupCmd default stable-msvc 2>&1 | Out-Null
            Write-Host "Rust toolchain configured (stable-msvc)" -ForegroundColor Green
        } catch {
            Write-Host "WARNING: Failed to set default toolchain" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "Cargo not found yet (will be available after rustup installation completes)" -ForegroundColor Gray
    Write-Host "   After installation, run: rustup default stable-msvc" -ForegroundColor Gray
}

# 2.8. Refresh environment and configure PATH
Write-Host ""
Write-Host "Refreshing environment variables..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

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

# User local bin path (used for UE Modding Tools and other tools)
$localBinPath = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $localBinPath)) {
    New-Item -ItemType Directory -Path $localBinPath -Force | Out-Null
    Write-Host "Created .local\bin directory" -ForegroundColor Gray
}
Add-ToPathIfNotExists $localBinPath

# Refresh PATH again after adding new paths
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 2.9. Install UE Modding Tools (FModel, Repak, UAssetGUI)
Write-Host ""
Write-Host "Installing UE Modding Tools..." -ForegroundColor Yellow

function Install-GitHubRelease {
    param(
        [string]$Repo,
        [string]$AssetPattern,
        [string]$ToolName,
        [string]$DestPath,
        [bool]$IsZip = $true
    )

    Write-Host "Installing $ToolName..." -ForegroundColor Gray

    try {
        # Get latest release info from GitHub API
        $releaseUrl = "https://api.github.com/repos/$Repo/releases/latest"
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ "User-Agent" = "PowerShell" }

        # Find matching asset
        $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1

        if (-not $asset) {
            Write-Host "WARNING: No matching asset found for $ToolName" -ForegroundColor Yellow
            return $false
        }

        $downloadUrl = $asset.browser_download_url
        $fileName = $asset.name
        $tempFile = Join-Path $env:TEMP $fileName

        Write-Host "   Downloading $fileName..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing

        # Ensure destination directory exists
        if (-not (Test-Path $DestPath)) {
            New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
        }

        if ($IsZip) {
            # Extract zip file
            $extractPath = Join-Path $DestPath $ToolName
            if (Test-Path $extractPath) {
                Remove-Item $extractPath -Recurse -Force
            }
            Expand-Archive -Path $tempFile -DestinationPath $extractPath -Force
            Write-Host "   Extracted to: $extractPath" -ForegroundColor Green
        } else {
            # Copy single executable
            $destFile = Join-Path $DestPath $fileName
            Copy-Item $tempFile $destFile -Force
            Write-Host "   Saved to: $destFile" -ForegroundColor Green
        }

        # Cleanup
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

        Write-Host "$ToolName installed successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "WARNING: Failed to install $ToolName - $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Set UE Tools destination path
$ueToolsPath = $localBinPath

# Install FModel (Windows only, .NET application)
$fmodelPath = Join-Path $ueToolsPath "FModel"
if (Test-Path (Join-Path $fmodelPath "FModel.exe")) {
    Write-Host "FModel is already installed" -ForegroundColor Green
} else {
    Install-GitHubRelease -Repo "4sval/FModel" -AssetPattern "FModel\.zip$" -ToolName "FModel" -DestPath $ueToolsPath -IsZip $true
}

# Install Repak (Rust CLI, cross-platform)
$repakExe = Join-Path $ueToolsPath "repak.exe"
if (Test-Path $repakExe) {
    Write-Host "Repak is already installed" -ForegroundColor Green
} else {
    try {
        Write-Host "Installing Repak..." -ForegroundColor Gray
        $releaseUrl = "https://api.github.com/repos/trumank/repak/releases/latest"
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ "User-Agent" = "PowerShell" }
        $asset = $release.assets | Where-Object { $_.name -match "x86_64-pc-windows-msvc\.zip$" } | Select-Object -First 1

        if ($asset) {
            $tempFile = Join-Path $env:TEMP $asset.name
            $tempExtract = Join-Path $env:TEMP "repak_extract"

            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempFile -UseBasicParsing

            if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
            Expand-Archive -Path $tempFile -DestinationPath $tempExtract -Force

            # Find and copy repak.exe
            $repakExeSource = Get-ChildItem -Path $tempExtract -Filter "repak.exe" -Recurse | Select-Object -First 1
            if ($repakExeSource) {
                if (-not (Test-Path $ueToolsPath)) {
                    New-Item -ItemType Directory -Path $ueToolsPath -Force | Out-Null
                }
                Copy-Item $repakExeSource.FullName $repakExe -Force
                Write-Host "Repak installed successfully" -ForegroundColor Green
            }

            # Cleanup
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "WARNING: No Windows build found for Repak" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "WARNING: Failed to install Repak - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Install UAssetGUI (Windows only, .NET application)
$uassetguiPath = Join-Path $ueToolsPath "UAssetGUI"
if (Test-Path (Join-Path $uassetguiPath "UAssetGUI.exe")) {
    Write-Host "UAssetGUI is already installed" -ForegroundColor Green
} else {
    Install-GitHubRelease -Repo "atenfyr/UAssetGUI" -AssetPattern "UAssetGUI\.zip$" -ToolName "UAssetGUI" -DestPath $ueToolsPath -IsZip $true
}

Write-Host ""
Write-Host "UE Modding Tools installation completed" -ForegroundColor Cyan
Write-Host "   Tools location: $ueToolsPath" -ForegroundColor Gray

# 3. Configure PowerShell Profile
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

# 4. Configure Git
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

# 5. WSL2 initialization (optional)
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

# 6. Refresh current session PATH
Write-Host ""
Write-Host "Refreshing current session environment variables..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 7. Complete
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
    $rustVersion = rustc --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Rust:   $rustVersion" -ForegroundColor Gray
    } else {
        Write-Host "   Rust:   Not found (run: rustup default stable-msvc)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Rust:   Not found (run: rustup default stable-msvc)" -ForegroundColor Yellow
}
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
