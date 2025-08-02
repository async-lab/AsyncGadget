#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 将源接口源地址的数据转发到DSXHF

##############################################

MODULE_NAME="dsxtp"

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

export ROOT_DIR=${ROOT_DIR:-"$DIR/../.."}

source "$ROOT_DIR/base/IO.sh"
source "$ROOT_DIR/base/LOG.sh"

##############################################

LAUNCH_DELAY=5

TABLE_NAME="dsxtp"

SLEEP_INTERVAL=5

TIMEOUT=5

SELF_ADDR="192.168.2.1"

INTERFACE="br-lan"
SOURCE_ADDR="192.168.2.0/24"

DPORT="{80, 443}"

PROXY_ADDR="192.168.2.19"
PROXY_PORT="15777"

EXCLUSIVE_ADDR="{123.123.123.123, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16}"

function EXIT() {
	NO_OUTPUT nft delete table "$TABLE_NAME"
	LOG "停止..."
	LOG
	exit "$@"
}

function CHECK_PROXY() {
	for i in seq $1; do
		local is_working=$(RETURN_AS_OUTPUT curl -m "$TIMEOUT" -x http://$PROXY_ADDR:$PROXY_PORT https://google.com)
		if [ "$is_working" -eq 0 ]; then
			return 0
		fi
	done
	return 1
}

function ASCII_ART() {
	LOG
	LOG
	LOG "▓█████▄   ██████ ▒██   ██▒▄▄▄█████▓ ██▓███  "
	LOG "▒██▀ ██▌▒██    ▒ ▒▒ █ █ ▒░▓  ██▒ ▓▒▓██░  ██▒"
	LOG "░██   █▌░ ▓██▄   ░░  █   ░▒ ▓██░ ▒░▓██░ ██▓▒"
	LOG "░▓█▄   ▌  ▒   ██▒ ░ █ █ ▒ ░ ▓██▓ ░ ▒██▄█▓▒ ▒"
	LOG "░▒████▓ ▒██████▒▒▒██▒ ▒██▒  ▒██▒ ░ ▒██▒ ░  ░"
	LOG " ▒▒▓  ▒ ▒ ▒▓▒ ▒ ░▒▒ ░ ░▓ ░  ▒ ░░   ▒▓▒░ ░  ░"
	LOG " ░ ▒  ▒ ░ ░▒  ░ ░░░   ░▒ ░    ░    ░▒ ░     "
	LOG " ░ ░  ░ ░  ░  ░   ░    ░    ░      ░░       "
	LOG "   ░          ░   ░    ░                    "
	LOG " ░                                          "
	LOG
}

function MAIN() {
	LOG
	LOG "nftables表名:         $TABLE_NAME"
	LOG "本机局域网IP:         $SELF_ADDR"
	LOG "代理服务器地址:       $PROXY_ADDR:$PROXY_PORT"
	LOG "代理子网设备接口源:   $INTERFACE"
	LOG "代理子网设备地址:	    $SOURCE_ADDR"
	LOG "代理端口:             $DPORT"

	ASCII_ART

	LOG "启动..."

	local is_service_online=1
	local is_last_proxy_online=0
	local is_last_proxy_working=0

	while true; do
		local is_table_exists=$(RETURN_AS_OUTPUT nft list table "$TABLE_NAME")
		local is_proxy_online=$(echo -e "\n" | RETURN_AS_OUTPUT nc "$PROXY_ADDR" "$PROXY_PORT")
		local is_proxy_working=$(RETURN_AS_OUTPUT CHECK_PROXY 5)

		if [ "$is_service_online" -eq 1 ] && [ "$is_table_exists" -eq 0 ]; then
			LOG "疑似已经开启相同进程，请不要重复开启"
			EXIT 1
		fi

		if [ "$is_proxy_online" -eq 1 ]; then
			if [ "$is_last_proxy_online" -eq 0 ]; then
				LOG "无法连接至代理服务器"

				local is_delete_success=$(RETURN_AS_OUTPUT nft delete table "$TABLE_NAME")
				if [ "$is_delete_success" -eq 0 ]; then
					LOG "关闭透明代理..."
				fi

				is_service_online=1
				STATE "服务离线"
			fi
		elif [ "$is_proxy_working" -eq 1 ]; then
			if [ "$is_last_proxy_working" -eq 0 ]; then
				is_service_online=1
				LOG "代理服务器无效"

				local is_delete_success=$(RETURN_AS_OUTPUT nft delete table "$TABLE_NAME")
				if [ "$is_delete_success" -eq 0 ]; then
					LOG "关闭透明代理..."
				fi

				is_service_online=1
				STATE "服务离线"
			fi
		elif [ "$is_table_exists" -eq 1 ]; then
			LOG "启动透明代理..."

			# 创建表
			nft add table ip "$TABLE_NAME"

			# 本地发出数据包
			nft add chain ip "$TABLE_NAME" output { type nat hook output priority -100 \; }
			# 源地址为SELF_ADDR，目的地址不为SELF_ADDR且目的端口为DPORT的包，将改变目的地址到代理地址
			# 代理本设备（发出方向）
			nft add rule \
				ip "$TABLE_NAME" output \
				ip daddr != "$SELF_ADDR" \
				ip daddr != "$SOURCE_ADDR" \
				ip daddr != "$EXCLUSIVE_ADDR" \
				tcp dport "$DPORT" \
				dnat to "$PROXY_ADDR":"$PROXY_PORT"

			# 在路由规则前，刚刚接收到数据包
			nft add chain ip "$TABLE_NAME" prerouting { type nat hook prerouting priority -100 \; }
			# 从INTERFACE进入，源地址为SOURCE_ADDR且不为PROXY_ADDR，目的地址不为SELF_ADDR且目的端口为DPORT的包，将改变目的地址到代理地址
			# 代理子网设备（发出方向）
			nft add rule \
				ip "$TABLE_NAME" prerouting iifname "$INTERFACE" \
				ip saddr "$SOURCE_ADDR" \
				ip saddr != "$PROXY_ADDR" \
				ip daddr != "$SELF_ADDR" \
				ip daddr != "$SOURCE_ADDR" \
				ip daddr != "$EXCLUSIVE_ADDR" \
				tcp dport "$DPORT" \
				dnat to "$PROXY_ADDR":"$PROXY_PORT"

			# # 经过路由规则后，即将发出数据包
			nft add chain ip "$TABLE_NAME" postrouting { type nat hook postrouting priority -100 \; }
			# 要从INTERFACE发送，源地址为SOURCE_ADDR，目的端口为DPORT的包，伪装其IP地址
			# 伪装子网设备IP（接收方向）
			nft add rule \
				ip "$TABLE_NAME" postrouting oifname "$INTERFACE" \
				ip saddr "$SOURCE_ADDR" \
				ip daddr "$PROXY_ADDR" \
				tcp dport "$DPORT" \
				masquerade

			is_service_online=0
			LOG "透明代理已启动"
			STATE "服务在线"
		fi

		is_last_proxy_online=$is_proxy_online
		is_last_proxy_working=$is_proxy_working
		sleep $SLEEP_INTERVAL
	done
}

trap EXIT SIGINT SIGTERM SIGQUIT

sleep "$LAUNCH_DELAY"

MAIN
