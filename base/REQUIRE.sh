#!/usr/bin/env bash
# -*- coding: utf-8 -*-

if [ -n "${__REQUIRE_LIB_LOADED-}" ]; then
    return 0
fi
__REQUIRE_LIB_LOADED=1


declare -gA __INCLUDED_LIBS=()

function REQUIRE() {
    local target="$1"

    # 1. 字符串快路径：若完全相同的入参路径已加载过，0 子进程 0 开销直接返回
    if [ -n "${__INCLUDED_LIBS["$target"]+_}" ]; then
        return 0
    fi

    if [ -d "$target" ]; then
        LOG "REQUIRE 错误: 目标是目录而非文件: $target" 2>/dev/null || echo "[REQUIRE 错误] 目标是目录: $target" >&2
        return 1
    fi

    # 2. 规范化物理绝对路径 (兼容相对路径/软链接/BusyBox/GNU)
    local real_path
    real_path="$(realpath "$target" 2>/dev/null || readlink -f "$target" 2>/dev/null || echo "$target")"

    # 3. 物理路径快路径：若物理文件已加载过，记录该别名并秒退
    if [ -n "${__INCLUDED_LIBS["$real_path"]+_}" ]; then
        __INCLUDED_LIBS["$target"]=1
        return 0
    fi

    # 4. 文件存在性校验
    if [ ! -f "$real_path" ]; then
        LOG "REQUIRE 错误: 文件不存在: $target" 2>/dev/null || echo "[REQUIRE 错误] 文件不存在: $target" >&2
        return 1
    fi

    # 5. 先行打标（防止循环依赖死递归栈溢出）
    __INCLUDED_LIBS["$target"]=1
    __INCLUDED_LIBS["$real_path"]=1

    # 6. 真正 source 执行
    if ! source "$real_path"; then
        unset "__INCLUDED_LIBS[$target]" "__INCLUDED_LIBS[$real_path]"
        return 1
    fi
}