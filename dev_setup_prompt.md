# 🚀 dev-setup：跨平台一键开发环境仓库生成指令（给 Cursor / Copilot）

请依据以下完整规范，为我生成一个跨平台开发环境自动化仓库 `dev-setup/`，包含 macOS、Windows、WSL 的一键初始化脚本、dotfiles、配置文件及 README。需严格依照结构创建所有目录与文件，并根据要求生成内容。

---

## 📁 目录结构（必须完整创建）

```
dev-setup/
├─ README.md
├─ mac/
│  ├─ install.sh
│  ├─ Brewfile
│  └─ mac.zshrc
├─ win/
│  ├─ setup.ps1
│  ├─ win_profile.ps1
│  └─ setup.winget.json
├─ dotfiles/
│  ├─ gitconfig
│  ├─ aliases.sh
│  └─ helpers/
│       └─ example.sh
└─ wsl/
   └─ setup.sh
```

---

## 🍎 macOS（mac/）文件要求

### 1. mac/install.sh
功能要求：
- 自动安装 Homebrew（若未安装）
- 自动加载 brew shellenv（兼容 Intel 与 Apple Silicon）
- 执行 Brewfile 内的安装清单
- 自动将以下内容插入 `~/.zshrc`（不可重复添加）：
  - `dotfiles/aliases.sh`
  - `mac/mac.zshrc`
- 若 `~/.gitconfig` 不存在，则复制 dotfiles/gitconfig
- 完成后提示用户 `source ~/.zshrc`

---

### 2. mac/Brewfile
必须包含这些 Homebrew 包：

#### 语言环境
```
python
node
git
openjdk@17
```

#### 前端工具
```
yarn
pnpm
typescript
```

#### CLI 工具
```
ripgrep
fd
bat
eza
fzf
tmux
wget
curl
httpie
jq
yq
neofetch
tree
```

#### 容器 / 工具
```
docker
docker-compose
```

#### App（cask）
```
visual-studio-code
google-chrome
iterm2
postman
bruno
7zip
```

---

### 3. mac/mac.zshrc
必须包含：
- PATH 扩展（java、brew、python）
- 自动补全、颜色提示
- 引用 dotfiles/aliases.sh 的机制

---

## 🪟 Windows（win/）文件要求

### 1. win/setup.ps1
功能要求：
- 自动导入 winget JSON
- 自动安装：Python、Node、Git、Docker Desktop、VSCode、Chrome、Windows Terminal、Oh-My-Posh
- 自动检测安装路径并写入 PATH（防重复）
- 复制 win_profile.ps1 → PowerShell Profile
- 自动刷新 `$env:PATH`（无需重启）
- 提供变量开关：是否启用 WSL2 初始化

---

### 2. win/setup.winget.json
必须包含以下软件：

#### 语言环境
```
Python.Python.3
OpenJS.NodeJS
Git.Git
```

#### 容器工具
```
Docker.DockerDesktop
```

#### 编辑器 / 终端
```
Microsoft.VisualStudioCode
Microsoft.WindowsTerminal
JanDeDobbeleer.OhMyPosh
```

#### 前端工具
```
Yarn.Yarn
```

#### 实用工具
```
7zip.7zip
Google.Chrome
Postman.Postman
Bruno.Bruno
```

---

### 3. win/win_profile.ps1
必须包含：
- 加载 dotfiles/aliases.sh（使用 Windows 可行方式）
- 设置 PSReadLine（自动提示、历史）
- 设置 Oh-My-Posh 主题
- PATH 自动扩展（防重复添加）

---

## 📁 dotfiles 内容要求

### 1. dotfiles/aliases.sh
包含以下 alias：

#### 常用 alias
```
alias ll="ls -al"
alias gs="git status"
alias gc="git commit"
alias gp="git push"
alias gb="git branch"
alias py="python3"
alias ..="cd .."
```

#### 开发常用
```
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias logs="tail -f logs/*.log"
```

#### 函数
```
mkcd() { mkdir -p "$1" && cd "$1"; }
```

---

### 2. dotfiles/gitconfig
```
[core]
    editor = code --wait
[alias]
    s = status
    co = checkout
    cm = commit
    lg = log --oneline --graph --all
```
（email/username 留占位符）

---

### 3. dotfiles/helpers/example.sh
内容：输出 "helper working"

---

## 🐧 WSL（wsl/setup.sh）要求
- 自动 apt update / upgrade
- 安装 python3、pip、node、npm、git
- 安装 ripgrep、fd、fzf、jq、yq
- 将 dotfiles/aliases.sh 加入 `~/.bashrc`
- 可重复执行

---

## 📘 README.md 内容要求

### Mac 一键安装
```bash
curl -fsSL https://raw.githubusercontent.com/<your-repo>/mac/install.sh | bash
```

### Windows 一键安装
```powershell
irm https://raw.githubusercontent.com/<your-repo>/win/setup.ps1 | iex
```

### WSL 初始化
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/<your-repo>/wsl/setup.sh)
```

---

## 🧩 全局要求
- 所有脚本可重复执行
- PATH 不可重复添加
- alias 不可重复写入
- 文件路径自动检测
- 所有脚本必须含防呆检查
- 仓库必须开箱即用
- 生成内容必须完整遵循规范，不可省略
```
