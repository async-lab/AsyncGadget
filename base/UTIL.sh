#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 检查包是否存在
function CHECK_PACKAGE() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    elif command -v dpkg >/dev/null 2>&1; then
        dpkg -l | grep -qw "$1"
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$1" >/dev/null 2>&1
    elif command -v brew >/dev/null 2>&1; then
        brew list "$1" >/dev/null 2>&1
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Qs "$1" >/dev/null 2>&1
    elif command -v pkg >/dev/null 2>&1; then
        pkg info "$1" >/dev/null 2>&1
    elif command -v opkg >/dev/null 2>&1; then
        local output="$(opkg info "$1")"
        if [ -n "$output" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi

    return "$?"
}

# URL 编码函数
function URLENCODE() {
    local length="${#1}"
    for ((i = 0; i < length; i++)); do
        local c="${1:i:1}"
        case $c in
        [a-zA-Z0-9.~_-])
            printf '%s\n' "$c"
            ;;
        *)
            printf '%%%02X' "'$c"
            ;;
        esac
    done
}

function PERIOD_TO_SECONDS() {
    local period="$1"

    case "$period" in
    *[0-9]s)
        echo "${period%s}"
        ;;
    *[0-9]m)
        echo $((${period%m} * 60))
        ;;
    *[0-9]h)
        echo $((${period%h} * 3600))
        ;;
    *)
        echo ""
        ;;
    esac
}

function FIND_POSITION() {
    local str="$1"
    local sub="$2"

    local sub_length=${#sub}
    local end=$(("${#str}" - length + 1))
    local i

    for ((i = 0; i < end; i++)); do
        if [[ "${str:i:sub_length}" == "$sub" ]]; then
            echo $((i + 1))
        fi
    done
}

function GET_SYSTEM_STAMP() {
    local now_stamp="$(awk '{print $1}' <"/proc/uptime")"
    echo "${now_stamp//./}"
}

function TRIM() {
    local str="$1"

    echo "${str}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
