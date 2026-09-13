#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Unit test suite for base/JSON.sh
# Tests coverage: GET, SET, DEL, HAS, TYPE, KEYS, ARR_LEN, ARR_PUSH,
# escaping, nesting, array indexing, and edge cases.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$DIR/.." && pwd)"

source "$ROOT_DIR/base/JSON.sh"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

function ASSERT_EQ() {
    local actual="$1" expected="$2" desc="$3"
    (( TOTAL_TESTS++ ))
    if [[ "$actual" == "$expected" ]]; then
        (( PASSED_TESTS++ ))
        printf "  \033[32m[PASS]\033[0m %s\n" "$desc"
    else
        (( FAILED_TESTS++ ))
        printf "  \033[31m[FAIL]\033[0m %s\n" "$desc"
        printf "         Expected: <%s>\n" "$expected"
        printf "         Actual:   <%s>\n" "$actual"
    fi
}

function ASSERT_TRUE() {
    local cmd="$1" desc="$2"
    (( TOTAL_TESTS++ ))
    if eval "$cmd" >/dev/null 2>&1; then
        (( PASSED_TESTS++ ))
        printf "  \033[32m[PASS]\033[0m %s\n" "$desc"
    else
        (( FAILED_TESTS++ ))
        printf "  \033[31m[FAIL]\033[0m %s (command failed: %s)\n" "$desc" "$cmd"
    fi
}

function ASSERT_FALSE() {
    local cmd="$1" desc="$2"
    (( TOTAL_TESTS++ ))
    if ! eval "$cmd" >/dev/null 2>&1; then
        (( PASSED_TESTS++ ))
        printf "  \033[32m[PASS]\033[0m %s\n" "$desc"
    else
        (( FAILED_TESTS++ ))
        printf "  \033[31m[FAIL]\033[0m %s (command unexpectedly succeeded: %s)\n" "$desc" "$cmd"
    fi
}

echo "=== Running JSON.sh Unit Tests ==="

# ----------------------------------------------------
# 1. Type Detection Tests
# ----------------------------------------------------
echo "--- 1. Type Detection (JSON_TYPE) ---"
ASSERT_EQ "$(JSON_TYPE '{"a": 1}')" "object" "Object type"
ASSERT_EQ "$(JSON_TYPE '[1, 2, 3]')" "array" "Array type"
ASSERT_EQ "$(JSON_TYPE '"hello world"')" "string" "String type"
ASSERT_EQ "$(JSON_TYPE '12345')" "number" "Integer type"
ASSERT_EQ "$(JSON_TYPE '-45.67e-2')" "number" "Scientific float type"
ASSERT_EQ "$(JSON_TYPE 'true')" "boolean" "Boolean true type"
ASSERT_EQ "$(JSON_TYPE 'false')" "boolean" "Boolean false type"
ASSERT_EQ "$(JSON_TYPE 'null')" "null" "Null type"
ASSERT_EQ "$(JSON_TYPE '{"x": 1}' "x")" "number" "Nested number type"
ASSERT_EQ "$(JSON_TYPE '{"x": [1]}' "x")" "array" "Nested array type"
ASSERT_EQ "$(JSON_TYPE '{"x": 1}' "not_found")" "undefined" "Undefined type on missing key"
ASSERT_EQ "$(JSON_TYPE '{"a": "123"}' "a")" "string" "String with digits is string not number"
ASSERT_EQ "$(JSON_TYPE '{"a": "true"}' "a")" "string" "String with true is string not boolean"
ASSERT_EQ "$(JSON_TYPE '{"a": "null"}' "a")" "string" "String with null is string not null"
ASSERT_EQ "$(JSON_TYPE '{"a": ""}' "a")" "string" "Empty string is string not undefined"
ASSERT_EQ "$(JSON_TYPE '{"a": "{\"k\":1}"}' "a")" "string" "JSON string is string not object"
ASSERT_EQ "$(JSON_TYPE '{"a": 01}' "a")" "undefined" "Strict number rejects leading zero 01"
ASSERT_EQ "$(JSON_TYPE '{"a": +1}' "a")" "undefined" "Strict number rejects leading plus +1"
ASSERT_EQ "$(JSON_TYPE '{"a": 1.}' "a")" "undefined" "Strict number rejects trailing dot"
ASSERT_EQ "$(JSON_TYPE '{"a": .5}' "a")" "undefined" "Strict number rejects leading dot"

# ----------------------------------------------------
# 2. String Escaping & Unescaping Tests
# ----------------------------------------------------
echo "--- 2. String Escaping & Unescaping ---"
json_str='{"msg": "He said: \"Hello, world!\"\nLine 2\\backslash\ttab"}'
ASSERT_EQ "$(JSON_GET "$json_str" "msg")" $'He said: "Hello, world!"\nLine 2\\backslash\ttab' "Escaped quotes, newlines, backslashes, tabs"

json_tricky='{"syntax_in_string": "{\"key\": [1, 2, 3], \"comma\": \",\"}"}'
ASSERT_EQ "$(JSON_GET "$json_tricky" "syntax_in_string")" '{"key": [1, 2, 3], "comma": ","}' "JSON syntax inside string value"

json_unicode='{"u": "\u4e2d\u6587\u6d4b\u8bd5"}'
ASSERT_EQ "$(JSON_GET "$json_unicode" "u")" "中文测试" "Unicode escape \uXXXX decoded"

json_surrogate='{"emoji": "\uD83D\uDE00"}'
ASSERT_EQ "$(JSON_GET "$json_surrogate" "emoji")" "😀" "Unicode surrogate pair \uD83D\uDE00 decoded"

json_nul='{"bad": "hello\u0000world"}'
if JSON_GET "$json_nul" "bad" >/dev/null 2>&1; then
    ASSERT_EQ "decoded" "error" "NUL byte \u0000 rejected in string"
else
    ASSERT_EQ "error" "error" "NUL byte \u0000 rejected in string"
fi

# ----------------------------------------------------
# 3. Simple & Nested GET Tests
# ----------------------------------------------------
echo "--- 3. Querying (JSON_GET & JSON_HAS) ---"
sample='{
  "code": 0,
  "msg": "success",
  "data": {
    "onlineUser": {
      "userName": "2024081063",
      "nodeIp": "10.23.64.230",
      "nodeMac": "CCD8437E154C",
      "active": true,
      "score": 98.5
    },
    "tokens": ["tok_a", "tok_b", "tok_c"],
    "nested_arr": [
      {"id": 1, "title": "first"},
      {"id": 2, "title": "second"}
    ]
  }
}'

ASSERT_EQ "$(JSON_GET "$sample" "code")" "0" "GET number at root"
ASSERT_EQ "$(JSON_GET "$sample" "msg")" "success" "GET string at root"
ASSERT_EQ "$(JSON_GET "$sample" "data.onlineUser.userName")" "2024081063" "GET nested string (dot path)"
ASSERT_EQ "$(JSON_GET "$sample" "data.onlineUser.active")" "true" "GET nested boolean"
ASSERT_EQ "$(JSON_GET "$sample" "data.onlineUser.score")" "98.5" "GET nested float"
ASSERT_EQ "$(JSON_GET "$sample" "data.tokens.0")" "tok_a" "GET array element by index"
ASSERT_EQ "$(JSON_GET "$sample" "data.tokens[1]")" "tok_b" "GET array element by bracket index"
ASSERT_EQ "$(JSON_GET "$sample" "data.nested_arr[0].title")" "first" "GET object in array by bracket index"
ASSERT_EQ "$(JSON_GET "$sample" "data.nested_arr.1.id")" "2" "GET object in array by dot index"

ASSERT_TRUE "JSON_HAS '$sample' 'data.onlineUser.nodeMac'" "JSON_HAS on existing path"
ASSERT_FALSE "JSON_HAS '$sample' 'data.onlineUser.not_exist'" "JSON_HAS on missing path"
ASSERT_FALSE "JSON_HAS '{\"a\": \"{\\\"b\\\": 1}\"}' 'a.b'" "Cannot traverse into string container"

# ----------------------------------------------------
# 4. Modifying & Creating (JSON_SET) Tests
# ----------------------------------------------------
echo "--- 4. Modifying & Creating (JSON_SET) ---"
init='{"name": "Alice", "age": 30}'

# Replace value
j1="$(JSON_SET "$init" "age" "31")"
ASSERT_EQ "$(JSON_GET "$j1" "age")" "31" "SET replace existing number"
ASSERT_EQ "$(JSON_GET "$j1" "name")" "Alice" "SET preserves sibling keys"

# Add new key at root
j2="$(JSON_SET "$j1" "city" "Chengdu")"
ASSERT_EQ "$(JSON_GET "$j2" "city")" "Chengdu" "SET add new string key"

# Add boolean and null
j3="$(JSON_SET "$j2" "is_admin" "true")"
j4="$(JSON_SET "$j3" "extra" "null")"
ASSERT_EQ "$(JSON_GET "$j4" "is_admin")" "true" "SET add boolean"
ASSERT_EQ "$(JSON_GET "$j4" "extra")" "null" "SET add null"

# Deep nested set on empty object
deep="$(JSON_SET "{}" "a.b.c.d" "deep_val")"
ASSERT_EQ "$(JSON_GET "$deep" "a.b.c.d")" "deep_val" "SET create full nested path from empty object"

# Nested set modifying existing branch
nested_base='{"user": {"profile": {"name": "Bob"}}}'
nested_mod="$(JSON_SET "$nested_base" "user.profile.age" "25")"
ASSERT_EQ "$(JSON_GET "$nested_mod" "user.profile.name")" "Bob" "SET nested preserves existing sibling"
ASSERT_EQ "$(JSON_GET "$nested_mod" "user.profile.age")" "25" "SET nested adds new sibling"

set_raw="$(JSON_SET '{}' 'sub' '{"k": 99}' raw)"
ASSERT_EQ "$(JSON_GET "$set_raw" "sub.k")" "99" "SET raw JSON object"
ASSERT_FALSE 'JSON_SET "{\"a\" 1}" a 2 ""' "SET fails on malformed container syntax"

# ----------------------------------------------------
# 5. Deleting (JSON_DEL) Tests
# ----------------------------------------------------
echo "--- 5. Deleting (JSON_DEL) ---"
# Single item
d1="$(JSON_DEL '{"only": 1}' "only")"
ASSERT_EQ "$d1" "{}" "DEL only item in object"

# First item in multi-item
d2="$(JSON_DEL '{"first": 1, "second": 2, "third": 3}' "first")"
ASSERT_EQ "$(JSON_GET "$d2" "second")" "2" "DEL first item preserves second item"
ASSERT_EQ "$(JSON_GET "$d2" "third")" "3" "DEL first item preserves third item"
ASSERT_FALSE "JSON_HAS '$d2' 'first'" "DEL first item removes key"

# Middle item in multi-item
d3="$(JSON_DEL '{"first": 1, "second": 2, "third": 3}' "second")"
ASSERT_EQ "$(JSON_GET "$d3" "first")" "1" "DEL middle item preserves first item"
ASSERT_EQ "$(JSON_GET "$d3" "third")" "3" "DEL middle item preserves third item"
ASSERT_FALSE "JSON_HAS '$d3' 'second'" "DEL middle item removes key"

# Last item in multi-item
d4="$(JSON_DEL '{"first": 1, "second": 2, "third": 3}' "third")"
ASSERT_EQ "$(JSON_GET "$d4" "first")" "1" "DEL last item preserves first item"
ASSERT_EQ "$(JSON_GET "$d4" "second")" "2" "DEL last item preserves second item"
ASSERT_FALSE "JSON_HAS '$d4' 'third'" "DEL last item removes key"

# Nested delete
d_nested="$(JSON_DEL '{"data": {"meta": {"del_me": 123, "keep_me": 456}}}' "data.meta.del_me")"
ASSERT_FALSE "JSON_HAS '$d_nested' 'data.meta.del_me'" "DEL nested path removes target"
ASSERT_EQ "$(JSON_GET "$d_nested" "data.meta.keep_me")" "456" "DEL nested path preserves sibling"

del_non_cont="$(JSON_DEL '{"a": "hello"}' 'a.b')"
ASSERT_EQ "$del_non_cont" '{"a": "hello"}' "DEL non-container path preserves JSON"

# ----------------------------------------------------
# 6. Array Operations Tests
# ----------------------------------------------------
echo "--- 6. Array Operations (ARR_LEN, ARR_PUSH, KEYS, Array DEL) ---"
arr='["first", "second", "third"]'
ASSERT_EQ "$(JSON_ARR_LEN "$arr")" "3" "ARR_LEN on 3-item array"
ASSERT_EQ "$(JSON_ARR_LEN '[]')" "0" "ARR_LEN on empty array"
ASSERT_FALSE 'JSON_ARR_LEN "{\"a\":1}" ""' "ARR_LEN fails on object container"

# ARR_PUSH to top-level array
arr_pushed="$(JSON_ARR_PUSH "$arr" "fourth")"
ASSERT_EQ "$(JSON_ARR_LEN "$arr_pushed")" "4" "ARR_PUSH increases length"
ASSERT_EQ "$(JSON_GET "$arr_pushed" "3")" "fourth" "ARR_PUSH appends correct value"
ASSERT_FALSE 'JSON_ARR_PUSH "[1" 2' "ARR_PUSH fails on unclosed array"

# ARR_PUSH to nested array
nested_arr_obj='{"data": {"items": [10, 20]}}'
nested_pushed="$(JSON_ARR_PUSH "$nested_arr_obj" "data.items" "30")"
ASSERT_EQ "$(JSON_ARR_LEN "$nested_pushed" "data.items")" "3" "ARR_PUSH to nested array increases length"
ASSERT_EQ "$(JSON_GET "$nested_pushed" "data.items[2]")" "30" "ARR_PUSH to nested array appends value"

# Array element deletion
arr_del0="$(JSON_DEL '["a", "b", "c"]' "0")"
ASSERT_EQ "$(JSON_GET "$arr_del0" "0")" "b" "DEL array index 0 shifts subsequent items"
ASSERT_EQ "$(JSON_ARR_LEN "$arr_del0")" "2" "DEL array index 0 reduces length"

arr_del1="$(JSON_DEL '["a", "b", "c"]' "1")"
ASSERT_EQ "$(JSON_GET "$arr_del1" "0")" "a" "DEL array index 1 preserves index 0"
ASSERT_EQ "$(JSON_GET "$arr_del1" "1")" "c" "DEL array index 1 shifts index 2 to 1"

# ----------------------------------------------------
# 7. Keys Enumeration Tests
# ----------------------------------------------------
echo "--- 7. Keys Enumeration (JSON_KEYS) ---"
obj_keys="$(JSON_KEYS '{"alpha": 1, "beta": 2, "gamma": 3}')"
expected_keys=$'alpha\nbeta\ngamma'
ASSERT_EQ "$obj_keys" "$expected_keys" "JSON_KEYS returns all object keys in order"

arr_keys="$(JSON_KEYS '["x", "y", "z"]')"
expected_arr_keys=$'0\n1\n2'
ASSERT_EQ "$arr_keys" "$expected_arr_keys" "JSON_KEYS returns all array indices"

echo "--- 8. Edge Cases & Robustness ---"
res=$(JSON_ARR_PUSH '{}' "x" 2>/dev/null) && status=0 || status=$?
ASSERT_EQ "$status" "1" "ARR_PUSH fails on object container"

res=$(JSON_ARR_PUSH '{"a":42}' "a" "x" 2>/dev/null) && status=0 || status=$?
ASSERT_EQ "$status" "1" "ARR_PUSH fails on nested non-array container"

res=$(JSON_SET '[10]' 8 99 '' 2>/dev/null) && status=0 || status=$?
ASSERT_EQ "$status" "1" "SET array index 8 on 1-item array fails"

res=$(JSON_SET '[10]' 1 99 '')
ASSERT_EQ "$res" "[10, 99]" "SET array at length appends element"

val=$(JSON_GET '{"a\n":1,"a":2}' a)
ASSERT_EQ "$val" "2" "GET distinguishes key with trailing newline"

# ----------------------------------------------------
# Summary
# ----------------------------------------------------
echo "==================================="
echo "Test Summary:"
printf "Total:  %d\n" "$TOTAL_TESTS"
printf "Passed: \033[32m%d\033[0m\n" "$PASSED_TESTS"
printf "Failed: \033[31m%d\033[0m\n" "$FAILED_TESTS"
echo "==================================="

if (( FAILED_TESTS > 0 )); then
    exit 1
else
    exit 0
fi
