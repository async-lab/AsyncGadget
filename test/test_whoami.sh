#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR="$DIR/.."

source "$ROOT_DIR/base/REQUIRE.sh"
REQUIRE "$ROOT_DIR/base/CONVERT.sh"
REQUIRE "$ROOT_DIR/base/STRUCTURE.sh"
REQUIRE "$ROOT_DIR/network/lib/school_auth.sh"

mock_response='{"code":200,"data":{"onlineUser":{"userName":"2025081023","authenticationTime":"2026-09-06 10:07:31","nodeIp":"10.23.64.231","nodeMac":"CCD8437E154C","nodePhysicalLocation":"办公实验室","userObjectId":"abc-123"}}}'

echo "Testing JSON parsing from mock response..."
user_type="$(JSON_TYPE "$mock_response" "data.onlineUser")"
echo "user_type: $user_type"
[ "$user_type" = "object" ]

kv_output="userName=$(JSON_GET "$mock_response" "data.onlineUser.userName")
authenticationTime=$(JSON_GET "$mock_response" "data.onlineUser.authenticationTime")
nodeIp=$(JSON_GET "$mock_response" "data.onlineUser.nodeIp")
nodeMac=$(JSON_GET "$mock_response" "data.onlineUser.nodeMac")
nodePhysicalLocation=$(JSON_GET "$mock_response" "data.onlineUser.nodePhysicalLocation")
userObjectId=$(JSON_GET "$mock_response" "data.onlineUser.userObjectId")"

declare -A user_info
PARSE_KV user_info "$kv_output"

echo "Parsed userName: ${user_info[userName]}"
echo "Parsed time: ${user_info[authenticationTime]}"
echo "Parsed IP: ${user_info[nodeIp]}"
echo "Parsed MAC: ${user_info[nodeMac]}"
echo "Parsed location: ${user_info[nodePhysicalLocation]}"
echo "Parsed UUID: ${user_info[userObjectId]}"

[ "${user_info[userName]}" = "2025081023" ]
[ "${user_info[authenticationTime]}" = "2026-09-06 10:07:31" ]
[ "${user_info[nodePhysicalLocation]}" = "办公实验室" ]

echo "ALL WHOAMI BASIC TESTS PASSED!"

echo "Testing PARSE_KV variable scoping..."
k="caller_k"
v="caller_v"
declare -A test_map=()
PARSE_KV test_map "foo=bar"
[ "$k" = "caller_k" ] || { echo "FAIL: k leaked"; exit 1; }
[ "$v" = "caller_v" ] || { echo "FAIL: v leaked"; exit 1; }
[ "${test_map[foo]}" = "bar" ] || { echo "FAIL: map value incorrect"; exit 1; }

echo "Testing newline injection prevention..."
mock_injection='{"code":200,"data":{"onlineUser":{"userName":"alice","nodePhysicalLocation":"room1\nuserName=bob\nevil=true"}}}'
user_name="$(JSON_GET "$mock_injection" "data.onlineUser.userName")"
node_loc="$(JSON_GET "$mock_injection" "data.onlineUser.nodePhysicalLocation")"
kv_safe="userName=${user_name//[$'\r\n']/}
nodePhysicalLocation=${node_loc//[$'\r\n']/ }"
declare -A injected_map=()
PARSE_KV injected_map "$kv_safe"
[ "${injected_map[userName]}" = "alice" ] || { echo "FAIL: userName injected!"; exit 1; }
[ -z "${injected_map[evil]}" ] || { echo "FAIL: evil injected!"; exit 1; }

echo "ALL EXTENDED TESTS PASSED!"

echo "Testing null userName rejection in GET_ONLINE_USER_INFO..."
function curl() {
    echo '{"code":200,"data":{"onlineUser":{"userName":null}}}'
    return 0
}
if GET_ONLINE_USER_INFO "dummy_iface" "dummy_session" >/dev/null 2>&1; then
    echo "FAIL: GET_ONLINE_USER_INFO should fail on userName: null"
    exit 1
fi

echo "Testing LOGOUT failure propagation on curl failure..."
function curl() {
    return 7
}
if LOGOUT "dummy_iface" "dummy_session" >/dev/null 2>&1; then
    echo "FAIL: LOGOUT should fail when curl fails"
    exit 1
fi

echo "Testing LOGOUT success on normal curl..."
function curl() {
    return 0
}
if ! LOGOUT "dummy_iface" "dummy_session" >/dev/null 2>&1; then
    echo "FAIL: LOGOUT should succeed when curl succeeds"
    exit 1
fi

echo "ALL NEW WHOAMI & LOGOUT TESTS PASSED!"
