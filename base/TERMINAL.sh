#!/usr/bin/env bash
# -*- coding: utf-8 -*-

function CLEAR() {
    echo -ne "\e[1J\e[H"
}

function HIDE_CURSOR() {
    echo -ne "\e[?25l"
}

function SHOW_CURSOR() {
    echo -ne "\e[?25h"
}
