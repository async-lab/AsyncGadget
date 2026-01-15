#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 空操作
function NOOP() {
    true
}

# 关闭命令的标准输出
function NO_STDOUT() {
    "$@" >/dev/null
    return "$?"
}

# 关闭命令的错误输出
function NO_ERR() {
    "$@" 2>/dev/null
    return "$?"
}

# 关闭命令的输出
function NO_OUTPUT() {
    "$@" >/dev/null 2>&1
    return "$?"
}

# 将命令的返回值作为输出
function RETURN_AS_OUTPUT() {
    NO_OUTPUT "$@"
    echo "$?"
}

# 将标准输入输出流的数据传递给命令参数
function STDIN() {
    local params=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        params+=("$line")
    done
    "$@" "$(printf "%s\n" "${params[@]}")"
    return "$?"
}

# 检查文件描述符是否存在
function CHECK_FD_IF_EXIST() {
    local fd="$1"
    if [ -e "/proc/$$/fd/$fd" ]; then
        return 0
    else
        return 1
    fi
}
