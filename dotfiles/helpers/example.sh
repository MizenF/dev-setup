#!/bin/bash

# 示例 helper 脚本
# 此文件会被 dotfiles/aliases.sh 自动加载
# 你可以在这里添加自定义函数和别名

# 示例函数
hello_helper() {
    echo "✅ Helper working! This is from dotfiles/helpers/example.sh"
    echo "You can add your own custom functions and aliases here."
}

# 示例别名
alias helper-test="hello_helper"

# 更多示例函数...
# 例如：项目特定的快捷方式、自定义工具等
