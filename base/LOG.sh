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
    echo -ne "\r\033[K"
    echo "$@"
}

function STDERR() {
    echo -ne "\r\033[K" >&2
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
    STDOUT "[$(date +"%Y-%m-%d %H:%M:%S")] $*"
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
            echo -ne "\r\033[K"
            echo "$@"
        }
        function LOG() {
            STDOUT "[$(date +"%Y-%m-%d %H:%M:%S")] $*"
        }
        function STATE() {
            STDOUT -n "[ 状态 ] $*"
        }
        ;;
    "systemd")
        function STDOUT() {
            echo "$@" " "
        }
        function LOG() {
            STDOUT "$@"
            STDFILE "[$(date +"%Y-%m-%d %H:%M:%S")] $*"
        }
        function STATE() {
            STDFILE -n "[ 状态 ] $*"
        }
        ;;
    *) ;;
    esac
}

if [ -z "$INVOCATION_ID" ]; then
    SET_LOG_TYPE "console"
else
    SET_LOG_TYPE "systemd"
fi
