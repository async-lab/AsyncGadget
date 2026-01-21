#!/usr/bin/env bash
# -*- coding: utf-8 -*-

#
#   0-------------------------------->x
#   | [xxx] xxx
#   | [xxx] xxx
#   | [xxx] xxx
#   |
#   |
#   |
#   v
#   y

SURFACE_LAYER_STDIN_FD="${SURFACE_LAYER_STDIN_FD:-0}"

# 切换到 xterm 备用屏幕（退出时再切回），避免退出后破坏主屏内容
function ALT_SCREEN_ENABLE() {
    echo -ne "\e[?1049h"
}

function ALT_SCREEN_DISABLE() {
    echo -ne "\e[?1049l"
}

# xterm synchronized output：在 disable 前不刷新屏幕，减少大块重绘闪烁
function XTERM_SYNC_ENABLE() {
    echo -ne "\e[?2026h"
}

function XTERM_SYNC_DISABLE() {
    echo -ne "\e[?2026l"
}

function CLEAR_RESET() {
    echo -ne "\ec"
}

function CLEAR() {
    echo -ne "\e[2J\e[H"
}

function CLEAR_TO_START() {
    echo -ne "\e[1J\e[H"
}

function CLEAR_LINE() {
    echo -ne "\e[K"
}

function CLEAR_TO_END() {
    echo -ne "\e[J"
}

function CLEAR_FROM_START_TO_END() {
    echo -ne "\e[H\e[J"
}

function CURSOR_SAVE() {
    echo -ne "\e[s"
}

function CURSOR_RESTORE() {
    echo -ne "\e[u"
}

function CURSOR_MOVE() {
    local x="$1"
    local y="$2"

    if [ "$x" -gt 0 ] && [ "$y" -gt 0 ]; then
        echo -ne "\e[${x};${y}H"
    fi
}

function CURSOR_TO_START() {
    echo -ne "\e[H"
}

function CURSOR_TO_END() {
    echo -ne "\e[99999;99999H"
}

function CURSOR_OFFSET_TO_LINE_START() {
    local n="$1"

    if [ "$n" -gt 0 ]; then
        echo -ne "\e[${n}E"
    elif [ "$n" -lt 0 ]; then
        n="$((-n))"
        echo -ne "\e[${n}F"
    else
        echo -ne "\e[G"
    fi
}

function CURSOR_OFFSET() {
    local x="$1"
    local y="$2"

    if [ "$x" -gt 0 ]; then
        echo -ne "\e[${x}C"
    elif [ "$x" -lt 0 ]; then
        x="$((-x))"
        echo -ne "\e[${x}D"
    fi

    if [ "$y" -gt 0 ]; then
        echo -ne "\e[${y}B"
    elif [ "$y" -lt 0 ]; then
        y="$((-y))"
        echo -ne "\e[${y}A"
    fi
}

function CURSOR_MOVE_HORIZONTAL() {
    local n="$1"

    if [ "$n" -gt 0 ]; then
        echo -ne "\e[${n}G"
    fi
}

function HIDE_CURSOR() {
    echo -ne "\e[?25l"
}

function SHOW_CURSOR() {
    echo -ne "\e[?25h"
}

function DISABLE_ECHO() {
    echo -ne "\033[8m"
}

function ENABLE_ECHO() {
    echo -ne "\e[0m"
}

function ECHO_COLOR() {
    local args=("$@")
    echo "$(echo -ne "\e[${1}m")${args["${#args[@]}" - 1]}$(echo -ne "\e[0m")"
}

function DEC_REQUEST() {
    local request="$1"
    local end_mark="$2"

    echo -ne "$request" >/dev/tty
    read -d "$end_mark" -s -r response <&"$SURFACE_LAYER_STDIN_FD"
    echo "$response"
}

function DSR() {
    DEC_REQUEST '\e[6n' 'R'
}

function DECRQTSR() {
    DEC_REQUEST '\e[18t' 't'
}

function _CHECK_DECRQTSR() {
    echo -ne "\e[18t" >/dev/tty
    if ! read -t 0.1 -d 't' -s -r response 2>/dev/null; then
        read -t 1 -d 't' -s -r response
    fi
    if [ -n "$response" ]; then
        return 0
    else
        return 1
    fi
}

WINDOW_INFO_SOURCE="CONST"

if command -v tput >/dev/null 2>&1; then
    WINDOW_INFO_SOURCE="TPUT"
elif command -v stty >/dev/null 2>&1; then
    WINDOW_INFO_SOURCE="STTY"
elif _CHECK_DECRQTSR <&"$SURFACE_LAYER_STDIN_FD"; then
    WINDOW_INFO_SOURCE="DEC"
elif [ -n "$LINES" ]; then
    WINDOW_INFO_SOURCE="ENV"
fi

function GET_LINES() {
    case "$WINDOW_INFO_SOURCE" in
    "TPUT")
        tput lines 2>/dev/null
        ;;
    "STTY")
        stty size 2>/dev/null <&"$SURFACE_LAYER_STDIN_FD" | cut -d' ' -f1
        ;;
    "DEC")
        DECRQTSR | cut -d';' -f2
        ;;
    "ENV")
        echo "$LINES"
        ;;
    *)
        echo "30"
        ;;
    esac
}

function GET_COLUMNS() {
    case "$WINDOW_INFO_SOURCE" in
    "TPUT")
        tput cols 2>/dev/null
        ;;
    "STTY")
        stty size 2>/dev/null <&"$SURFACE_LAYER_STDIN_FD" | cut -d' ' -f2
        ;;
    "DEC")
        DECRQTSR | cut -d';' -f3
        ;;
    "ENV")
        echo "$COLUMNS"
        ;;
    *)
        echo "90"
        ;;
    esac
}

function GET_SHOW_LENGTH() {
    local length=0
    while IFS= read -r -n1 char; do
        case "$char" in
        $'\t') ((length += 8 - length % 8)) ;;
        # $'v') ((length += "$(GET_COLUMNS)")) ;;
        [[:cntrl:]] | '') ;;
        [a-zA-Z0-9\!\"\#\$%\&\'\(\)\*\+\,-\./:\;\<=\>\?\@\[\\\]^_\`\{\|\}\~] | ' ') ((length++)) ;;
        $'\xe2\x80\x8b' | $'\xe2\x80\x8c' | $'\xe2\x80\x8d' | $'\xe2\x80\x8e') ;;
        [一-龥] | [ぁ-ゔ] | [ァ-ヴー] | [々〆〤] | [㈠-㉃]) ((length += 2)) ;;
        *) ;;
        esac
    done <<<"$(echo "$*" | sed -r 's/\x1B\[[0-9;]*[mKABCDHf]//g')"

    echo "$length"
}

function FOLD() {
    local window_columns="$1"
    shift || true
    local str="$*"

    case "$window_columns" in
    '' | *[!0-9]*)
        if [ -n "$str" ]; then
            str="$window_columns $str"
        else
            str="$window_columns"
        fi
        window_columns="$(GET_COLUMNS)"
        ;;
    esac

    local -a segs=()
    local line=""
    if [ -n "$str" ]; then
        while IFS= read -r line; do
            FOLD_LINE_TO_ARRAY segs "$window_columns" "$line"
            printf '%s\n' "${segs[@]}"
        done <<<"$str"
    else
        while IFS= read -r line; do
            FOLD_LINE_TO_ARRAY segs "$window_columns" "$line"
            printf '%s\n' "${segs[@]}"
        done
    fi
}

function FOLD_LINE_TO_ARRAY() {
    local out_array_name="$1"
    local window_columns="$2"
    local line="$3"
    local keep_last="$4"

    local -n out="$out_array_name"
    out=()

    case "$window_columns" in
    '' | *[!0-9]*)
        window_columns="$(GET_COLUMNS)"
        ;;
    esac

    case "$keep_last" in
    '' | *[!0-9]*)
        keep_last=0
        ;;
    esac

    if [ -z "$line" ]; then
        out+=("")
        return 0
    fi

    # Fast path:
    # 1) 纯可见 ASCII：宽度恒为 1
    # 2) ASCII + CJK：宽度恒为 1/2（覆盖常见中文日志）
    local is_fast=1
    case "$line" in
    *$'\x1b'* | *$'\t'*)
        is_fast=0
        ;;
    *[!\ -~]*)
        is_fast=0
        case "$line" in
        *[!\ -~一-龥ぁ-ゔァ-ヴー々〆〤㈠-㉃]*)
            ;;
        *)
            is_fast=2
            ;;
        esac
        ;;
    esac
    case "$is_fast" in
    1)
        local len="${#line}"
        if [ "$len" -le "$window_columns" ]; then
            out+=("$line")
        else
            if [ "$keep_last" -gt 0 ]; then
                local seg_total="$(((len + window_columns - 1) / window_columns))"
                local from="$((seg_total - keep_last))"
                if ((from < 0)); then
                    from=0
                fi
                line="${line:$((from * window_columns))}"
                len="${#line}"
            fi

            local offset=0
            while ((offset + window_columns < len)); do
                out+=("${line:offset:window_columns}")
                ((offset += window_columns))
            done
            out+=("${line:offset}")
        fi
        return 0
        ;;
    2)
        local -a starts=(0)
        local pos=0
        local seg_width=0
        local run_type=0
        local run_len=0
        local len="${#line}"

        while ((pos < len)); do
            if ((run_len <= 0)); then
                local rest="${line:pos}"
                if [[ "$rest" == [\ -~]* ]]; then
                    run_type=1
                    local ascii_prefix="${rest%%[!\ -~]*}"
                    run_len="${#ascii_prefix}"
                else
                    run_type=2
                    local cjk_prefix="${rest%%[!一-龥ぁ-ゔァ-ヴー々〆〤㈠-㉃]*}"
                    run_len="${#cjk_prefix}"
                fi
                if ((run_len <= 0)); then
                    run_type=1
                    run_len=1
                fi
            fi

            local rem_cols="$((window_columns - seg_width))"
            local take_chars=0
            if ((run_type == 1)); then
                if ((rem_cols <= 0)); then
                    starts+=("$pos")
                    seg_width=0
                    continue
                fi
                take_chars="$rem_cols"
                if ((take_chars > run_len)); then
                    take_chars="$run_len"
                fi
                pos="$((pos + take_chars))"
                run_len="$((run_len - take_chars))"
                seg_width="$((seg_width + take_chars))"
            else
                if ((rem_cols <= 1)); then
                    starts+=("$pos")
                    seg_width=0
                    continue
                fi
                take_chars="$((rem_cols / 2))"
                if ((take_chars > run_len)); then
                    take_chars="$run_len"
                fi
                pos="$((pos + take_chars))"
                run_len="$((run_len - take_chars))"
                seg_width="$((seg_width + take_chars * 2))"
            fi

            if ((seg_width >= window_columns)); then
                starts+=("$pos")
                seg_width=0
            fi
        done

        if ((${#starts[@]} > 1)) && ((${starts[${#starts[@]} - 1]} >= len)); then
            unset 'starts[${#starts[@]} - 1]'
        fi

        local seg_total="${#starts[@]}"
        local from=0
        if [ "$keep_last" -gt 0 ]; then
            from="$((seg_total - keep_last))"
            if ((from < 0)); then
                from=0
            fi
        fi

        local base_start="${starts[from]}"
        local tail_part="${line:base_start}"

        local start=0
        local end=0
        for ((pos = from; pos < seg_total; pos++)); do
            start="${starts[pos]}"
            if ((pos + 1 < seg_total)); then
                end="${starts[pos + 1]}"
            else
                end="$len"
            fi
            out+=("${tail_part:$((start - base_start)):$((end - start))}")
        done
        return 0
        ;;
    *)
        local segment=""
        local seg_width=0
        local char=""
        local char_width=0

        exec 8<<<"$line"
        while IFS= read -r -n1 char <&8; do
            if [[ "$char" == $'\n' ]]; then
                break
            fi

            # 保持 ANSI CSI 序列不被切断（显示宽度为 0）
            if [[ "$char" == $'\x1b' ]]; then
                local esc="$char"
                local c2=""
                if IFS= read -r -n1 c2 <&8; then
                    esc+="$c2"
                    if [ "$c2" == "[" ]; then
                        local c3=""
                        while IFS= read -r -n1 c3 <&8; do
                            esc+="$c3"
                            case "$c3" in
                            [@-~]) break ;;
                            esac
                        done
                    fi
                fi
                segment+="$esc"
                continue
            fi

            char_width=0
            case "$char" in
            $'\t') char_width=$((8 - seg_width % 8)) ;;
            [[:cntrl:]] | '') char_width=0 ;;
            [a-zA-Z0-9\!\"\#\$%\&\'\(\)\*\+\,-\./:\;\<=\>\?\@\[\\\]^_\`\{\|\}\~] | ' ') char_width=1 ;;
            $'\xe2\x80\x8b' | $'\xe2\x80\x8c' | $'\xe2\x80\x8d' | $'\xe2\x80\x8e') char_width=0 ;;
            [一-龥] | [ぁ-ゔ] | [ァ-ヴー] | [々〆〤] | [㈠-㉃]) char_width=2 ;;
            *) char_width=1 ;;
            esac

            if ((seg_width + char_width > window_columns)) && [ -n "$segment" ]; then
                out+=("$segment")
                segment=""
                seg_width=0
            fi

            segment+="$char"
            ((seg_width += char_width))

            if ((seg_width >= window_columns)) && [ -n "$segment" ]; then
                out+=("$segment")
                segment=""
                seg_width=0
            fi
        done
        exec 8<&-

        if [ -n "$segment" ]; then
            out+=("$segment")
        fi

        if [ "$keep_last" -gt 0 ] && ((${#out[@]} > keep_last)); then
            out=("${out[@]: -$keep_last}")
        fi
        return 0
        ;;
    esac
}

function EXPAND() {
    local str="$*"
    local result=""

    while IFS= read -r line; do
        if echo "$line" | grep -q $'\t'; then
            local expanded_line=""

            for ((i = 0; i < ${#line}; i++)); do
                local char="${line:$i:1}"
                if [[ "$char" == $'\t' ]]; then
                    local space_count=$((8 - $(GET_SHOW_LENGTH "${line:0:$i}") % 8))
                    expanded_line+=$(printf "%${space_count}s")
                else
                    expanded_line+="$char"
                fi
            done

            result+="$expanded_line"$'\n'
        else
            result+="$line"$'\n'
        fi
    done <<<"$str"

    echo "$result"
}

function SMOOTH_ECHO() {
    local args=("$@")
    local args_length="${#args[@]}"
    local buffer="${args["$args_length" - 1]}"

    buffer="${buffer%$'\n'}"
    # 不要先清屏再打印：会让下半屏先空一下产生闪烁
    # 用 xterm synchronized output 把一次刷新包起来，避免“边写边渲染”
    buffer="${buffer//$'\n'/$'\033[K\n'}"
    printf '\033[?2026h\033[H%s\033[K\033[J\033[?2026l' "$buffer"
}
