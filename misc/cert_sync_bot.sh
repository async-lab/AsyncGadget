#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 需要jq和jo
# 用于向Vault推送和拉取证书

##############################################
################### META #####################

MODULE_NAME="cert_sync_bot"

DIR="$(readlink -f "$(dirname "$0")")"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/IO.sh"
source "$ROOT_DIR/base/LOG.sh"
source "$ROOT_DIR/base/LOGIC.sh"
source "$ROOT_DIR/base/UTIL.sh"

##############################################
################### GLOBAL ###################

# env
# export VAULT_HOST="https://vault.internal.asynclab.club:8888/v1"
# export VAULT_CERTIFICATE_PATH="/kv/data/certificate"
# export USERNAME="用户名"
# export PASSWORD="密码"

METHOD="$1"
DOMAIN="$2"
CERT_FILE="$3"
PRIVKEY_FILE="$4"

VAULT_TOKEN=""

##############################################
################# TOOLFUNC ###################

function CURL() {
    curl -s -X "$1" \
        "$VAULT_HOST$2" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -H "X-Vault-Token:$VAULT_TOKEN" \
        -d "$3"
}

function INSERT_TO_JSON() {
    echo "$1" | jq -r ".\"$2\"=\"$3\""
}

##############################################
################ PROCESSFUNC #################

function INIT_VAULT_TOKEN() {
    local result=$(jo password="$PASSWORD" | STDIN CURL "POST" "/auth/ldap/login/$USERNAME")
    VAULT_TOKEN=$(echo "$result" | jq -r .auth.client_token)
}

function UPLOAD_CERTIFICATE() {
    if [ ! -f "$CERT_FILE" ]; then
        LOG "证书文件不存在!"
        return
    elif [ ! -f "$PRIVKEY_FILE" ]; then
        LOG "私钥文件不存在!"
        return
    fi
    local result=$(CURL "GET" "$VAULT_CERTIFICATE_PATH")
    local data=$(echo "$result" | jq -r .data.data)
    data=$(INSERT_TO_JSON "$data" "${DOMAIN}.cert" "$(cat "$CERT_FILE")")
    data=$(INSERT_TO_JSON "$data" "${DOMAIN}.privkey" "$(cat "$PRIVKEY_FILE")")
    jo data="$data" | NO_OUTPUT STDIN CURL "POST" "$VAULT_CERTIFICATE_PATH"
}

function DOWNLOAD_CERTIFICATE() {
    local result=$(CURL "GET" "$VAULT_CERTIFICATE_PATH")
    local cert=$(echo "$result" | jq -r .data.data.\""$DOMAIN".cert\")
    local privkey=$(echo "$result" | jq -r .data.data.\""$DOMAIN".privkey\")
    mkdir -p "$(dirname "$CERT_FILE")"
    mkdir -p "$(dirname "$PRIVKEY_FILE")"
    echo "$cert" >"$CERT_FILE"
    echo "$privkey" >"$PRIVKEY_FILE"
}

##############################################
################ PROGRAMFUNC #################

function EXIT() {
    exit "$@"
}

function USAGE() {
    LOG "环境变量:"
    LOG "VAULT_HOST: \"https://vault.internal.asynclab.club:8888/v1\""
    LOG "VAULT_CERTIFICATE_PATH: \"/kv/data/certificate\""
    LOG "USERNAME: \"用户名\""
    LOG "PASSWORD: \"密码\""
    LOG "用法:"
    LOG "cert_sync_bot.sh <DOWNLOAD/UPLOAD> <域名> <证书文件> <私钥文件>"
}

function CHECK_PACKAGES() {
    local packages=("jq" "jo")
    local completed=0
    for package in "${packages[@]}"; do
        if ! CHECK_PACKAGE "$package"; then
            LOG "未安装 $package"
            completed=1
        fi
    done
    return "$completed"
}

function CHECK_PARAMS() {
    CHECK_IF_ALL_EXIST "$VAULT_HOST" "$VAULT_CERTIFICATE_PATH" "$VAULT_CERTIFICATE_PATH" "$PASSWORD" "$METHOD" "$DOMAIN" "$CERT_FILE" "$PRIVKEY_FILE"
    if [ "$METHOD" != "DOWNLOAD" ] && [ "$METHOD" != "UPLOAD" ]; then
        return 1
    fi
    return "$?"
}

function MAIN() {
    if ! CHECK_PACKAGES; then
        EXIT 1
    fi

    if ! CHECK_PARAMS; then
        USAGE
        EXIT 1
    fi

    LOG

    INIT_VAULT_TOKEN

    case "$METHOD" in
    "UPLOAD")
        LOG "上传中..."
        UPLOAD_CERTIFICATE
        LOG "上传完成!"
        LOG "域名: $DOMAIN"
        LOG "cert文件路径: $CERT_FILE"
        LOG "privkey文件路径: $PRIVKEY_FILE"
        ;;
    "DOWNLOAD")
        LOG "下载中..."
        DOWNLOAD_CERTIFICATE
        LOG "下载完成!"
        LOG "域名: $DOMAIN"
        LOG "cert文件路径: $CERT_FILE"
        LOG "privkey文件路径: $PRIVKEY_FILE"
        ;;
    *)
        USAGE
        EXIT 1
        ;;
    esac

    EXIT 0
}

MAIN "$@"
