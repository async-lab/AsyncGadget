#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 简单的校园网登录程序

##############################################
################### META #####################

MODULE_NAME="simple_auth"

DIR="$(readlink -f "$(dirname "$0")")"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"
source "$ROOT_DIR/network/lib/school_auth.sh"

##############################################
################### GLOBAL ###################

METHOD="$1"
INTERFACE="$2"
ISP_NAME="$3"
USERNAME="$4"
PASSWORD="$5"

CHECK_IP="223.5.5.5"
CHECK_TIMEOUT="3"
CHECK_RETRY="10"

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
}

function CHECK_PARAMS() {
    if ! CHECK_IF_ALL_EXIST "$METHOD"; then
        return "$NO"
    fi
    case "$METHOD" in
    "login")
        if ! CHECK_IF_ALL_EXIST "$INTERFACE" "$ISP_NAME" "$USERNAME" "$PASSWORD"; then
            return "$NO"
        fi
        ;;
    "logout")
        if ! CHECK_IF_ALL_EXIST "$INTERFACE"; then
            return "$NO"
        fi
        ;;
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
        response="$(AUTH "$INTERFACE" "$ISP_NAME" "$USERNAME" "$PASSWORD")"
        is_success="$?"
        if IS_YES "$is_success"; then
            LOG "登录成功"
        else
            LOG "登录失败: $response"
        fi
        ;;
    "logout")
        response="$(LOGOUT "$INTERFACE")"
        is_success="$?"
        if IS_YES "$is_success"; then
            LOG "下线成功"
        else
            LOG "下线失败: $response"
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
