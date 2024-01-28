#!/bin/bash

# 需要jq和jo
# 用于向Vault推送和拉取证书

HOST="https://vault.internal.asynclab.club:8888/v1"

USERNAME="$1"
PASSWORD="$2"

VAULT_TOKEN=""

VAULT_CERTIFICATE_PATH="/kv/data/certificate"

USAGE="$3"
DOMAIN="$4"
CERT_FILE="$5"
PRIVKEY_FILE="$6"

##############################################

function NO_OUTPUT() {
    "$@" >/dev/null 2>&1
    return $?
}

function RETURN_AS_OUTPUT() {
    NO_OUTPUT "$@"
    echo $?
}

function LOG() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $@"
}

function STDIN() {
    local params=()
    while IFS= read -r line; do
        params+=("$line")
    done
    "$@" "${params[@]}"
    return $?
}

##############################################

function CURL() {
    curl -s -X "$1" \
        "$HOST$2" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -H "X-Vault-Token:$VAULT_TOKEN" \
        -d "$3"
}

function INSERT_TO_JSON() {
    echo "$1" | jq -r ".\""$2"\"=\""$3"\""
}

##############################################

function INIT_VAULT_TOKEN() {
    local result=$(jo password="$PASSWORD" | STDIN CURL "POST" "/auth/ldap/login/$USERNAME")
    VAULT_TOKEN=$(echo "$result" | jq -r .auth.client_token)
}

function UPLOAD_CERTIFICATE() {
    local result=$(CURL "GET" "$VAULT_CERTIFICATE_PATH")
    local data=$(echo "$result" | jq -r .data.data)
    data=$(INSERT_TO_JSON "$data" ""$DOMAIN"_cert" $(cat "$CERT_FILE"))
    data=$(INSERT_TO_JSON "$data" ""$DOMAIN"_privkey" $(cat "$PRIVKEY_FILE"))
    jo data="$(echo "$data")" | NO_OUTPUT STDIN CURL "POST" "$VAULT_CERTIFICATE_PATH"
}

function DOWNLOAD_CERTIFICATE() {
    local result=$(CURL "GET" "$VAULT_CERTIFICATE_PATH")
    local cert=$(echo "$result" | jq -r .data.data."$DOMAIN"_cert)
    local privkey=$(echo "$result" | jq -r .data.data."$DOMAIN"_privkey)
    echo "$cert" >"$CERT_FILE"
    echo "$privkey" >"$PRIVKEY_FILE"
}

##############################################

function EXIT() {
    exit $@
}

function MAIN() {
    INIT_VAULT_TOKEN

    if [[ -z "$USERNAME" ]] || [[ -z "$PASSWORD" ]] || [[ -z "$DOMAIN" ]] || [[ -z "$CERT_FILE" ]] || [[ -z "$PRIVKEY_FILE" ]]; then
        LOG "请输入正确的参数!"
        LOG "run.sh [LDAP用户名] [LDAP密码] [DOWNLOAD/UPLOAD] [域名] [证书文件] [私钥文件]"
        EXIT 1
    fi

    if [[ "$USAGE" == "UPLOAD" ]]; then
        UPLOAD_CERTIFICATE
    elif [[ "$USAGE" == "DOWNLOAD" ]]; then
        DOWNLOAD_CERTIFICATE
    else
        LOG "请输入正确的参数!"
        EXIT 1
    fi

    EXIT 0
}

MAIN
