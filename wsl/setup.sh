#!/bin/bash

# WSL 开发环境自动安装脚本
# 可重复执行，自动检测已有配置

set -e

echo "🚀 开始配置 WSL 开发环境..."
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# 1. 更新系统
echo "📦 更新系统..."
sudo apt update -y
sudo apt upgrade -y
echo "✅ 系统更新完成"

# 2. 安装基础开发工具
echo ""
echo "📦 安装基础开发工具..."

# Python
if ! command -v python3 &> /dev/null; then
    echo "正在安装 Python3..."
    sudo apt install -y python3 python3-pip
else
    echo "✅ Python3 已安装"
fi

# Node.js & npm
if ! command -v node &> /dev/null; then
    echo "正在安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
else
    echo "✅ Node.js 已安装"
fi

# Git
if ! command -v git &> /dev/null; then
    echo "正在安装 Git..."
    sudo apt install -y git
else
    echo "✅ Git 已安装"
fi

# Ensure ~/.local/bin is in PATH for current session (used by fd symlink, repak, etc.)
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# 3. 安装 CLI 工具
echo ""
echo "📦 安装 CLI 工具..."

# ripgrep
if ! command -v rg &> /dev/null; then
    echo "正在安装 ripgrep..."
    sudo apt install -y ripgrep
else
    echo "✅ ripgrep 已安装"
fi

# fd
if ! command -v fd &> /dev/null; then
    echo "正在安装 fd..."
    sudo apt install -y fd-find
    # 创建符号链接（因为在 Ubuntu 上叫 fdfind）
    if [ ! -f "$HOME/.local/bin/fd" ]; then
        mkdir -p "$HOME/.local/bin"
        ln -s "$(which fdfind)" "$HOME/.local/bin/fd" 2>/dev/null || true
    fi
else
    echo "✅ fd 已安装"
fi

# fzf
if ! command -v fzf &> /dev/null; then
    echo "正在安装 fzf..."
    sudo apt install -y fzf
else
    echo "✅ fzf 已安装"
fi

# jq
if ! command -v jq &> /dev/null; then
    echo "正在安装 jq..."
    sudo apt install -y jq
else
    echo "✅ jq 已安装"
fi

# yq
if ! command -v yq &> /dev/null; then
    echo "正在安装 yq..."
    YQ_ARCH=$(dpkg --print-architecture)
    sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}"
    sudo chmod +x /usr/local/bin/yq
else
    echo "✅ yq 已安装"
fi

# GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "正在安装 GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -y
    sudo apt install -y gh
else
    echo "✅ GitHub CLI 已安装"
fi

# 其他实用工具
echo ""
echo "📦 安装其他实用工具..."
sudo apt install -y curl wget zip unzip tree htop net-tools build-essential

echo "✅ 工具安装完成"

# 4. 安装 Claude Code
echo ""
echo "📦 安装 Claude Code..."
if command -v claude &> /dev/null; then
    echo "✅ Claude Code 已安装"
else
    echo "正在安装 Claude Code..."
    # Note: Remote script - relies on HTTPS transport security
    curl -fsSL https://claude.ai/install.sh | bash -s latest
    # Refresh PATH to pick up newly installed binary
    export PATH="$HOME/.local/bin:$PATH"
    if command -v claude &> /dev/null; then
        echo "✅ Claude Code 安装成功"
    else
        echo "⚠️  Claude Code 安装可能失败，请手动安装: curl -fsSL https://claude.ai/install.sh | bash -s latest"
    fi
fi

# 4.1. 安装 Claude Code 插件
echo ""
echo "📦 安装 Claude Code 插件..."

if command -v claude &> /dev/null; then
    # 注册 Claude marketplace（幂等：已存在则跳过）
    if claude plugin marketplace list 2>/dev/null | grep -q "claude-plugins-official"; then
        echo "✅ Claude marketplace 已注册: claude-plugins-official"
    else
        echo "📦 注册 Claude marketplace: claude-plugins-official"
        claude plugin marketplace add anthropics/claude-plugins-official
    fi

    CLAUDE_PLUGINS=(
        "commit-commands"
        "code-review"
        "code-simplifier"
        "feature-dev"
        "frontend-design"
        "security-guidance"
        "ralph-loop"
        "superpowers"
        "typescript-lsp"
        "context7"
        "github"
        "supabase"
    )

    for plugin in "${CLAUDE_PLUGINS[@]}"; do
        echo "   安装: $plugin"
        claude plugin install "${plugin}@claude-plugins-official" --scope user 2>/dev/null && \
            echo "   ✅ $plugin" || \
            echo "   ⚠️  $plugin 安装失败"
    done
    echo "✅ Claude Code 插件安装完成"
else
    echo "⚠️  Claude Code 未安装，跳过插件安装"
fi

# 5. 安装 Codex CLI
echo ""
echo "📦 安装 Codex CLI (@openai/codex)..."
if command -v npm &> /dev/null; then
    if npm list -g @openai/codex &> /dev/null; then
        echo "✅ Codex CLI 已安装"
    else
        echo "正在安装 Codex CLI..."
        if npm install -g @openai/codex; then
            echo "✅ Codex CLI 安装成功"
        else
            echo "⚠️  Codex CLI 安装失败，请手动安装: npm install -g @openai/codex"
        fi
    fi
else
    echo "⚠️  npm 未安装，跳过 Codex CLI 安装"
    echo "   请先安装 Node.js/npm，然后运行: npm install -g @openai/codex"
fi

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

# 6. 配置 .bashrc
echo ""
echo "⚙️  配置 .bashrc..."

BASHRC="$HOME/.bashrc"

# 添加 dotfiles/aliases.sh
ALIASES_LINE="[ -f \"$REPO_ROOT/dotfiles/aliases.sh\" ] && source \"$REPO_ROOT/dotfiles/aliases.sh\""
ALIASES_MARKER="# dev-setup: aliases.sh"
if ! grep -Fq "$ALIASES_MARKER" "$BASHRC"; then
    echo "" >> "$BASHRC"
    echo "$ALIASES_MARKER" >> "$BASHRC"
    echo "$ALIASES_LINE" >> "$BASHRC"
    echo "✅ 已添加 aliases.sh 到 .bashrc"
else
    echo "✅ aliases.sh 已存在于 .bashrc"
fi

# 添加 ~/.local/bin 到 PATH
LOCAL_BIN_PATH='export PATH="$HOME/.local/bin:$PATH"'
LOCAL_BIN_MARKER="# dev-setup: local-bin-path"
if ! grep -Fq "$LOCAL_BIN_MARKER" "$BASHRC"; then
    echo "" >> "$BASHRC"
    echo "$LOCAL_BIN_MARKER" >> "$BASHRC"
    echo "$LOCAL_BIN_PATH" >> "$BASHRC"
    echo "✅ 已添加 ~/.local/bin 到 PATH"
else
    echo "✅ ~/.local/bin 已在 PATH 中"
fi

# 7. 配置 Git
echo ""
echo "⚙️  配置 Git..."

GITCONFIG="$HOME/.gitconfig"
if [ ! -f "$GITCONFIG" ]; then
    if [ -f "$REPO_ROOT/dotfiles/gitconfig" ]; then
        cp "$REPO_ROOT/dotfiles/gitconfig" "$GITCONFIG"
        echo "✅ 已复制 gitconfig"
        echo "⚠️  请运行以下命令设置 Git 用户信息："
        echo "   git config --global user.name \"Your Name\""
        echo "   git config --global user.email \"your.email@example.com\""
    else
        echo "⚠️  未找到 dotfiles/gitconfig"
    fi
else
    echo "✅ .gitconfig 已存在"
fi

# 8. 设置 Python pip 源（可选，加速下载）
echo ""
echo "⚙️  配置 pip..."
mkdir -p "$HOME/.pip"
if [ ! -f "$HOME/.pip/pip.conf" ]; then
    cat > "$HOME/.pip/pip.conf" << 'EOF'
[global]
index-url = https://pypi.org/simple
trusted-host = pypi.org
EOF
    echo "✅ 已配置 pip"
else
    echo "✅ pip.conf 已存在"
fi

# 9. 完成
echo ""
echo "✨ 安装完成！"
echo ""
echo "📌 下一步："
echo "   1. 运行: source ~/.bashrc"
echo "   2. 配置 Git 用户信息（如果尚未配置）"
echo "   3. 重新打开终端使配置生效"
echo ""
echo "📚 已安装工具版本："
echo "   Python:  $(python3 --version 2>&1)"
echo "   Node:    $(node --version 2>&1)"
echo "   npm:     $(npm --version 2>&1)"
echo "   Git:     $(git --version 2>&1)"
echo "   GitHub CLI: $(gh --version 2>&1 | head -1)"
echo ""
echo "🎉 WSL 开发环境配置完成！"
