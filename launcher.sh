#!/usr/bin/env bash
# -*- coding: utf-8 -*-

##############################################

DIR="$(readlink -f "$(dirname "$0")")"

export ROOT_DIR="$DIR"

CERT_SYNC_BOT="$ROOT_DIR/misc/cert_sync_bot.sh"
GIT_RELEASE_UPDATER="$ROOT_DIR/misc/git_release_updater.sh"
STALKER="$ROOT_DIR/misc/stalker.sh"
SYSTEMD_BOT="$ROOT_DIR/misc/systemd_bot.sh"
AUTOAUTH="$ROOT_DIR/network/autoauth.sh"

##############################################

SCRIPT="$1"
SCRIPT_PID=""

function EXIT() {
    kill "$SCRIPT_PID"
    exit "$@"
}

function MAIN() {
    shift # 移除第一个参数（脚本名）
    if [[ -z "$SCRIPT" ]]; then
        echo "请输入正确的参数!"
        echo "用法: launcher.sh <脚本> <脚本参数>"
        EXIT 1
    fi

    case "$SCRIPT" in
    "cert_sync_bot")
        $CERT_SYNC_BOT "$@" &
        ;;
    "git_release_updater")
        $GIT_RELEASE_UPDATER "$@" &
        ;;
    "stalker")
        $STALKER "$@" &
        ;;
    "systemd_bot")
        $SYSTEMD_BOT "$@" &
        ;;
    "autoauth")
        $AUTOAUTH "$@" &
        ;;
    *)
        echo "未知的脚本名称"
        EXIT 1
        ;;
    esac

    SCRIPT_PID="$!"
    wait "$SCRIPT_PID"
    EXIT 0
}

trap EXIT SIGINT SIGTERM

MAIN "$@"
