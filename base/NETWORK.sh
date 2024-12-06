#!/usr/bin/env bash
# -*- coding: utf-8 -*-

NETWORK_CHECK_IP="223.5.5.5"
NETWORK_CHECK_TIMEOUT="3"
NETWORK_CHECK_RETRY="5"

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
