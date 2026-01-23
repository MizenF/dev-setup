# 🚀 dev-setup：跨平台一键开发环境仓库

一键自动化配置 macOS、Windows、WSL 开发环境的完整解决方案。

## 📋 功能特性

- ✅ **macOS**：自动安装 Homebrew、开发工具、配置 shell
- ✅ **Windows**：自动安装 winget 软件包、配置 PowerShell
- ✅ **WSL**：自动安装 Linux 开发工具、配置环境
- ✅ **跨平台 dotfiles**：统一的 Git 配置、aliases、工具函数
- ✅ **可重复执行**：所有脚本支持重复运行，智能检测已有配置

## 🍎 macOS 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/<your-repo>/dev-setup/main/mac/install.sh | bash
```

或手动执行：
```bash
cd mac
chmod +x install.sh
./install.sh
```

**安装内容：**
- Homebrew 包管理器
- Python, Node.js, Git, OpenJDK 17
- 前端工具：yarn, pnpm, typescript
- CLI 工具：ripgrep, fd, bat, eza, fzf, tmux 等
- 容器工具：Docker, Docker Compose
- 应用：VSCode, Chrome, iTerm2, Postman, Bruno, Claude Desktop, Discord 等

**安装后：**
```bash
source ~/.zshrc
```

---

## 🪟 Windows 一键安装

以**管理员身份**运行 PowerShell：

```powershell
irm https://raw.githubusercontent.com/<your-repo>/dev-setup/main/win/setup.ps1 | iex
```

或手动执行：
```powershell
cd win
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
.\setup.ps1
```

**安装内容：**

| 分类 | 工具 |
|------|------|
| 语言 & 运行时 | Python 3, Node.js, OpenJDK 17, Rust |
| 版本控制 | Git |
| 容器 | Docker Desktop |
| IDE & 编辑器 | VSCode, Visual Studio 2022 Community (C++ workloads) |
| 终端 | Windows Terminal, Oh-My-Posh |
| AI 工具 | Claude Desktop, Claude Code CLI, Codex CLI |
| CLI 工具 | ripgrep, fd, fzf, jq, yq, bat, eza, httpie |
| 前端工具 | Yarn, pnpm |
| 应用 | Chrome, Postman, Bruno, Discord, 7zip |
| UE Modding | FModel, Repak, UAssetGUI |
| VS Code 插件 | Cline (AI assistant), Remote SSH |

**安装流程：**

1. 检查系统虚拟化状态
2. 通过 winget 安装软件包
3. 配置 PATH 环境变量
4. 安装 Visual Studio 2022 Community（含 C++ 桌面开发、游戏开发工作负载）
5. 安装 AI CLI 工具（Claude Code、Codex）
6. 配置 Rust 工具链（stable-msvc）
7. 安装 UE Modding 工具
8. 安装 VS Code 插件
9. 配置 PowerShell Profile
10. 交互式配置 Git 用户信息

**可选：启用 WSL2 初始化**

```powershell
.\setup.ps1 -enableWSL $true
```

**注意：Docker Desktop 安装**

如果系统未启用 VirtualMachinePlatform，脚本会：
1. 自动启用该 Windows 功能
2. 跳过 Docker 安装并提示重启
3. 重启后再次运行脚本即可完成 Docker 安装

---

## 🐧 WSL 初始化

在 WSL 终端中执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/<your-repo>/dev-setup/main/wsl/setup.sh)
```

或手动执行：
```bash
cd wsl
chmod +x setup.sh
./setup.sh
```

**安装内容：**
- Python3, Node.js, Git
- CLI 工具：ripgrep, fd, fzf, jq, yq
- 自动配置 .bashrc

**安装后：**
```bash
source ~/.bashrc
```

---

## 📁 目录结构

```
dev-setup/
├─ README.md                    # 本文档
├─ CLAUDE.md                    # Claude Code 项目指南
├─ mac/                         # macOS 配置
│  ├─ install.sh               # 主安装脚本
│  ├─ Brewfile                 # Homebrew 包清单
│  └─ mac.zshrc                # macOS 专用 zsh 配置
├─ win/                         # Windows 配置
│  ├─ setup.ps1                # 主安装脚本（需管理员权限）
│  ├─ win_profile.ps1          # PowerShell Profile
│  └─ setup.winget.json        # winget 软件包清单
├─ dotfiles/                    # 跨平台配置文件（hub）
│  ├─ gitconfig                # Git 全局配置模板
│  ├─ aliases.sh               # 通用命令别名（~50+ aliases）
│  └─ helpers/                 # 工具函数
│       └─ example.sh
└─ wsl/                         # WSL 配置
   └─ setup.sh                 # WSL 初始化脚本
```

**架构说明**：采用 hub-and-spoke 模式，`dotfiles/` 作为中心枢纽，各平台脚本加载共享配置，确保跨平台一致的 shell 体验。

---

## 🔧 手动配置指南

### dotfiles 使用

所有脚本会自动加载 `dotfiles/aliases.sh`，包含常用 alias：

```bash
ll          # ls -al
gs          # git status
gc          # git commit
gp          # git push
dcu         # docker compose up -d
dcd         # docker compose down
mkcd <dir>  # 创建并进入目录
```

### Git 配置

首次使用需配置用户信息：

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

---

## 📌 注意事项

1. **macOS**: 安装完成后必须执行 `source ~/.zshrc` 使配置生效
2. **Windows**:
   - 必须以**管理员身份**运行 PowerShell
   - Docker 需要硬件虚拟化支持（VT-x/AMD-V），请在 BIOS 中启用
   - 首次安装可能需要重启以启用 VirtualMachinePlatform，重启后再次运行脚本
   - Visual Studio 安装较慢，请耐心等待
3. **WSL**: 首次安装需执行 `source ~/.bashrc` 刷新环境
4. 所有脚本支持**幂等执行**（可重复运行），智能检测已安装的工具并跳过

---

## 🛠️ 自定义配置

### 添加自己的软件包

- **macOS**: 编辑 `mac/Brewfile`
- **Windows**: 编辑 `win/setup.winget.json`
- **WSL**: 编辑 `wsl/setup.sh` 中的 apt install 列表

### 添加自定义 alias

编辑 `dotfiles/aliases.sh`，添加你的命令别名

### 添加 helper 函数

在 `dotfiles/helpers/` 目录下创建新的 `.sh` 文件

---

## 📝 许可证

MIT License

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## 📧 联系

如有问题或建议，请通过 Issue 反馈。
