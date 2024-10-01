#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 检查变量是否存在，只要有一个不存在就返回1
function CHECK_IF_ALL_EXIST() {
    for arg in "$@"; do
        if [ -z "$arg" ]; then
            return 1
        fi
    done
    return 0
}

# 检查变量是否不存在，只要有一个存在就返回1
function CHECK_IF_ALL_NULL() {
    for arg in "$@"; do
        if [ -n "$arg" ]; then
            return 1
        fi
    done
    return 0
}

# 取反
function NOT() {
    if [ "$1" -eq 0 ]; then
        echo 1
    else
        echo 0
    fi
}

# 检查包是否存在
function CHECK_PACKAGE() {
    if command -v dpkg >/dev/null 2>&1; then
        dpkg -l | grep -qw "$1"
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$1" >/dev/null 2>&1
    elif command -v brew >/dev/null 2>&1; then
        brew list "$1" >/dev/null 2>&1
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Qs "$1" >/dev/null 2>&1
    elif command -v pkg >/dev/null 2>&1; then
        pkg info "$1" >/dev/null 2>&1
    else
        return 1
    fi

    return "$?"
}
