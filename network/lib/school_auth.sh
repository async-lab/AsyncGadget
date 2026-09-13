#!/usr/bin/env bash
# -*- coding: utf-8 -*-

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR=${ROOT_DIR:-"$DIR/../.."}

source "$ROOT_DIR/base/REQUIRE.sh"
REQUIRE "$ROOT_DIR/base/LOGIC.sh"
REQUIRE "$ROOT_DIR/base/AES.sh"
REQUIRE "$ROOT_DIR/base/JSON.sh"

AUTH_IP="10.254.241.66"
ISP_MAPPING=("ctcc" "cmcc" "unicom" "cernet")
REQUEST_TIMEOUT="5"

function AUTH() {
    local isp_code="${ISP_MAPPING[$1]}"
    local username="$2"
    local password="$3"
    local interface="$4"

    if [ -z "$isp_code" ]; then
        isp_code="$1"
    fi

    local curl_func="curl"
    if [ -n "$interface" ]; then
        curl_func="curl --interface $interface"
    fi

    local user_ip=""
    if [ -n "$interface" ]; then
        user_ip="$(ip -4 addr show dev "$interface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)"
    fi

    local cookie_file
    cookie_file="$(mktemp "/tmp/auth_cookie.XXXXXX")"

    # Step 1: 请求重定向页面，获取 sessionId 与 nasIp
    local probe_url="http://${AUTH_IP}/eportal/index.jsp?wlanuserip=${user_ip}&wlanacname=H3C%2dCR16010%2dF"
    local redir_resp
    redir_resp="$($curl_func -s -m "$REQUEST_TIMEOUT" -c "$cookie_file" -i "$probe_url")"
    local location
    location="$(printf '%s\n' "$redir_resp" | awk -F': ' '/[Ll]ocation:/ {print $2}' | tr -d '\r\n')"

    local session_id
    session_id="$(printf '%s\n' "$location" | sed -n 's/.*[?&]sessionId=\([^&]*\).*/\1/p')"
    local custom_page_id
    custom_page_id="$(printf '%s\n' "$location" | sed -n 's/.*[?&]customPageId=\([^&]*\).*/\1/p')"
    local nas_ip
    nas_ip="$(printf '%s\n' "$location" | sed -n 's/.*[?&]nasIp=\([^&]*\).*/\1/p')"
    [ -z "$custom_page_id" ] && custom_page_id="4"

    if [ -z "$session_id" ]; then
        rm -f "$cookie_file"
        echo "获取认证会话失败: 未能获取到 sessionId"
        return "$NO"
    fi

    # Step 2: 访问 /pc/center 获取动态 AES 密钥和 CAS execution 令牌
    local center_url="http://${AUTH_IP}/pc/center?flowSessionId=${session_id}&customPageId=${custom_page_id}&preview=false&appType=normal&language=zh-CN&timer=$(date +%s%3N)&nasIp=${nas_ip}&userIp=${user_ip}"
    local center_html
    center_html="$($curl_func -s -m "$REQUEST_TIMEOUT" -L -b "$cookie_file" -c "$cookie_file" "$center_url")"

    local crypto_key
    crypto_key="$(printf '%s\n' "$center_html" | sed -n 's/.*id=["'\'' ]*login-croypto["'\'' ][^>]*>\([^<]*\)<.*/\1/p' | tr -d '\r\n ')"
    local execution
    execution="$(printf '%s\n' "$center_html" | sed -n 's/.*id=["'\'' ]*login-page-flowkey["'\'' ][^>]*>\([^<]*\)<.*/\1/p' | tr -d '\r\n ')"

    if [ -z "$crypto_key" ] || [ -z "$execution" ]; then
        rm -f "$cookie_file"
        echo "提取认证加密参数失败"
        return "$NO"
    fi

    # Step 3: AES 加密密码与 payload
    local enc_pwd
    enc_pwd="$(AES_128_ECB_ENCRYPT "$crypto_key" "$password")"
    local enc_payload
    enc_payload="$(AES_128_ECB_ENCRYPT "$crypto_key" "{}")"

    local cas_login_url="http://${AUTH_IP}/cas-sso/login?flowSessionId=${session_id}&customPageId=${custom_page_id}&preview=false&appType=normal&language=zh-CN&timer=$(date +%s%3N)&nasIp=${nas_ip}&userIp=${user_ip}&accept-language=zh-CN"

    local cas_resp
    cas_resp="$($curl_func -s -m "$REQUEST_TIMEOUT" -b "$cookie_file" -c "$cookie_file" -i -X POST "$cas_login_url" \
        -H "Origin: http://${AUTH_IP}" \
        -H "Referer: $center_url" \
        --data-urlencode "username=$username" \
        --data-urlencode "type=UsernamePassword" \
        --data-urlencode "_eventId=submit" \
        --data-urlencode "geolocation=" \
        --data-urlencode "execution=$execution" \
        --data-urlencode "captcha_code=" \
        --data-urlencode "croypto=$crypto_key" \
        --data-urlencode "password=$enc_pwd" \
        --data-urlencode "captcha_payload=$enc_payload")"

    # Step 4: 服务/运营商认证
    local service_resp
    service_resp="$($curl_func -s -m "$REQUEST_TIMEOUT" -b "$cookie_file" -c "$cookie_file" -X POST "http://${AUTH_IP}/eportal/network/serviceLogin" \
        -H 'Content-Type: application/json' \
        -d "{\"sessionId\":\"$session_id\",\"service\":\"$isp_code\"}")"

    rm -f "$cookie_file"

    if [[ "$service_resp" == *"\"authResult\""*"\"success\""* ]]; then
        echo "sessionId=$session_id"
        return "$YES"
    else
        local err_msg
        err_msg="$(printf '%s\n' "$service_resp" | sed -n 's/.*"authMessage"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        if [ -n "$err_msg" ] && [ "$err_msg" != "null" ]; then
            echo "$err_msg"
        elif [ -n "$service_resp" ]; then
            echo "$service_resp"
        else
            echo "认证无响应"
        fi
        return "$NO"
    fi
}

function LOGOUT() {
    local interface="$1"
    local session_id="$2"

    local curl_func="curl"
    if [ -n "$interface" ]; then
        curl_func="curl --interface $interface"
    fi

    # 若未提供 session_id，则自动请求重定向页面提取当前网卡的 sessionId
    if [ -z "$session_id" ]; then
        local user_ip=""
        if [ -n "$interface" ]; then
            user_ip="$(ip -4 addr show dev "$interface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"
        fi
        local probe_url="http://${AUTH_IP}/eportal/index.jsp?wlanuserip=${user_ip}&wlanacname=H3C%2dCR16010%2dF"
        local redir_resp
        if ! redir_resp="$($curl_func -s -m "$REQUEST_TIMEOUT" -i "$probe_url")"; then
            LOG "下线失败: 无法连接认证服务器"
            return "$NO"
        fi
        local location
        location="$(printf '%s\n' "$redir_resp" | sed -n 's/^[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn]:[[:space:]]*//p' | head -n1 | tr -d '\r\n')"
        session_id="$(printf '%s\n' "$location" | sed -n 's/.*[?&]sessionId=\([^&]*\).*/\1/p')"
    fi

    if [ -z "$session_id" ]; then
        LOG "下线失败: 未能获取到 sessionId"
        return "$NO"
    fi

    if ! $curl_func -s -m "$REQUEST_TIMEOUT" -X POST "http://${AUTH_IP}/eportal/network/offline" \
        -H 'Content-Type: application/json' \
        -d "{\"sessionId\":\"$session_id\"}" >/dev/null 2>&1; then
        LOG "下线失败: 请求认证中心下线接口超时或失败"
        return "$NO"
    fi

    $curl_func -s -m "$REQUEST_TIMEOUT" "http://${AUTH_IP}/cas-sso/logout" >/dev/null 2>&1

    return "$YES"
}

# 获取网卡当前的在线用户信息
# 参数:
#   $1 - interface: 网卡名称 (可选，如 macvlan1)
#   $2 - session_id: 认证会话ID (可选，默认自动从重定向探测页面提取)
# 返回码:
#   $YES (0): 在线，stdout 输出键值对 (key=value 格式，每行一项)，推荐配合 base/CONVERT.sh 的 PARSE_KV 解析
#   $NO  (1): 确认离线，stdout 输出 "离线"
#   2       : 查询失败 (超时、网络不通或服务端异常)，stdout 输出错误信息
# 返回键名 (在线时):
#   userName: 学号/工号
#   authenticationTime: 认证时间 (YYYY-MM-DD HH:MM:SS)
#   nodeIp: 网卡IP
#   nodeMac: MAC地址
#   nodePhysicalLocation: 物理位置
#   userObjectId: 用户对象ID
#
# 使用示例:
#   if info_raw="$(GET_ONLINE_USER_INFO "macvlan1")"; then
#       declare -A user_info
#       PARSE_KV user_info "$info_raw"
#       echo "登录账号: ${user_info[userName]}"
#       echo "登录时间: ${user_info[authenticationTime]}"
#   fi
function GET_ONLINE_USER_INFO() {
    local interface="$1"
    local session_id="$2"

    local curl_func="curl"
    if [ -n "$interface" ]; then
        curl_func="curl --interface $interface"
    fi

    if [ -z "$session_id" ]; then
        local user_ip=""
        if [ -n "$interface" ]; then
            user_ip="$(ip -4 addr show dev "$interface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"
        fi
        local probe_url="http://${AUTH_IP}/eportal/index.jsp?wlanuserip=${user_ip}&wlanacname=H3C%2dCR16010%2dF"
        local redir_resp
        if ! redir_resp="$($curl_func -s -m "$REQUEST_TIMEOUT" -i "$probe_url")"; then
            echo "探测请求失败"
            return 2
        fi
        local location
        location="$(printf '%s\n' "$redir_resp" | sed -n 's/^[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn]:[[:space:]]*//p' | head -n1 | tr -d '\r\n')"
        session_id="$(printf '%s\n' "$location" | sed -n 's/.*[?&]sessionId=\([^&]*\).*/\1/p')"
    fi

    if [ -z "$session_id" ]; then
        echo "未能获取到 sessionId"
        return 2
    fi

    local response
    if ! response="$($curl_func -s -m "$REQUEST_TIMEOUT" "http://${AUTH_IP}/eportal/adaptor/getOnlineUserInfo?sessionId=${session_id}")"; then
        echo "请求失败"
        return 2
    fi

    if [ -z "$response" ]; then
        echo "无回复"
        return 2
    fi

    local code_val
    code_val="$(JSON_GET "$response" "code")"
    if [ "$code_val" != "200" ]; then
        echo "服务端响应异常"
        return 2
    fi

    local user_type
    user_type="$(JSON_TYPE "$response" "data.onlineUser")"
    if [ "$user_type" != "object" ]; then
        echo "离线"
        return "$NO"
    fi

    local name_type
    name_type="$(JSON_TYPE "$response" "data.onlineUser.userName")"
    if [ "$name_type" != "string" ]; then
        echo "离线"
        return "$NO"
    fi

    local user_name
    user_name="$(JSON_GET "$response" "data.onlineUser.userName")"
    if [ -z "$user_name" ] || [ "$user_name" == "null" ]; then
        echo "离线"
        return "$NO"
    fi

    local auth_time node_ip node_mac node_loc user_obj_id
    auth_time="$(JSON_GET "$response" "data.onlineUser.authenticationTime")"
    node_ip="$(JSON_GET "$response" "data.onlineUser.nodeIp")"
    node_mac="$(JSON_GET "$response" "data.onlineUser.nodeMac")"
    node_loc="$(JSON_GET "$response" "data.onlineUser.nodePhysicalLocation")"
    user_obj_id="$(JSON_GET "$response" "data.onlineUser.userObjectId")"

    printf 'userName=%s\n' "${user_name//[$'\r\n']/}"
    printf 'authenticationTime=%s\n' "${auth_time//[$'\r\n']/}"
    printf 'nodeIp=%s\n' "${node_ip//[$'\r\n']/}"
    printf 'nodeMac=%s\n' "${node_mac//[$'\r\n']/}"
    printf 'nodePhysicalLocation=%s\n' "${node_loc//[$'\r\n']/ }"
    printf 'userObjectId=%s\n' "${user_obj_id//[$'\r\n']/}"
    return "$YES"
}
