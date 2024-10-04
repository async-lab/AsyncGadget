#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 需要jq和jo
# 用于从Github拉取Release文件

##############################################
################### META #####################

MODULE_NAME="git_release_updater"

DIR="$(readlink -f "$(dirname "$0")")"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"

##############################################
################### GLOBAL ###################

# env
# export OWNER="Async-Lab"
# export REPO="AsyncWebServer"
# export PAT="xxx"
# export SERVICE_NAME="backend"

VERSION_FILE="$1"
JAR_FILE="$2"
TEMP_FILE="$3"

##############################################
################# TOOLFUNC ###################

function CURL() {
    if [ -z "$PAT" ]; then
        curl -s -L "$@"
    else
        curl -s -L -H "Authorization: Bearer $PAT" "$@"
    fi
}

function RESTART_SERVICE() {
    if ! systemctl restart "$SERVICE_NAME"; then
        return 1
    fi

    if ! systemctl status --no-pager "$SERVICE_NAME"; then
        return 1
    fi

    return 0
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "环境变量:"
    LOG "OWNER: \"Async-Lab\""
    LOG "REPO: \"AsyncWebServer\""
    LOG "PAT:\"xxxx\""
    LOG "SERVICE_NAME:\"backend\""
    LOG "用法:"
    LOG "git_release_updater.sh <VERSION_FILE> <JAR_FILE> <TEMP_FILE>"
}

function CHECK_PARAMS() {
    CHECK_IF_ALL_EXIST "$OWNER" "$REPO"
    return "$?"
}

function MAIN() {
    if ! CHECK_PARAMS; then
        USAGE
        EXIT 1
    fi

    LOG "检测新版本..."

    touch "$VERSION_FILE"
    local latest=$(CURL "https://api.github.com/repos/$OWNER/$REPO/releases/latest")
    local current_version=$(cat "$VERSION_FILE")
    local latest_version=$(echo "$latest" | jq -r .assets[].id)

    if [ "$current_version" != "$latest_version" ]; then
        LOG "当前版本:$current_version, 检测到新版本: $latest_version..."
        LOG "下载新版本..."

        rm -rf "$TEMP_FILE"

        local is_successful=$(RETURN_AS_OUTPUT CURL -H "Accept:application/octet-stream" -o "$TEMP_FILE" "https://api.github.com/repos/$OWNER/$REPO/releases/assets/$latest_version")

        if [ "$is_successful" -eq 0 ]; then
            LOG "下载完成!"

            mv "$JAR_FILE" "$JAR_FILE.bak"
            mv "$TEMP_FILE" "$JAR_FILE"
            if [ -n "$SERVICE_NAME" ]; then
                LOG "重启服务..."
                if ! RESTART_SERVICE; then
                    LOG "服务重启失败!"
                    LOG "重启上一版本……"
                    mv "$JAR_FILE.bak" "$JAR_FILE"
                    if ! RESTART_SERVICE; then
                        LOG "重启上一版本失败!"
                    else
                        LOG "重启上一版本成功!"
                    fi
                    EXIT 1
                fi

                rm -rf "$JAR_FILE.bak"
                echo "$latest_version" >./version
                LOG "服务重启成功!"
            fi
        else
            LOG "下载失败!"
        fi
    else
        LOG "当前无新版本"
    fi

    EXIT 0
}

RUN_MAIN MAIN "$@"
