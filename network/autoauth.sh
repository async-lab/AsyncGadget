#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 为openwrt多线环境编写的校园网登录程序

##############################################
################### META #####################

MODULE_NAME="autoauth"

DIR="$(readlink -f "$(dirname "$0")")"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"

##############################################
################### GLOBAL ###################

ACCOUNT_FILE="$1"
SLEEP_TIME="${2:-10}"
WAIT_TIME="$(PERIOD_TO_SECONDS "${3:-"2h"}")"

CHECK_IP="223.5.5.5"
AUTH_IP="10.254.241.19"
ISP_MAPPING=("电信" "移动" "联通" "教育网")
CHECK_TIMEOUT="3"
CHECK_RETRY="10"
REQUEST_TIMEOUT="3"
ACCOUNTS=()

##############################################
################# TOOLFUNC ###################

function CHECH_NETWORK() {
    local interface="$1"
    if ping -I "$interface" -W "$CHECK_TIMEOUT" -c 1 "$CHECK_IP" >/dev/null; then
        return 0
    elif ping -I "$interface" -W "$CHECK_TIMEOUT" -c "$CHECK_RETRY" "$CHECK_IP" >/dev/null; then
        return 0
    else
        return 1
    fi
}

##############################################
################ PROCESSFUNC #################

function AUTH() {
    local interface="$1"
    local isp_name="${ISP_MAPPING[$2]}"
    local username="$3"
    local password="$4"

    local gateway_ip="$(netstat -nr | grep "$interface" | grep "^0.0.0.0" | awk '{print $2}')"

    local query_result="$(curl --interface "$interface" -m "$REQUEST_TIMEOUT" -s "http://${gateway_ip}" | grep -o "http://${AUTH_IP}/eportal/index.jsp?[^'\"']*")"
    local query_str="${query_result#*http://"${AUTH_IP}"/eportal/index.jsp?}"

    local referer_prefix="http://${AUTH_IP}/eportal/index.jsp?"

    local response="$(curl --interface "$interface" -m "$REQUEST_TIMEOUT" -s \
        -X POST \
        -H "Host: ${AUTH_IP}" \
        -H "Connection: keep-alive" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36 Edg/118.0.2088.76" \
        -H "Accept: */*" \
        -H "Origin: http://${AUTH_IP}" \
        -H "Referer: $referer_prefix$query_str" \
        -H "Accept-Encoding: gzip, deflate" \
        -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6" \
        -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        --data-urlencode "userId=$username" \
        --data-urlencode "password=$password" \
        --data-urlencode "service=$isp_name" \
        --data-urlencode "queryString=$query_str" \
        --data-urlencode "operatorPwd=" \
        --data-urlencode "operatorUserId=" \
        --data-urlencode "validcode=" \
        --data-urlencode "passwordEncrypt=false" \
        "http://${AUTH_IP}/eportal/InterFace.do?method=login")"

    if [[ $response == *"success"* ]]; then
        return 0
    else
        return 1
    fi
}

##############################################
################ PROGRAMFUNC #################

function LOAD_ACCOUNTS() {
    if [ ! -f "$ACCOUNT_FILE" ]; then
        return 1
    fi

    local accounts_from_file=()
    while IFS=, read -r isp username password; do
        if CHECK_IF_ALL_EXIST "$isp" "$username" "$password"; then
            accounts_from_file+=("${isp},${username},${password},0,0")
        else
            return 1
        fi
    done <"$ACCOUNT_FILE"

    for ((i = 0; i < ${#accounts_from_file[@]}; i++)); do
        local account_from_file="${accounts_from_file[$i]}"
        IFS=',' read -r -a account_from_file_arr <<<"$account_from_file"
        local is_exist=1
        for ((j = 0; j < ${#ACCOUNTS[@]}; j++)); do
            local account="${ACCOUNTS[$j]}"
            IFS=',' read -r -a account_arr <<<"$account"
            if [ "${account_arr[1]}" == "${account_from_file_arr[1]}" ]; then
                is_exist=0
                break
            fi
        done

        if [ "$is_exist" -eq 1 ]; then
            LOG "新增账号: ${account_from_file_arr[1]}"
            ACCOUNTS+=("$account_from_file")
        fi
    done

    for ((i = 0; i < ${#ACCOUNTS[@]}; i++)); do
        local account="${ACCOUNTS[$i]}"
        IFS=',' read -r -a account_arr <<<"$account"
        local is_exist=1
        for ((j = 0; j < ${#accounts_from_file[@]}; j++)); do
            local account_from_file="${accounts_from_file[$j]}"
            IFS=',' read -r -a account_from_file_arr <<<"$account_from_file"
            if [ "${account_arr[1]}" == "${account_from_file_arr[1]}" ]; then
                is_exist=0
                break
            fi
        done

        if [ "$is_exist" -eq 1 ]; then
            LOG "删除账号: ${account_arr[1]}"
            unset "ACCOUNTS[$i]"
        fi
    done

    return 0
}

function USAGE() {
    LOG "用法:"
    LOG "autoauth.sh <账密文件路径> (循环睡眠时间(秒)) (挤占等待时间(xs,xm,xh))"
}

function CHECK_PARAMS() {
    CHECK_IF_ALL_EXIST "$ACCOUNT_FILE" "$SLEEP_TIME" "$WAIT_TIME"
    return $?
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
    if ! CHECK_PARAMS; then
        USAGE
        EXIT 1
    fi

    LOG "账密文件路径:         $ACCOUNT_FILE"
    LOG "循环睡眠时间:         $SLEEP_TIME"
    LOG "挤占等待时间:         $WAIT_TIME"

    LOG_ASCII_ART

    LOG "启动……"

    local macvlan_num="$(ip link show | grep -c "macvlan")"

    LOG "macvlan数量: $macvlan_num"

    local all_online=1

    while true; do
        LOAD_ACCOUNTS

        local has_offline=1

        for i in $(seq 1 "$macvlan_num"); do
            local interface="macvlan$i"
            if ! CHECH_NETWORK "$interface"; then
                has_offline=0
                LOG "接口 $interface 无网络连接"
                local has_auth=1

                for ((j = 0; j < ${#ACCOUNTS[@]}; j++)); do
                    local account="${ACCOUNTS[j]}"
                    IFS=',' read -r -a account_arr <<<"$account"
                    if [ "${account_arr[3]}" -eq 0 ] && [ "$(($(date +%s) - account_arr[4]))" -gt "$WAIT_TIME" ]; then
                        if AUTH "$interface" "${account_arr[4]}" "${account_arr[1]}" "${account_arr[2]}"; then
                            LOG "接口 $interface 上线！账号: ${account_arr[1]}"
                            account_arr[3]="$i"
                            has_auth=0
                        else
                            LOG "接口 $interface 认证失败！账号: ${account_arr[1]}"
                            account_arr[4]="$(date +%s)"
                        fi
                    elif [ "${account_arr[3]}" -eq "$i" ]; then
                        LOG "接口 $interface 掉线！账号: ${account_arr[1]}"
                        account_arr[3]=0
                        account_arr[4]="$(date +%s)"
                    fi
                    ACCOUNTS[j]="$(
                        IFS=,
                        echo "${account_arr[*]}"
                    )"
                    if [ "$has_auth" -eq 0 ]; then
                        break
                    fi
                done

                if [ "$has_auth" -eq 1 ]; then
                    LOG "接口 $interface 无可用账号"
                fi
            fi
        done

        if [ "$has_offline" -eq 0 ]; then
            all_online=1
        elif [ "$all_online" -eq 1 ]; then
            LOG "所有接口上线！"
            all_online=0
        fi

        sleep "$SLEEP_TIME"
    done

    EXIT 0
}

MAIN "$@"
