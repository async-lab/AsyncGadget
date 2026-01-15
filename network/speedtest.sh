#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 使用 curl 测试网络速度

##############################################
################### META #####################

MODULE_NAME="speedtest"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

REFRESH_INTERVAL="1"

SPEEDTEST_PIDS=()
PROGRESS_FILES=()

for ((i = 0; i < THREAD_NUM; i++)); do
    PROGRESS_FILES+=("$(mktemp "$(MAKE_GADGET_TMP_NAME "speedtest" "progress")")")
done

##############################################
################# TOOLFUNC ###################


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

function START_SPEEDTEST_TASK() {
    local url="$1"
    local progress_file="$2"

    curl -fSL -o /dev/null -w "%{speed_download}"$'\n' "$url" 2>"$progress_file" >>"$DATA_TMP_FILE" &

    local pid="$!"
    SPEEDTEST_PIDS+=("$pid")
    echo "$pid" >>"$PIDS_TMP_FILE"
}

function GET_REALTIME_SPEED_SUM() {
    local sum=0

    for ((i = 0; i < ${#SPEEDTEST_PIDS[@]}; i++)); do
        local pid="${SPEEDTEST_PIDS[$i]}"
        if ! IS_RUNNING "$pid"; then
            continue
        fi

        local progress_file="${PROGRESS_FILES[$i]}"
        local realtime_speed=0
        if [ -f "$progress_file" ]; then
            local speed_token="$(tr '\r' '\n' <"$progress_file" | awk '$NF ~ /^[0-9.]+[kKmMgGtT]?$/ {speed=$NF} END {print speed}')"
            realtime_speed="$(HUMAN_TO_RAW "$speed_token")"
        fi

        ((sum += "$(MULTIPLY "$realtime_speed" 8)"))
    done

    echo "$sum"
}

function SHOW_REALTIME_STATUS() {
    local node="$1"

    if [ "$LOG_TYPE" != "console" ]; then
        return 0
    fi

    while true; do
        local has_running="$NO"
        for pid in "${SPEEDTEST_PIDS[@]}"; do
            if IS_RUNNING "$pid"; then
                has_running="$YES"
                break
            fi
        done

        if IS_NO "$has_running"; then
            break
        fi

        local sum_realtime="$(GET_REALTIME_SPEED_SUM)"
        STATE "[$node] -> 「 $(RAW_TO_HUMAN "$sum_realtime")b/s 」"

        if ! NO_OUTPUT sleep "$REFRESH_INTERVAL"; then
            sleep 1
        fi
    done
}

function SPEEDTEST() {
    local node="$1"
    local url="$2"

    echo 0 >"$STD_TMP_FILE"

    for progress_file in "${PROGRESS_FILES[@]}"; do
        CLEAR_FILE "$progress_file"
    done

    CLEAR_FILE "$PIDS_TMP_FILE" "$DATA_TMP_FILE"

    SPEEDTEST_PIDS=()
    for ((i = 0; i < THREAD_NUM; i++)); do
        START_SPEEDTEST_TASK "$url" "${PROGRESS_FILES[$i]}"
    done

    SHOW_REALTIME_STATUS "$node"

    if [ -f "$PIDS_TMP_FILE" ]; then
        while read -r pid; do
            NO_OUTPUT wait "$pid"
        done <"$PIDS_TMP_FILE"
    fi
    CLEAR_FILE "$PIDS_TMP_FILE"

    local sum=0

    if [ -f "$DATA_TMP_FILE" ]; then
        while read -r speed; do
            speed="$(TRIM "$speed")"
            case "$speed" in
            '' | *[!0-9.]*)
                continue
                ;;
            esac
            ((sum += speed))
        done <"$DATA_TMP_FILE"
    fi
    CLEAR_FILE "$DATA_TMP_FILE"

    SPEEDTEST_PIDS=()

    echo "$sum" >"$STD_TMP_FILE"
    return 0
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "用法："
    LOG "speedtest.sh [节点(CN,HK,JP,SG,DE,FR,US)] [线程数(4)]"
}

function EXIT() {
    while read -r pid; do
        if IS_RUNNING "$pid"; then
            NO_OUTPUT kill -9 "$pid"
        fi
    done <"$PIDS_TMP_FILE"
    for progress_file in "${PROGRESS_FILES[@]}"; do
        NO_OUTPUT rm -f "$progress_file"
    done
    DEFAULT_EXIT "$@"
}

function LOG_ASCII_ART() {
    LOG
    LOG ' __ _  __ __ _ ___ __ _____'
    LOG '(_ |_)|_ |_ | \ | |_ (_  | '
    LOG '__)|  |__|__|_/ | |____) | '
    LOG
}

function MAIN() {
    if ! DEFAULT_MAIN; then
        EXIT 1
    fi

    LOG "节点: $NODES"
    LOG "线程数: $THREAD_NUM"
    LOG "开始测试..."
    LOG_ASCII_ART
    local nodes_arr=()
    IFS=',' read -r -a nodes_arr <<<"$NODES"

    for node in "${nodes_arr[@]}"; do
        local url="$(NODE_SELECTOR "$node")"
        if [ -z "$url" ]; then
            LOG "未知的节点: $node"
            USAGE
            continue
        fi

        SPEEDTEST "$node" "$url"

        local speed=0
        if [ -f "$STD_TMP_FILE" ]; then
            read -r speed <"$STD_TMP_FILE" || speed=0
        fi
        case "$speed" in
        '' | *[!0-9]*)
            speed=0
            ;;
        esac

        LOG "节点: $node, 比特率: $(RAW_TO_HUMAN "$(MULTIPLY "$speed" 8)")b/s"
    done
    EXIT 0
}

RUN_MAIN MAIN "$@"
