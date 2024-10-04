#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 日志查看器，封装tail

##############################################
################### META #####################

MODULE_NAME="stalker"

DIR=$(readlink -f "$(dirname "$0")")
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"

##############################################
################### GLOBAL ###################

SHOW_MODULE_NAME="$1"
SHOW_LINES="${2:-30}"

##############################################
################# TOOLFUNC ###################

function USAGE() {
    LOG "请输入正确的参数!"
    LOG "用法: stalker.sh <模块名称> [行数]"
}

##############################################
################ PROGRAMFUNC #################

function EXIT() {
    SHOW_CURSOR
    CLEAR
    DEFAULT_EXIT "$@"
}

function CHECK_PARAMS() {
    CHECK_IF_ALL_EXIST "$SHOW_MODULE_NAME" "$SHOW_LINES"
    return "$?"
}

function ASCII_ART() {
    printf '%s\n' ' _______ _______ _______ _____   __  __ _______ ______  '
    printf '%s\n' '|     __|_     _|   _   |     |_|  |/  |    ___|   __ \ '
    printf '%s\n' '|__     | |   | |       |       |     <|    ___|      < '
    printf '%s\n' '|_______| |___| |___|___|_______|__|\__|_______|___|__| '
}

function MAIN() {
    local buffer=""

    if ! CHECK_PARAMS; then
        USAGE
        EXIT 1
    fi

    if [ ! -f "/var/log/$SHOW_MODULE_NAME.log" ]; then
        LOG "日志文件不存在!"
        EXIT 1
    else
        CLEAR
        while true; do
            buffer="$(CLEAR_TO_START)$(HIDE_CURSOR)"
            buffer+="$(ASCII_ART)      [ $(date +"%F %T") ]"$'\n'
            buffer+="————————————————————————————————————————————————————————————————————————————————————————"$'\n'
            buffer+=$'\n'
            buffer+="$(tail -n "$SHOW_LINES" "/var/log/$SHOW_MODULE_NAME.log")"
            echo "$buffer"
            if ! NO_OUTPUT sleep 0.1; then
                sleep 1
            fi
        done
        CLEAR
    fi

    EXIT 0
}

MAIN "$@"
