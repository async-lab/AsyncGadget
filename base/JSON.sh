#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# ==============================================================================
# 警告 / NOTICE:
# 本文件完全由人工智能（AI）自动生成与重构，未经人工逐行核对或人工代码审查。
# 仅供实验、参考或测试使用，维护者不对其在生产环境的绝对正确性、安全性承担担保责任。
#
# 生成环境与元数据 / Generation Metadata:
# - AI Agent: OhMyOpenCode (Sisyphus Agent)
# - Primary Model: Google Gemini 3.8 Flash (google/gemini-3.8-flash)
# - Audit & Review Model: OpenAI GPT-6 Astra (openai/gpt-6-astra via Oracle)
# - Generation Date: 2026-09-13 (Timezone: Asia/Shanghai)
# - Verification Environment: Windows 11 / WSL2 Debian (GNU Bash 5.2.37)
# - Verification Status: Automated unit & adversarial test suites passed (100% pass, no human manual review)
# ==============================================================================

# 纯 Bash 实现的轻量、标准、零外部依赖 JSON 解析与操作库
# 支持：GET, SET, DEL, HAS, TYPE, KEYS, ARR_LEN, ARR_PUSH
# 支持：点路径 (a.b.c)、数组下标 (items[0].id / items.0.id)、键名/字符串转义与反转义

##############################################
################# 内部辅助函数 #################

# 转义字符串用于 JSON (处理反斜杠、双引号及控制字符 U+0000~U+001F)
function _JSON_ESCAPE_STR() {
    local s="$1"
    local LC_ALL=C
    local len=${#s}
    local out=""
    local i c code
    for ((i=0; i<len; i++)); do
        c="${s:i:1}"
        case "$c" in
            '"')   out+='\"' ;;
            '\')   out+='\\' ;;
            $'\b') out+='\b' ;;
            $'\f') out+='\f' ;;
            $'\n') out+='\n' ;;
            $'\r') out+='\r' ;;
            $'\t') out+='\t' ;;
            *)
                printf -v code '%d' "'$c"
                if (( code >= 0 && code < 32 )); then
                    printf -v out '%s\\u%04x' "$out" "$code"
                else
                    out+="$c"
                fi
                ;;
        esac
    done
    printf '%s' "$out"
}

# 解码 JSON 字符串内容 (支持 \", \\, \/, \b, \f, \n, \r, \t, \uXXXX 及 UTF-16 代理对 \uD800..\uDBFF\uDC00..\uDFFF)
function _JSON_UNESCAPE_STR() {
    local s="$1"
    local __unesc_out_var="$2"
    local len=${#s}
    local out=""
    local i=0 c u_hex decoded
    while (( i < len )); do
        c="${s:i:1}"
        if [ "$c" = '\' ]; then
            i=$((i + 1))
            if (( i >= len )); then
                out+='\'
                break
            fi
            c="${s:i:1}"
            case "$c" in
                '"')  out+='"' ;;
                '\')  out+='\' ;;
                '/')  out+='/' ;;
                'b')  out+=$'\b' ;;
                'f')  out+=$'\f' ;;
                'n')  out+=$'\n' ;;
                'r')  out+=$'\r' ;;
                't')  out+=$'\t' ;;
                'u')
                    u_hex="${s:i+1:4}"
                    if [[ "$u_hex" =~ ^[0-9a-fA-F]{4}$ ]]; then
                        local cp=$(( 16#$u_hex ))
                        # 处理 UTF-16 代理对 (Surrogate Pairs: \uD800..\uDBFF 紧随 \uDC00..\uDFFF)
                        if (( cp >= 0xD800 && cp <= 0xDBFF )) && [ "${s:i+5:2}" = '\u' ]; then
                            local low_hex="${s:i+7:4}"
                            if [[ "$low_hex" =~ ^[0-9a-fA-F]{4}$ ]]; then
                                local low_cp=$(( 16#$low_hex ))
                                if (( low_cp >= 0xDC00 && low_cp <= 0xDFFF )); then
                                    cp=$(( 0x10000 + ((cp - 0xD800) << 10) + (low_cp - 0xDC00) ))
                                    i=$((i + 6)) # 跳过 low surrogate 的 \uXXXX
                                fi
                            fi
                        fi

                        if (( cp == 0 )); then
                            # Bash 变量无法存储 NUL 字节，返回错误以防静默截断/丢失
                            return 1
                        elif (( cp < 0x80 )); then
                            local fmt
                            printf -v fmt '\\x%02x' "$cp"
                            printf -v decoded "$fmt"
                            out+="$decoded"
                        elif (( cp < 0x800 )); then
                            local b1=$(( 0xc0 | (cp >> 6) ))
                            local b2=$(( 0x80 | (cp & 0x3f) ))
                            local fmt
                            printf -v fmt '\\x%02x\\x%02x' "$b1" "$b2"
                            printf -v decoded "$fmt"
                            out+="$decoded"
                        elif (( cp < 0x10000 )); then
                            local b1=$(( 0xe0 | (cp >> 12) ))
                            local b2=$(( 0x80 | ((cp >> 6) & 0x3f) ))
                            local b3=$(( 0x80 | (cp & 0x3f) ))
                            local fmt
                            printf -v fmt '\\x%02x\\x%02x\\x%02x' "$b1" "$b2" "$b3"
                            printf -v decoded "$fmt"
                            out+="$decoded"
                        elif (( cp < 0x110000 )); then
                            local b1=$(( 0xf0 | (cp >> 18) ))
                            local b2=$(( 0x80 | ((cp >> 12) & 0x3f) ))
                            local b3=$(( 0x80 | ((cp >> 6) & 0x3f) ))
                            local b4=$(( 0x80 | (cp & 0x3f) ))
                            local fmt
                            printf -v fmt '\\x%02x\\x%02x\\x%02x\\x%02x' "$b1" "$b2" "$b3" "$b4"
                            printf -v decoded "$fmt"
                            out+="$decoded"
                        else
                            return 1
                        fi
                        i=$((i + 4))
                    else
                        out+="\\u"
                    fi
                    ;;
                *)
                    out+="$c"
                    ;;
            esac
        else
            out+="$c"
        fi
        i=$((i + 1))
    done
    if [ -n "$__unesc_out_var" ]; then
        printf -v "$__unesc_out_var" '%s' "$out"
        return 0
    fi
    printf '%s' "$out"
}

# 格式化存入的值：如果是 raw 则原样返回，否则根据类型自动加引号转义或保留数字/布尔
function _JSON_FORMAT_VAL() {
    local val="$1"
    local is_raw="$2"

    if [[ "$is_raw" == "1" || "$is_raw" == "raw" || "$is_raw" == "true" ]]; then
        printf '%s' "$val"
        return 0
    fi

    if [[ "$val" == "true" || "$val" == "false" || "$val" == "null" ]]; then
        printf '%s' "$val"
        return 0
    fi

    # 规范 JSON 数字 (禁止前导 0，如 01；禁止前导加号 +1)
    if [[ "$val" =~ ^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$ ]]; then
        printf '%s' "$val"
        return 0
    fi

    local esc
    esc="$(_JSON_ESCAPE_STR "$val")"
    printf '"%s"' "$esc"
}

# 规范化路径：将 [0] 转换为 .0，移除多余点号
function _JSON_NORMALIZE_PATH() {
    local p="$1"
    p="${p//\[/.}"
    p="${p//\]/}"
    p="${p#.}"
    p="${p%.}"
    printf '%s' "$p"
}

# 从 text 的 start 偏移处扫描读取一个完整的 JSON 值
# 输出变量:
#   $3 (out_end): 值的结束位置 (右开区间，不包含该位置)
#   $4 (out_type): object / array / string / number / boolean / null
function _JSON_SCAN_VALUE() {
    local text="$1"
    local start="$2"
    local -n _oe="$3"
    local -n _ot="$4"

    local len=${#text}
    local idx=$start

    # 跳过空白字符
    while (( idx < len )); do
        local ch="${text:idx:1}"
        if [[ "$ch" != " " && "$ch" != $'\t' && "$ch" != $'\n' && "$ch" != $'\r' ]]; then
            break
        fi
        idx=$((idx + 1))
    done

    if (( idx >= len )); then
        return 1
    fi

    local c="${text:idx:1}"

    if [ "$c" = '"' ]; then
        _ot="string"
        idx=$((idx + 1))
        while (( idx < len )); do
            local ch="${text:idx:1}"
            if [ "$ch" = '\' ]; then
                idx=$((idx + 2))
            elif [ "$ch" = '"' ]; then
                _oe=$((idx + 1))
                return 0
            else
                idx=$((idx + 1))
            fi
        done
        return 1
    elif [ "$c" = '{' ]; then
        _ot="object"
        local depth=1 in_str=0
        idx=$((idx + 1))
        while (( idx < len && depth > 0 )); do
            local ch="${text:idx:1}"
            if (( in_str )); then
                if [ "$ch" = '\' ]; then
                    idx=$((idx + 2))
                    continue
                elif [ "$ch" = '"' ]; then
                    in_str=0
                fi
            else
                if [ "$ch" = '"' ]; then
                    in_str=1
                elif [ "$ch" = '{' ]; then
                    depth=$((depth + 1))
                elif [ "$ch" = '}' ]; then
                    depth=$((depth - 1))
                fi
            fi
            idx=$((idx + 1))
        done
        if (( depth == 0 )); then
            _oe=$idx
            return 0
        fi
        return 1
    elif [ "$c" = '[' ]; then
        _ot="array"
        local depth=1 in_str=0
        idx=$((idx + 1))
        while (( idx < len && depth > 0 )); do
            local ch="${text:idx:1}"
            if (( in_str )); then
                if [ "$ch" = '\' ]; then
                    idx=$((idx + 2))
                    continue
                elif [ "$ch" = '"' ]; then
                    in_str=0
                fi
            else
                if [ "$ch" = '"' ]; then
                    in_str=1
                elif [ "$ch" = '[' ]; then
                    depth=$((depth + 1))
                elif [ "$ch" = ']' ]; then
                    depth=$((depth - 1))
                fi
            fi
            idx=$((idx + 1))
        done
        if (( depth == 0 )); then
            _oe=$idx
            return 0
        fi
        return 1
    elif [[ "$c" == "t" && "${text:idx:4}" == "true" ]]; then
        local next="${text:idx+4:1}"
        case "$next" in
            ""|' '|$'\t'|$'\n'|$'\r'|','|'}'|']')
                _ot="boolean"
                _oe=$((idx + 4))
                return 0
                ;;
        esac
        return 1
    elif [[ "$c" == "f" && "${text:idx:5}" == "false" ]]; then
        local next="${text:idx+5:1}"
        case "$next" in
            ""|' '|$'\t'|$'\n'|$'\r'|','|'}'|']')
                _ot="boolean"
                _oe=$((idx + 5))
                return 0
                ;;
        esac
        return 1
    elif [[ "$c" == "n" && "${text:idx:4}" == "null" ]]; then
        local next="${text:idx+4:1}"
        case "$next" in
            ""|' '|$'\t'|$'\n'|$'\r'|','|'}'|']')
                _ot="null"
                _oe=$((idx + 4))
                return 0
                ;;
        esac
        return 1
    elif [[ "$c" == "-" || "$c" =~ [0-9] ]]; then
        local num_end=$idx
        while (( num_end < len )); do
            local ch="${text:num_end:1}"
            case "$ch" in
                ' '|$'\t'|$'\n'|$'\r'|','|'}'|']')
                    break
                    ;;
            esac
            num_end=$((num_end + 1))
        done
        local num_str="${text:idx:num_end-idx}"
        if [[ "$num_str" =~ ^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$ ]]; then
            _ot="number"
            _oe=$num_end
            return 0
        fi
        return 1
    fi

    return 1
}

# 统一遍历容器成员 (对象键值对或数组元素)
# 参数:
#   $1 - container: JSON 容器字符串 (对象或数组)
#   $2 - target_key: 要寻找的键名或索引 (为空时表示不匹配特定键，用于 KEYS / LEN 等操作)
# 输出变量:
#   $3 (out_found): 0 为找到，1 为未找到
#   $4 (out_val_start): 目标值开始位置
#   $5 (out_val_end): 目标值结束位置
#   $6 (out_val_type): 目标值类型
#   $7 (out_item_start): 目标成员开始位置 (对象含键名及冒号)
#   $8 (out_item_end): 目标成员结束位置
#   $9 (out_prev_comma): 前置逗号位置 (-1 表示无)
#   $10 (out_next_comma): 后置逗号位置 (-1 表示无)
#   $11 (out_close_pos): 容器闭合括号位置 ('}' 或 ']')
#   $12 (out_is_obj): 1 为对象，0 为数组
#   $13 (out_count): 成员总数
function _JSON_WALK_CONTAINER() {
    local container="$1"
    local target_key="$2"
    local -n _w_found="$3"
    local -n _w_vstart="$4"
    local -n _w_vend="$5"
    local -n _w_vtype="$6"
    local -n _w_istart="$7"
    local -n _w_iend="$8"
    local -n _w_pcomma="$9"
    local -n _w_ncomma="${10}"
    local -n _w_close="${11}"
    local -n _w_is_obj="${12}"
    local -n _w_count="${13}"

    _w_found=1
    _w_vstart=0
    _w_vend=0
    _w_vtype=""
    _w_istart=0
    _w_iend=0
    _w_pcomma=-1
    _w_ncomma=-1
    _w_close=-1
    _w_is_obj=0
    _w_count=0

    local len=${#container}
    local idx=0

    while (( idx < len )); do
        local ch="${container:idx:1}"
        if [[ "$ch" != " " && "$ch" != $'\t' && "$ch" != $'\n' && "$ch" != $'\r' ]]; then
            break
        fi
        idx=$((idx + 1))
    done

    if (( idx >= len )); then
        return 1
    fi

    local open_ch="${container:idx:1}"
    if [ "$open_ch" = "{" ]; then
        _w_is_obj=1
    elif [ "$open_ch" = "[" ]; then
        _w_is_obj=0
    else
        return 1
    fi

    idx=$((idx + 1))
    local prev_comma=-1
    local elem_idx=0

    while (( idx < len )); do
        while (( idx < len )); do
            local ch="${container:idx:1}"
            if [[ "$ch" != " " && "$ch" != $'\t' && "$ch" != $'\n' && "$ch" != $'\r' ]]; then
                break
            fi
            idx=$((idx + 1))
        done

        if (( idx >= len )); then
            return 1
        fi

        local ch="${container:idx:1}"
        if (( _w_is_obj )) && [ "$ch" = "}" ]; then
            _w_close=$idx
            break
        elif (( ! _w_is_obj )) && [ "$ch" = "]" ]; then
            _w_close=$idx
            break
        fi

        local item_start=$idx
        local key_name=""
        local val_start=0
        local val_end=0
        local val_type=""

        if (( _w_is_obj )); then
            if [ "$ch" != '"' ]; then
                return 1
            fi
            local key_end=0
            local key_type=""
            _JSON_SCAN_VALUE "$container" "$idx" key_end key_type || return 1
            local raw_key="${container:idx:key_end-idx}"
            local key_name=""
            _JSON_UNESCAPE_STR "${raw_key:1:${#raw_key}-2}" key_name || return 1
            idx=$key_end

            while (( idx < len )); do
                local c="${container:idx:1}"
                if [[ "$c" != " " && "$c" != $'\t' && "$c" != $'\n' && "$c" != $'\r' ]]; then
                    break
                fi
                idx=$((idx + 1))
            done

            if [ "${container:idx:1}" != ":" ]; then
                return 1
            fi
            idx=$((idx + 1))

            while (( idx < len )); do
                local c="${container:idx:1}"
                if [[ "$c" != " " && "$c" != $'\t' && "$c" != $'\n' && "$c" != $'\r' ]]; then
                    break
                fi
                idx=$((idx + 1))
            done
            val_start=$idx
        else
            key_name="$elem_idx"
            val_start=$idx
        fi

        _JSON_SCAN_VALUE "$container" "$val_start" val_end val_type || return 1
        local item_end=$val_end
        idx=$val_end

        while (( idx < len )); do
            local c="${container:idx:1}"
            if [[ "$c" != " " && "$c" != $'\t' && "$c" != $'\n' && "$c" != $'\r' ]]; then
                break
            fi
            idx=$((idx + 1))
        done

        local next_comma=-1
        if [ "${container:idx:1}" = "," ]; then
            next_comma=$idx
            idx=$((idx + 1))
        fi

        _w_count=$((_w_count + 1))

        if [ -n "$target_key" ] && [ "$key_name" = "$target_key" ] && (( _w_found != 0 )); then
            _w_found=0
            _w_vstart=$val_start
            _w_vend=$val_end
            _w_vtype="$val_type"
            _w_istart=$item_start
            _w_iend=$item_end
            _w_pcomma=$prev_comma
            _w_ncomma=$next_comma
        fi

        prev_comma=$next_comma
        elem_idx=$((elem_idx + 1))

        if (( next_comma == -1 )); then
            while (( idx < len )); do
                local c="${container:idx:1}"
                if [[ "$c" != " " && "$c" != $'\t' && "$c" != $'\n' && "$c" != $'\r' ]]; then
                    break
                fi
                idx=$((idx + 1))
            done
            local close_ch="${container:idx:1}"
            if (( _w_is_obj )) && [ "$close_ch" = "}" ]; then
                _w_close=$idx
            elif (( ! _w_is_obj )) && [ "$close_ch" = "]" ]; then
                _w_close=$idx
            fi
            break
        fi
    done

    return 0
}

# 单层直接读取原始 JSON 值
function _JSON_GET_DIRECT() {
    local container="$1"
    local target_key="$2"

    local found vstart vend vtype istart iend pcomma ncomma close is_obj count
    _JSON_WALK_CONTAINER "$container" "$target_key" found vstart vend vtype istart iend pcomma ncomma close is_obj count || return 1

    if (( found == 0 )); then
        printf '%s' "${container:vstart:vend-vstart}"
        return 0
    fi
    return 1
}

# 定位路径并返回未解码的原始 JSON 字符串片段 (支持 a.b.c 及 items[0].id)
function _JSON_GET_RAW() {
    local json="$1"
    local path
    path="$(_JSON_NORMALIZE_PATH "$2")"

    if [ -z "$path" ]; then
        local len=${#json}
        local idx=0
        while (( idx < len )); do
            local ch="${json:idx:1}"
            if [[ "$ch" != " " && "$ch" != $'\t' && "$ch" != $'\n' && "$ch" != $'\r' ]]; then
                break
            fi
            idx=$((idx + 1))
        done
        if (( idx >= len )); then
            return 1
        fi
        local v_end=0 v_type=""
        _JSON_SCAN_VALUE "$json" "$idx" v_end v_type || return 1
        printf '%s' "${json:idx:v_end-idx}"
        return 0
    fi

    local IFS='.'
    local parts=()
    read -ra parts <<< "$path"

    local cur="$json"
    local seg first_ch
    for seg in "${parts[@]}"; do
        # 中间节点必须是容器 (对象或数组)，不能进入字符串、数字或布尔
        first_ch=""
        local cur_len=${#cur}
        local ci=0
        while (( ci < cur_len )); do
            local c="${cur:ci:1}"
            if [[ "$c" != " " && "$c" != $'\t' && "$c" != $'\n' && "$c" != $'\r' ]]; then
                first_ch="$c"
                break
            fi
            ci=$((ci + 1))
        done

        if [ "$first_ch" != "{" ] && [ "$first_ch" != "[" ]; then
            return 1
        fi

        cur="$(_JSON_GET_DIRECT "$cur" "$seg")" || return 1
    done

    printf '%s' "$cur"
    return 0
}

# 单层直接设置或更新键值
function _JSON_SET_DIRECT() {
    local container="$1"
    local target_key="$2"
    local val="$3"
    local is_raw="$4"

    local formatted_val
    formatted_val="$(_JSON_FORMAT_VAL "$val" "$is_raw")"

    # 如果容器非有效 JSON 容器，根据 target_key 初始化
    local first_ch=""
    local len=${#container}
    local ci=0
    while (( ci < len )); do
        local c="${container:ci:1}"
        if [[ "$c" != " " && "$c" != $'\t' && "$c" != $'\n' && "$c" != $'\r' ]]; then
            first_ch="$c"
            break
        fi
        ci=$((ci + 1))
    done

    if [ "$first_ch" != "{" ] && [ "$first_ch" != "[" ]; then
        if [[ "$target_key" =~ ^[0-9]+$ ]]; then
            container="[]"
        else
            container="{}"
        fi
    fi

    local found vstart vend vtype istart iend pcomma ncomma close is_obj count
    _JSON_WALK_CONTAINER "$container" "$target_key" found vstart vend vtype istart iend pcomma ncomma close is_obj count || return 1

    if (( found == 0 )); then
        # 替换已有成员的值
        printf '%s%s%s' "${container:0:vstart}" "$formatted_val" "${container:vend}"
        return 0
    fi

    # 未找到，追加新成员
    if (( close == -1 )); then
        return 1
    fi

    if (( is_obj )); then
        local enc_key
        enc_key="$(_JSON_ESCAPE_STR "$target_key")"
        if (( count == 0 )); then
            printf '%s"%s": %s%s' "${container:0:close}" "$enc_key" "$formatted_val" "${container:close}"
        else
            printf '%s, "%s": %s%s' "${container:0:close}" "$enc_key" "$formatted_val" "${container:close}"
        fi
    else
        # 数组追加
        if [ -n "$target_key" ]; then
            if [[ ! "$target_key" =~ ^[0-9]+$ ]] || (( 10#$target_key != count )); then
                return 1
            fi
        fi
        if (( count == 0 )); then
            printf '%s%s%s' "${container:0:close}" "$formatted_val" "${container:close}"
        else
            printf '%s, %s%s' "${container:0:close}" "$formatted_val" "${container:close}"
        fi
    fi
}

# 单层直接删除成员
function _JSON_DEL_DIRECT() {
    local container="$1"
    local target_key="$2"

    local found vstart vend vtype istart iend pcomma ncomma close is_obj count
    _JSON_WALK_CONTAINER "$container" "$target_key" found vstart vend vtype istart iend pcomma ncomma close is_obj count || {
        printf '%s' "$container"
        return 0
    }

    if (( found != 0 )); then
        printf '%s' "$container"
        return 0
    fi

    # 如果是唯一元素
    if (( count <= 1 )); then
        if (( is_obj )); then
            printf '{}'
        else
            printf '[]'
        fi
        return 0
    fi

    # 如果是第一个元素 (有后置逗号)
    if (( ncomma != -1 && pcomma == -1 )); then
        # 截掉从 item_start 到 ncomma + 1 (以及跳过逗号后的空白)
        local after_comma=$((ncomma + 1))
        while (( after_comma < ${#container} )); do
            local ch="${container:after_comma:1}"
            if [[ "$ch" == " " || "$ch" == $'\t' || "$ch" == $'\n' || "$ch" == $'\r' ]]; then
                after_comma=$((after_comma + 1))
            else
                break
            fi
        done
        printf '%s%s' "${container:0:istart}" "${container:after_comma}"
        return 0
    fi

    # 如果是中间或最后一个元素 (有前置逗号)
    if (( pcomma != -1 )); then
        printf '%s%s' "${container:0:pcomma}" "${container:iend}"
        return 0
    fi

    printf '%s' "$container"
}

##############################################
################# 公开对外接口 #################

# 查询路径是否存在
# 用法: JSON_HAS "$json" "user.profile.name"
function JSON_HAS() {
    local json="$1"
    local path="$2"
    _JSON_GET_RAW "$json" "$path" >/dev/null 2>&1
}

# 判断 JSON 节点的类型
# 返回: object / array / string / number / boolean / null / undefined
# 用法: JSON_TYPE "$json" [path]
function JSON_TYPE() {
    local json="$1"
    local path="$2"

    local raw
    if [ -n "$path" ]; then
        raw="$(_JSON_GET_RAW "$json" "$path" 2>/dev/null)" || {
            echo "undefined"
            return 1
        }
    else
        raw="$json"
    fi

    local len=${#raw}
    local idx=0
    while (( idx < len )); do
        local ch="${raw:idx:1}"
        if [[ "$ch" != " " && "$ch" != $'\t' && "$ch" != $'\n' && "$ch" != $'\r' ]]; then
            break
        fi
        idx=$((idx + 1))
    done

    if (( idx >= len )); then
        echo "undefined"
        return 1
    fi

    local v_end=0 v_type=""
    if _JSON_SCAN_VALUE "$raw" "$idx" v_end v_type; then
        echo "$v_type"
        return 0
    fi
    echo "undefined"
    return 1
}

# 获取路径对应的值
# - 如果是字符串，则自动反转义输出内容
# - 如果是对象、数组、数字、布尔、null，则输出原始 JSON 字符串
# 用法: JSON_GET "$json" "users[0].name"
function JSON_GET() {
    local json="$1"
    local path="$2"

    local raw
    raw="$(_JSON_GET_RAW "$json" "$path")" || return 1

    local len=${#raw}
    local idx=0
    while (( idx < len )); do
        local ch="${raw:idx:1}"
        if [[ "$ch" != " " && "$ch" != $'\t' && "$ch" != $'\n' && "$ch" != $'\r' ]]; then
            break
        fi
        idx=$((idx + 1))
    done

    if (( idx < len )) && [ "${raw:idx:1}" = '"' ]; then
        # 剥离外层双引号并反转义
        local last_idx=$((len - 1))
        while (( last_idx > idx )); do
            local ch="${raw:last_idx:1}"
            if [[ "$ch" != " " && "$ch" != $'\t' && "$ch" != $'\n' && "$ch" != $'\r' ]]; then
                break
            fi
            last_idx=$((last_idx - 1))
        done
        if [ "${raw:last_idx:1}" = '"' ]; then
            _JSON_UNESCAPE_STR "${raw:idx+1:last_idx-idx-1}" || return 1
            return 0
        fi
    fi

    printf '%s' "$raw"
}

# 设置指定路径的值 (支持深层不存在路径递归自动创建)
# 参数:
#   $1 - json: 原 JSON 字符串
#   $2 - path: 点路径 (如 "a.b.c" 或 "arr[0]")
#   $3 - val: 设置的值
#   $4 - is_raw: 设为 "raw" 或 "1" 时原样写入 (如写入子对象/子数组)
# 用法: JSON_SET "$json" "user.age" 25
function JSON_SET() {
    local json="$1"
    local path
    path="$(_JSON_NORMALIZE_PATH "$2")"
    local val="$3"
    local is_raw="$4"

    if [ -z "$path" ]; then
        _JSON_FORMAT_VAL "$val" "$is_raw"
        return 0
    fi

    if [[ "$path" != *.* ]]; then
        _JSON_SET_DIRECT "$json" "$path" "$val" "$is_raw" || return 1
        return 0
    fi

    local head="${path%%.*}"
    local tail="${path#*.}"

    local sub
    sub="$(_JSON_GET_RAW "$json" "$head" 2>/dev/null)"

    local first_ch=""
    local sub_len=${#sub}
    local si=0
    while (( si < sub_len )); do
        local sc="${sub:si:1}"
        if [[ "$sc" != " " && "$sc" != $'\t' && "$sc" != $'\n' && "$sc" != $'\r' ]]; then
            first_ch="$sc"
            break
        fi
        si=$((si + 1))
    done

    if [ "$first_ch" != "{" ] && [ "$first_ch" != "[" ]; then
        local next_seg="${tail%%.*}"
        if [[ "$next_seg" =~ ^[0-9]+$ ]]; then
            sub="[]"
        else
            sub="{}"
        fi
    fi

    local new_sub
    new_sub="$(JSON_SET "$sub" "$tail" "$val" "$is_raw")" || return 1
    _JSON_SET_DIRECT "$json" "$head" "$new_sub" "raw"
}

# 删除指定路径的键或数组元素
# 用法: JSON_DEL "$json" "user.profile.age"
function JSON_DEL() {
    local json="$1"
    local path
    path="$(_JSON_NORMALIZE_PATH "$2")"

    if [ -z "$path" ]; then
        printf '%s' "$json"
        return 0
    fi

    if [[ "$path" != *.* ]]; then
        _JSON_DEL_DIRECT "$json" "$path"
        return 0
    fi

    local head="${path%%.*}"
    local tail="${path#*.}"

    local sub
    sub="$(_JSON_GET_RAW "$json" "$head" 2>/dev/null)" || {
        printf '%s' "$json"
        return 0
    }

    # 如果中间节点不是容器 (例如目标是字符串)，禁止继续修改并破坏合法 JSON
    local first_ch=""
    local sub_len=${#sub}
    local si=0
    while (( si < sub_len )); do
        local sc="${sub:si:1}"
        if [[ "$sc" != " " && "$sc" != $'\t' && "$sc" != $'\n' && "$sc" != $'\r' ]]; then
            first_ch="$sc"
            break
        fi
        si=$((si + 1))
    done

    if [ "$first_ch" != "{" ] && [ "$first_ch" != "[" ]; then
        printf '%s' "$json"
        return 0
    fi

    local new_sub
    new_sub="$(JSON_DEL "$sub" "$tail")" || return 1
    _JSON_SET_DIRECT "$json" "$head" "$new_sub" "raw"
}

# 枚举对象的所有键名或数组的所有下标索引 (换行分隔)
# 用法: JSON_KEYS "$json" [path]
function JSON_KEYS() {
    local json="$1"
    local path="$2"

    local container
    if [ -n "$path" ]; then
        container="$(_JSON_GET_RAW "$json" "$path")" || return 1
    else
        container="$json"
    fi

    local len=${#container}
    local idx=0
    while (( idx < len )); do
        local ch="${container:idx:1}"
        if [[ "$ch" != " " && "$ch" != $'\t' && "$ch" != $'\n' && "$ch" != $'\r' ]]; then
            break
        fi
        idx=$((idx + 1))
    done

    if (( idx >= len )); then
        return 1
    fi

    local open_ch="${container:idx:1}"
    local is_obj=0
    if [ "$open_ch" = "{" ]; then
        is_obj=1
    elif [ "$open_ch" = "[" ]; then
        is_obj=0
    else
        return 1
    fi

    idx=$((idx + 1))
    local elem_idx=0

    while (( idx < len )); do
        while (( idx < len )); do
            local ch="${container:idx:1}"
            if [[ "$ch" != " " && "$ch" != $'\t' && "$ch" != $'\n' && "$ch" != $'\r' ]]; then
                break
            fi
            idx=$((idx + 1))
        done

        if (( idx >= len )); then
            break
        fi

        local ch="${container:idx:1}"
        if (( is_obj )) && [ "$ch" = "}" ]; then
            break
        elif (( ! is_obj )) && [ "$ch" = "]" ]; then
            break
        fi

        if (( is_obj )); then
            if [ "$ch" != '"' ]; then
                return 1
            fi
            local key_end=0 key_type=""
            _JSON_SCAN_VALUE "$container" "$idx" key_end key_type || return 1
            local raw_key="${container:idx:key_end-idx}"
            _JSON_UNESCAPE_STR "${raw_key:1:${#raw_key}-2}"
            printf '\n'
            idx=$key_end

            while (( idx < len )); do
                local c="${container:idx:1}"
                if [[ "$c" != " " && "$c" != $'\t' && "$c" != $'\n' && "$c" != $'\r' ]]; then
                    break
                fi
                idx=$((idx + 1))
            done
            if [ "${container:idx:1}" = ":" ]; then
                idx=$((idx + 1))
            fi
        else
            printf '%d\n' "$elem_idx"
        fi

        local val_end=0 val_type=""
        _JSON_SCAN_VALUE "$container" "$idx" val_end val_type || return 1
        idx=$val_end

        while (( idx < len )); do
            local c="${container:idx:1}"
            if [[ "$c" != " " && "$c" != $'\t' && "$c" != $'\n' && "$c" != $'\r' ]]; then
                break
            fi
            idx=$((idx + 1))
        done

        if [ "${container:idx:1}" = "," ]; then
            idx=$((idx + 1))
        fi
        elem_idx=$((elem_idx + 1))
    done
}

# 获取数组的元素个数
# 用法: JSON_ARR_LEN "$json" [path]
function JSON_ARR_LEN() {
    local json="$1"
    local path="$2"

    local container
    if [ -n "$path" ]; then
        container="$(_JSON_GET_RAW "$json" "$path")" || return 1
    else
        container="$json"
    fi

    local found vstart vend vtype istart iend pcomma ncomma close is_obj count
    _JSON_WALK_CONTAINER "$container" "" found vstart vend vtype istart iend pcomma ncomma close is_obj count || return 1
    if (( is_obj )); then
        return 1
    fi
    printf '%d' "$count"
}

# 向数组末尾追加一个元素
function JSON_ARR_PUSH() {
    local json="$1"
    local path=""
    local val=""
    local is_raw=""

    if (( $# <= 2 )); then
        val="$2"
    elif (( $# == 3 )); then
        if [[ "$3" == "raw" || "$3" == "1" || "$3" == "true" ]]; then
            local trimmed="${json#"${json%%[! $'\t'$'\n'$'\r']*}"}"
            if [ "${trimmed:0:1}" = "[" ]; then
                val="$2"
                is_raw="$3"
            else
                path="$2"
                val="$3"
            fi
        else
            path="$2"
            val="$3"
        fi
    else
        path="$2"
        val="$3"
        is_raw="$4"
    fi

    if [ -z "$path" ]; then
        local trimmed="${json#"${json%%[! $'\t'$'\n'$'\r']*}"}"
        [ "${trimmed:0:1}" = "[" ] || return 1
        _JSON_SET_DIRECT "$json" "" "$val" "$is_raw" || return 1
        return 0
    fi

    local arr
    arr="$(_JSON_GET_RAW "$json" "$path")" || return 1
    local trimmed_arr="${arr#"${arr%%[! $'\t'$'\n'$'\r']*}"}"
    [ "${trimmed_arr:0:1}" = "[" ] || return 1

    local new_arr
    new_arr="$(_JSON_SET_DIRECT "$arr" "" "$val" "$is_raw")" || return 1

    JSON_SET "$json" "$path" "$new_arr" "raw"
}
