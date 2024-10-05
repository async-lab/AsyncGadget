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

SHOW_SOURCE="$1"

##############################################
################# TOOLFUNC ###################

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "请输入正确的参数!"
    LOG "用法: stalker.sh <模块名称/文件路径/命令>"
}

function EXIT() {
    ENABLE_ECHO
    SHOW_CURSOR
    clear
    DEFAULT_EXIT "$@"
}

function CHECK_PARAMS() {
    CHECK_IF_ALL_EXIST "$SHOW_SOURCE"
    return "$?"
}

function GET_SHOW() {
    local show_cmd="$SHOW_SOURCE"
    local window_lines="$(GET_LINES)"
    local window_columns="$(GET_COLUMNS)"

    IFS=, read -r lines columns <"$DATA_TMP_FILE"
    if [ "$lines" -ne "$window_lines" ] || [ "$columns" -ne "$window_columns" ]; then
        echo "$window_lines,$window_columns" >"$DATA_TMP_FILE"
        CLEAR
    fi

    local show_lines="$((window_lines - 7))"
    if [ "$show_lines" -lt 0 ]; then
        show_lines=0
    fi

    if [ -f "/var/log/${SHOW_SOURCE}.log" ]; then
        show_cmd="tail -n ${show_lines} /var/log/${SHOW_SOURCE}.log"
    elif [ -f "$SHOW_SOURCE" ]; then
        show_cmd="tail -n ${show_lines} ${SHOW_SOURCE}"
    fi

    local raw_result="$($show_cmd)"
    local result=""

    local total_lines=0
    while IFS= read -r line; do
        while true; do
            if [ "$total_lines" -eq "$show_lines" ]; then
                break
            fi

            if [ "${#line}" -gt "$window_columns" ]; then
                result+="${line:0:$window_columns}"$'\n'
                line="${line:$window_columns}"
                total_lines="$((total_lines + 1))"
            else
                result+="$line"$'\n'
                total_lines="$((total_lines + 1))"
                break
            fi
        done
    done <<<"$raw_result"

    echo "$result"
}

function ASCII_ART() {
    echo ' _______ _______ _______ _____   __  __ _______ ______  '
    echo '|     __|_     _|   _   |     |_|  |/  |    ___|   __ \ '
    echo '|__     | |   | |       |       |     <|    ___|      < '
    echo '|_______| |___| |___|___|_______|__|\__|_______|___|__| '
}

function MAIN() {
    local buffer=""

    if ! CHECK_PARAMS; then
        USAGE
        DEFAULT_EXIT 1
    fi

    echo "$(GET_LINES),$(GET_COLUMNS)" >"$DATA_TMP_FILE"

    CLEAR
    while true; do
        local content="$(GET_SHOW)"
        buffer="$(ENABLE_ECHO)$(HIDE_CURSOR)"
        buffer+="$(ASCII_ART)      [ $(date +"%F %T") ]"$'\n'
        buffer+="—————————————————————————————————————————————————————————————————————————————————————————"$'\n'$'\n'
        buffer+="${content}"
        buffer+="$(DISABLE_ECHO)"
        SMOOTH_ECHO -n "$buffer"
        if ! NO_OUTPUT sleep 0.1; then
            sleep 1
        fi
    done
    CLEAR

    EXIT 0
}

RUN_MAIN MAIN "$@"
