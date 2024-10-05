#!/usr/bin/env bash
# -*- coding: utf-8 -*-

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
    while IFS= read -r line; do
        params+=("$line")
    done
    "$@" "${params[@]}"
    return "$?"
}

function CHECK_FD() {
    local fd="$1"
    if [ -e "/proc/$$/fd/$fd" ]; then
        return 0
    else
        return 1
    fi
}
