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
#################### MAP #####################

# 检查关联数组里某个 key 是否存在。
function MAP_HAS() {
    local -n _map="$1"
    local key="$2"
    [[ -n "${_map["$key"]+_}" ]]
}

# 获取关联数组的值（不存在则输出空字符串）。
function MAP_GET() {
    local -n _map="$1"
    local key="$2"
    printf '%s' "${_map["$key"]}"
}

# 设置关联数组的值。
function MAP_SET() {
    local -n _map="$1"
    local key="$2"
    local value="$3"
    _map["$key"]="$value"
}

# 删除关联数组的 key。
function MAP_DEL() {
    local -n _map="$1"
    local key="$2"
    unset "_map[\"$key\"]"
}
