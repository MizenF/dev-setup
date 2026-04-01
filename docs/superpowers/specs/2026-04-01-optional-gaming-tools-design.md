# Optional Gaming Tools Installation

**Date:** 2026-04-01
**Status:** Approved

## Goal

Strip all game development / UE modding tools out of the base installation and offer them as an optional "extended install" prompted after the base setup completes.

## Scope — What Gets Moved

| Tool | Platform | Current Location |
|------|----------|-----------------|
| Microsoft.VisualStudio.2022.BuildTools (winget) | Windows | setup.winget.json |
| Rustlang.Rustup (winget) | Windows | setup.winget.json |
| VS 2022 Community + NativeDesktop/NativeGame workloads | Windows | setup.ps1 §2.4.2 |
| Rust toolchain configuration (stable-msvc) | Windows | setup.ps1 §2.7 |
| FModel | Windows | setup.ps1 §2.8 |
| Repak | Windows | setup.ps1 §2.8 |
| UAssetGUI | Windows | setup.ps1 §2.8 |
| Repak | WSL | setup.sh §5.5 |

## Interaction Design

After the base installation completes, before the "completed" summary, prompt the user:

**Windows (PowerShell):**
```
是否进行扩展安装（UE 游戏开发/Modding 工具）？
[N] 否  [Y] 是  (默认: N):
```

**WSL (Bash):**
```
是否进行扩展安装（UE Modding 工具）？[N/y]:
```

- Default is N (no install).
- Selecting Y runs the gaming tools installation immediately.

## Changes Per File

### win/setup.winget.json
- Remove `Microsoft.VisualStudio.2022.BuildTools` entry
- Remove `Rustlang.Rustup` entry

### win/setup.ps1
1. Remove sections §2.4.2 (VS Community install), §2.7 (Rust config), §2.8 (UE Modding Tools) from the main flow.
2. Wrap all removed code in a function (e.g., `Install-GamingTools`) that includes:
   - `winget install` for BuildTools and Rustup
   - VS 2022 Community installation with NativeDesktop + NativeGame + Windows 10 SDK
   - Rust toolchain configuration
   - UE Modding Tools (FModel, Repak, UAssetGUI) — reuses existing `Install-GitHubRelease` function
3. Insert prompt before the "Complete" section (before §3). On Y, call `Install-GamingTools`.
4. Keep `.local/bin` and `.cargo/bin` PATH entries in base (harmless, used by other tools too). Update comment on `.local/bin` to remove "UE Modding Tools" reference.

### wsl/setup.sh
1. Remove §5.5 (Repak install, lines 185-227) and the FModel/UAssetGUI note (lines 230-231) from the main flow.
2. Wrap in a function (e.g., `install_gaming_tools`) containing the Repak installation logic.
3. Insert prompt before the "完成" section (before §6). On y, call `install_gaming_tools`.

## What Stays in Base

- `.local/bin` and `.cargo/bin` PATH configuration (generic, not gaming-specific)
- All other tools, languages, CLI utilities, apps
