#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 更新gadget

##############################################
################### META #####################

MODULE_NAME="update"

DIR="$(readlink -f "$(dirname "$0")")"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/STD.sh"

##############################################
################### GLOBAL ###################

DEPENDED_PACKAGES=("git")

##############################################
################# TOOLFUNC ###################

##############################################
################ PROCESSFUNC #################

##############################################
################ PROGRAMFUNC #################

function MAIN() {
    if ! DEFAULT_MAIN; then
        EXIT 1
    fi

    cd "$ROOT_DIR" &>"$STD_TMP_FILE" || true
    local err="$(<"$STD_TMP_FILE")"

    if [ -n "$err" ]; then
        LOG_MULTILINE "$err"
        EXIT 1
    fi

    git pull &>"$STD_TMP_FILE" || true
    local res="$(<"$STD_TMP_FILE")"

    if [ -n "$res" ]; then
        LOG_MULTILINE "$res"
        EXIT 1
    fi

    EXIT 0
}

RUN_MAIN MAIN "$@"
