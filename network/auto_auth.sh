#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 为openwrt多线环境编写的校园网登录程序

##############################################
################### META #####################

MODULE_NAME="auto_auth"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"
source "$ROOT_DIR/network/lib/school_auth.sh"

##############################################
################### GLOBAL ###################

ACCOUNT_FILE="$1"
SLEEP_TIME="${2:-10}"
WAIT_TIME="$(PERIOD_TO_SECONDS "${3:-"2h"}")"

FAILED_RETRY_TIME=180

START_TABLE="2333"
START_RULE="100"

ACCOUNTS=()

MANDATORY_PARAMS=("$ACCOUNT_FILE" "$SLEEP_TIME" "$WAIT_TIME")

##############################################
################# TOOLFUNC ###################

##############################################
################ PROCESSFUNC #################

function LOAD_ACCOUNTS() {
    if [ ! -f "$ACCOUNT_FILE" ]; then
        return "$NO"
    fi

    local accounts_from_file=()
    while IFS=, read -r isp username password; do
        if CHECK_IF_ALL_EXIST "$isp" "$username" "$password"; then
            accounts_from_file+=("$(TRIM "$isp"),$(TRIM "$username"),$(TRIM "$password"),0,0") # isp, username, password, interface, last_try_time
        else
            return "$NO"
        fi
    done <"$ACCOUNT_FILE"

    for ((i = 0; i < ${#accounts_from_file[@]}; i++)); do
        local account_from_file="${accounts_from_file[$i]}"
        IFS=',' read -r -a account_from_file_arr <<<"$account_from_file"
        local is_exist="$NO"
        for ((j = 0; j < ${#ACCOUNTS[@]}; j++)); do
            local account="${ACCOUNTS[$j]}"
            IFS=',' read -r -a account_arr <<<"$account"
            if [ "${account_arr[1]}" == "${account_from_file_arr[1]}" ]; then
                is_exist="$YES"
                break
            fi
        done

        if IS_NO "$is_exist"; then
            LOG "新增账号: ${account_from_file_arr[1]}"
            ACCOUNTS+=("$account_from_file")
        fi
    done

    for ((i = 0; i < ${#ACCOUNTS[@]}; i++)); do
        local account="${ACCOUNTS[$i]}"
        IFS=',' read -r -a account_arr <<<"$account"
        local is_exist="$NO"
        for ((j = 0; j < ${#accounts_from_file[@]}; j++)); do
            local account_from_file="${accounts_from_file[$j]}"
            IFS=',' read -r -a account_from_file_arr <<<"$account_from_file"
            if [ "${account_arr[1]}" == "${account_from_file_arr[1]}" ]; then
                is_exist="$YES"
                break
            fi
        done

        if IS_NO "$is_exist"; then
            LOG "删除账号: ${account_arr[1]}"
            unset "ACCOUNTS[$i]"
        fi
    done

    return "$YES"
}

function DEL_IP_ROUTING() {
    local macvlan_num="$(ip link show | grep -c "macvlan")"

    for ((i = 1; i <= macvlan_num; i++)); do
        local interface="macvlan$i"

        NO_OUTPUT ip route flush table "$((START_TABLE + i))"
        NO_OUTPUT ip rule del pref "$((START_RULE + i))"
    done
}

function ADD_IP_ROUTING() {
    local macvlan_num="$(ip link show | grep -c "macvlan")"

    for ((i = 1; i <= macvlan_num; i++)); do
        local interface="macvlan$i"
        local gateway_ip="$(ip route show dev "$interface" default 2>/dev/null | awk '{print $3}')"

        NO_OUTPUT ip route add "$AUTH_IP" via "$gateway_ip" dev "$interface" table "$((START_TABLE + i))"
        NO_OUTPUT ip rule add pref "$((START_RULE + i))" from all to "$AUTH_IP" oif "$interface" lookup "$((START_TABLE + i))"
    done
}

function AUTH_FOR_INTERFACE_FROM_ACCOUNTS() {
    local interface="$1"

    local no_offline="$YES"

    if ! CHECK_NETWORK "$interface"; then
        LOG "接口 $interface 无网络连接"

        no_offline="$NO"
        local has_auth="$NO"
        for ((j = 0; j < ${#ACCOUNTS[@]}; j++)); do
            local account="${ACCOUNTS[j]}"
            IFS=',' read -r -a account_arr <<<"$account"
            if [ "${account_arr[3]}" -eq 0 ] && [ "$(($(date +%s) - account_arr[4]))" -gt "$WAIT_TIME" ]; then
                local response
                response="$(AUTH "${account_arr[0]}" "${account_arr[1]}" "${account_arr[2]}" "$interface")"
                has_auth="$?"
                if IS_YES "$has_auth"; then
                    LOG "接口 $interface 上线！账号: ${account_arr[1]}"
                    account_arr[3]="$i"
                else
                    LOG "接口 $interface 认证失败！账号: ${account_arr[1]}"
                    LOG "错误信息: $response"
                    account_arr[4]="$(($(date +%s) - WAIT_TIME + FAILED_RETRY_TIME))"
                fi
            elif [ "${account_arr[3]}" -eq "$i" ]; then
                LOG "接口 $interface 被挤占！账号: ${account_arr[1]}"
                account_arr[3]=0
                account_arr[4]="$(date +%s)"
            fi
            ACCOUNTS[j]="$(
                IFS=,
                echo "${account_arr[*]}"
            )"
            if IS_YES "$has_auth"; then
                break
            fi
        done

        if IS_NO "$has_auth"; then
            LOG "接口 $interface 无可用账号"
        fi
    fi

    return "$no_offline"
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "用法:"
    LOG "auto_auth.sh <账密文件路径> [循环睡眠时间(秒)] [挤占等待时间(xs,xm,xh)]"
}

function EXIT() {
    DEL_IP_ROUTING
    DEFAULT_EXIT "$@"
}

function LOG_ASCII_ART() {
    LOG
    LOG ' ________  ___  ___  _________  ________  ________  ___  ___  _________  ___  ___      '
    LOG '|\   __  \|\  \|\  \|\___   ___\\   __  \|\   __  \|\  \|\  \|\___   ___\\  \|\  \     '
    LOG '\ \  \|\  \ \  \\\  \|___ \  \_\ \  \|\  \ \  \|\  \ \  \\\  \|___ \  \_\ \  \\\  \    '
    LOG ' \ \   __  \ \  \\\  \   \ \  \ \ \  \\\  \ \   __  \ \  \\\  \   \ \  \ \ \   __  \   '
    LOG '  \ \  \ \  \ \  \\\  \   \ \  \ \ \  \\\  \ \  \ \  \ \  \\\  \   \ \  \ \ \  \ \  \  '
    LOG '   \ \__\ \__\ \_______\   \ \__\ \ \_______\ \__\ \__\ \_______\   \ \__\ \ \__\ \__\ '
    LOG '    \|__|\|__|\|_______|    \|__|  \|_______|\|__|\|__|\|_______|    \|__|  \|__|\|__| '
    LOG
}

function MAIN() {
    if ! DEFAULT_MAIN; then
        EXIT 1
    fi

    LOG "账密文件路径:         $ACCOUNT_FILE"
    LOG "循环睡眠时间:         $SLEEP_TIME"
    LOG "挤占等待时间:         $WAIT_TIME"

    LOG_ASCII_ART

    LOG "启动……"

    local macvlan_num="$(ip link show | grep -c "macvlan")"

    LOG "macvlan数量: $macvlan_num"

    if [ "$macvlan_num" -eq 0 ]; then
        LOG "未找到macvlan接口！"
        EXIT 1
    fi

    local all_online="$NO"

    DEL_IP_ROUTING
    ADD_IP_ROUTING

    while true; do
        LOAD_ACCOUNTS

        local has_offline="$NO"

        for ((i = 1; i <= macvlan_num; i++)); do
            local interface="macvlan$i"

            if ! AUTH_FOR_INTERFACE_FROM_ACCOUNTS "$interface"; then
                has_offline="$YES"
            fi
        done

        if IS_YES "$has_offline"; then
            all_online="$NO"
        elif IS_NO "$all_online"; then
            LOG "所有接口上线！"
            all_online="$YES"
        fi

        sleep "$SLEEP_TIME"
    done

    EXIT 0
}

RUN_MAIN MAIN "$@"
