# dev-setup

跨平台一键开发环境自动化仓库 —— 一条命令完成 macOS / Windows / WSL 的开发环境初始化。

## 特性

- **macOS**：基于 Homebrew，一份 Brewfile 管理所有包
- **Windows**：基于 winget，自动检测虚拟化、配置 PowerShell Profile
- **WSL**：基于 apt，自动配置 `.bashrc`
- **跨平台 dotfiles**：统一的 Git 配置、shell 别名、辅助函数
- **Claude Code 插件**：自动注册官方 marketplace 并安装常用插件
- **幂等可重复执行**：所有脚本智能检测已有配置，可放心重复运行

## macOS 安装

```bash
git clone https://github.com/MizenF/dev-setup.git
cd dev-setup/mac
chmod +x install.sh
./install.sh
```

安装内容：

| 分类 | 工具 |
|---|---|
| 语言运行时 | Python, Node.js, OpenJDK 17 |
| 前端工具 | Yarn, pnpm, TypeScript |
| CLI 工具 | ripgrep, fd, bat, eza, fzf, tmux, jq, yq, httpie, gh, tree, neofetch |
| 容器 | Docker, Docker Compose |
| 应用 (Cask) | VSCode, Chrome, iTerm2, Postman, Bruno, 7zip |
| AI / 编辑器 | Claude Desktop, Google Antigravity IDE |
| 通讯 | Discord, Signal |

安装完成后：

```bash
source ~/.zshrc
```

## Windows 安装

以**管理员身份**运行 PowerShell：

```powershell
git clone https://github.com/MizenF/dev-setup.git
cd dev-setup
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
.\win\setup.ps1
```

安装内容：

| 分类 | 工具 |
|---|---|
| 语言运行时 | Python 3.12, Node.js, Git, OpenJDK 17 |
| 容器 | Docker Desktop |
| 编辑器 / 终端 | VSCode, Windows Terminal, Oh-My-Posh |
| AI / 编辑器 | Claude Code CLI, Codex CLI, Google Antigravity IDE |
| 前端工具 | Yarn |
| CLI 工具 | GitHub CLI |
| 应用 | Chrome, Postman, Bruno, 7zip, Discord, Signal |

安装流程：

1. 检查系统虚拟化状态
2. 通过 winget 批量安装软件包
3. 自动刷新 PATH
4. 安装 AI CLI 工具（Claude Code、Codex）
5. 注册 Claude Code marketplace 并安装插件
6. 询问是否进行**扩展安装**（默认跳过，详见下方）
7. 安装 VS Code 插件
8. 配置 PowerShell Profile
9. 交互式配置 Git 用户信息

可选启用 WSL2 初始化：

```powershell
.\win\setup.ps1 -enableWSL $true
```

**关于 Docker Desktop：** 如系统未启用 `VirtualMachinePlatform`，脚本会自动启用该 Windows 功能并提示重启；重启后再次运行即可完成 Docker 安装。Docker 还需要在 BIOS 中启用硬件虚拟化（VT-x / AMD-V）。

## WSL 安装

```bash
git clone https://github.com/MizenF/dev-setup.git
cd dev-setup
bash wsl/setup.sh
```

安装内容：

- Python 3、Node.js、Git
- CLI 工具：ripgrep, fd, fzf, jq, yq
- AI 工具：Claude Code CLI, Codex CLI
- Claude Code marketplace + 常用插件
- 自动配置 `.bashrc`

安装完成后：

```bash
source ~/.bashrc
```

## 扩展安装（可选）

基础安装完成后，三个平台都会询问是否安装额外的 C++ / Rust / UE 资源处理工具链，**默认跳过**：

| 平台 | 包含 |
|---|---|
| Windows | Visual Studio 2022 Community（C++ Desktop + Game 工作负载）、Rust 工具链、FModel、Repak、UAssetGUI |
| WSL | Repak |

仅在需要这套工具链时选择"是"。

## Claude Code 插件

三个平台的脚本都会自动：

1. 注册官方 marketplace `claude-plugins-official`（来自 [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official)）
2. 安装以下常用插件（`--scope user`）：

```
commit-commands, code-review, code-simplifier, feature-dev,
frontend-design, security-guidance, ralph-loop, superpowers,
typescript-lsp, context7, github, supabase
```

如需调整清单，编辑各脚本中的 `CLAUDE_PLUGINS` / `$claudePlugins` 数组。

## 目录结构

```
dev-setup/
├─ README.md
├─ CLAUDE.md                # Claude Code 项目指南
├─ mac/
│  ├─ install.sh            # 主安装脚本
│  ├─ Brewfile              # Homebrew 包清单
│  └─ mac.zshrc             # macOS 专用 zsh 配置
├─ win/
│  ├─ setup.ps1             # 主安装脚本（需管理员）
│  ├─ win_profile.ps1       # PowerShell Profile
│  └─ setup.winget.json     # winget 包清单
├─ wsl/
│  └─ setup.sh              # WSL 初始化脚本
└─ dotfiles/                # 跨平台共享配置（hub）
   ├─ gitconfig             # Git 配置模板
   ├─ aliases.sh            # 通用 shell 别名
   └─ helpers/              # 辅助函数
```

采用 hub-and-spoke 架构：`dotfiles/` 为中心枢纽，三个平台脚本加载共享配置，确保 shell 体验一致。

## 自定义

| 想做什么 | 改哪里 |
|---|---|
| 增删 macOS 包 | `mac/Brewfile` |
| 增删 Windows 包 | `win/setup.winget.json` |
| 增删 WSL 包 | `wsl/setup.sh`（搜 `apt install`） |
| 自定义 alias | `dotfiles/aliases.sh` |
| 添加 helper 函数 | 在 `dotfiles/helpers/` 新建 `.sh` |
| 调整 Claude 插件清单 | 三个安装脚本中的 `CLAUDE_PLUGINS` 数组 |

Git 用户信息（首次使用）：

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## 注意事项

- **macOS**：安装完成后必须 `source ~/.zshrc` 使配置生效
- **Windows**：必须管理员身份运行；首次启用 `VirtualMachinePlatform` 后需重启再次运行脚本
- **WSL**：首次安装后 `source ~/.bashrc` 刷新环境
- 所有脚本支持幂等执行（可重复运行，已安装的会自动跳过）

## License

MIT
