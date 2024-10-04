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
SPEEDTEST="$ROOT_DIR/network/speedtest.sh"

##############################################

SCRIPT="$1"
SCRIPT_PID=""

# 创建后台进程手动关闭可以防止一些奇怪的情况
# 直接前台运行它也会创建子shell，有些时候就关不掉
function EXIT() {
    kill "$SCRIPT_PID" >/dev/null 2>&1
    wait "$SCRIPT_PID" >/dev/null 2>&1
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
    "speedtest")
        $SPEEDTEST "$@" &
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
