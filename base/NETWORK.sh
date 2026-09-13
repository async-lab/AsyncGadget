#!/usr/bin/env bash
# -*- coding: utf-8 -*-

NETWORK_CHECK_IP="223.5.5.5"
NETWORK_CHECK_URL="https://connect.rom.miui.com/generate_204"
NETWORK_CHECK_TIMEOUT="2"
NETWORK_CHECK_RETRY="2"
NETWORK_CHECK_DELAY="1"

function CHECK_NETWORK() {
    local interface="$1"

    local ping_func="ping"

    if [ -n "$interface" ]; then
        ping_func="ping -I $interface"
    fi

    if $ping_func -W "$NETWORK_CHECK_TIMEOUT" -c 1 "$NETWORK_CHECK_IP" >/dev/null; then
        return 0
    fi

    if [ "$NETWORK_CHECK_RETRY" -eq 0 ]; then
        return 1
    fi

    if $ping_func -W "$NETWORK_CHECK_TIMEOUT" -c "$NETWORK_CHECK_RETRY" "$NETWORK_CHECK_IP" >/dev/null; then
        return 0
    else
        return 1
    fi
}

function CHECK_NETWORK_HTTPS() {
    local interface="$1"

    local curl_cmd=(curl -fs -o /dev/null
                    --connect-timeout "$NETWORK_CHECK_TIMEOUT"
                    --max-time "$NETWORK_CHECK_TIMEOUT")

    if [ -n "$interface" ]; then
        curl_cmd+=(--interface "$interface")
    fi

    local retry="${NETWORK_CHECK_RETRY:-2}"
    local delay="${NETWORK_CHECK_DELAY:-1}"
    local i
    for ((i=0; i<=retry; i++)); do
        if "${curl_cmd[@]}" "$NETWORK_CHECK_URL"; then
            return 0
        fi
        if (( i < retry && delay > 0 )); then
            sleep "$delay"
        fi
    done

    return 1
}
