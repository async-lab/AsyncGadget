#!/usr/bin/env bash
# -*- coding: utf-8 -*-

YES="0"
NO="1"

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

function IS_YES() {
    if [ "$1" -eq "$YES" ]; then
        return 0
    else
        return 1
    fi
}

function IS_NO() {
    if [ "$1" -eq "$NO" ]; then
        return 0
    else
        return 1
    fi
}
