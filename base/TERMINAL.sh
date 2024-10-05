#!/usr/bin/env bash
# -*- coding: utf-8 -*-

function CLEAR() {
    echo -ne "\ec"
}

function CLEAR_TO_START() {
    echo -ne "\e[1J\e[H"
}

function CLEAR_LINE() {
    echo -ne "\e[K"
}

function CURSOR_TO_START() {
    echo -ne "\e[H"
}

function CLEAR_TO_END() {
    echo -ne "\e[J"
}

function CLEAR_FROM_START_TO_END() {
    echo -ne "\e[H\e[J"
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

function SMOOTH_ECHO() {
    local args=("$@")
    local args_length="${#args[@]}"
    local buffer="${args["$args_length" - 1]}"
    local result="$(CURSOR_TO_START)"

    while IFS= read -r line; do
        result+="${line}$(CLEAR_LINE)"$'\n'
    done <<<"$buffer"

    result+="$(CLEAR_TO_END)"
    echo "${args[@]:0:$args_length-1}" "$result"
}

function DECRQTSR() {
    echo -ne "\e[18t" >/dev/tty
    if [ -e "/proc/$$/fd/3" ]; then
        read -d 't' -s -r response <&3
    else
        read -d 't' -s -r response
    fi
    echo "$response"
}

function _CHECK_DECRQTSR() {
    echo -ne "\e[18t" >/dev/tty
    if [ -e "/proc/$$/fd/3" ]; then
        if ! read -t 0.1 -d 't' -s -r response <&3; then
            read -t 1 -d 't' -s -r response <&3
        fi
    else
        if ! read -t 0.1 -d 't' -s -r response; then
            read -t 1 -d 't' -s -r response
        fi
    fi
    if [ -n "$response" ]; then
        return 0
    else
        return 1
    fi
}

WINDOW_LINES_SOURCE="DECRQTSR"
WINDOW_COLUMNS_SOURCE="DECRQTSR"

if [ -n "$(tput lines 2>/dev/null)" ]; then
    WINDOW_LINES_SOURCE="TPUT"
elif _CHECK_DECRQTSR; then
    WINDOW_LINES_SOURCE="DECRQTSR"
elif [ -n "$LINES" ]; then
    WINDOW_LINES_SOURCE="ENV"
fi

_CHECK_DECRQTSR

if [ -n "$(tput cols 2>/dev/null)" ]; then
    WINDOW_COLUMNS_SOURCE="TPUT"
elif _CHECK_DECRQTSR; then
    WINDOW_COLUMNS_SOURCE="DECRQTSR"
elif [ -n "$COLUMNS" ]; then
    WINDOW_COLUMNS_SOURCE="ENV"
fi

function GET_LINES() {
    case "$WINDOW_LINES_SOURCE" in
    "TPUT")
        tput lines 2>/dev/null
        ;;
    "DECRQTSR")
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
    case "$WINDOW_COLUMNS_SOURCE" in
    "TPUT")
        tput cols 2>/dev/null
        ;;
    "DECRQTSR")
        DECRQTSR | cut -d';' -f1
        ;;
    "ENV")
        echo "$COLUMNS"
        ;;
    *)
        echo "90"
        ;;
    esac
}
