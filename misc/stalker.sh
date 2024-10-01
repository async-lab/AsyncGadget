#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 日志查看器，封装tail

##############################################

DIR=$(readlink -f "$(dirname "$0")")
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/IO.sh"
source "$ROOT_DIR/base/LOG.sh"
source "$ROOT_DIR/base/UTIL.sh"

##############################################

NAME="$1"
LINES="${2:-30}"

function USAGE() {
    LOG "请输入正确的参数!"
    LOG "用法: stalker.sh <模块名称> [行数]"
}

function CLEAR() {
    echo -e "\ec"
}

function EXIT {
    LOG "退出stalker..."
    exit "$@"
}

function CHECK_PARAMS() {
    CHECK_IF_ALL_EXIST "$NAME"
    return "$?"
}

function MAIN() {

    if ! CHECK_PARAMS; then
        USAGE
        EXIT 1
    fi

    if [ ! -f "/var/log/$NAME.log" ]; then
        LOG "日志文件不存在!"
        EXIT 1
    else
        CLEAR
        watch -n 0.1 tail -n "$LINES" "/var/log/$NAME.log"
        CLEAR
    fi

    EXIT 0
}

trap EXIT SIGINT SIGTERM

MAIN "$@"
