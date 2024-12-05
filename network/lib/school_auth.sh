#!/usr/bin/env bash
# -*- coding: utf-8 -*-

AUTH_IP="10.254.241.19"
ISP_MAPPING=("电信" "移动" "联通" "教育网")
REQUEST_TIMEOUT="3"

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
    local response="$(curl --interface "$interface" -m "$REQUEST_TIMEOUT" -s -X POST http://${AUTH_IP}/eportal/InterFace.do?method=logout)"

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
