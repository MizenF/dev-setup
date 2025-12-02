#!/bin/bash

# 跨平台通用别名和函数
# 由 mac/install.sh 和 wsl/setup.sh 自动加载

# ============================================
# 基础别名
# ============================================

alias ll="ls -al"
alias la="ls -A"
alias l="ls -CF"

# ============================================
# Git 别名
# ============================================

alias gs="git status"
alias gc="git commit"
alias gp="git push"
alias gb="git branch"
alias gco="git checkout"
alias gl="git log --oneline --graph --all"
alias gd="git diff"
alias ga="git add"
alias gaa="git add ."

# ============================================
# Python 别名
# ============================================

alias py="python3"
alias pip="pip3"

# ============================================
# 导航别名
# ============================================

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"

# ============================================
# Docker 别名
# ============================================

alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcl="docker compose logs -f"
alias dps="docker ps"
alias dpsa="docker ps -a"
alias di="docker images"

# ============================================
# 日志查看
# ============================================

alias logs="tail -f logs/*.log"

# ============================================
# 实用别名
# ============================================

# 清屏
alias c="clear"

# 快速编辑配置
alias bashrc="code ~/.bashrc"
alias zshrc="code ~/.zshrc"
alias vimrc="code ~/.vimrc"

# 进程查看
alias psg="ps aux | grep -v grep | grep -i -e VSZ -e"

# 网络
alias ports="netstat -tulanp"

# 历史命令
alias h="history"
alias hg="history | grep"

# 磁盘使用
alias du1="du -h --max-depth=1"
alias df="df -h"

# ============================================
# 实用函数
# ============================================

# 创建目录并进入
mkcd() {
    if [ -z "$1" ]; then
        echo "Usage: mkcd <directory>"
        return 1
    fi
    mkdir -p "$1" && cd "$1"
}

# 快速查找文件
ff() {
    if [ -z "$1" ]; then
        echo "Usage: ff <filename>"
        return 1
    fi
    find . -type f -name "*$1*"
}

# 快速查找目录
fd() {
    if [ -z "$1" ]; then
        echo "Usage: fd <dirname>"
        return 1
    fi
    find . -type d -name "*$1*"
}

# 解压任何格式
extract() {
    if [ -z "$1" ]; then
        echo "Usage: extract <file>"
        return 1
    fi
    
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' 无法解压" ;;
        esac
    else
        echo "'$1' 不是有效文件"
    fi
}

# 快速启动 HTTP 服务器
serve() {
    local port="${1:-8000}"
    echo "启动 HTTP 服务器在端口 $port..."
    python3 -m http.server "$port"
}

# Git 快速提交
gac() {
    if [ -z "$1" ]; then
        echo "Usage: gac <commit message>"
        return 1
    fi
    git add .
    git commit -m "$1"
}

# Git 快速提交并推送
gacp() {
    if [ -z "$1" ]; then
        echo "Usage: gacp <commit message>"
        return 1
    fi
    git add .
    git commit -m "$1"
    git push
}

# 显示当前目录大小
dirsize() {
    du -sh "${1:-.}"
}

# 显示系统信息
sysinfo() {
    echo "系统信息："
    echo "==========="
    uname -a
    echo ""
    echo "CPU 信息："
    if command -v lscpu &> /dev/null; then
        lscpu | grep "Model name"
    fi
    echo ""
    echo "内存信息："
    free -h
    echo ""
    echo "磁盘信息："
    df -h
}

# ============================================
# 加载用户自定义 helpers
# ============================================

# 获取当前脚本所在目录
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$DOTFILES_DIR/helpers"

# 加载 helpers 目录下的所有 .sh 文件
if [ -d "$HELPERS_DIR" ]; then
    for helper in "$HELPERS_DIR"/*.sh; do
        if [ -f "$helper" ]; then
            source "$helper"
        fi
    done
fi
