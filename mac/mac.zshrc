# macOS-specific zsh configuration
# This file is sourced by ~/.zshrc

# ============================================
# PATH 扩展
# ============================================

# Homebrew (Apple Silicon)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Homebrew (Intel)
if [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Java (OpenJDK)
if [[ -d "/opt/homebrew/opt/openjdk@17" ]]; then
    export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
    export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
elif [[ -d "/usr/local/opt/openjdk@17" ]]; then
    export PATH="/usr/local/opt/openjdk@17/bin:$PATH"
    export JAVA_HOME="/usr/local/opt/openjdk@17"
fi

# Python
if command -v python3 &> /dev/null; then
    PYTHON_USER_BASE=$(python3 -m site --user-base)
    export PATH="$PYTHON_USER_BASE/bin:$PATH"
fi

# Node global packages
if [[ -d "$HOME/.npm-global" ]]; then
    export PATH="$HOME/.npm-global/bin:$PATH"
fi

# ============================================
# 自动补全
# ============================================

# 启用自动补全
autoload -Uz compinit
compinit

# 补全时忽略大小写
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# 补全菜单选择
zstyle ':completion:*' menu select

# ============================================
# 命令历史
# ============================================

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# 历史记录选项
setopt HIST_IGNORE_ALL_DUPS  # 删除重复条目
setopt HIST_FIND_NO_DUPS     # 搜索时不显示重复
setopt HIST_SAVE_NO_DUPS     # 保存时不写入重复
setopt SHARE_HISTORY         # 多终端共享历史

# ============================================
# 颜色提示
# ============================================

# 启用颜色支持
autoload -Uz colors && colors

# ls 颜色
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# grep 颜色
export GREP_COLOR='1;32'
alias grep='grep --color=auto'

# eza (如果已安装)
if command -v eza &> /dev/null; then
    alias ls='eza --icons'
    alias la='eza --icons -a'
    alias ll='eza --icons -lah'
    alias tree='eza --tree --icons'
fi

# bat (如果已安装)
if command -v bat &> /dev/null; then
    alias cat='bat --style=plain --paging=never'
    export BAT_THEME="OneHalfDark"
fi

# ============================================
# 提示符
# ============================================

# 简单的彩色提示符
PROMPT='%{$fg[cyan]%}%n@%m%{$reset_color%} %{$fg[yellow]%}%~%{$reset_color%} %# '

# Git 分支显示（如果在 git 仓库中）
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst
zstyle ':vcs_info:git:*' formats '%F{green}[%b]%f '
RPROMPT='${vcs_info_msg_0_}'

# ============================================
# 其他选项
# ============================================

# 自动 cd（输入目录名即可 cd）
setopt AUTO_CD

# 命令纠错
setopt CORRECT

# 不保存重复的连续命令
setopt HIST_IGNORE_DUPS

# 后台任务完成时立即通知
setopt NOTIFY

# ============================================
# fzf 集成（如果已安装）
# ============================================

if command -v fzf &> /dev/null; then
    # Ctrl+R: 历史命令搜索
    source <(fzf --zsh) 2>/dev/null || true
fi

# ============================================
# 欢迎信息
# ============================================

# 显示系统信息（首次打开终端）
if [[ -z "$TMUX" ]] && command -v neofetch &> /dev/null; then
    neofetch
fi
