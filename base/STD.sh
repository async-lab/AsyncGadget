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

##############################################
################### GLOBAL ###################

##############################################
################# TOOLFUNC ###################

##############################################
################ PROCESSFUNC #################

##############################################
################ PROGRAMFUNC #################

function USAGE() {
    LOG "请输入正确的参数!"
}

function EXIT() {
    LOG "正在退出..."
    exit "$@"
}

function CHECK_PARAMS() {
    return 0
}

function MAIN() {
    EXIT 0
}

trap EXIT SIGINT SIGTERM
