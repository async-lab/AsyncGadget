#!/usr/bin/env bash
# -*- coding: utf-8 -*-

#
#   0-------------------------------->x
#   | [xxx] xxx
#   | [xxx] xxx
#   | [xxx] xxx
#   |
#   |
#   |
#   v
#   y

function CLEAR() {
    echo -ne "\ec"
}

function CLEAR_TO_START() {
    echo -ne "\e[1J\e[H"
}

function CLEAR_LINE() {
    echo -ne "\e[K"
}

function CLEAR_TO_END() {
    echo -ne "\e[J"
}

function CLEAR_FROM_START_TO_END() {
    echo -ne "\e[H\e[J"
}

function CURSOR_SAVE() {
    echo -ne "\e[s"
}

function CURSOR_RESTORE() {
    echo -ne "\e[u"
}

function CURSOR_MOVE() {
    local x="$1"
    local y="$2"

    if [ "$x" -gt 0 ] && [ "$y" -gt 0 ]; then
        echo -ne "\e[${x};${y}H"
    fi
}

function CURSOR_TO_START() {
    echo -ne "\e[H"
}

function CURSOR_TO_END() {
    echo -ne "\e[99999;99999H"
}

function CURSOR_OFFSET_TO_LINE_START() {
    local n="$1"

    if [ "$n" -gt 0 ]; then
        echo -ne "\e[${n}E"
    elif [ "$n" -lt 0 ]; then
        n="$((-n))"
        echo -ne "\e[${n}F"
    else
        echo -ne "\e[G"
    fi
}

function CURSOR_OFFSET() {
    local x="$1"
    local y="$2"

    if [ "$x" -gt 0 ]; then
        echo -ne "\e[${x}C"
    elif [ "$x" -lt 0 ]; then
        x="$((-x))"
        echo -ne "\e[${x}D"
    fi

    if [ "$y" -gt 0 ]; then
        echo -ne "\e[${y}B"
    elif [ "$y" -lt 0 ]; then
        y="$((-y))"
        echo -ne "\e[${y}A"
    fi
}

function CURSOR_MOVE_HORIZONTAL() {
    local n="$1"

    if [ "$n" -gt 0 ]; then
        echo -ne "\e[${n}G"
    fi
}

function HIDE_CURSOR() {
    echo -ne "\e[?25l"
}

function SHOW_CURSOR() {
    echo -ne "\e[?25h"
}

function DISABLE_ECHO() {
    echo -ne "\033[8m"
}

function ENABLE_ECHO() {
    echo -ne "\e[0m"
}

function ECHO_COLOR() {
    local args=("$@")
    echo "$(echo -ne "\e[${1}m")${args["${#args[@]}" - 1]}$(echo -ne "\e[0m")"
}

function DEC_REQUEST() {
    local request="$1"
    local end_mark="$2"

    echo -ne "$request" >/dev/tty
    read -d "$end_mark" -s -r response <&"$STDIN"
    echo "$response"
}

function DSR() {
    DEC_REQUEST '\e[6n' 'R'
}

function DECRQTSR() {
    DEC_REQUEST '\e[18t' 't'
}

function _CHECK_DECRQTSR() {
    echo -ne "\e[18t" >/dev/tty
    if ! read -t 0.1 -d 't' -s -r response 2>/dev/null; then
        read -t 1 -d 't' -s -r response
    fi
    if [ -n "$response" ]; then
        return 0
    else
        return 1
    fi
}

WINDOW_INFO_SOURCE="CONST"

if command -v tput >/dev/null 2>&1; then
    WINDOW_INFO_SOURCE="TPUT"
elif command -v stty >/dev/null 2>&1; then
    WINDOW_INFO_SOURCE="STTY"
elif _CHECK_DECRQTSR <&"$STDIN"; then
    WINDOW_INFO_SOURCE="DEC"
elif [ -n "$LINES" ]; then
    WINDOW_INFO_SOURCE="ENV"
fi

function GET_LINES() {
    case "$WINDOW_INFO_SOURCE" in
    "TPUT")
        tput lines 2>/dev/null
        ;;
    "STTY")
        stty size 2>/dev/nul <&"$STDIN" | cut -d' ' -f1
        ;;
    "DEC")
        DECRQTSR | cut -d';' -f2
        ;;
    "ENV")
        echo "$LINES"
        ;;
    *)
        echo "30"
        ;;
    esac
}

function GET_COLUMNS() {
    case "$WINDOW_INFO_SOURCE" in
    "TPUT")
        tput cols 2>/dev/null
        ;;
    "STTY")
        stty size 2>/dev/nul <&"$STDIN" | cut -d' ' -f2
        ;;
    "DEC")
        DECRQTSR | cut -d';' -f3
        ;;
    "ENV")
        echo "$COLUMNS"
        ;;
    *)
        echo "90"
        ;;
    esac
}

function GET_LINE_SHOW_LENGTH() {
    local length=0
    while IFS= read -r -n1 char; do
        case "$char" in
        $'\t') ((length += 8 - length % 8)) ;;
        # $'v') ((length += "$(GET_COLUMNS)")) ;;
        [[:cntrl:]] | '') ;;
        [a-zA-Z0-9\!\"\#\$%\&\'\(\)\*\+\,-\./:\;\<=\>\?\@\[\\\]^_\`\{\|\}\~] | ' ') ((length++)) ;;
        $'\xe2\x80\x8b' | $'\xe2\x80\x8c' | $'\xe2\x80\x8d' | $'\xe2\x80\x8e ') ;;
        [一-龥] | [ぁ-ゔ] | [ァ-ヴー] | [々〆〤] | [㈠-㉃]) ((length += 2)) ;;
        *) ;;
        esac
    done <<<"$(echo "$*" | sed -r 's/\x1B\[[0-9;]*[mKABCDHf]//g')"

    echo "$length"
}

function FOLD() {
    local str=("$@")
    local window_columns="$(GET_COLUMNS)"
    local result=""

    while IFS= read -r line; do
        while true; do
            local line_show_length="$(GET_LINE_SHOW_LENGTH "$line")"
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
                    local cut_show_length="$(GET_LINE_SHOW_LENGTH "${line:0:$cut_length}")"

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
    done <<<"${str[@]}"

    echo -n "$result"
}

function EXPAND() {
    local str="$*"
    local result=""

    while IFS= read -r line; do
        if echo "$line" | grep -q $'\t'; then
            local expanded_line=""

            for ((i = 0; i < ${#line}; i++)); do
                local char="${line:$i:1}"
                if [[ "$char" == $'\t' ]]; then
                    local space_count=$((8 - $(GET_LINE_SHOW_LENGTH "${line:0:$i}") % 8))
                    expanded_line+=$(printf "%${space_count}s")
                else
                    expanded_line+="$char"
                fi
            done

            result+="$expanded_line"$'\n'
        else
            result+="$line"$'\n'
        fi
    done <<<"$str"

    echo "$result"
}

function SMOOTH_ECHO() {
    local window_columns="$(GET_COLUMNS)"
    local args=("$@")
    local args_length="${#args[@]}"
    local buffer="${args["$args_length" - 1]}"
    buffer="$(EXPAND "$buffer")"

    local result="$(CURSOR_TO_START)"
    local line_show_length=0
    while IFS= read -r line; do
        line_show_length="$(GET_LINE_SHOW_LENGTH "$line")"
        line="$(echo "$line" | expand)"
        result+="${line}"
        if [ "$line_show_length" -ne "$window_columns" ]; then
            result+="$(CLEAR_LINE)"
        fi
        result+=$'\n'
    done <<<"$buffer"
    result="${result%"$(CLEAR_LINE)"$'\n'}"
    result="${result%$'\n'}"

    if [ "$line_show_length" -eq "$window_columns" ]; then
        result+=$'\n'
    fi
    result+="$(CLEAR_TO_END)"

    echo "${args[@]:0:$args_length-1}" "$result"
}
