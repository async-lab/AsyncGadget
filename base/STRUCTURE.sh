#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Bash data-structure helpers.
# 目标：让脚本里“数组/映射”的常用操作更清爽一些。
#
# 说明：
# - 这里使用 nameref（declare/local -n），需要 Bash >= 4.3。
# - 本仓库工具大多面向 Linux/OpenWrt（已安装 bash），因此默认可用。

##############################################
################# ARRAY/LIST #################

# 压缩索引数组：把 unset 造成的“洞”去掉，保证后续 for ((i=0; i<${#arr[@]}; i++)) 不漏元素。
function LIST_COMPACT() {
    local -n _list="$1"
    local tmp=()
    local item
    for item in "${_list[@]}"; do
        tmp+=("$item")
    done
    _list=("${tmp[@]}")
}

# 检查索引数组里是否包含某个值（完全匹配）。
function LIST_CONTAINS() {
    local -n _list="$1"
    local needle="$2"
    local item
    for item in "${_list[@]}"; do
        if [ "$item" == "$needle" ]; then
            return 0
        fi
    done
    return 1
}

##############################################
################### OTHER ####################

# 键值对解析函数
function PARSE_KV() {
    local -n __out=$1
    local __parse_k __parse_v
    __out=()
    while IFS='=' read -r __parse_k __parse_v; do
        [[ -n $__parse_k ]] && __out["$__parse_k"]="$__parse_v"
    done <<< "$2"
}