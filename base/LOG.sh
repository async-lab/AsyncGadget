#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 日志

##############################################

MAX_LOG_LINES=${MAX_LOG_LINES:-1000}

function GET_LOG_FILE_PATH() {
    echo "/var/log/${MODULE_NAME}.log"
}

function LIMIT_LOG_LINES() {
    local log_lines="$(wc -l <"$(GET_LOG_FILE_PATH)")"
    local extra_lines="$((log_lines - MAX_LOG_LINES))"

    if [ $extra_lines -gt 0 ]; then
        sed -i "1,${extra_lines}d" "$(GET_LOG_FILE_PATH)"
    fi
}

##############################################

function STDOUT() {
    echo -ne "\r\e[K"
    echo "$@"
}

function STDERR() {
    echo -ne "\r\e[K" >&2
    echo "$@" >&2
}

function STDFILE() {
    local file="$(GET_LOG_FILE_PATH)"

    if [ "${file##*.}" != "log" ]; then
        return 1
    fi

    touch "$file"

    LIMIT_LOG_LINES

    if [ "$(tail -c1 "$file")" != $'' ]; then
        sed -i '$ d' "$file"
    fi
    echo "$@" >>"$file"

    return 0
}

##############################################

function LOG() {
    STDOUT "[$(date +"%F %T")] $*"
}

function LOG_MULTILINE() {
    local line
    while IFS= read -r line; do
        LOG "$line"
    done
}

function STATE() {
    STDOUT -n "[ 状态 ] $*"
}

##############################################

function SET_LOG_TYPE() {
    LOG_TYPE="$1"

    case "$LOG_TYPE" in
    "console")
        function STDOUT() {
            echo -ne "\r\e[K"
            echo "$@"
        }
        function LOG() {
            STDOUT "[$(date +"%F %T")] $*"
        }
        function STATE() {
            STDOUT -n "[ 状态 ] $*"
        }
        ;;
    "file")
        function STDOUT() {
            echo "$@" " "
        }
        function LOG() {
            STDOUT "$@"
            STDFILE "[$(date +"%F %T")] $*"
        }
        function STATE() {
            STDFILE -n "[ 状态 ] $*"
        }
        ;;
    *) ;;
    esac
}

if [ -n "$TERM" ] && [ -z "$LOG_IN_FILE" ]; then
    SET_LOG_TYPE "console"
else
    SET_LOG_TYPE "file"
fi
