#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 标准Gadget库

##############################################
################### META #####################

DIR="$(readlink -f "$(dirname "$0")")"
export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/IO.sh"
source "$ROOT_DIR/base/LOG.sh"
source "$ROOT_DIR/base/LOGIC.sh"
source "$ROOT_DIR/base/UTIL.sh"
source "$ROOT_DIR/base/TERMINAL.sh"

##############################################
################### GLOBAL ###################

##############################################
################# TOOLFUNC ###################

##############################################
################ PROCESSFUNC #################

function DEFAULT_USAGE() {
    LOG "请输入正确的参数!"
}

function DEFAULT_EXIT() {
    if [ -n "$MODULE_NAME" ]; then
        LOG "正在退出${MODULE_NAME}..."
    else
        LOG "正在退出..."
    fi
    exit "$@"
}

function DEFAULT_CHECK_PARAMS() {
    return 0
}

function DEFAULT_MAIN() {
    EXIT 0
}

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    DEFAULT_USAGE
}

function EXIT() {
    DEFAULT_EXIT "$@"
}

function CHECK_PARAMS() {
    return "$(RETURN_AS_OUTPUT DEFAULT_CHECK_PARAMS)"
}

function MAIN() {
    DEFAULT_MAIN
}

trap EXIT SIGINT SIGTERM
