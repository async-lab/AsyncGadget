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
