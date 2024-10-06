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

MAIN_PID=""
STD_FIFO=""
STD_TMP_FILE=""
DATA_TMP_FILE=""

if ! CHECK_FD 3; then
    exec 3<&0
fi

export STDIN="${STDIN:-3}"

##############################################
################# TOOLFUNC ###################

# 说来话长，如果trap了结束信号之后sleep，则这时无法触发trap指定的函数
# 所以这里将trap和主进程分离，保证trap的有效性
#
# 然后是STD_TMP，因为命令替换和管道都会创建子shell
# 如果子shell不耗时访问资源还好，耗时的话就会导致主shell结束了子shell还在访问资源
# 所以用一个文件去存标准输出，就可以在一个shell内完成函数给变量赋值的操作
function RUN_MAIN() {
    STD_FIFO="$(mktemp -u "/tmp/gadget_fifo.XXXXXX")"
    mkfifo "$STD_FIFO"
    STD_TMP_FILE="$(mktemp "/tmp/gadget_tmp.XXXXXX")"
    DATA_TMP_FILE="$(mktemp "/tmp/gadget_tmp.XXXXXX")"
    "$@" &
    MAIN_PID="$!"
    wait "$MAIN_PID"
}

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
    NO_OUTPUT rm -f "$STD_FIFO"
    NO_OUTPUT rm -f "$STD_TMP_FILE"
    NO_OUTPUT rm -f "$DATA_TMP_FILE"
    NO_OUTPUT kill "$MAIN_PID"
    NO_OUTPUT wait "$MAIN_PID"
    exec 3<&-
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

trap EXIT SIGINT SIGTERM SIGALRM
