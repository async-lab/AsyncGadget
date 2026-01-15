#!/usr/bin/env bash
# -*- coding: utf-8 -*-

function PLUS() {
    local a="$1"
    local b="$2"

    awk -v n1="$a" -v n2="$b" 'BEGIN { printf "%.0f", n1 + n2 }'
}

function MINUS() {
    local a="$1"
    local b="$2"

    awk -v n1="$a" -v n2="$b" 'BEGIN { printf "%.0f", n1 - n2 }'
}

function MULTIPLY() {
    local a="$1"
    local b="$2"

    awk -v n1="$a" -v n2="$b" 'BEGIN { printf "%.0f", n1 * n2 }'
}

function DIVIDE() {
    local a="$1"
    local b="$2"

    awk -v n1="$a" -v n2="$b" 'BEGIN { printf "%.0f", n1 / n2 }'
}
