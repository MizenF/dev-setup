# Optional Gaming Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all gaming/UE modding tools out of base installation into an optional post-install prompt.

**Architecture:** Wrap gaming-related code in functions (`Install-GamingTools` / `install_gaming_tools`), remove gaming packages from winget manifest, and add a Y/N prompt after base install completes.

**Tech Stack:** PowerShell, Bash, JSON (winget manifest)

---

### Task 1: Remove gaming packages from winget manifest

**Files:**
- Modify: `win/setup.winget.json`

- [ ] **Step 1: Remove BuildTools and Rustup entries**

Edit `win/setup.winget.json` — remove these two package objects:

```json
        {
          "PackageIdentifier": "Microsoft.VisualStudio.2022.BuildTools"
        },
```

```json
        {
          "PackageIdentifier": "Rustlang.Rustup"
        },
```

The file should go from 17 packages to 15.

- [ ] **Step 2: Verify JSON is valid**

Run:
```bash
python3 -c "import json; json.load(open('win/setup.winget.json'))" && echo "VALID"
```
Expected: `VALID`

- [ ] **Step 3: Commit**

```bash
git add win/setup.winget.json
git commit -m "Remove gaming packages (BuildTools, Rustup) from base winget manifest"
```

---

### Task 2: Refactor win/setup.ps1 — extract gaming code into function and add prompt

**Files:**
- Modify: `win/setup.ps1`

- [ ] **Step 1: Update .local/bin PATH comment**

At line 394, change the comment from:

```powershell
# User local bin path (used for UE Modding Tools and other tools)
```

to:

```powershell
# User local bin path
```

- [ ] **Step 2: Move Install-GitHubRelease function before the gaming section**

The `Install-GitHubRelease` function (currently lines 585-645 inside the UE Modding Tools section) is a generic utility. It needs to stay accessible. Since it's only used by gaming tools, it will move into the new `Install-GamingTools` function in the next step — no separate extraction needed.

- [ ] **Step 3: Replace sections §2.4.2, §2.7, §2.8 with Install-GamingTools function**

Remove these three sections from the main flow:
- §2.4.2 "Install Visual Studio 2022 Community with specific workloads" (lines 410-449)
- §2.7 "Configure Rust environment" (lines 544-579)
- §2.8 "Install UE Modding Tools" (lines 581-709)

Replace them all with a single function definition placed right after §2.6 (Codex CLI, ends around line 542). Insert the following:

```powershell
# ===== Optional: Gaming / UE Modding Tools =====
function Install-GamingTools {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  扩展安装: UE 游戏开发 / Modding 工具" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # 1. Install Visual Studio Build Tools and Rust via winget
    Write-Host "Installing Visual Studio Build Tools..." -ForegroundColor Yellow
    try {
        winget install --id Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements
        Write-Host "Visual Studio Build Tools installed" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Visual Studio Build Tools installation failed" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Installing Rust (rustup)..." -ForegroundColor Yellow
    try {
        winget install --id Rustlang.Rustup --accept-package-agreements --accept-source-agreements
        Write-Host "Rust installed" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Rust installation failed" -ForegroundColor Yellow
    }

    # Refresh PATH after winget installs
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # 2. Install Visual Studio 2022 Community with C++ workloads
    Write-Host ""
    Write-Host "Installing Visual Studio 2022 Community with C++ workloads..." -ForegroundColor Yellow

    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vsInstalled = $false

    if (Test-Path $vsWhere) {
        $vsInfo = & $vsWhere -products Microsoft.VisualStudio.Product.Community -version "[17.0,18.0)" -format json 2>$null | ConvertFrom-Json
        if ($vsInfo -and $vsInfo.Count -gt 0) {
            $vsInstalled = $true
            Write-Host "Visual Studio 2022 Community is already installed" -ForegroundColor Green
            Write-Host "   To modify workloads, open Visual Studio Installer manually" -ForegroundColor Gray
        }
    }

    if (-not $vsInstalled) {
        try {
            $vsWorkloads = @(
                "--add Microsoft.VisualStudio.Workload.NativeDesktop",
                "--add Microsoft.VisualStudio.Workload.NativeGame",
                "--add Microsoft.VisualStudio.Component.Windows10SDK.19041",
                "--includeRecommended"
            ) -join " "

            Write-Host "   Workloads: C++ Desktop, Game Development, Windows 10 SDK (19041)" -ForegroundColor Gray
            Write-Host "   This may take a while..." -ForegroundColor Gray

            winget install --id Microsoft.VisualStudio.2022.Community --accept-package-agreements --accept-source-agreements --override "--passive --wait $vsWorkloads"

            Write-Host "Visual Studio 2022 Community installed successfully" -ForegroundColor Green
        } catch {
            Write-Host "WARNING: Visual Studio installation failed" -ForegroundColor Yellow
            Write-Host "   You can manually install it from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Gray
        }
    }

    # 3. Configure Rust environment
    Write-Host ""
    Write-Host "Configuring Rust environment..." -ForegroundColor Yellow

    $rustupPath = $null
    $rustupCmd = Get-Command rustup -ErrorAction SilentlyContinue
    if ($rustupCmd) {
        $rustupPath = $rustupCmd.Source
    }

    if (-not $rustupPath) {
        $defaultRustup = Join-Path $env:USERPROFILE ".cargo\bin\rustup.exe"
        if (Test-Path $defaultRustup) {
            $rustupPath = $defaultRustup
        }
    }

    if ($rustupPath) {
        Write-Host "Found rustup, initializing Rust toolchain..." -ForegroundColor Gray
        try {
            & $rustupPath default stable-msvc 2>&1 | Out-Null
            Write-Host "Rust toolchain configured (stable-msvc)" -ForegroundColor Green
        } catch {
            Write-Host "WARNING: Failed to set default toolchain" -ForegroundColor Yellow
        }
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        Write-Host "WARNING: rustup not found" -ForegroundColor Yellow
        Write-Host "   Rust may still be installing. Run this script again to configure Rust." -ForegroundColor Gray
    }

    # 4. Install UE Modding Tools (FModel, Repak, UAssetGUI)
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
            $releaseUrl = "https://api.github.com/repos/$Repo/releases/latest"
            $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ "User-Agent" = "PowerShell" }

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

            if (-not (Test-Path $DestPath)) {
                New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
            }

            if ($IsZip) {
                $extractPath = Join-Path $DestPath $ToolName
                if (Test-Path $extractPath) {
                    Remove-Item $extractPath -Recurse -Force
                }
                Expand-Archive -Path $tempFile -DestinationPath $extractPath -Force
                Write-Host "   Extracted to: $extractPath" -ForegroundColor Green
            } else {
                $destFile = Join-Path $DestPath $fileName
                Copy-Item $tempFile $destFile -Force
                Write-Host "   Saved to: $destFile" -ForegroundColor Green
            }

            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

            Write-Host "$ToolName installed successfully" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "WARNING: Failed to install $ToolName - $($_.Exception.Message)" -ForegroundColor Yellow
            return $false
        }
    }

    $localBinPath = Join-Path $env:USERPROFILE ".local\bin"
    $ueToolsPath = $localBinPath

    # FModel
    $fmodelPath = Join-Path $ueToolsPath "FModel"
    if (Test-Path (Join-Path $fmodelPath "FModel.exe")) {
        Write-Host "FModel is already installed" -ForegroundColor Green
    } else {
        Install-GitHubRelease -Repo "4sval/FModel" -AssetPattern "FModel\.zip$" -ToolName "FModel" -DestPath $ueToolsPath -IsZip $true
    }

    # Repak
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

                $repakExeSource = Get-ChildItem -Path $tempExtract -Filter "repak.exe" -Recurse | Select-Object -First 1
                if ($repakExeSource) {
                    if (-not (Test-Path $ueToolsPath)) {
                        New-Item -ItemType Directory -Path $ueToolsPath -Force | Out-Null
                    }
                    Copy-Item $repakExeSource.FullName $repakExe -Force
                    Write-Host "Repak installed successfully" -ForegroundColor Green
                }

                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Write-Host "WARNING: No Windows build found for Repak" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "WARNING: Failed to install Repak - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # UAssetGUI
    $uassetguiPath = Join-Path $ueToolsPath "UAssetGUI"
    if (Test-Path (Join-Path $uassetguiPath "UAssetGUI.exe")) {
        Write-Host "UAssetGUI is already installed" -ForegroundColor Green
    } else {
        Install-GitHubRelease -Repo "atenfyr/UAssetGUI" -AssetPattern "UAssetGUI\.zip$" -ToolName "UAssetGUI" -DestPath $ueToolsPath -IsZip $true
    }

    Write-Host ""
    Write-Host "UE Modding Tools installation completed" -ForegroundColor Cyan
    Write-Host "   Tools location: $ueToolsPath" -ForegroundColor Gray
}
```

- [ ] **Step 4: Add the prompt before the "Complete" section**

Insert the following right before `# 3. Configure PowerShell Profile` (currently line 760):

```powershell
# ===== Optional Extended Installation =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  基础安装已完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "可选扩展: UE 游戏开发 / Modding 工具包" -ForegroundColor Yellow
Write-Host "  包含: Visual Studio 2022 Community (C++/Game workloads)" -ForegroundColor Gray
Write-Host "        Rust 工具链, FModel, Repak, UAssetGUI" -ForegroundColor Gray
Write-Host ""
$extendedInstall = Read-Host "是否进行扩展安装？[N] 否 / [Y] 是 (默认: N)"
if ($extendedInstall -eq 'Y' -or $extendedInstall -eq 'y') {
    Install-GamingTools
} else {
    Write-Host "已跳过扩展安装" -ForegroundColor Gray
}
```

- [ ] **Step 5: Remove Rust version from the final version check block**

In the final "Checking installed tool versions" section (around line 930-949), remove the Rust version check block:

```powershell
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
```

This avoids confusing base-only users with a "Rust: Not found" message.

- [ ] **Step 6: Verify script parses correctly**

Run (from PowerShell):
```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile("$PWD\win\setup.ps1", [ref]$null, [ref]$errors); if ($errors.Count -eq 0) { "VALID" } else { $errors }
```
Expected: `VALID`

- [ ] **Step 7: Commit**

```bash
git add win/setup.ps1
git commit -m "Move gaming tools to optional post-install prompt in Windows setup"
```

---

### Task 3: Refactor wsl/setup.sh — extract gaming code into function and add prompt

**Files:**
- Modify: `wsl/setup.sh`

- [ ] **Step 1: Replace §5.5 (Repak install + note) with install_gaming_tools function**

Remove lines 185-231 (the Repak installation section and the FModel/UAssetGUI note). Replace with a function definition placed in the same location:

```bash
# ===== Optional: Gaming / UE Modding Tools =====
install_gaming_tools() {
    echo ""
    echo "========================================"
    echo "  扩展安装: UE Modding 工具"
    echo "========================================"
    echo ""

    # Repak - .pak 文件打包/解包工具 (Rust CLI, 跨平台)
    REPAK_PATH="$HOME/.local/bin/repak"
    if [ -f "$REPAK_PATH" ]; then
        echo "✅ Repak 已安装"
    else
        echo "正在安装 Repak..."
        mkdir -p "$HOME/.local/bin"

        REPAK_URL=$(curl -s https://api.github.com/repos/trumank/repak/releases/latest | \
            grep "browser_download_url.*x86_64-unknown-linux-gnu.zip" | \
            cut -d '"' -f 4)

        if [ -n "$REPAK_URL" ]; then
            TEMP_ZIP="/tmp/repak.zip"
            TEMP_DIR="/tmp/repak_extract"

            curl -sL "$REPAK_URL" -o "$TEMP_ZIP"
            rm -rf "$TEMP_DIR"
            unzip -q "$TEMP_ZIP" -d "$TEMP_DIR"

            REPAK_BIN=$(find "$TEMP_DIR" -name "repak" -type f | head -1)
            if [ -n "$REPAK_BIN" ]; then
                cp "$REPAK_BIN" "$REPAK_PATH"
                chmod +x "$REPAK_PATH"
                echo "✅ Repak 安装成功"
            else
                echo "⚠️  Repak 安装失败：未找到可执行文件"
            fi

            rm -f "$TEMP_ZIP"
            rm -rf "$TEMP_DIR"
        else
            echo "⚠️  Repak 安装失败：无法获取下载链接"
            echo "   请手动从 https://github.com/trumank/repak/releases 下载"
        fi
    fi

    echo ""
    echo "📝 注意: FModel、UAssetGUI 和 Signal 仅支持 Windows/macOS 桌面环境"
    echo "   如需使用，请在 Windows 下运行 win/setup.ps1 或 macOS 下运行 mac/install.sh"
    echo ""
    echo "✅ UE Modding 工具安装完成"
}
```

- [ ] **Step 2: Add the prompt before the "配置 .bashrc" section**

Insert the following right before `# 6. 配置 .bashrc` (currently line 233):

```bash
# ===== Optional Extended Installation =====
echo ""
echo "========================================"
echo "  ✅ 基础安装已完成"
echo "========================================"
echo ""
echo "可选扩展: UE Modding 工具包 (Repak)"
echo "  用于 .pak 文件打包/解包"
echo ""
read -p "是否进行扩展安装？[N/y] (默认: N): " extended_choice
if [ "$extended_choice" = "y" ] || [ "$extended_choice" = "Y" ]; then
    install_gaming_tools
else
    echo "已跳过扩展安装"
fi
```

- [ ] **Step 3: Verify script syntax**

Run:
```bash
bash -n wsl/setup.sh && echo "VALID"
```
Expected: `VALID`

- [ ] **Step 4: Commit**

```bash
git add wsl/setup.sh
git commit -m "Move Repak to optional post-install prompt in WSL setup"
```

---

### Task 4: Update CLAUDE.md to document the optional installation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add optional tools section to CLAUDE.md**

After the "## Installed Tools Categories" section, add:

```markdown
## Optional Extended Installation

After base setup completes, users are prompted to optionally install gaming/UE modding tools:
- **Windows:** VS 2022 Community (C++/Game workloads), Rust toolchain, FModel, Repak, UAssetGUI
- **WSL:** Repak

These tools are NOT installed by default. The prompt defaults to No.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Document optional gaming tools installation in CLAUDE.md"
```
