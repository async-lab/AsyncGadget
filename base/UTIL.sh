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

function FIND_POSITION() {
    local str="$1"
    local sub="$2"

    local sub_length=${#sub}
    local end=$(("${#str}" - sub_length + 1))
    local i

    for ((i = 0; i < end; i++)); do
        if [[ "${str:i:sub_length}" == "$sub" ]]; then
            echo $((i + 1))
        fi
    done
}

function GET_SYSTEM_STAMP() {
    # 用于耗时统计的时间戳（毫秒）
    # 默认使用 /proc/uptime（单调递增，通常 10ms 精度）
    local uptime=""
    IFS=' ' read -r uptime _ </proc/uptime

    local sec="${uptime%.*}"
    local frac="${uptime#*.}"
    frac="${frac}00"
    frac="${frac:0:2}"

    echo "$((10#$sec * 1000 + 10#$frac * 10))"
}

if [ -n "${EPOCHREALTIME-}" ]; then
    function GET_SYSTEM_STAMP() {
        local now="${EPOCHREALTIME/./}"
        echo "${now:0:-3}"
    }
else
    __TEST_STAMP="$(date +%s%3N 2>/dev/null)"
    if [[ "$__TEST_STAMP" =~ ^[0-9]+$ ]]; then
        function GET_SYSTEM_STAMP() { date +%s%3N; }
    elif [ -r /proc/timer_list ]; then
        function GET_SYSTEM_STAMP() {
            local nsecs=""

            local line=""
            while IFS= read -r line; do
                case "$line" in
                'now at '*)
                    nsecs="${line#now at }"
                    nsecs="${nsecs%% *}"
                    break
                    ;;
                esac
            done </proc/timer_list

            if [[ "$nsecs" =~ ^[0-9]+$ ]] && [ ${#nsecs} -gt 6 ]; then
                echo "${nsecs:0:${#nsecs}-6}"
            else
                echo 0
            fi
        }
    fi
    unset __TEST_STAMP
fi

function IS_RUNNING() {
    local pid="$1"

    if [ -r "/proc/$pid/stat" ]; then
        local state
        state="$(NO_ERR awk "{print \$3}" "/proc/$pid/stat")"
        if [ -z "$state" ] || [ "$state" == "Z" ]; then
            return 1
        fi
        return 0
    fi

    NO_OUTPUT kill -0 "$pid"
    return "$?"
}
