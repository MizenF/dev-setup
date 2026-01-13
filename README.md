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
- Python 3, Node.js, Git
- Docker Desktop
- VSCode, Windows Terminal, Oh-My-Posh
- Yarn, 7zip, Chrome, Postman, Bruno, Claude Desktop, Discord
- 自动配置 PowerShell Profile

**可选：启用 WSL2 初始化**

编辑 `setup.ps1`，设置：
```powershell
$enableWSL = $true
```

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
├─ mac/                         # macOS 配置
│  ├─ install.sh               # 主安装脚本
│  ├─ Brewfile                 # Homebrew 包清单
│  └─ mac.zshrc                # macOS 专用 zsh 配置
├─ win/                         # Windows 配置
│  ├─ setup.ps1                # 主安装脚本
│  ├─ win_profile.ps1          # PowerShell Profile
│  └─ setup.winget.json        # winget 软件包清单
├─ dotfiles/                    # 跨平台配置文件
│  ├─ gitconfig                # Git 全局配置
│  ├─ aliases.sh               # 通用命令别名
│  └─ helpers/                 # 工具函数
│       └─ example.sh
└─ wsl/                         # WSL 配置
   └─ setup.sh                 # WSL 初始化脚本
```

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
2. **Windows**: 必须以管理员身份运行 PowerShell
3. **WSL**: 首次安装需执行 `source ~/.bashrc` 刷新环境
4. 所有脚本支持重复执行，不会重复安装或配置

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
