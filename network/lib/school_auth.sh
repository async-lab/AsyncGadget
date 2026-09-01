#!/usr/bin/env bash
# -*- coding: utf-8 -*-

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR=${ROOT_DIR:-"$DIR/../.."}
REQUIRE "$ROOT_DIR/base/AES.sh"

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
            user_ip="$(ip -4 addr show dev "$interface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)"
        fi
        local probe_url="http://${AUTH_IP}/eportal/index.jsp?wlanuserip=${user_ip}&wlanacname=H3C%2dCR16010%2dF"
        local redir_resp
        redir_resp="$($curl_func -s -m "$REQUEST_TIMEOUT" -i "$probe_url")"
        local location
        location="$(printf '%s\n' "$redir_resp" | awk -F': ' '/[Ll]ocation:/ {print $2}' | tr -d '\r\n')"
        session_id="$(printf '%s\n' "$location" | sed -n 's/.*[?&]sessionId=\([^&]*\).*/\1/p')"
    fi

    if [ -n "$session_id" ]; then
        $curl_func -s -m "$REQUEST_TIMEOUT" -X POST "http://${AUTH_IP}/eportal/network/offline" \
            -H 'Content-Type: application/json' \
            -d "{\"sessionId\":\"$session_id\"}" >/dev/null 2>&1
    fi

    $curl_func -s -m "$REQUEST_TIMEOUT" "http://${AUTH_IP}/cas-sso/logout" >/dev/null 2>&1

    return "$YES"
}
function GET_ONLINE_USER_INFO() {
    local interface="$1"
    local session_id="$2"

    if [ -z "$session_id" ]; then
        echo "缺少sessionId"
        return "$NO"
    fi

    local curl_func="curl"
    if [ -n "$interface" ]; then
        curl_func="curl --interface $interface"
    fi

    local response
    response="$($curl_func -s -m "$REQUEST_TIMEOUT" -X POST "http://${AUTH_IP}/eportal/workFlow/getCurrentNode" \
        -H 'Content-Type: application/json' \
        -d "{\"sessionId\":\"$session_id\",\"flowKey\":\"portal_auth\"}")"

    if [ -z "$response" ]; then
        echo "无回复"
        return "$NO"
    fi

    echo "$response"

    if [[ "$response" == *"\"currentNodePath\""*"\"finish\""* ]] || [[ "$response" == *"\"code\""*"200"* ]]; then
        return "$YES"
    fi
    return "$NO"
}
