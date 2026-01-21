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
SLEEP_TIME="$(PERIOD_TO_SECONDS "10s")"
FAILED_RETRY_TIME="$(PERIOD_TO_SECONDS "3m")"

START_TABLE="2333"
START_RULE="100"

# 账号池（按 username 做 key，避免维护“结构体数组”）
declare -A ACCOUNT_ISP=()       # username -> isp
declare -A ACCOUNT_PASSWORD=()  # username -> password
declare -A ACCOUNT_BIND=()      # username -> interface_id(从1开始；0表示未绑定)
declare -A ACCOUNT_LAST_TRY=()  # username -> epoch seconds
ACCOUNTS_ORDER=()              # 账号尝试顺序（来自文件的顺序）

# 接口列表（按 macvlan 数字后缀排序）
MACVLAN_INTERFACES=()

# 接口状态机（只在状态变化时输出）
declare -A INTERFACE_STATE=()

MANDATORY_PARAMS=("$ACCOUNT_FILE")

##############################################
################# TOOLFUNC ###################

##############################################
################ PROCESSFUNC #################

function LOAD_ACCOUNTS() {
    if [ ! -f "$ACCOUNT_FILE" ]; then
        return "$NO"
    fi

    # 先解析到临时结构里，保证“文件有问题时不污染内存账号池”
    local -A seen=()
    local next_order=()
    local -A next_isp=()
    local -A next_password=()
    local -A next_bind=()
    local -A next_last_try=()
    local isp="" username="" password=""

    while true; do
        isp=""
        username=""
        password=""

        IFS=, read -r isp username password || {
            # 兼容文件最后一行缺少换行符的情况：有内容就处理，无内容就退出
            if [ -z "$isp$username$password" ]; then
                break
            fi
        }

        isp="$(TRIM "$isp")"
        username="$(TRIM "$username")"
        password="$(TRIM "$password")"

        # 跳过空行 / 注释
        if [ -z "$isp" ] && [ -z "$username" ] && [ -z "$password" ]; then
            continue
        fi
        case "$isp" in
        \#*) continue ;;
        esac

        if ! CHECK_IF_ALL_EXIST "$isp" "$username" "$password"; then
            return "$NO"
        fi

        # 同一用户名在文件里重复出现时：以最后一次为准，但不重复加入顺序列表
        if [ -z "${seen[$username]+_}" ]; then
            seen["$username"]=1
            next_order+=("$username")

            if [ -n "${ACCOUNT_ISP[$username]+_}" ]; then
                # 账号已存在：保留运行时状态（绑定/冷却）
                next_bind["$username"]="${ACCOUNT_BIND[$username]:-0}"
                next_last_try["$username"]="${ACCOUNT_LAST_TRY[$username]:-0}"
            else
                # 新账号
                next_bind["$username"]=0
                next_last_try["$username"]=0
            fi
        fi

        next_isp["$username"]="$isp"
        next_password["$username"]="$password"
    done <"$ACCOUNT_FILE"

    # 变更日志（新增/删除）
    local old_username
    for old_username in "${next_order[@]}"; do
        if [ -z "${ACCOUNT_ISP[$old_username]+_}" ]; then
            LOG "新增账号: $old_username"
        fi
    done

    for old_username in "${ACCOUNTS_ORDER[@]}"; do
        if [ -z "${seen[$old_username]+_}" ]; then
            LOG "删除账号: $old_username"
        fi
    done

    # 提交更新
    ACCOUNT_ISP=()
    ACCOUNT_PASSWORD=()
    ACCOUNT_BIND=()
    ACCOUNT_LAST_TRY=()

    for username in "${!next_isp[@]}"; do
        ACCOUNT_ISP["$username"]="${next_isp[$username]}"
        ACCOUNT_PASSWORD["$username"]="${next_password[$username]}"
        ACCOUNT_BIND["$username"]="${next_bind[$username]:-0}"
        ACCOUNT_LAST_TRY["$username"]="${next_last_try[$username]:-0}"
    done

    ACCOUNTS_ORDER=("${next_order[@]}")

    return "$YES"
}

function LIST_MACVLAN_INTERFACES() {
    # 输出：按 macvlan 数字后缀排序的接口名（每行一个）
    # 兼容 ip 输出里的 macvlanX@ethY: 形式
    ip link show 2>/dev/null \
        | awk -F': ' '/^[0-9]+: / {print $2}' \
        | awk '{print $1}' \
        | sed 's/:$//' \
        | cut -d'@' -f1 \
        | grep -E '^macvlan[0-9]+$' \
        | awk '{n=$0; sub(/^macvlan/, "", n); print n, $0}' \
        | sort -n \
        | awk '{print $2}'
}

function REFRESH_MACVLAN_INTERFACES() {
    local ifaces=()
    local iface
    while IFS= read -r iface; do
        [ -n "$iface" ] && ifaces+=("$iface")
    done < <(LIST_MACVLAN_INTERFACES)
    MACVLAN_INTERFACES=("${ifaces[@]}")
}

function UPDATE_INTERFACE_STATE() {
    local interface="$1"
    local new_state="$2"
    local message="$3"

    local old_state="${INTERFACE_STATE[$interface]:-}"
    if [ "$old_state" != "$new_state" ]; then
        if [ -n "$message" ]; then
            LOG "$message"
        fi
        INTERFACE_STATE["$interface"]="$new_state"
    fi
}

function DEL_IP_ROUTING() {
    local idx=1
    local interface
    for interface in "${MACVLAN_INTERFACES[@]}"; do
        NO_OUTPUT ip route flush table "$((START_TABLE + idx))"
        NO_OUTPUT ip rule del pref "$((START_RULE + idx))"
        ((idx++))
    done
}

function ADD_IP_ROUTING() {
    local idx=1
    local interface
    for interface in "${MACVLAN_INTERFACES[@]}"; do
        local gateway_ip
        gateway_ip="$(ip route show dev "$interface" default 2>/dev/null | awk '{print $3}')"
        if [ -z "$gateway_ip" ]; then
            LOG "接口 $interface 未找到网关，跳过认证路由规则"
            ((idx++))
            continue
        fi

        NO_OUTPUT ip route add "$AUTH_IP" via "$gateway_ip" dev "$interface" table "$((START_TABLE + idx))"
        NO_OUTPUT ip rule add pref "$((START_RULE + idx))" from all to "$AUTH_IP" oif "$interface" lookup "$((START_TABLE + idx))"
        ((idx++))
    done
}

function AUTH_FOR_INTERFACE_FROM_ACCOUNTS() {
    local interface_id="$1"
    local interface="$2"

    if CHECK_NETWORK "$interface"; then
        UPDATE_INTERFACE_STATE "$interface" "online" ""
        return "$YES"
    fi

    local has_auth="$NO"
    local has_candidate="$NO"
    local now="$(date +%s)"

    local username
    # 先清理所有绑定到该接口的账号（避免“同接口多账号绑定”的脏状态）
    for username in "${ACCOUNTS_ORDER[@]}"; do
        local bind_id="${ACCOUNT_BIND[$username]:-0}"
        if [ "$bind_id" -eq "$interface_id" ]; then
            LOG "接口 $interface 离线，释放账号: $username"
            ACCOUNT_BIND["$username"]=0
            ACCOUNT_LAST_TRY["$username"]=0
        fi
    done

    # 再按顺序找一个账号尝试认证
    for username in "${ACCOUNTS_ORDER[@]}"; do
        local bind_id="${ACCOUNT_BIND[$username]:-0}"
        local last_try="${ACCOUNT_LAST_TRY[$username]:-0}"

        if [ "$bind_id" -ne 0 ]; then
            continue
        fi

        if [ "$((now - last_try))" -le "$FAILED_RETRY_TIME" ]; then
            continue
        fi

        has_candidate="$YES"
        local response="$(AUTH "${ACCOUNT_ISP[$username]}" "$username" "${ACCOUNT_PASSWORD[$username]}" "$interface")"
        has_auth="$?"
        if IS_YES "$has_auth"; then
            LOG "接口 $interface 上线！账号: $username"
            ACCOUNT_BIND["$username"]="$interface_id"
            UPDATE_INTERFACE_STATE "$interface" "online" ""
        else
            LOG "接口 $interface 认证失败！账号: $username"
            LOG "错误信息: $response"
            ACCOUNT_LAST_TRY["$username"]="$now"
        fi

        if IS_YES "$has_auth"; then
            break
        fi
    done

    if IS_NO "$has_auth"; then
        if IS_NO "$has_candidate"; then
            UPDATE_INTERFACE_STATE "$interface" "no_account" "接口 $interface 无可用账号"
        else
            UPDATE_INTERFACE_STATE "$interface" "offline" "接口 $interface 无网络连接"
        fi
    fi

    return "$NO"
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "用法:"
    LOG "auto_auth.sh <账密文件路径>"
    LOG "账密文件格式: 每行 \"ISP,账号,密码\"（ISP: 0电信/1移动/2联通/3教育网；支持空行与 # 注释）"
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
    LOG "循环睡眠时间(固定):   $SLEEP_TIME"
    LOG "失败重试等待时间:     $FAILED_RETRY_TIME"

    LOG_ASCII_ART

    LOG "启动……"

    REFRESH_MACVLAN_INTERFACES
    local macvlan_num="${#MACVLAN_INTERFACES[@]}"

    LOG "macvlan数量: $macvlan_num"
    LOG "接口列表: ${MACVLAN_INTERFACES[*]}"

    if [ "$macvlan_num" -eq 0 ]; then
        LOG "未找到macvlan接口!"
        EXIT 1
    fi

    local all_online="$NO"

    DEL_IP_ROUTING
    ADD_IP_ROUTING

    while true; do
        LOAD_ACCOUNTS

        local has_offline="$NO"

        local idx=1
        local interface
        for interface in "${MACVLAN_INTERFACES[@]}"; do
            if ! AUTH_FOR_INTERFACE_FROM_ACCOUNTS "$idx" "$interface"; then
                has_offline="$YES"
            fi
            ((idx++))
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
