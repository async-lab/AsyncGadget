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
        read -t 1 -d 't' -s -r response <&3
    else
        read -t 1 -d 't' -s -r response
    fi
    echo "$response"
}

function GET_LINES() {
    local lines=""
    if [ -z "$lines" ]; then
        lines=$(tput lines 2>/dev/null)
    fi
    if [ -z "$lines" ]; then
        lines="$(DECRQTSR | cut -d';' -f2)"
    fi
    if [ -z "$lines" ]; then
        lines="$LINES"
    fi
    if [ -z "$lines" ]; then
        lines=30
    fi
    echo "$lines"
}

function GET_COLUMNS() {
    local columns=""
    if [ -z "$columns" ]; then
        columns=$(tput columns 2>/dev/null)
    fi
    if [ -z "$columns" ]; then
        columns="$(DECRQTSR | cut -d';' -f3)"
    fi
    if [ -z "$columns" ]; then
        columns="$COLUMNS"
    fi
    if [ -z "$columns" ]; then
        columns=90
    fi
    echo "$columns"
}
