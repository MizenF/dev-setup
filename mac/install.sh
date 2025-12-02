#!/bin/bash

# macOS 开发环境自动安装脚本
# 可重复执行，自动检测已有配置

set -e

echo "🚀 开始配置 macOS 开发环境..."
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# 1. 检查并安装 Homebrew
echo "📦 检查 Homebrew..."
if ! command -v brew &> /dev/null; then
    echo "正在安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✅ Homebrew 已安装"
fi

# 2. 配置 brew shellenv（兼容 Intel 和 Apple Silicon）
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    # Apple Silicon
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
    # Intel
    eval "$(/usr/local/bin/brew shellenv)"
fi

# 3. 执行 Brewfile 安装
echo ""
echo "📦 安装软件包（根据 Brewfile）..."
if [[ -f "$SCRIPT_DIR/Brewfile" ]]; then
    brew bundle --file="$SCRIPT_DIR/Brewfile"
    echo "✅ 软件包安装完成"
else
    echo "⚠️  未找到 Brewfile，跳过软件包安装"
fi

# 4. 配置 .zshrc
echo ""
echo "⚙️  配置 zsh..."

ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

# 添加 dotfiles/aliases.sh
ALIASES_LINE="[ -f \"$REPO_ROOT/dotfiles/aliases.sh\" ] && source \"$REPO_ROOT/dotfiles/aliases.sh\""
if ! grep -Fxq "$ALIASES_LINE" "$ZSHRC"; then
    echo "" >> "$ZSHRC"
    echo "# Load dev-setup aliases" >> "$ZSHRC"
    echo "$ALIASES_LINE" >> "$ZSHRC"
    echo "✅ 已添加 aliases.sh 到 .zshrc"
else
    echo "✅ aliases.sh 已存在于 .zshrc"
fi

# 添加 mac.zshrc
MAC_ZSHRC_LINE="[ -f \"$SCRIPT_DIR/mac.zshrc\" ] && source \"$SCRIPT_DIR/mac.zshrc\""
if ! grep -Fxq "$MAC_ZSHRC_LINE" "$ZSHRC"; then
    echo "" >> "$ZSHRC"
    echo "# Load macOS-specific config" >> "$ZSHRC"
    echo "$MAC_ZSHRC_LINE" >> "$ZSHRC"
    echo "✅ 已添加 mac.zshrc 到 .zshrc"
else
    echo "✅ mac.zshrc 已存在于 .zshrc"
fi

# 5. 配置 Git
echo ""
echo "⚙️  配置 Git..."
GITCONFIG="$HOME/.gitconfig"
if [[ ! -f "$GITCONFIG" ]]; then
    if [[ -f "$REPO_ROOT/dotfiles/gitconfig" ]]; then
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

# 6. 完成
echo ""
echo "✨ 安装完成！"
echo ""
echo "📌 下一步："
echo "   1. 运行: source ~/.zshrc"
echo "   2. 配置 Git 用户信息（如果尚未配置）"
echo "   3. 重新打开终端或运行 'exec zsh' 使配置生效"
echo ""
