#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 使用 curl 测试网络速度

##############################################
################### META #####################

MODULE_NAME="speedtest"

DIR="$(readlink -f "$(dirname "$0")")"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"

##############################################
################### GLOBAL ###################

NODES="${1:-"CN"}"
THREAD_NUM="${2:-4}"

NODE_CN="https://dldir1.qq.com/qqfile/qq/PCQQ9.7.17/QQ9.7.17.29225.exe"
NODE_HK="http://hkg.download.datapacket.com/100mb.bin"
NODE_JP="http://tyo.download.datapacket.com/100mb.bin"
NODE_SG="https://sgp.proof.ovh.net/files/100Mb.dat"
NODE_DE="https://nbg1-speed.hetzner.com/100MB.bin"
NODE_FR="http://par.download.datapacket.com/100mb.bin"
NODE_US="http://lax.download.datapacket.com/100mb.bin"

##############################################
################# TOOLFUNC ###################

function RAW_SPEED_TO_HUMAN() {
    local speed="$1"
    local unit="B/s"
    if [ "$speed" -gt 1024 ]; then
        ((speed /= 1024))
        unit="KB/s"
    fi
    if [ "$speed" -gt 1024 ]; then
        ((speed /= 1024))
        unit="MB/s"
    fi
    if [ "$speed" -gt 1024 ]; then
        ((speed /= 1024))
        unit="GB/s"
    fi
    echo "$speed $unit"
}

function RAW_SPEED_TO_BITRATE() {
    local speed="$(("$1" * 8))"
    local unit="b/s"
    if [ "$speed" -gt 1024 ]; then
        ((speed /= 1024))
        unit="Kb/s"
    fi
    if [ "$speed" -gt 1024 ]; then
        ((speed /= 1024))
        unit="Mb/s"
    fi
    if [ "$speed" -gt 1024 ]; then
        ((speed /= 1024))
        unit="Gb/s"
    fi
    echo "$speed $unit"
}

##############################################
################ PROCESSFUNC #################

function NODE_SELECTOR() {
    local node="$1"

    case "$node" in
    "CN")
        echo "$NODE_CN"
        ;;
    "HK")
        echo "$NODE_HK"
        ;;
    "JP")
        echo "$NODE_JP"
        ;;
    "SG")
        echo "$NODE_SG"
        ;;
    "DE")
        echo "$NODE_DE"
        ;;
    "FR")
        echo "$NODE_FR"
        ;;
    "US")
        echo "$NODE_US"
        ;;
    *)
        echo ""
        ;;
    esac
}

function SINGLE_THREAD_SPEEDTEST() {
    curl -o /dev/null -s -w "%{speed_download}"$'\n' "$@"
}

function SPEEDTEST() {
    local url="$1"

    for ((i = 0; i < THREAD_NUM; i++)); do
        SINGLE_THREAD_SPEEDTEST "$url" >>"$DATA_TMP_FILE" &
        echo "$!" >>"$PIDS_TMP_FILE"
    done

    while read -r pid; do
        NO_OUTPUT wait "$pid"
    done <"$PIDS_TMP_FILE"
    NO_OUTPUT echo -n >"$PIDS_TMP_FILE"

    local sum=0

    while read -r speed; do
        ((sum += speed))
    done <"$DATA_TMP_FILE"
    NO_OUTPUT echo -n >"$DATA_TMP_FILE"

    echo "$sum"
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "用法："
    LOG "speedtest.sh [节点(CN,HK)] [线程数(4)]"
}

function EXIT() {
    while read -r pid; do
        if [ -d "/proc/$pid" ]; then
            NO_OUTPUT kill -9 "$pid"
        fi
    done <"$PIDS_TMP_FILE"
    DEFAULT_EXIT "$@"
}

function CHECK_PARAMS() {
    CHECK_IF_ALL_EXIST "$THREAD_NUM" "$NODES"
    return "$?"
}

function LOG_ASCII_ART() {
    LOG
    LOG ' __ _  __ __ _ ___ __ _____'
    LOG '(_ |_)|_ |_ | \ | |_ (_  | '
    LOG '__)|  |__|__|_/ | |____) | '
    LOG
}

function MAIN() {
    if ! CHECK_PARAMS; then
        USAGE
        EXIT 1
    fi

    LOG "节点: $NODES"
    LOG "线程数: $THREAD_NUM"
    LOG "开始测试..."
    LOG_ASCII_ART
    {
        IFS=','
        for node in $NODES; do
            local url="$(NODE_SELECTOR "$node")"
            if [ -z "$url" ]; then
                LOG "未知的节点: $node"
                continue
            fi

            local speed="$(SPEEDTEST "$url")"
            LOG "节点: $node, 字节率：$(RAW_SPEED_TO_HUMAN "$speed"), 比特率：$(RAW_SPEED_TO_BITRATE "$speed")"
        done
    }
    EXIT 0
}

RUN_MAIN MAIN "$@"
