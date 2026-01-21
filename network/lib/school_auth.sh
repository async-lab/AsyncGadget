#!/usr/bin/env bash
# -*- coding: utf-8 -*-

AUTH_IP="10.254.241.19"
ISP_MAPPING=("电信" "移动" "联通" "教育网")
REQUEST_TIMEOUT="3"

function AUTH() {
    local isp_name="${ISP_MAPPING[$1]}"
    local username="$2"
    local password="$3"
    local interface="$4"

    local curl_func="curl"
    if [ -n "$interface" ]; then
        curl_func="curl --interface $interface"
    fi

    local gateway_ip="$(ip route show dev "$interface" default 2>/dev/null | awk '{print $3}')" #用网关做query ip可以省一个路由规则，因为链上的不需要路由

    local query_result="$($curl_func -m "$REQUEST_TIMEOUT" -s "http://${gateway_ip}" | grep -o "http://${AUTH_IP}/eportal/index\.jsp?[^\"' ]*")"
    local query_str="${query_result#*http://"${AUTH_IP}"/eportal/index.jsp?}"

    local referer_prefix="http://${AUTH_IP}/eportal/index.jsp?"

    local raw_response="$($curl_func -m "$REQUEST_TIMEOUT" -s -D - \
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

    local header=""
    local response="$raw_response"
    if [[ "$raw_response" == *$'\r\n\r\n'* ]]; then
        header="${raw_response%%$'\r\n\r\n'*}"
        response="${raw_response#*$'\r\n\r\n'}"
    elif [[ "$raw_response" == *$'\n\n'* ]]; then
        header="${raw_response%%$'\n\n'*}"
        response="${raw_response#*$'\n\n'}"
    fi

    if [[ "$response" == *"success"* ]]; then
        local cookie_value=""
        if [ -n "$header" ]; then
            cookie_value="$(printf '%s\n' "$header" | tr -d '\r' | sed -n 's/^[Ss]et-[Cc]ookie:.*JSESSIONID=\([^;]*\).*/\1/p' | tail -n1)"
        fi
        if [ -n "$cookie_value" ]; then
            echo "JSESSIONID=$cookie_value"
        fi
        return "$YES"
    elif [ -z "$response" ]; then
        echo "无回复"
        return "$NO"
    else
        echo "$response"
        return "$NO"
    fi
}

function LOGOUT() {
    local interface="$1"

    local curl_func="curl"
    if [ -n "$interface" ]; then
        curl_func="curl --interface $interface"
    fi

    local response="$($curl_func -m "$REQUEST_TIMEOUT" -s -X POST http://${AUTH_IP}/eportal/InterFace.do?method=logout)"

    if [[ "$response" == *"success"* ]]; then
        return "$YES"
    elif [ -z "$response" ]; then
        echo "无回复"
        return "$NO"
    else
        echo "$response"
        return "$NO"
    fi
}

function GET_ONLINE_USER_INFO() {
    local interface="$1"
    local user_index="$2"
    local cookie_string="$3"
    local keepalive_interval="${4:-0}"

    if [ -z "$user_index" ]; then
        echo "缺少userIndex"
        return "$NO"
    fi

    local curl_func="curl"
    if [ -n "$interface" ]; then
        curl_func="curl --interface $interface"
    fi

    local -a cookie_args=()
    if [ -n "$cookie_string" ]; then
        cookie_args=(-b "$cookie_string")
    fi

    local referer="http://${AUTH_IP}/eportal/success.jsp?userIndex=$user_index&keepaliveInterval=$keepalive_interval"

    local response="$($curl_func -m "$REQUEST_TIMEOUT" -s \
        "${cookie_args[@]}" \
        -X POST \
        -H "Host: ${AUTH_IP}" \
        -H "Connection: keep-alive" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36 Edg/118.0.2088.76" \
        -H "Accept: */*" \
        -H "Origin: http://${AUTH_IP}" \
        -H "Referer: $referer" \
        -H "Accept-Encoding: gzip, deflate" \
        -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6" \
        -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        --data-urlencode "userIndex=$user_index" \
        "http://${AUTH_IP}/eportal/InterFace.do?method=getOnlineUserInfo")"

    if [ -z "$response" ]; then
        echo "无回复"
        return "$NO"
    fi

    echo "$response"

    if [[ "$response" == *"\"result\":\"success\""* ]] || [[ "$response" == *"\"result\":\"wait\""* ]]; then
        return "$YES"
    fi
    return "$NO"
}

function KEEPALIVE() {
    local interface="$1"
    local user_index="$2"
    local cookie_string="$3"
    local keepalive_interval="${4:-0}"

    if [ -z "$user_index" ]; then
        echo "缺少userIndex"
        return "$NO"
    fi

    local curl_func="curl"
    if [ -n "$interface" ]; then
        curl_func="curl --interface $interface"
    fi

    local -a cookie_args=()
    if [ -n "$cookie_string" ]; then
        cookie_args=(-b "$cookie_string")
    fi

    local referer="http://${AUTH_IP}/eportal/success.jsp?userIndex=$user_index&keepaliveInterval=$keepalive_interval"

    local response="$($curl_func -m "$REQUEST_TIMEOUT" -s \
        "${cookie_args[@]}" \
        -X POST \
        -H "Host: ${AUTH_IP}" \
        -H "Connection: keep-alive" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36 Edg/118.0.2088.76" \
        -H "Accept: */*" \
        -H "Origin: http://${AUTH_IP}" \
        -H "Referer: $referer" \
        -H "Accept-Encoding: gzip, deflate" \
        -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6" \
        -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        --data-urlencode "userIndex=$user_index" \
        "http://${AUTH_IP}/eportal/InterFace.do?method=keepalive")"

    if [ -z "$response" ]; then
        echo "无回复"
        return "$NO"
    fi

    if [[ "$response" == *"success"* ]]; then
        echo "$response"
        return "$YES"
    else
        echo "$response"
        return "$NO"
    fi
}
