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

CHECK_ENTER_PID=""

DEPENDED_PACKAGES=("fold")
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

    local window_columns="$(GET_COLUMNS)"
    local result=""

    while IFS= read -r line; do
        while true; do

            local line_show_length=0
            while IFS= read -r -n1 char; do
                case "$char" in
                $'\t') ((line_show_length += 8 - line_show_length % 8)) ;;
                # $'v') ((length += "$(GET_COLUMNS)")) ;;
                [[:cntrl:]] | '') ;;
                [a-zA-Z0-9.~_-] | ' ') ((line_show_length++)) ;;
                $'\xe2\x80\x8b' | $'\xe2\x80\x8c' | $'\xe2\x80\x8d' | $'\xe2\x80\x8e ') ;;
                [一-龥] | [ぁ-ゔ] | [ァ-ヴー] | [々〆〤] | [㈠-㉃]) ((line_show_length += 2)) ;;
                *) ;;
                esac
            done <<<"$line"

            if [ "$line_show_length" -le "$window_columns" ]; then
                result+="${line}"$'\n'
                break
            else
                local mark=2
                local line_length="${#line}"
                local cut_length="$((line_length / 2))"
                local step="$((line_length / 4))"
                if [ "$step" -lt 1 ]; then
                    step=1
                fi
                local latest_step="$step"
                while true; do

                    local cut_show_length=0
                    while IFS= read -r -n1 char; do
                        case "$char" in
                        $'\t') ((cut_show_length += 8 - cut_show_length % 8)) ;;
                        # $'v') ((length += "$(GET_COLUMNS)")) ;;
                        [[:cntrl:]] | '') ;;
                        [a-zA-Z0-9.~_-] | ' ') ((cut_show_length++)) ;;
                        $'\xe2\x80\x8b' | $'\xe2\x80\x8c' | $'\xe2\x80\x8d' | $'\xe2\x80\x8e ') ;;
                        [一-龥] | [ぁ-ゔ] | [ァ-ヴー] | [々〆〤] | [㈠-㉃]) ((cut_show_length += 2)) ;;
                        *) ;;
                        esac
                    done <<<"${line:0:$cut_length}"

                    if [ "$cut_show_length" -lt "$window_columns" ]; then
                        if [ "$mark" -eq 1 ] && [ "$latest_step" -eq 1 ]; then
                            break
                        fi
                        ((cut_length += step))
                        latest_step="$step"
                        if [ "$mark" -eq 1 ] && [ "$step" -gt 1 ]; then
                            ((step /= 2))
                        fi
                        mark=0
                    elif [ "$cut_show_length" -gt "$window_columns" ]; then
                        if [ "$mark" -eq 0 ] && [ "$latest_step" -eq 1 ]; then
                            ((cut_length--))
                            break
                        fi
                        ((cut_length -= step))
                        latest_step="$step"
                        if [ "$mark" -eq 0 ] && [ "$step" -gt 1 ]; then
                            ((step /= 2))
                        fi
                        mark=1
                    else
                        break
                    fi
                done
                result+="${line:0:$cut_length}"$'\n'
                line="${line:$cut_length}"
            fi
        done
    done <<<"$($show_cmd 2>&1 | tail -n "$show_lines" | sed "s/"$'\v'"/$(printf "%*s" "$window_columns" ' ')/g")"

    echo -n "$result" | tail -n "$show_lines"
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

PROCESS_TIME=0

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

        local window_columns="$(GET_COLUMNS)"

        local p2=""

        while IFS= read -r line; do
            if echo "$line" | grep -q $'\t'; then
                local expanded_line=""

                for ((i = 0; i < ${#line}; i++)); do
                    local char="${line:$i:1}"
                    if [[ "$char" == $'\t' ]]; then
                        local space_count=0
                        while IFS= read -r -n1 char; do
                            case "$char" in
                            $'\t') ((line_show_length += 8 - line_show_length % 8)) ;;
                            [[:cntrl:]] | '') ;;
                            [a-zA-Z0-9.~_-] | ' ') ((line_show_length++)) ;;
                            $'\xe2\x80\x8b' | $'\xe2\x80\x8c' | $'\xe2\x80\x8d' | $'\xe2\x80\x8e ') ;;
                            [一-龥] | [ぁ-ゔ] | [ァ-ヴー] | [々〆〤] | [㈠-㉃]) ((line_show_length += 2)) ;;
                            *) ;;
                            esac
                        done <<<"${line:0:$i}"

                        local space_count=$((8 - space_count % 8))
                        expanded_line+=$(printf "%${space_count}s")
                    else
                        expanded_line+="$char"
                    fi
                done

                p2+="$expanded_line"$'\n'
            else
                p2+="$line"$'\n'
            fi
        done <<<"$buffer"

        buffer="$p2"

        local p1="$(CURSOR_TO_START)"
        local line_show_length=0
        while IFS= read -r line; do
            local line_show_length=0
            while IFS= read -r -n1 char; do
                case "$char" in
                $'\t') ((line_show_length += 8 - line_show_length % 8)) ;;
                # $'v') ((length += "$(GET_COLUMNS)")) ;;
                [[:cntrl:]] | '') ;;
                [a-zA-Z0-9.~_-] | ' ') ((line_show_length++)) ;;
                $'\xe2\x80\x8b' | $'\xe2\x80\x8c' | $'\xe2\x80\x8d' | $'\xe2\x80\x8e ') ;;
                [一-龥] | [ぁ-ゔ] | [ァ-ヴー] | [々〆〤] | [㈠-㉃]) ((line_show_length += 2)) ;;
                *) ;;
                esac
            done <<<"$line"
            p1+="${line}"
            if [ "$line_show_length" -ne "$window_columns" ]; then
                p1+="$(CLEAR_LINE)"
            fi
            p1+=$'\n'
        done <<<"$buffer"
        p1="${p1%"$(CLEAR_LINE)"$'\n'}"
        p1="${p1%$'\n'}"

        if [ "$line_show_length" -eq "$window_columns" ]; then
            p1+=$'\n'
        fi
        p1+="$(CLEAR_TO_END)"

        echo -n "$p1"

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
