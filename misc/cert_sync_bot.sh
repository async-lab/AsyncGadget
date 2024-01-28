#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 需要jq和jo
# 用于向Vault推送和拉取证书

##############################################

MODULE_NAME="cert_sync_bot"

DIR="$(readlink -f "$(dirname "$0")")"

export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/IO.sh"
source "$ROOT_DIR/base/LOG.sh"
source "$ROOT_DIR/base/JSON.sh"
source "$ROOT_DIR/base/UTIL.sh"

##############################################

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

function CURL() {
    curl -s -X "$1" \
        "$VAULT_HOST$2" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -H "X-Vault-Token:$VAULT_TOKEN" \
        -d "$3"
}

##############################################

function INIT_VAULT_TOKEN() {
    local result=$(jo password="$PASSWORD" | STDIN CURL "POST" "/auth/ldap/login/$USERNAME")
    VAULT_TOKEN=$(echo "$result" | jq -r .auth.client_token)
}

function UPLOAD_CERTIFICATE() {
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
    echo "$cert" >"$CERT_FILE"
    echo "$privkey" >"$PRIVKEY_FILE"
}

##############################################

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

function CHECK_PARAMS() {
    CHECK_IF_ALL_EXIST "$VAULT_HOST" "$VAULT_CERTIFICATE_PATH" "$VAULT_CERTIFICATE_PATH" "$PASSWORD" "$DOMAIN" "$CERT_FILE" "$PRIVKEY_FILE"
}

function MAIN() {
    if [ "$(CHECK_PARAMS)" -eq 1 ]; then
        USAGE
        EXIT 1
    fi

    LOG

    INIT_VAULT_TOKEN

    if [ "$METHOD" == "UPLOAD" ]; then
        LOG "上传中..."
        UPLOAD_CERTIFICATE
        LOG "上传完成!"
        LOG "域名: $DOMAIN"
        LOG "cert文件路径: $CERT_FILE"
        LOG "privkey文件路径: $PRIVKEY_FILE"
    elif [ "$METHOD" == "DOWNLOAD" ]; then
        LOG "下载中..."
        DOWNLOAD_CERTIFICATE
        LOG "下载完成!"
        LOG "域名: $DOMAIN"
        LOG "cert文件路径: $CERT_FILE"
        LOG "privkey文件路径: $PRIVKEY_FILE"
    else
        USAGE
        EXIT 1
    fi

    EXIT 0
}

MAIN "$@"
