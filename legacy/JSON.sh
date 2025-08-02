#!/usr/bin/env bash
# -*- coding: utf-8 -*-

##############################################

# MODULE_NAME="JSON"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ROOT_DIR=${ROOT_DIR:-"$DIR/.."}

source "$ROOT_DIR/base/UTIL.sh"

##############################################

function INSERT_TO_JSON() {
    echo "$1" | jq -r ".\"$2\"=\"$3\""
}

# function __INTERNAL_JSON() {
#     function JSON_RAW_KEY_PROCESSOR() {
#         local raw_key="$1"
#         local key=""

#         local path_level=0

#         local quote_flag=1
#         local esc_flag=1
#         local index_flag=1
#         local root_array_flag=1

#         local buffer=""

#         local last_char=""

#         if [ "${raw_key:0:1}" == "." ]; then
#             raw_key="${raw_key:1}"
#             key+="."
#         else
#             root_array_flag=0
#         fi

#         for ((offset = 0; offset < "${#raw_key}"; offset++)); do
#             local char="${raw_key:offset:1}"
#             local keyword_flag=1
#             local last_index_flag="$index_flag"

#             case "$char" in
#             "\"")
#                 if [ "$esc_flag" -eq 1 ]; then
#                     quote_flag="$(NOT "$quote_flag")"
#                     keyword_flag=0
#                 fi
#                 ;;
#             "[")
#                 if [ "$quote_flag" -eq 1 ]; then
#                     index_flag=0
#                 fi
#                 ;;
#             "]")
#                 if [ "$quote_flag" -eq 1 ]; then
#                     index_flag=1
#                 fi
#                 ;;
#             ".")
#                 if [ "$quote_flag" -eq 1 ]; then
#                     keyword_flag=0
#                     if [ "$last_char" != "]" ]; then
#                         buffer+="\""
#                     fi
#                     key+="\"$buffer."
#                     buffer=""
#                     ((path_level++))
#                 fi
#                 ;;
#             esac

#             if [ "$char" == "\\" ]; then
#                 esc_flag="$(NOT "$esc_flag")"
#             else
#                 esc_flag=1
#             fi

#             if [ "$keyword_flag" -eq 1 ]; then
#                 if [ "$last_index_flag" -eq 1 ] && [ "$index_flag" -eq 0 ] && [ "$last_char" != "]" ] && ([ "$root_array_flag" -eq 1 ] || [ "$path_level" -ne 0 ] && [ "" ]); then
#                     buffer+="\""
#                 fi
#                 buffer+="$char"
#             fi

#             last_char="$char"
#         done

#         if [ "$root_array_flag" -eq 1 ] || ([ "$path_level" -ne 0 ] && [ "$root_array_flag" -eq 0 ]); then
#             buffer="\"$buffer"
#         fi
#         if [ "$last_char" != "]" ]; then
#             buffer+="\""
#         fi

#         key+="$buffer"

#         echo "$key"
#     }

#     function JSON_READ() {
#         function GET_PATH_STR() {
#             local -n local_path_list="$1"
#             local -n local_object_array_depth_list="$2"
#             local -n local_array_index_list="$3"

#             local path_str=""

#             for ((i = 0; i < ${#local_path_list[@]}; i++)); do
#                 path_str+=".${local_path_list[$i]}"

#                 local object_array_depth="${local_object_array_depth_list[$i]}"
#                 local next_object_array_depth="${local_object_array_depth_list[$((i + 1))]}"
#                 for ((j = "$object_array_depth"; j < "${next_object_array_depth:-${#local_array_index_list[@]}}"; j++)); do
#                     local index="${local_array_index_list[$j]}"
#                     if [ -n "$index" ]; then
#                         path_str+="[$index]"
#                     fi
#                 done
#             done

#             if [ "${#local_path_list[@]}" -eq 0 ]; then
#                 for ((i = 0; i < "${#local_array_index_list[@]}"; i++)); do
#                     local index="${local_array_index_list[$j]}"
#                     if [ -n "$index" ]; then
#                         path_str+="[$index]"
#                     fi
#                 done
#             fi

#             path_str=${path_str//\\\\/\\}
#             echo "$path_str"
#         }

#         local raw_key=$1

#         if [ "$raw_key" == "." ]; then
#             echo "$json"
#         fi

#         local object_depth=0
#         local array_depth=0
#         local object_array_depth_list=()
#         local array_index_list=()

#         local value_object_depth=
#         local value_array_depth=

#         local quote_flag=1
#         local esc_flag=1
#         local key_input_flag=1
#         local path_append_flag=1
#         local value_input_flag=1
#         local finished_flag=1

#         local key="$(JSON_RAW_KEY_PROCESSOR "$raw_key")"
#         local json=$2

#         local key_buffer=""
#         local value_buffer=""
#         local buffer=""
#         local path_list=()

#         local last_char=""

#         for ((offset = 0; offset < "${#json}"; offset++)); do
#             local char="${json:offset:1}"
#             local next_char="${json:offset+1:1}"
#             local keyword_flag=1
#             local invalid_flag=1
#             local array_index_flag=1

#             if [ "$char" == "\"" ] && [ "$esc_flag" -eq 1 ]; then
#                 keyword_flag=0
#                 quote_flag=$(NOT "$quote_flag")
#             elif [ "$quote_flag" -eq 1 ]; then
#                 case "$char" in
#                 "{")
#                     keyword_flag=0
#                     path_append_flag=0
#                     key_input_flag=0
#                     if [ "$value_input_flag" -eq 0 ] && [ -z "$value_object_depth" ] && [ -z "$value_array_depth" ]; then
#                         value_object_depth="$object_depth"
#                     fi
#                     object_array_depth_list+=("$array_depth")
#                     ((object_depth++))
#                     ;;
#                 "}")
#                     keyword_flag=0
#                     ((object_depth--))
#                     unset "object_array_depth_list[-1]"
#                     unset "path_list[-1]"
#                     if [ "$value_input_flag" -eq 0 ]; then
#                         if [ "$object_depth" == "$value_object_depth" ]; then
#                             finished_flag=0
#                         elif [ -z "$value_object_depth" ] && [ -z "$value_array_depth" ]; then
#                             finished_flag=0
#                             invalid_flag=0
#                         fi
#                     fi
#                     ;;
#                 "[")
#                     keyword_flag=0
#                     key_input_flag=1
#                     array_index_flag=0
#                     if [ "$value_input_flag" -eq 0 ] && [ -z "$value_object_depth" ] && [ -z "$value_array_depth" ]; then
#                         value_array_depth="$array_depth"
#                     fi
#                     ((array_depth++))
#                     array_index_list+=(0)
#                     ;;
#                 "]")
#                     keyword_flag=0
#                     unset "array_index_list[-1]"
#                     ((array_depth--))

#                     if [ "$value_input_flag" -eq 0 ]; then
#                         if [ "$array_depth" == "$value_array_depth" ]; then
#                             finished_flag=0
#                         elif [ -z "$value_object_depth" ] && [ -z "$value_array_depth" ]; then
#                             finished_flag=0
#                             invalid_flag=0
#                         fi
#                     fi
#                     ;;
#                 ",")
#                     keyword_flag=0
#                     if [ "${#object_array_depth_list[@]}" -ne 0 ] && [ "$array_depth" == "${object_array_depth_list[-1]}" ]; then
#                         key_input_flag=0
#                     else
#                         ((array_index_list[-1]++))
#                         array_index_flag=0
#                     fi

#                     if [ "$value_input_flag" -eq 0 ] && [ -z "$value_object_depth" ] && [ -z "$value_array_depth" ]; then
#                         finished_flag=0
#                         invalid_flag=0
#                     fi
#                     ;;
#                 ":")
#                     keyword_flag=0
#                     key_input_flag=1
#                     if [ "$value_input_flag" -eq 0 ] && [ -z "$value_object_depth" ] && [ -z "$value_array_depth" ]; then
#                         invalid_flag=0
#                     fi
#                     ;;
#                 "t" | "r" | "u" | "e" | "f" | "a" | "l" | "s" | "n" | [0-9])
#                     :
#                     ;;
#                 *)
#                     invalid_flag=0
#                     ;;
#                 esac
#             fi

#             if [ "$char" == "\\" ]; then
#                 esc_flag="$(NOT "$esc_flag")"
#             else
#                 esc_flag=1
#             fi

#             if [ "$invalid_flag" -eq 1 ]; then
#                 if [ "$key_input_flag" -eq 0 ] && [ "$keyword_flag" -eq 1 ]; then
#                     key_buffer+="$char"
#                 fi

#                 if [ "$value_input_flag" -eq 0 ]; then
#                     value_buffer+="$char"
#                 fi

#                 if [ "$quote_flag" -eq 1 ] && [ -n "$key_buffer" ]; then
#                     if [ "$path_append_flag" -eq 0 ]; then
#                         path_list+=("\"$key_buffer\"")
#                         path_append_flag=1
#                     else
#                         if [ "${#path_list[@]}" -gt 0 ]; then
#                             path_list[-1]="\"$key_buffer\""
#                         fi
#                     fi

#                     local path_str="$(GET_PATH_STR "path_list" "object_array_depth_list" "array_index_list")"

#                     if [ "$path_str" == "$key" ]; then
#                         value_input_flag=0
#                     fi

#                     key_buffer=""
#                 fi

#                 if [ "$next_char" != "]" ] && [ "$array_index_flag" -eq 0 ]; then
#                     local path_str="$(GET_PATH_STR "path_list" "object_array_depth_list" "array_index_list")"

#                     if [ "$path_str" == "$key" ]; then
#                         value_input_flag=0
#                     fi
#                 fi

#                 last_char="$char"
#             fi

#             if [ "$finished_flag" -eq 0 ]; then
#                 echo "$value_buffer"
#                 return 0
#             fi
#         done
#     }

#     local method=$1
#     local key=$2
#     local json=$3

#     if [ -z "$method" ] || [ -z "$key" ] || [ -z "$json" ]; then
#         return 1
#     fi

#     case "$method" in
#     "read")
#         (JSON_READ "$key" "$json")
#         ;;
#     *)
#         return 1
#         ;;
#     esac
# }

function __INTERNAL_JSON() {
    function JSON_RAW_KEY_PROCESSOR() {
        local raw_key="$1"
        local path_list=()

        local path_level=0

        local quote_flag=1
        local esc_flag=1

        local buffer=""

        local last_char=""

        for ((offset = 0; offset < "${#raw_key}"; offset++)); do
            local char="${raw_key:offset:1}"
            local keyword_flag=1

            case "$char" in
            "\"")
                if [ "$esc_flag" -eq 1 ]; then
                    quote_flag="$(NOT "$quote_flag")"
                    keyword_flag=0
                fi
                ;;
            "[")
                if [ "$quote_flag" -eq 1 ]; then
                    if [ -n "$last_char" ]; then
                        buffer+="\""
                    fi
                fi
                ;;
            ".")
                if [ "$quote_flag" -eq 1 ]; then
                    keyword_flag=0
                    if [ -n "$buffer" ] && [ "$path_level" -gt 0 ]; then
                        buffer="\"$buffer"
                        if [ "$last_char" != "]" ]; then
                            buffer+="\""
                        fi
                    fi

                    path_list+=("$buffer")
                    buffer=""
                    ((path_level++))
                fi
                ;;
            esac

            if [ "$char" == "\\" ]; then
                esc_flag="$(NOT "$esc_flag")"
            else
                esc_flag=1
            fi

            if [ "$keyword_flag" -eq 1 ]; then
                buffer+="$char"
            fi

            last_char="$char"
        done

        if [ -n "$buffer" ]; then
            if [ "$path_level" -gt 0 ]; then
                buffer="\"$buffer"
            fi

            if [ "$last_char" != "]" ]; then
                buffer+="\""
            fi
        fi

        if [ "$quote_flag" -eq 0 ]; then
            return 1
        fi

        path_list+=("$buffer")

        for path in "${path_list[@]}"; do
            echo "$path"
        done
    }

    function JSON_READ() {
        function GET_CURRENT_PATH() {
            local is_array_flag"$1"
            local path="$2"
            local key_buffer="$3"

            local current_path=""

            if [ -n "$key_buffer" ]; then
                if [ "$is_array_flag" -eq 0 ]; then
                    current_path="${path}[$key_buffer]"
                else
                    current_path="${path}.\"$key_buffer\""
                fi
            else
                current_path="$path"
            fi

            echo "$current_path"
            return 0
        }

        local offset="${1:-0}"
        local path="${2:-}"
        local depth="${3:-0}"

        local esc_flag=1
        local quote_flag=1
        local key_input_flag=0
        local is_array_flag=1
        local value_input_flag="${4:-1}"
        local find_flag=1

        local key_buffer=""
        local value_buffer=""
        local result=()

        local start_char="${json:offset:1}"

        if [ "$key" == "." ] && [ "$depth" -eq 0 ]; then
            value_input_flag=0
            value_buffer+="$start_char"
        fi

        if [ "$start_char" == "[" ]; then
            is_array_flag=0
            key_buffer=0
            local current_path="$(GET_CURRENT_PATH 0 "$path" 0)"
            if [ "$key" == "$current_path" ]; then
                find_flag=0
                value_input_flag=0
            fi
        elif [ "$start_char" != "{" ]; then
            return 1
        fi

        ((offset++))

        for (( ; offset < "${#json}"; offset++)); do
            local char="${json:offset:1}"
            local keyword_flag=1
            local invalid_flag=1

            if [ "$char" == "\"" ] && [ "$esc_flag" -eq 1 ]; then
                keyword_flag=0
                quote_flag=$(NOT "$quote_flag")
            elif [ "$quote_flag" -eq 1 ]; then
                case "$char" in
                "{" | "[")
                    keyword_flag=0

                    local current_path="$(GET_CURRENT_PATH "$is_array_flag" "$path" "$key_buffer")"
                    readarray -t result < <(JSON_READ "$offset" "$current_path" "$((depth + 1))" "$value_input_flag")

                    if [ "$?" -eq 1 ]; then
                        return 1
                    fi

                    if [ -n "${result[1]}" ] && [ "$value_input_flag" -eq 1 ]; then
                        echo "${result[0]}"
                        echo "${result[1]}"
                        return 0
                    fi

                    if [ "$value_input_flag" -eq 0 ]; then
                        value_buffer+="$char${result[1]}"
                    fi

                    offset="${result[0]}"
                    continue
                    ;;
                "}" | "]")
                    keyword_flag=0
                    echo "$offset"
                    if [ "$value_input_flag" -eq 0 ]; then
                        if [ "$find_flag" -eq 0 ]; then
                            echo "$value_buffer"
                        else
                            echo "$value_buffer$char"
                        fi
                    fi
                    return 0
                    ;;
                ",")
                    keyword_flag=0
                    key_input_flag=0

                    if [ "$find_flag" -eq 0 ] && [ "$value_input_flag" -eq 0 ]; then
                        echo "$offset"
                        echo "$value_buffer"
                        return 0
                    fi

                    if [ "$is_array_flag" -eq 0 ]; then
                        ((key_buffer++))

                        if [ "$key" == "$(GET_CURRENT_PATH "$is_array_flag" "$path" "$key_buffer")" ]; then
                            find_flag=0
                            value_input_flag=0
                            continue
                        fi
                    else
                        key_buffer=""
                    fi
                    ;;
                ":")
                    keyword_flag=0
                    key_input_flag=1

                    if [ "$key" == "$(GET_CURRENT_PATH "$is_array_flag" "$path" "$key_buffer")" ]; then
                        find_flag=0
                        value_input_flag=0
                        continue
                    fi
                    ;;
                "t" | "r" | "u" | "e" | "f" | "a" | "l" | "s" | "n" | [0-9] | "." | "-")
                    :
                    ;;
                [[:space:]])
                    invalid_flag=0
                    ;;
                *)
                    return 1
                    ;;
                esac
            fi

            if [ "$char" == "\\" ]; then
                esc_flag="$(NOT "$esc_flag")"
            else
                esc_flag=1
            fi

            if [ "$invalid_flag" -eq 1 ]; then
                if [ "$is_array_flag" -eq 1 ] && [ "$key_input_flag" -eq 0 ] && [ "$keyword_flag" -eq 1 ]; then
                    key_buffer+="$char"
                fi

                if [ "$value_input_flag" -eq 0 ]; then
                    value_buffer+="$char"
                fi
            fi
        done
    }

    function JSON_WRITE() {
        local result=()
        key="."
        readarray -t result < <(JSON_READ)
        json="${result[1]}"

        export key="$(
            IFS="."
            echo "${path_list[*]}"
        )"

        if [ "$key" == "." ]; then
            echo "$body"
            return 0
        fi

        readarray -t result < <(JSON_READ)
        local offset="${result[0]}"
        local old_body="${result[1]}"
        if [ -n "$old_body" ]; then
            json="${json:0:$((offset - ${#old_body}))}$body${json:offset}"
            echo "$json"
            return 0
        fi
    }

    local method="$1"
    local raw_key="$2"
    export path_list=()
    readarray -t path_list < <(JSON_RAW_KEY_PROCESSOR "$raw_key")
    export key="$(
        IFS="."
        echo "${path_list[*]}"
    )"
    export body="$3"
    export json="${!#}"
    json=$(echo "$json" | tr -d $'\n\r\t')
    json="${json#"${json%%[![:space:]]*}"}"
    json="${json%"${json##*[![:space:]]}"}"

    # 上面的意思是
    # "   /-hello    -/"
    # "   "
    # "/-hello-/    "
    # "    "
    # "hello"

    if [ -z "$method" ] || [ -z "$key" ] || [ -z "$json" ]; then
        return 1
    fi

    case "$method" in
    "read")
        local result=()
        readarray -t result < <(JSON_READ)
        echo "${result[1]}"
        ;;
    *)
        (JSON_WRITE)
        ;;
    esac
}

function JSON() {
    (__INTERNAL_JSON "$@")
}
