#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 日志查看器

##############################################
################### META #####################

MODULE_NAME="stalker"

DIR=$(readlink -f "$(dirname "$0")")
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"

##############################################
################### GLOBAL ###################

SHOW_SOURCE="$*"

PROCESS_TIME=0

MANDATORY_PARAMS=("$SHOW_SOURCE")

##############################################
################ PROCESSFUNC #################

function GET_SHOW() {
    local show_cmd="$SHOW_SOURCE"
    local window_lines="$(GET_LINES)"
    local window_columns="$(GET_COLUMNS)"
    if [ ! -f "$DATA_TMP_FILE" ]; then
        return
    fi
    IFS=, read -r lines columns <"$DATA_TMP_FILE"
    if [ "$lines" -ne "$window_lines" ] || [ "$columns" -ne "$window_columns" ]; then
        echo "$window_lines,$window_columns" >"$DATA_TMP_FILE"
        echo 0 >"$STD_TMP_FILE"
    else
        echo 1 >"$STD_TMP_FILE"
    fi

    local show_lines="$((window_lines - 7))"
    if [ "$show_lines" -lt 0 ]; then
        show_lines=0
    fi

    if [ -f "/var/log/${SHOW_SOURCE}.log" ]; then
        show_cmd="cat /var/log/${SHOW_SOURCE}.log"
    elif [ -f "$SHOW_SOURCE" ] || [ -p "$SHOW_SOURCE" ]; then
        show_cmd="cat ${SHOW_SOURCE}"
    fi

    $show_cmd 2>&1 | tail -n "$show_lines" | sed "s/"$'\v'"/$(printf "%*s" "$window_columns" ' ')/g" | STDIN FOLD | tail -n "$show_lines"
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "用法: stalker.sh <模块名称/文件路径/命令>"
}

function EXIT() {
    ENABLE_ECHO
    SHOW_CURSOR
    CLEAR
    DEFAULT_EXIT "$@"
}

function ASCII_ART() {
    echo ' _______ _______ _______ _____   __  __ _______ ______  '
    echo '|     __|_     _|   _   |     |_|  |/  |    ___|   __ \ '"      按Ctrl+C关闭"
    echo '|__     | |   | |       |       |     <|    ___|      < '"      处理时间：$PROCESS_TIME ms"
    echo '|_______| |___| |___|___|_______|__|\__|_______|___|__| '"      [ $(date +"%F %T") ]     "
}

function MAIN() {
    if ! DEFAULT_MAIN; then
        DEFAULT_EXIT 1
    fi

    echo "$(GET_LINES),$(GET_COLUMNS)" >"$DATA_TMP_FILE"
    CLEAR
    while true; do
        local before="$(GET_SYSTEM_STAMP)"
        local content="$(GET_SHOW)"

        local buffer=""
        if [ -f "$STD_TMP_FILE" ]; then
            read -r is_resize <"$STD_TMP_FILE"
            if [ "$is_resize" -eq 0 ]; then
                buffer+="$(CLEAR)"
            fi
        fi
        buffer+="$(ENABLE_ECHO)$(HIDE_CURSOR)"
        buffer+="$(ASCII_ART)"$'\n'
        buffer+="—————————————————————————————————————————————————————————————————————————————————————————"$'\n'$'\n'
        buffer+="$content"
        buffer+="$(DISABLE_ECHO)"
        SMOOTH_ECHO -n "$buffer"
        CURSOR_MOVE 6 1

        local now="$(GET_SYSTEM_STAMP)"
        PROCESS_TIME="$((now - before))"
        if [ "$PROCESS_TIME" -lt 100 ]; then
            if ! NO_OUTPUT sleep 0.1; then
                sleep 1
            fi
        fi
    done
    CLEAR

    EXIT 0
}

RUN_MAIN MAIN "$@"
