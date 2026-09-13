#!/usr/bin/env bash
# Unit tests for network/auto_auth.sh dynamic sync and auth logic

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/.." || exit 1

source base/STD.sh
REQUIRE network/lib/school_auth.sh

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_eq() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo -e "\e[32m[PASS]\e[0m $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "\e[31m[FAIL]\e[0m $desc: expected '$expected', got '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=== Testing auto_auth.sh Dynamic Sync & Binding ==="

# Prepare test account file
TEST_ACCOUNTS="/tmp/test_accounts.txt"
cat <<'EOF' > "$TEST_ACCOUNTS"
0,2025081023,pass1
1,2024081063,pass2
0,2022124020,pass3
EOF

# Source auto_auth functions without running RUN_MAIN
# Define globals needed by auto_auth
# Load functions from auto_auth.sh (without executing MAIN)
eval "$(sed -e '/^RUN_MAIN/d' network/auto_auth.sh)"

ACCOUNT_FILE="$TEST_ACCOUNTS"
LOAD_ACCOUNTS

# Test 1: First tick, macvlan1 is reported online with account 2025081023
function GET_ONLINE_USER_INFO() {
    if [[ "$1" == "macvlan1" ]]; then
        echo -e "userName=2025081023\nauthenticationTime=2026-09-13 10:00:00\nnodeIp=10.23.64.231\nnodeMac=AA:BB:CC\nnodePhysicalLocation=Lab\nuserObjectId=1"
        return 0
    elif [[ "$1" == "macvlan2" ]]; then
        echo -e "userName=external_user\nauthenticationTime=2026-09-13 10:00:00\nnodeIp=10.23.64.230\nnodeMac=AA:BB:DD\nnodePhysicalLocation=Lab\nuserObjectId=2"
        return 0
    else
        echo "离线"
        return 1
    fi
}

AUTH_FOR_INTERFACE_FROM_ACCOUNTS "macvlan1"
assert_eq "macvlan1 online binds 2025081023" "macvlan1" "${ACCOUNT_BIND[2025081023]}"
assert_eq "macvlan1 interface state is online" "online" "${INTERFACE_STATE[macvlan1]}"

# Test 2: macvlan2 is reported online with external account
AUTH_FOR_INTERFACE_FROM_ACCOUNTS "macvlan2"
assert_eq "external account not in ACCOUNT_BIND" "" "${ACCOUNT_BIND[external_user]:-}"
assert_eq "macvlan2 interface state is online" "online" "${INTERFACE_STATE[macvlan2]}"

# Test 3: Account drift - macvlan1 account manually changed to 2024081063
function GET_ONLINE_USER_INFO() {
    if [[ "$1" == "macvlan1" ]]; then
        echo -e "userName=2024081063\nauthenticationTime=2026-09-13 11:00:00\nnodeIp=10.23.64.231\nnodeMac=AA:BB:CC\nnodePhysicalLocation=Lab\nuserObjectId=3"
        return 0
    fi
    echo "离线"
    return 1
}

AUTH_FOR_INTERFACE_FROM_ACCOUNTS "macvlan1"
assert_eq "old account 2025081023 is released" "" "${ACCOUNT_BIND[2025081023]}"
assert_eq "new account 2024081063 is bound to macvlan1" "macvlan1" "${ACCOUNT_BIND[2024081063]}"

# Test 4: macvlan3 is offline on BRAS, attempts AUTH with first available candidate
MOCK_AUTH_LOG="/tmp/mock_auth.log"
rm -f "$MOCK_AUTH_LOG"

function AUTH() {
    echo "$2" > "$MOCK_AUTH_LOG"
    echo "mock_session_ok"
    return 0
}

function GET_ONLINE_USER_INFO() {
    echo "离线"
    return 1
}

AUTH_FOR_INTERFACE_FROM_ACCOUNTS "macvlan3"
auth_ret="$?"
assert_eq "AUTH_FOR_INTERFACE_FROM_ACCOUNTS returns YES (0) on success" "0" "$auth_ret"
mock_auth_user="$(cat "$MOCK_AUTH_LOG" 2>/dev/null)"
assert_eq "AUTH was triggered with first available candidate 2025081023" "2025081023" "$mock_auth_user"
assert_eq "2025081023 is now bound to macvlan3" "macvlan3" "${ACCOUNT_BIND[2025081023]}"
assert_eq "macvlan3 interface state is online" "online" "${INTERFACE_STATE[macvlan3]}"

# Test 5: Query error (e.g. timeout / network down, return 2) preserves existing binding and does not trigger AUTH
rm -f "$MOCK_AUTH_LOG"
function GET_ONLINE_USER_INFO() {
    echo "请求超时"
    return 2
}

AUTH_FOR_INTERFACE_FROM_ACCOUNTS "macvlan3"
query_err_ret="$?"
assert_eq "AUTH_FOR_INTERFACE_FROM_ACCOUNTS returns NO (1) on query error" "1" "$query_err_ret"
assert_eq "Query error preserves macvlan3 binding to 2025081023" "macvlan3" "${ACCOUNT_BIND[2025081023]}"
assert_eq "AUTH was NOT triggered on query error" "" "$(cat "$MOCK_AUTH_LOG" 2>/dev/null)"

MACVLAN_INTERFACES=("macvlan1" "macvlan2")
ACCOUNT_BIND[2025081023]=""
ACCOUNT_BIND[2024081063]=""
rm -f "$MOCK_AUTH_LOG"

function GET_ONLINE_USER_INFO() {
    if [[ "$1" == "macvlan2" ]]; then
        echo -e "userName=2025081023\nauthenticationTime=2026-09-13 12:00:00\nnodeIp=10.23.64.232\nnodeMac=AA:BB:EE\nnodePhysicalLocation=Lab\nuserObjectId=4"
        return 0
    fi
    echo "离线"
    return 1
}

SYNC_ONLINE_ACCOUNTS
assert_eq "SYNC_ONLINE_ACCOUNTS binds 2025081023 to macvlan2" "macvlan2" "${ACCOUNT_BIND[2025081023]}"

AUTH_FOR_INTERFACE_FROM_ACCOUNTS "macvlan1"
mock_auth_user="$(cat "$MOCK_AUTH_LOG" 2>/dev/null)"
assert_eq "macvlan1 does not preempt 2025081023 and instead uses 2024081063" "2024081063" "$mock_auth_user"
assert_eq "2024081063 is bound to macvlan1" "macvlan1" "${ACCOUNT_BIND[2024081063]}"

rm -f "$TEST_ACCOUNTS" "$MOCK_AUTH_LOG"

echo "----------------------------------------"
echo "Results: $TESTS_PASSED / $TESTS_RUN passed, $TESTS_FAILED failed."
if [[ "$TESTS_FAILED" -gt 0 ]]; then
    exit 1
fi
exit 0
