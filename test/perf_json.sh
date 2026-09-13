#!/usr/bin/env bash
# Pure-Bash adversarial tests and repeatable benchmarks; no external utilities.
# Run: wsl bash /mnt/f/Asynclab/AsyncGadget/test/perf_json.sh
# Exit 1 means a test failed; benchmarks still run. Bash 5+ for EPOCHREALTIME.
# This is a finite adversarial matrix, not a proof of complete RFC conformance.
if (( BASH_VERSINFO[0] < 5 )); then
    printf 'Bash 5+ required for microsecond timing.\n' >&2
    exit 2
fi
source "${BASH_SOURCE[0]%/*}/../base/JSON.sh" || exit 2
export LC_ALL=C
# Prove neither the harness nor tested APIs require external executables.
PATH=/__json_benchmark_no_external_commands__
passed=0 failed=0 skipped=0
actual='' status=0

capture() {
    # Sentinel prevents command substitution from removing real trailing LFs.
    actual=$( "$@"; status=$?; printf '\034'; exit "$status" )
    status=$?
    actual=${actual%$'\034'}
}

check() {
    local label=$1 expected_status=$2 expected=$3
    shift 3
    capture "$@"
    if { [[ $expected_status == reject ]] && (( status != 0 )); } ||
       { [[ $expected_status != reject && $status == "$expected_status" && $actual == "$expected" ]]; }; then
        ((passed+=1))
        printf 'PASS %s\n' "$label"
    else
        ((failed+=1))
        printf 'FAIL %s | expected rc=%s value=%q; actual rc=%d value=%q\n' \
            "$label" "$expected_status" "$expected" "$status" "$actual"
    fi
}

reject_document() {
    local label=$1 document=$2
    check "RFC/$label/root GET" reject '' JSON_GET "$document" ''
    check "RFC/$label/root TYPE" reject '' JSON_TYPE "$document" ''
}

printf 'ENV Bash=%s OS=%s locale=%s; external PATH disabled\n' "$BASH_VERSION" "$OSTYPE" "$LC_ALL"
printf '\n=== RFC syntax rejection ===\n'
bad_labels=(missing-colon unclosed-object unclosed-array object-trailing-comma array-trailing-comma
    missing-comma mismatched-nesting invalid-escape short-unicode nonhex-unicode
    unterminated-string trailing-backslash trailing-junk trailing-object second-value
    bare-key single-quotes comment empty whitespace invalid-literal literal-suffix missing-value)
bad_docs=('{"a" 1}' '{"a":1' '[1,2' '{"a":1,}' '[1,2,]'
    '{"a":1 "b":2}' '{"a":[1}' '"\q"' '"\u123"' '"\uZZZZ"'
    '"abc' '"abc\' 'true junk' '{}junk' '1 2'
    '{a:1}' "{'a':1}" '/*x*/true' '' $' \t\r\n' 'True' 'truex' '{"a":}')
for ((i=0; i<${#bad_docs[@]}; i++)); do
    reject_document "${bad_labels[i]}" "${bad_docs[i]}"
done
for doc in '{"a" 1}' '{"a":1' '{"a":1,}' '{"a":1 "b":2}' '{"a":[1}' '{"a":1}junk'; do
    check "RFC/member GET $doc" reject '' JSON_GET "$doc" a
    check "RFC/KEYS $doc" reject '' JSON_KEYS "$doc" ''
done
for doc in '[1,2,]' '[1,2' '[1 2]' '[1}2]' '[1]junk'; do
    check "RFC/ARR_LEN $doc" reject '' JSON_ARR_LEN "$doc" ''
done
for ((i=1; i<32; i++)); do
    printf -v oct '%03o' "$i"
    printf -v control '%b' "\\$oct"
    reject_document "unescaped-control-$i" "\"a${control}b\""
    check "RFC/control-$i in key" reject '' JSON_KEYS "{\"a${control}b\":1}" ''
    printf -v escaped '\\u%04x' "$i"
    check "unicode/escaped-control-$i" 0 "a${control}b" JSON_GET "\"a${escaped}b\"" ''
    capture JSON_SET '{}' s "a${control}b" ''
    check "roundtrip/control-$i" 0 "a${control}b" JSON_GET "$actual" s
done
((skipped+=1))
printf 'SKIP literal ASCII 0: Bash arguments cannot contain NUL; escaped NUL tested below.\n'
for ws in $'\v' $'\f' $'\302\240'; do
    reject_document 'non-JSON-whitespace' "${ws}true"
done

printf '\n=== Numbers and valid roots ===\n'
for number in -12.75 1e5 -2.5e-3 0 -0 0.0 1E+9 -0.0 1e-9999 1e9999 9007199254740993; do
    check "number/GET $number" 0 "$number" JSON_GET "$number" ''
    check "number/TYPE $number" 0 $'number\n' JSON_TYPE "$number" ''
    capture JSON_SET '{}' n "$number" ''
    check "number/SET $number" 0 "$number" JSON_GET "$actual" n
done
for number in 01 +1 .5 5. -01 00 --1 1e 1e+ NaN Infinity 0x10; do
    reject_document "invalid-number-$number" "$number"
    check "number/nested reject $number" reject '' JSON_GET "{\"n\":$number}" n
    capture JSON_SET '{}' n "$number" ''
    check "number/SET invalid numeric text is string $number" 0 $'string\n' JSON_TYPE "$actual" n
done
for doc in '{}' '[]' true false null '""' '"braces {} [] , :"'; do
    check "valid/HAS $doc" 0 '' JSON_HAS "$doc" ''
done
check 'valid/JSON whitespace' 0 true JSON_GET $' \t\r\ntrue \n\r\t ' ''
check 'valid/empty string' 0 '' JSON_GET '""' ''
check 'unicode/BMP and astral' 0 $'A\xc3\xa9\xe4\xb8\xad\xf0\x9f\x98\x80' JSON_GET '"\u0041\u00E9\u4e2d\uD83D\uDE00"' ''
check 'unicode/max scalar' 0 $'\xf4\x8f\xbf\xbf' JSON_GET '"\uDBFF\uDFFF"' ''
check 'unicode/raw UTF-8' 0 $'\xe4\xb8\xad\xf0\x9f\x98\x80' JSON_GET $'"\xe4\xb8\xad\xf0\x9f\x98\x80"' ''
check 'escape/slash quotes backslash' 0 $'a/b"c\\d' JSON_GET '"a\/b\"c\\d"' ''
check 'escape/quoted key and value' 0 'say "hi"' JSON_GET '{"a\"b":"say \"hi\""}' 'a"b'
check 'escape/unicode key' 0 7 JSON_GET '{"\u0061":7}' a
check 'escape/trailing newline value' 0 $'x\n' JSON_GET '{"a":"x\n"}' a
check 'limit/NUL decoding rejects rather than truncates' reject '' JSON_GET '"a\u0000b"' ''
check 'valid/NUL remains representable in raw container' 0 '{"a":"\u0000"}' JSON_GET '{"a":"\u0000"}' ''
# RFC 8259 ABNF permits lone surrogate escapes; interoperability is unspecified.
for doc in '"\uD800"' '"\uDC00"' '"\uD800\u0041"' $'"\xff"'; do
    capture JSON_GET "$doc" ''
    printf 'OBSERVE unicode input=%q rc=%d decoded-bytes=%q (not a portable scalar string)\n' "$doc" "$status" "$actual"
done

printf '\n=== API boundaries and mutation stress ===\n'
check 'missing/GET' reject '' JSON_GET '{"a":null}' missing
check 'missing/HAS' reject '' JSON_HAS '{}' a
check 'null/HAS' 0 '' JSON_HAS '{"a":null}' a
check 'path/no traversal into string' reject '' JSON_GET '{"a":"{\"b\":1}"}' a.b
check 'keys/order' 0 $'a\nb\n' JSON_KEYS '{"a":1,"b":2}' ''
check 'array/bracket path' 0 2 JSON_GET '{"a":[1,2]}' 'a[1]'
check 'array/out of range' reject '' JSON_GET '[1]' 9
check 'array/negative index' reject '' JSON_GET '[1]' -1
check 'API/SET malformed object reports failure' reject '' JSON_SET '{"a" 1}' a 2 ''
check 'API/PUSH malformed array reports failure' reject '' JSON_ARR_PUSH '[1' 2
check 'API/ARR_LEN non-array rejects' reject '' JSON_ARR_LEN '{"a":1}' ''
check 'API/DEL missing unchanged' 0 '{"a":1}' JSON_DEL '{"a":1}' absent
check 'API/DEL singleton object' 0 '{}' JSON_DEL '{"a":1}' a
check 'API/DEL singleton array' 0 '[]' JSON_DEL '[1]' 0
for pair in 'empty-key|{"":7}|' 'dot-key|{"a.b":7}|a.b' 'bracket-key|{"a[0]":7}|a[0]' 'newline-key|{"a\n":7}|'; do
    IFS='|' read -r label doc path <<< "$pair"
    [[ $label == newline-key ]] && path=$'a\n'
    capture JSON_GET "$doc" "$path"
    printf 'OBSERVE path limitation %s rc=%d value=%q\n' "$label" "$status" "$actual"
done
capture JSON_GET '{"a":1,"a":2}' a
printf 'OBSERVE duplicate keys (RFC SHOULD unique): rc=%d selected=%q\n' "$status" "$actual"
obj='{}'
for ((i=0; i<20; i++)); do
    capture JSON_SET "$obj" "k$i" "$i" ''
    obj=$actual
    check "SET20/status-$i" 0 "$status" printf '%s' 0
    check "SET20/value-$i" 0 "$i" JSON_GET "$obj" "k$i"
done
expected_keys=''
for ((i=0; i<20; i++)); do expected_keys+="k$i"$'\n'; done
check 'SET20/all keys' 0 "$expected_keys" JSON_KEYS "$obj" ''
for key in k0 k10 k19; do
    capture JSON_DEL "$obj" "$key"
    obj=$actual
    check "DEL20/$key absent" reject '' JSON_HAS "$obj" "$key"
done
expected_keys=''
for ((i=1; i<19; i++)); do
    ((i == 10)) && continue
    expected_keys+="k$i"$'\n'
    check "DEL20/survivor-$i" 0 "$i" JSON_GET "$obj" "k$i"
done
check 'DEL20/all surviving keys' 0 "$expected_keys" JSON_KEYS "$obj" ''
arr='[]'
for ((i=0; i<50; i++)); do
    capture JSON_ARR_PUSH "$arr" "$i"
    arr=$actual
    check "PUSH50/status-$i" 0 "$status" printf '%s' 0
    check "PUSH50/length-$i" 0 "$((i+1))" JSON_ARR_LEN "$arr" ''
done
for ((i=0; i<50; i++)); do check "PUSH50/value-$i" 0 "$i" JSON_GET "$arr" "$i"; done
check 'DEL/array first' 0 '[2,3]' JSON_DEL '[1,2,3]' 0
check 'DEL/array middle' 0 '[1,3]' JSON_DEL '[1,2,3]' 1
check 'DEL/array last' 0 '[1,2]' JSON_DEL '[1,2,3]' 2
capture JSON_ARR_PUSH '{"a":[]}' a '{"id":7}' raw
check 'PUSH/nested raw object' 0 7 JSON_GET "$actual" 'a[0].id'
capture JSON_SET '{}' 'a"b' $'quote" slash\\ line\n' ''
check 'SET/escaped key and value' 0 $'quote" slash\\ line\n' JSON_GET "$actual" 'a"b'

make_deep() {
    deep=7 deep_path=''
    local j
    for ((j=0; j<$1; j++)); do deep='{"a":'"$deep"'}'; deep_path+='.a'; done
    deep_path=${deep_path#.}
}
for depth in 16 32; do
    make_deep "$depth"
    check "deep$depth/GET" 0 7 JSON_GET "$deep" "$deep_path"
    capture JSON_SET "$deep" "$deep_path" 8 ''
    check "deep$depth/SET" 0 8 JSON_GET "$actual" "$deep_path"
    capture JSON_SET '{}' "$deep_path" 9 ''
    check "deep$depth/create" 0 9 JSON_GET "$actual" "$deep_path"
    capture JSON_DEL "$deep" "$deep_path"
    check "deep$depth/DEL" reject '' JSON_HAS "$actual" "$deep_path"
done

printf '\n=== Benchmarks: three measured rounds after one warmup ===\n'
# Synthetic, sanitized eportal-shaped data based on the existing test fixture.
# Exact byte sizes; repeated session records rather than one giant padding string.
make_payload() {
    local target=$1 record prefix suffix padding
    record='{"userName":"2024081063","nodeIp":"10.23.64.230","nodeMac":"CCD8437E154C","active":true,"score":98.5}'
    prefix='{"code":0,"msg":"success","data":{"onlineUser":'"$record"',"sessions":['
    suffix='],"padding":""}}'
    payload=$prefix$record
    while (( ${#payload}+${#record}+1+${#suffix} <= target )); do payload+=,$record; done
    printf -v padding '%*s' "$((target-${#payload}-${#suffix}))" ''
    payload+='],"padding":"'"$padding"'"}}'
}

clock() { local t=$EPOCHREALTIME; now=${t/./}; }
workload() {
    local mode=$1 n=$2 document=$3 path=$4 j result=$3 scan_end scan_type
    for ((j=0; j<n; j++)); do
        case $mode in
            get) JSON_GET "$document" "$path" >/dev/null || return 1 ;;
            set) result=$(JSON_SET "$result" "$path" "$j" '') || return 1 ;;
            push) result=$(JSON_ARR_PUSH "$result" "$j") || return 1 ;;
            scan) _JSON_SCAN_VALUE "$document" 0 scan_end scan_type || return 1 ;;
            walk) JSON_KEYS "$document" "$path" >/dev/null || return 1 ;;
        esac
    done
    case $mode in
        set) [[ $(JSON_GET "$result" "$path") == "$((n-1))" ]] ;;
        push) [[ $(JSON_ARR_LEN "$result" '') == "$n" ]] ;;
        scan) [[ $scan_end == "${#document}" && $scan_type == object ]] ;;
        *) return 0 ;;
    esac
}

bench() {
    local label=$1 mode=$2 n=$3 document=$4 path=$5 round start elapsed a b c median rc
    workload "$mode" 1 "$document" "$path" || { printf 'BENCH ERROR warmup %s\n' "$label"; ((failed+=1)); return; }
    for round in 1 2 3; do
        clock; start=$now
        workload "$mode" "$n" "$document" "$path"; rc=$?
        clock; elapsed=$((now-start))
        printf 'BENCH %s round=%d n=%d bytes=%d total_us=%d us/op=%d rc=%d\n' \
            "$label" "$round" "$n" "${#document}" "$elapsed" "$((elapsed/n))" "$rc"
        ((rc != 0)) && ((failed+=1))
        case $round in 1) a=$elapsed ;; 2) b=$elapsed ;; 3) c=$elapsed ;; esac
    done
    if ((a>b)); then median=$a; a=$b; b=$median; fi
    if ((b>c)); then b=$c; fi
    if ((a>b)); then b=$a; fi
    median=$b
    printf 'MEDIAN %s total_us=%d us/op=%d input_KiB/s=%d\n' "$label" "$median" "$((median/n))" "$(( ${#document}*n*1000000/(1024*(median+1)) ))"
}

memory_snapshot() {
    local key value
    if [[ -r /proc/$$/status ]]; then
        while IFS=: read -r key value; do
            case $key in VmRSS|VmHWM) printf 'MEMORY parent %s:%s\n' "$key" "$value" ;; esac
        done < /proc/$$/status
    else
        printf 'MEMORY /proc unavailable; no portable pure-Bash RSS counter.\n'
    fi
}
memory_snapshot
for size in 512 5120; do
    make_payload "$size"
    check "fixture/size-$size" 0 "$size" printf '%s' "${#payload}"
    check "fixture/eportal-$size" 0 2024081063 JSON_GET "$payload" data.onlineUser.userName
    bench "GET-$size" get 100 "$payload" data.onlineUser.userName
    bench "SET-$size" set 50 "$payload" data.onlineUser.score
    bench "SCAN-$size" scan 100 "$payload" ''
    bench "WALK-sessions-$size" walk 100 "$payload" data.sessions
done
bench PUSH50 push 50 '[]' ''
for depth in 1 16 32; do
    make_deep "$depth"
    bench "DEEP-GET-$depth" get 100 "$deep" "$deep_path"
done
memory_snapshot
printf 'NOTE SCAN is boundary scanning, WALK enumerates sessions; neither is full RFC validation.\n'
printf 'NOTE GET redirects stdout; SET/PUSH include capture and final verification. No timing thresholds.\n'
printf 'NOTE parent RSS/HWM excludes child peaks; byte throughput counts input once, not repeated scans.\n'
printf 'SUMMARY passed=%d failed=%d skipped=%d total=%d\n' "$passed" "$failed" "$skipped" "$((passed+failed+skipped))"
((failed == 0))
