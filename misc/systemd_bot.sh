#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 自动创建简单的systemd服务

##############################################
################### META #####################

MODULE_NAME="systemd_bot"

DIR=$(readlink -f "$(dirname "$0")")
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"

##############################################
################### GLOBAL ###################

METHOD="$1"
TYPE="$2"
NAME="$3"
PARAM="$4"

MANDATORY_PARAMS=("$METHOD" "$TYPE" "$NAME")

##############################################
################ PROCESSFUNC #################

function CREATE_SERVICE() {
    cat <<EOF >"/etc/systemd/system/$1.service"
[Unit]
Description=$1
After=network.target

[Service]
ExecStart=$2
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$1"
    systemctl restart "$1"
}

function CREATE_TIMER() {
    cat <<EOF >"/etc/systemd/system/$1.timer"
[Unit]
Description=$1 timer

[Timer]
OnCalendar=$2

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable "$1.timer"
    systemctl restart "$1.timer"
}

function DELETE_SERVICE() {
    systemctl stop "$1"
    systemctl disable "$1"
    rm "/etc/systemd/system/$1.service"
    systemctl daemon-reload
}

function DELETE_TIMER() {
    systemctl stop "$1.timer"
    systemctl disable "$1.timer"
    rm "/etc/systemd/system/$1.timer"
    systemctl daemon-reload
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "请输入正确的参数!"
    LOG "用法: systemd_bot.sh <create|delete> <service/timer> <name> <path/OnCalendar>"
}

function MAIN() {
    if ! DEFAULT_MAIN; then
        DEFAULT_EXIT 1
    fi

    case "$METHOD" in
    "create")
        if [ -z "$PARAM" ]; then
            USAGE
            EXIT 1
        fi

        local path="$(readlink -f "$(dirname "$PARAM")")/$(basename "$PARAM")"

        if [ -x "$path" ]; then
            PARAM="$path"
        fi

        case "$TYPE" in
        "service")
            CREATE_SERVICE "$NAME" "$PARAM"
            ;;
        "timer")
            CREATE_TIMER "$NAME" "$PARAM"
            ;;
        *)
            USAGE
            EXIT 1
            ;;
        esac
        ;;
    "delete")
        if [ "$TYPE" == "service" ]; then
            DELETE_SERVICE "$NAME"
        elif [ "$TYPE" == "timer" ]; then
            DELETE_TIMER "$NAME"
        fi
        ;;
    *)
        USAGE
        EXIT 1
        ;;
    esac

    EXIT 0
}

RUN_MAIN MAIN "$@"
