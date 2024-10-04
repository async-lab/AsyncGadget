#!/bin/bash

# ./autoauth.sh 用户名 密码 macvlan1 <sleep_time> <timeout>

# 设置参数
USERNAME="$1"
PASSWORD="$2"
ISPNAME="$3"
INTERFACE="$4"       # 指定的网卡
SLEEPTIME="${5:-10}" # 默认为 10 秒
TIMEOUT="${6:-3}"    # 默认为 3 秒

ISP_MAPPING=("电信" "移动" "联通" "教育网")

CHECK_IP="223.5.5.5"
AUTH_IP="10.254.241.19"

# 检查网络连接
check_network() {
    if ping -I "$INTERFACE" -w "$TIMEOUT" -c "3" "$CHECK_IP" >/dev/null; then
        return 0
    else
        return 1
    fi
}

# 进行认证
auth() {
    GATEWAY_IP="$(netstat -nr | grep "$INTERFACE" | grep "^0.0.0.0" | awk '{print $2}')"

    RES_STR=$(curl --interface "$INTERFACE" -m "$TIMEOUT" -s "http://${GATEWAY_IP}" | grep -o "http://${AUTH_IP}/eportal/index.jsp?[^'\"']*")
    QUERY_STR="${RES_STR#*http://"${AUTH_IP}"/eportal/index.jsp?}"

    echo "$QUERY_STR"

    ENCODED_ISPNAME="${ISP_MAPPING[$ISPNAME]}"
    REFERER_PREFIX="http://${AUTH_IP}/eportal/index.jsp?"

    RESPONSE=$(curl --interface "$INTERFACE" -m "$TIMEOUT" -s \
        -X POST \
        -H "Host: ${AUTH_IP}" \
        -H "Connection: keep-alive" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36 Edg/118.0.2088.76" \
        -H "Accept: */*" \
        -H "Origin: http://${AUTH_IP}" \
        -H "Referer: $REFERER_PREFIX$QUERY_STR" \
        -H "Accept-Encoding: gzip, deflate" \
        -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6" \
        -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        --data-urlencode "userId=$USERNAME" \
        --data-urlencode "password=$PASSWORD" \
        --data-urlencode "service=$ENCODED_ISPNAME" \
        --data-urlencode "queryString=$QUERY_STR" \
        --data-urlencode "operatorPwd=" \
        --data-urlencode "operatorUserId=" \
        --data-urlencode "validcode=" \
        --data-urlencode "passwordEncrypt=false" \
        "http://${AUTH_IP}/eportal/InterFace.do?method=login")

    echo "$RESPONSE"
}

# URL 编码函数
urlencode() {
    local length="${#1}"
    for ((i = 0; i < length; i++)); do
        local c="${1:i:1}"
        case $c in
        [a-zA-Z0-9.~_-])
            printf '%s\n' "$c"
            ;;
        *)
            printf '%%%02X' "'$c"
            ;;
        esac
    done
}

# 主循环
while true; do
    echo "Checking the Network..."
    if check_network; then
        echo "The Network has been connected."
    else
        echo "Connecting..."
        RESPONSE=$(auth)
        echo "$RESPONSE"
        if [[ $RESPONSE == *"success"* ]]; then
            echo "Connected!"
        else
            echo "Fail to connect."
        fi
    fi

    echo "Sleeping for $SLEEPTIME s ..."
    sleep "$SLEEPTIME"
done
