#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 管理compose和apt定时更新任务

##############################################
################### META #####################

MODULE_NAME="cron_updater"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"

##############################################
################### GLOBAL ###################

SERVICE="$1"
CRON_EXPR="${2:-0 2 * * *}"

DEPENDED_PACKAGES=("crontab")

if [[ "$SERVICE" == compose:* ]]; then
    DEPENDED_PACKAGES+=("flock")
fi

##############################################
################ PROCESSFUNC #################

function TOGGLE_CRON() {
    local mark="$1"
    local expr="$2"
    local command="$3"
    local marker

    marker="# AsyncGadget cron_updater: $mark"
    marker="${marker//%/\\%}"
    command="${command//%/\\%}"

    if crontab -l 2>/dev/null | grep -Fq -- "$marker"; then
        crontab -l 2>/dev/null | grep -Fv -- "$marker" | crontab - || return 1
        LOG "已关闭定时任务: $mark"
        return 0
    fi

    (crontab -l 2>/dev/null; printf "%s %s %s\n" "$expr" "$command" "$marker") | crontab - || return 1
    LOG "已开启定时任务: $mark ($expr)"
}

function UPSERT_CRON() {
    local mark="$1"
    local expr="$2"
    local command="$3"
    local marker
    local existed=false

    marker="# AsyncGadget cron_updater: $mark"
    marker="${marker//%/\\%}"
    command="${command//%/\\%}"

    if crontab -l 2>/dev/null | grep -Fq -- "$marker"; then
        existed=true
    fi

    (crontab -l 2>/dev/null | grep -Fv -- "$marker"; printf "%s %s %s\n" "$expr" "$command" "$marker") | crontab - || return 1

    if [ "$existed" == true ]; then
        LOG "已更新定时任务: $mark ($expr)"
    else
        LOG "已开启定时任务: $mark ($expr)"
    fi
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "请输入正确的参数!"
    LOG "用法: cron_updater.sh compose:<compose目录> [\"cron表达式\"]"
    LOG "      cron_updater.sh apt [\"cron表达式\"]"
    LOG "未指定cron表达式时切换任务，指定时新增或更新任务"
}

function CHECK_PARAMS() {
    [[ "$SERVICE" == compose:* ]] || [ "$SERVICE" == "apt" ]
}

function MAIN() {
    local compose_dir
    local compose_dir_arg
    local compose_command
    local marker_name
    local command

    if ! DEFAULT_MAIN; then
        EXIT 1
    fi

    if [[ "$SERVICE" == compose:* ]]; then
        compose_dir_arg="${SERVICE#compose:}"
        if [ -z "$compose_dir_arg" ]; then
            USAGE
            EXIT 1
        fi
        compose_dir="$(cd -- "$compose_dir_arg" 2>/dev/null && pwd -P)"
        if [ -z "$compose_dir" ]; then
            LOG "compose目录不存在: $compose_dir_arg"
            EXIT 1
        fi
        if [[ "$compose_dir" == *$'\n'* ]] || [[ "$compose_dir" == *$'\r'* ]]; then
            LOG "路径不能包含换行符!"
            EXIT 1
        fi
        marker_name="compose:$compose_dir"
        compose_command="cd $(QUOTE "$compose_dir") && docker compose up -d --pull always && docker system prune -af"
        command="flock -w 3600 /tmp/asyncgadget-docker-update.lock sh -c $(QUOTE "$compose_command")"
    else
        marker_name="apt"
        command="apt update && apt dist-upgrade -y && apt autoremove -y"
    fi

    case "$#" in
    1)
        TOGGLE_CRON "$marker_name" "$CRON_EXPR" "$command" || EXIT 1
        ;;
    2)
        UPSERT_CRON "$marker_name" "$CRON_EXPR" "$command" || EXIT 1
        ;;
    *)
        USAGE
        EXIT 1
        ;;
    esac
    EXIT 0
}

RUN_MAIN MAIN "$@"
