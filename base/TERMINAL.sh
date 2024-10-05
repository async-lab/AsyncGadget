#!/usr/bin/env bash
# -*- coding: utf-8 -*-

function CLEAR_TO_START() {
    echo -ne "\e[1J\e[H"
}

function CLEAR() {
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

function DECRQTSR() {
    echo -ne "\e[18t" >/dev/tty
    if [ -e "/proc/$$/fd/3" ]; then
        read -d 't' -s -r response <&3
    else
        read -d 't' -s -r response
    fi
    echo "$response"
}

function GET_LINES() {
    DECRQTSR | cut -d';' -f2
}

function GET_COLUMNS() {
    DECRQTSR | cut -d';' -f3
}
