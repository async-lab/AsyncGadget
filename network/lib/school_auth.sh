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

    local query_result="$($curl_func -m "$REQUEST_TIMEOUT" -s "http://${gateway_ip}" | grep -o "http://${AUTH_IP}/eportal/index.jsp?[^'\"']*")"
    local query_str="${query_result#*http://"${AUTH_IP}"/eportal/index.jsp?}"

    local referer_prefix="http://${AUTH_IP}/eportal/index.jsp?"

    local response="$($curl_func -m "$REQUEST_TIMEOUT" -s \
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
