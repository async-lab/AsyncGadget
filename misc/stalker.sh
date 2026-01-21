#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 日志查看器

##############################################
################### META #####################

MODULE_NAME="stalker"

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"

##############################################
################### GLOBAL ###################

SHOW_SOURCE="$*"

PROCESS_TIME=0

MANDATORY_PARAMS=("$SHOW_SOURCE")

STALKER_RESIZED=1
STALKER_CACHE_HIT=0
STALKER_CACHE_WINDOW_LINES=0
STALKER_CACHE_WINDOW_COLUMNS=0
STALKER_CACHE_SOURCE=""
STALKER_CACHE_RAW=""
STALKER_CACHE_CONTENT=""

##############################################
################ PROCESSFUNC #################

function GET_SHOW() {
    local out_var="$1"
    local window_lines="$2"
    local window_columns="$3"

    local -n out="$out_var"
    out=""
    STALKER_CACHE_HIT=0

    local show_lines="$((window_lines - 7))"
    if [ "$show_lines" -lt 0 ]; then
        show_lines=0
    fi
    if [ "$show_lines" -eq 0 ]; then
        return 0
    fi

    local show_file=""
    if [ -f "/var/log/${SHOW_SOURCE}.log" ]; then
        show_file="/var/log/${SHOW_SOURCE}.log"
    elif [ -f "$SHOW_SOURCE" ] || [ -p "$SHOW_SOURCE" ]; then
        show_file="$SHOW_SOURCE"
    fi

    # 对普通文件，避免 `cat file | tail`（pipe 上的 tail 无法 seek，会导致每帧都读完整文件）
    local raw=""
    if [ -n "$show_file" ]; then
        raw="$(tail -n "$show_lines" -- "$show_file" 2>&1)"
    else
        local show_cmd="$SHOW_SOURCE"
        raw="$($show_cmd 2>&1 | tail -n "$show_lines")"
    fi

    if [[ "$raw" == *$'\v'* ]]; then
        local vtab_replace="$(printf "%*s" "$window_columns" ' ')"
        raw="${raw//$'\v'/$vtab_replace}"
    fi

    if [ "$window_lines" -eq "$STALKER_CACHE_WINDOW_LINES" ] \
        && [ "$window_columns" -eq "$STALKER_CACHE_WINDOW_COLUMNS" ] \
        && [ "$SHOW_SOURCE" == "$STALKER_CACHE_SOURCE" ] \
        && [ "$raw" == "$STALKER_CACHE_RAW" ]; then
        out="$STALKER_CACHE_CONTENT"
        STALKER_CACHE_HIT=1
        return 0
    fi

    # cache miss: 需要逐行处理；C locale 下 mapfile 略快（避免多字节字符路径开销）
    local -a raw_lines=()
    LC_ALL=C mapfile -t raw_lines <<<"$raw"

    # 从底部开始补齐 show_lines 行：够了就提前停止，避免对无用行做折行
    local -a rev_lines=()
    local -a segs=()

    local i
    for ((i = ${#raw_lines[@]} - 1; i >= 0; i--)); do
        local needed="$((show_lines - ${#rev_lines[@]}))"
        if [ "$needed" -le 0 ]; then
            break
        fi

        # needed 表示“还差多少显示行”，等价于 `FOLD_LINE | tail -n "$needed"`
        FOLD_LINE_TO_ARRAY segs "$window_columns" "${raw_lines[i]}" "$needed"

        local seg_i
        for ((seg_i = ${#segs[@]} - 1; seg_i >= 0; seg_i--)); do
            rev_lines+=("${segs[seg_i]}")
        done
    done

    local i
    for ((i = ${#rev_lines[@]} - 1; i >= 0; i--)); do
        out+="${rev_lines[i]}"$'\n'
    done

    STALKER_CACHE_WINDOW_LINES="$window_lines"
    STALKER_CACHE_WINDOW_COLUMNS="$window_columns"
    STALKER_CACHE_SOURCE="$SHOW_SOURCE"
    STALKER_CACHE_RAW="$raw"
    STALKER_CACHE_CONTENT="$out"
    return 0
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "用法: stalker.sh <模块名称/文件路径/命令>"
}

function EXIT() {
    XTERM_SYNC_DISABLE
    ENABLE_ECHO
    SHOW_CURSOR
    ALT_SCREEN_DISABLE
    DEFAULT_EXIT "$@"
}

function MAIN() {
    if ! DEFAULT_MAIN; then
        DEFAULT_EXIT 1
    fi

    trap 'STALKER_RESIZED=1' SIGWINCH

    STALKER_RESIZED=0
    ALT_SCREEN_ENABLE

    local seq_clear="$(CLEAR_FROM_START_TO_END)"
    local seq_enable_echo="$(ENABLE_ECHO)"
    local seq_hide_cursor="$(HIDE_CURSOR)"
    local seq_disable_echo="$(DISABLE_ECHO)"

    printf '%s' "$seq_clear"

    local window_lines="$(GET_LINES)"
    local window_columns="$(GET_COLUMNS)"
    while true; do
        local is_resize=1
        if [ "$STALKER_RESIZED" -eq 1 ]; then
            local new_window_lines="$(GET_LINES)"
            local new_window_columns="$(GET_COLUMNS)"

            if [ "$new_window_lines" -ne "$window_lines" ] || [ "$new_window_columns" -ne "$window_columns" ]; then
                window_lines="$new_window_lines"
                window_columns="$new_window_columns"
                is_resize=0
            fi
            STALKER_RESIZED=0
        fi

        local before="$(GET_SYSTEM_STAMP)"
        local content=""
        GET_SHOW content "$window_lines" "$window_columns"

        local now_str=""
        printf -v now_str '%(%F %T)T' -1

        # 内容不变时只刷新头部，避免每帧整屏重绘（降低闪烁/IO）
        if [ "$is_resize" -eq 1 ] && [ "$STALKER_CACHE_HIT" -eq 1 ]; then
            local header=""

            header+="$seq_enable_echo$seq_hide_cursor"
            header+=' _______ _______ _______ _____   __  __ _______ ______  '$'\033[K\n'
            header+='|     __|_     _|   _   |     |_|  |/  |    ___|   __ \ '"      按Ctrl+C关闭"$'\033[K\n'
            header+='|__     | |   | |       |       |     <|    ___|      < '"      处理时间：$PROCESS_TIME ms"$'\033[K\n'
            header+='|_______| |___| |___|___|_______|__|\__|_______|___|__| '"      [ $now_str ]     "$'\033[K\n'
            header+="—————————————————————————————————————————————————————————————————————————————————————————"$'\033[K\n'
            header+=$'\033[K\n'
            header+="$seq_disable_echo"

            printf '\033[?2026h\033[H%s\033[?2026l' "$header"
            CURSOR_MOVE 6 1
        else
            local buffer=""
            if [ "$is_resize" -eq 0 ]; then
                buffer+="$seq_clear"
            fi

            buffer+="$seq_enable_echo$seq_hide_cursor"
            buffer+=' _______ _______ _______ _____   __  __ _______ ______  '$'\n'
            buffer+='|     __|_     _|   _   |     |_|  |/  |    ___|   __ \ '"      按Ctrl+C关闭"$'\n'
            buffer+='|__     | |   | |       |       |     <|    ___|      < '"      处理时间：$PROCESS_TIME ms"$'\n'
            buffer+='|_______| |___| |___|___|_______|__|\__|_______|___|__| '"      [ $now_str ]     "$'\n'
            buffer+="—————————————————————————————————————————————————————————————————————————————————————————"$'\n'$'\n'
            buffer+="$content"
            buffer+="$seq_disable_echo"
            SMOOTH_ECHO -n "$buffer"
            CURSOR_MOVE 6 1
        fi

        local now="$(GET_SYSTEM_STAMP)"
        PROCESS_TIME="$((now - before))"
        if [ "$PROCESS_TIME" -lt 100 ]; then
            if ! NO_OUTPUT sleep 0.1; then
                sleep 1
            fi
        fi
    done
    CLEAR_FROM_START_TO_END

    EXIT 0
}

RUN_MAIN MAIN "$@"
