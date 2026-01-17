#!/usr/bin/env bash
# -*- coding: utf-8 -*-

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

function TRIM() {
    local str="$1"

    echo "${str}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

function RAW_TO_HUMAN() {
    local input="${1:-0}"
    
    input="$(TRIM "$input")"
    case "$input" in
        ''|*[!0-9]*) input=0 ;;
    esac

    if (( input < 1024 )); then
        echo "${input}"
        return
    fi

    local suffixes=("" "K" "M" "G" "T" "P")
    local i=0
    local val=$input

    while (( input >= 1024 && i < 5 )); do
        (( input /= 1024 ))
        (( i++ ))
    done

    awk -v n="$val" -v i="$i" -v unit="${suffixes[$i]}" 'BEGIN {
        divisor = 1024 ^ i;
        printf "%.1f%s\n", n / divisor, unit
    }'
}

function HUMAN_TO_RAW() {
    local input="$1"
    
    input="$(TRIM "$input")"
    [ -z "$input" ] && echo 0 && return

    local unit="${input: -1}"
    local number="${input}"
    local factor=1

    case "${unit,,}" in
        k) factor=1024; number="${input%?}" ;;
        m) factor=$((1024 * 1024)); number="${input%?}" ;;
        g) factor=$((1024 * 1024 * 1024)); number="${input%?}" ;;
        t) factor=$((1024 * 1024 * 1024 * 1024)); number="${input%?}" ;;
        p) factor=$((1024 * 1024 * 1024 * 1024 * 1024)); number="${input%?}" ;;
        *) ;;
    esac

    awk -v n="$number" -v f="$factor" 'BEGIN { printf "%.0f", n * f }'
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