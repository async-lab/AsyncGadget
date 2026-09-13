#!/usr/bin/env bash
# -*- coding: utf-8 -*-

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/base/AES.sh"

PASSED=0
FAILED=0

function ASSERT_EQ() {
    local desc="$1"
    local actual="$2"
    local expected="$3"
    if [ "$actual" = "$expected" ]; then
        printf "   \033[32m[PASS]\033[0m %s\n" "$desc"
        ((PASSED++))
    else
        printf "   \033[31m[FAIL]\033[0m %s\n" "$desc"
        printf "          Expected: %s\n" "$expected"
        printf "          Actual:   %s\n" "$actual"
        ((FAILED++))
    fi
}

function ASSERT_FAIL() {
    local desc="$1"
    shift
    if ! "$@" >/dev/null 2>&1; then
        printf "   \033[32m[PASS]\033[0m %s\n" "$desc"
        ((PASSED++))
    else
        printf "   \033[31m[FAIL]\033[0m %s (expected failure but succeeded)\n" "$desc"
        ((FAILED++))
    fi
}

echo "=== Running AES.sh Unit Tests ==="

echo "--- 1. Encryption against OpenSSL ground truth ---"
KEY_B64="K34VFiiu0qar9xWICc9PPA=="
KEY_HEX="2b7e151628aed2a6abf7158809cf4f3c"

test_cases=(
    ""
    "12345"
    "123456789012345"
    "1234567890123456"
    "12345678901234567"
    "Hello World! AES-128-ECB Test"
    "你好，世界！这是一段中文测试文本。"
    "Special chars: !@#$%^&*()_+~[]{}:;'\"<>?,./\ "
)

for text in "${test_cases[@]}"; do
    bash_out="$(AES_128_ECB_ENCRYPT "$KEY_B64" "$text")"
    openssl_out="$(printf '%s' "$text" | openssl enc -aes-128-ecb -K "$KEY_HEX" -base64 -A)"
    ASSERT_EQ "ECB encrypt: [${text:0:20}...]" "$bash_out" "$openssl_out"
done

echo "--- 2. Key validation and error handling ---"
ASSERT_FAIL "Reject key shorter than 16 bytes" AES_128_ECB_ENCRYPT "c2hvcnQ=" "text"
ASSERT_FAIL "Reject key longer than 16 bytes" AES_128_ECB_ENCRYPT "K34VFiiu0qar9xWICc9PPA123456==" "text"
ASSERT_FAIL "Reject key with invalid characters" AES_128_ECB_ENCRYPT "K34VFiiu0qar9xWICc9PP!==" "text"
ASSERT_FAIL "Reject key with missing padding" AES_128_ECB_ENCRYPT "K34VFiiu0qar9xWICc9PPA" "text"
ASSERT_FAIL "Reject wrong argument count" AES_128_ECB_ENCRYPT "K34VFiiu0qar9xWICc9PPA=="

echo "--- 3. Base64 Decode validation ---"
local_arr=("original")
ASSERT_FAIL "Decode invalid length base64" AES_B64_DECODE "abc" local_arr
ASSERT_EQ "Atomic write preserved on failure" "${local_arr[0]}" "original"
ASSERT_FAIL "Decode invalid char base64" AES_B64_DECODE "ab!d" local_arr
ASSERT_FAIL "Decode invalid padding" AES_B64_DECODE "a=cd" local_arr
ASSERT_FAIL "Decode mid-string padding" AES_B64_DECODE "Zg==AAAA" local_arr
ASSERT_FAIL "Decode non-zero padding bits (Zh==)" AES_B64_DECODE "Zh==" local_arr

echo "--- 4. NIST SP 800-38A Standard Vector (Raw 16-byte Block) ---"
nist_key=(0x00 0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0e 0x0f)
nist_pt=(0x00 0x11 0x22 0x33 0x44 0x55 0x66 0x77 0x88 0x99 0xaa 0xbb 0xcc 0xdd 0xee 0xff)
nist_expected_hex="69c4e0d86a7b0430d8cdb78070b4c55a"

nist_rk=()
AES_EXPAND_KEY nist_key nist_rk
nist_ct=()
AES_ENCRYPT_16B nist_pt nist_rk nist_ct

actual_hex=""
for b in "${nist_ct[@]}"; do
    printf -v h '%02x' "$b"
    actual_hex+="$h"
done
ASSERT_EQ "NIST SP 800-38A single block vector" "$actual_hex" "$nist_expected_hex"

echo "==================================="
echo "Test Summary:"
echo "Total:  $((PASSED + FAILED))"
printf "Passed: \033[32m%d\033[0m\n" "$PASSED"
printf "Failed: \033[31m%d\033[0m\n" "$FAILED"
echo "==================================="

exit "$FAILED"
