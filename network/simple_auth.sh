#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 简单的校园网登录程序

##############################################
################### META #####################

MODULE_NAME="simple_auth"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"
REQUIRE "$ROOT_DIR/network/lib/school_auth.sh"

##############################################
################### GLOBAL ###################

METHOD="$1"
INTERFACE="$2"
ISP="$3"
USERNAME="$4"
PASSWORD="$5"

##############################################
################# TOOLFUNC ###################

##############################################
################ PROCESSFUNC #################

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "用法:"
    LOG "simple_auth.sh login <网卡> <ISP(0:电信/1:移动/2:联通/3:教育网)> <账号> <密码>"
    LOG "simple_auth.sh logout <网卡>"
    LOG "simple_auth.sh whoami <网卡>"
}

function CHECK_PARAMS() {
    if ! CHECK_IF_ALL_EXIST "$METHOD" "$INTERFACE"; then
        return "$NO"
    fi
    case "$METHOD" in
    "login")
        if ! CHECK_IF_ALL_EXIST "$ISP" "$USERNAME" "$PASSWORD"; then
            return "$NO"
        fi
        ;;
    "logout" | "whoami") ;;
    *)
        return "$NO"
        ;;
    esac
    return "$YES"
}

function MAIN() {
    if ! DEFAULT_MAIN; then
        EXIT 1
    fi

    local response=""
    local is_success="$NO"

    case "$METHOD" in
    "login")
        if CHECK_NETWORK_HTTPS "$INTERFACE"; then
            LOG "网络已连接"
            EXIT 0
        fi

        response="$(AUTH "$ISP" "$USERNAME" "$PASSWORD" "$INTERFACE")"
        is_success="$?"
        if IS_YES "$is_success"; then
            LOG "登录成功"
            EXIT 0
        else
            LOG "登录失败: $response"
            EXIT 1
        fi
        ;;
    "logout")
        response="$(LOGOUT "$INTERFACE")"
        is_success="$?"
        if IS_YES "$is_success"; then
            LOG "下线成功"
            EXIT 0
        else
            LOG "下线失败: $response"
            EXIT 1
        fi
        ;;
    "whoami")
        response="$(GET_ONLINE_USER_INFO "$INTERFACE")"
        is_success="$?"
        if IS_YES "$is_success"; then
            declare -A user_info
            PARSE_KV user_info "$response"
            LOG "网卡: $INTERFACE"
            LOG "账号: ${user_info[userName]}"
            LOG "登录时间: ${user_info[authenticationTime]}"
            LOG "位置: ${user_info[nodePhysicalLocation]}"
            LOG "IP: ${user_info[nodeIp]}"
            LOG "MAC: ${user_info[nodeMac]}"
            EXIT 0
        else
            LOG "网卡 $INTERFACE 未登录 ($response)"
            EXIT 1
        fi
        ;;
    *)
        LOG "错误的方法"
        EXIT 1
        ;;
    esac

    EXIT 0
}

RUN_MAIN MAIN "$@"
