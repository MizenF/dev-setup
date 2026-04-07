# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cross-platform development environment automation repository (跨平台一键开发环境仓库). Provides one-command automated setup for macOS, Windows, and WSL development environments with unified dotfiles configuration.

## Installation Commands

**macOS:**
```bash
cd mac && chmod +x install.sh && ./install.sh
```

**Windows (requires admin PowerShell):**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
.\win\setup.ps1
```

**WSL:**
```bash
bash wsl/setup.sh
```

## Architecture

```
dev-setup/
├── dotfiles/          # Platform-agnostic configuration (hub)
│   ├── aliases.sh     # Shared shell aliases (~50+ aliases)
│   ├── gitconfig      # Git configuration template
│   └── helpers/       # Custom functions/scripts
├── mac/               # macOS: Homebrew-based installation
│   ├── install.sh     # Main installer
│   ├── Brewfile       # Package manifest
│   └── mac.zshrc      # macOS-specific shell config
├── win/               # Windows: winget + PowerShell
│   ├── setup.ps1      # Main installer (requires admin)
│   ├── win_profile.ps1 # PowerShell profile
│   └── setup.winget.json # Package manifest
└── wsl/               # WSL: apt-based installation
    └── setup.sh       # Main installer
```

The architecture follows a hub-and-spoke pattern where dotfiles are the central hub loaded by all platform-specific scripts, ensuring consistent shell experience across all environments.

## Key Conventions

**All scripts are idempotent** - can be safely re-run without duplicating configurations or reinstalling existing tools.

**Bash/Shell scripts:**
- Use `set -e` for error handling
- Under `set -e`, use `if command; then` pattern instead of `command; if [ $? -eq 0 ]` — the latter is dead code because `set -e` exits on failure before `$?` is checked
- Check tool existence with `command -v` before installing
- Support both ARM64 and x86-64 architectures (e.g., use `dpkg --print-architecture` for download URLs)
- Escape sequences for colored output
- Use stable marker comments (e.g., `# dev-setup: aliases.sh`) for `.bashrc`/`.zshrc` idempotency checks — not path-dependent `grep -Fx` matching

**PowerShell scripts:**
- Require administrator elevation (`#Requires -RunAsAdministrator`)
- Use try-catch for error handling
- Registry checks for Windows features (VirtualMachinePlatform, Hyper-V)
- **Critical:** All `.ps1` files with CJK characters must use UTF-8 BOM encoding — PowerShell 5.1 cannot parse non-ASCII without BOM
- **Critical:** Must refresh PATH immediately after `winget import` since new tools won't be visible to current session otherwise
- When tools may not be in PATH yet, use fallback paths (e.g., `$env:ProgramFiles\nodejs\npm.cmd`)
- PSReadLine `PredictionSource`/`PredictionViewStyle` require PS 7+ — guard with `$PSVersionTable.PSVersion.Major -ge 7`
- Avoid `<angle brackets>` and commas in `Read-Host` prompt strings — PS 5.1 parser misinterprets them
- Windows copies `dotfiles/gitconfig` but overrides `autocrlf` to `true` (template uses `input` for Unix)

**Configuration templates:**
- Git config uses placeholders: `YOUR_NAME_HERE`, `YOUR_EMAIL_HERE`
- Interactive prompts configure user-specific values on first run

## Installed Tools Categories

- **Languages:** Python 3, Node.js, OpenJDK 17
- **CLI utilities:** ripgrep, fd, fzf, jq, yq, bat, eza, httpie
- **Containers:** Docker, Docker Compose
- **AI tools:** Claude Desktop, Claude Code CLI, Codex CLI
- **Apps:** VSCode, Chrome, Windows Terminal/iTerm2, Discord, Signal

## Optional Extended Installation

After base setup completes, users are prompted to optionally install gaming/UE modding tools:
- **Windows:** VS 2022 Community (C++/Game workloads), Rust toolchain, FModel, Repak, UAssetGUI
- **WSL:** Repak

These tools are NOT installed by default. The prompt defaults to No.
