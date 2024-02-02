#!/usr/bin/env bash
# -*- coding: utf-8 -*-

##############################################

DIR=$(readlink -f "$(dirname "$0")")

export ROOT_DIR="$DIR"

CERT_SYNC_BOT="$ROOT_DIR/misc/cert_sync_bot.sh"
SYSTEMD_BOT="$ROOT_DIR/misc/systemd_bot.sh"
DSXTP="$ROOT_DIR/network/dsxtphf/dsxtp.sh"
DSXHF="$ROOT_DIR/network/dsxtphf/dsxhf.py"
STALKER="$ROOT_DIR/misc/stalker.sh"

##############################################

SCRIPT="$1"

function MAIN() {
    shift # 移除第一个参数（脚本名）
    if [[ -z "$SCRIPT" ]]; then
        echo "请输入正确的参数!"
        echo "用法: launcher.sh <脚本> <脚本参数>"
        exit 1
    fi

    case "$SCRIPT" in
    "cert_sync_bot")
        $CERT_SYNC_BOT "$@"
        ;;
    "systemd_bot")
        $SYSTEMD_BOT "$@"
        ;;
    "dsxtp")
        $DSXTP "$@"
        ;;
    "dsxhf")
        $DSXHF "$@"
        ;;
    "stalker")
        $STALKER "$@"
        ;;
    *)
        echo "未知的脚本名称"
        exit 1
        ;;
    esac
}

MAIN "$@"
