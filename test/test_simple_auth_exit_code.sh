#!/usr/bin/env bash
# Unit tests for network/simple_auth.sh exit codes

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/.." || exit 1

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_exit_code() {
    local desc="$1"
    local expected="$2"
    shift 2
    TESTS_RUN=$((TESTS_RUN + 1))
    
    "$@" >/dev/null 2>&1
    local actual=$?
    
    if [[ "$actual" -eq "$expected" ]]; then
        echo "[PASS] $desc (exit $actual)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "[FAIL] $desc: expected exit $expected, got $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=== Testing network/simple_auth.sh Exit Codes ==="

# 1. Missing parameters
assert_exit_code "missing all parameters exits 1" 1 bash network/simple_auth.sh
assert_exit_code "login missing username/password exits 1" 1 bash network/simple_auth.sh login eth0 0
assert_exit_code "invalid method exits 1" 1 bash network/simple_auth.sh foobar eth0

# 2. whoami failure (non-existent interface)
assert_exit_code "whoami fails on nonexistent interface exits 1" 1 bash network/simple_auth.sh whoami dummy_nonexistent_iface

# 3. Mock environment for whoami success / failure
MOCK_BIN_DIR=$(mktemp -d)

cat <<'EOF' > "$MOCK_BIN_DIR/curl"
#!/usr/bin/env bash
for arg in "$@"; do
    if [[ "$arg" == *"index.jsp"* ]]; then
        printf "HTTP/1.1 302 Found\r\nLocation: http://10.254.241.66/eportal/index.jsp?sessionId=test_sess_123\r\n\r\n"
        exit 0
    elif [[ "$arg" == *"getOnlineUserInfo"* ]]; then
        printf '{"result":"success","code":200,"data":{"onlineUser":{"userName":"2024081063","userObjectId":"abc","nodeMac":"AA:BB:CC","nodeIp":"10.23.64.230","nodePhysicalLocation":"Lab","authenticationTime":"2026-09-13 12:00:00"}}}'
        exit 0
    fi
done
exit 1
EOF
chmod +x "$MOCK_BIN_DIR/curl"

assert_exit_code "whoami with successful user info exits 0" 0 env PATH="$MOCK_BIN_DIR:$PATH" bash network/simple_auth.sh whoami eth0

cat <<'EOF' > "$MOCK_BIN_DIR/curl"
#!/usr/bin/env bash
for arg in "$@"; do
    if [[ "$arg" == *"index.jsp"* ]]; then
        printf "HTTP/1.1 302 Found\r\nLocation: http://10.254.241.66/eportal/index.jsp?sessionId=test_sess_123\r\n\r\n"
        exit 0
    elif [[ "$arg" == *"getOnlineUserInfo"* ]]; then
        printf '{"result":"success","data":{"onlineUser":null}}'
        exit 0
    fi
done
exit 1
EOF
chmod +x "$MOCK_BIN_DIR/curl"

assert_exit_code "whoami with offline user exits 1" 1 env PATH="$MOCK_BIN_DIR:$PATH" bash network/simple_auth.sh whoami eth0

echo "=== Testing launcher.sh Exit Code Propagation ==="
assert_exit_code "launcher missing script exits 1" 1 bash launcher.sh
assert_exit_code "launcher unknown script exits 1" 1 bash launcher.sh unknown_script
assert_exit_code "launcher propagates simple_auth failure (exit 1)" 1 bash launcher.sh simple_auth whoami dummy_nonexistent_iface

cat <<'EOF' > "$MOCK_BIN_DIR/curl"
#!/usr/bin/env bash
for arg in "$@"; do
    if [[ "$arg" == *"index.jsp"* ]]; then
        printf "HTTP/1.1 302 Found\r\nLocation: http://10.254.241.66/eportal/index.jsp?sessionId=test_sess_123\r\n\r\n"
        exit 0
    elif [[ "$arg" == *"getOnlineUserInfo"* ]]; then
        printf '{"result":"success","code":200,"data":{"onlineUser":{"userName":"2024081063","userObjectId":"abc","nodeMac":"AA:BB:CC","nodeIp":"10.23.64.230","nodePhysicalLocation":"Lab","authenticationTime":"2026-09-13 12:00:00"}}}'
        exit 0
    fi
done
exit 1
EOF
chmod +x "$MOCK_BIN_DIR/curl"

assert_exit_code "launcher propagates simple_auth success (exit 0)" 0 env PATH="$MOCK_BIN_DIR:$PATH" bash launcher.sh simple_auth whoami eth0_ok

rm -rf "$MOCK_BIN_DIR"

echo "----------------------------------------"
echo "Results: $TESTS_PASSED / $TESTS_RUN passed, $TESTS_FAILED failed."
if [[ "$TESTS_FAILED" -gt 0 ]]; then
    exit 1
fi
exit 0
