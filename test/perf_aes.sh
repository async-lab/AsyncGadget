#!/usr/bin/env bash
# Adversarial AES-128-ECB tests. Requires Bash >=5, OpenSSL, od, tr, locale.
# Run: wsl bash /mnt/f/Asynclab/AsyncGadget/test/perf_aes.sh
# Exit 0: all assertions passed; 1: failures; 2: harness/dependency failure.
# Finite exhaustive domains are labeled; this is not an exhaustive AES proof.
set -o pipefail
export LC_ALL=C
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)" || exit 2
(( BASH_VERSINFO[0] >= 5 )) || { echo 'Bash >=5 required' >&2; exit 2; }
for tool in openssl od tr locale; do
    command -v "$tool" >/dev/null || { echo "Missing: $tool" >&2; exit 2; }
done
source "$BASE_DIR/base/AES.sh" || exit 2
PASSED=0 FAILED=0
KEY_HEX=2b7e151628aed2a6abf7158809cf4f3c
KEY_B64=K34VFiiu0qar9xWICc9PPA==

ASSERT_EQ() {
    if [[ $2 == "$3" ]]; then
        printf 'PASS %s\n' "$1"
        ((PASSED+=1))
    else
        printf 'FAIL %s expected=%q actual=%q\n' "$1" "$3" "$2"
        ((FAILED+=1))
    fi
    return 0
}

# Never store binary output in a Bash string: NUL bytes are not representable.
EMIT_HEX() {
    local hx=$1 esc='' p
    for ((p=0; p<${#hx}; p+=2)); do esc+="\\x${hx:p:2}"; done
    printf '%b' "$esc"
}
HEX_ARRAY() {
    local hx=$1 p
    local -n target=$2
    target=()
    for ((p=0; p<${#hx}; p+=2)); do target+=( "$((16#${hx:p:2}))" ); done
}
ORACLE() {
    openssl enc -aes-128-ecb -nosalt -K "$KEY_HEX" "$@" -a -A
}
CHECK_TEXT() {
    local label=$1 payload=$2 expected actual rc
    expected=$(printf '%s' "$payload" | ORACLE) || exit 2
    actual=$(AES_128_ECB_ENCRYPT "$KEY_B64" "$payload"); rc=$?
    ASSERT_EQ "$label status" "$rc" 0
    ASSERT_EQ "$label OpenSSL" "$actual" "$expected"
}
REJECT_B64() {
    local label=$1 encoded=$2 rc
    local -a decoded=(91 92 93)
    AES_B64_DECODE "$encoded" decoded; rc=$?
    ASSERT_EQ "$label rejection status" "$rc" 1
    ASSERT_EQ "$label atomic failure" "${decoded[*]}" '91 92 93'
}

printf 'ENV Bash=%s OS=%s locale=%s\n' "$BASH_VERSION" "$OSTYPE" "$LC_ALL"
openssl version || exit 2
printf '\n=== NIST SP 800-38A F.1.1: raw multi-block ECB ===\n'
NIST_PT=6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710
NIST_CT=3ad77bb40d7a3660a89ecaf32466ef97
NIST_CT+=f5d3d58503b9699de785895a96fdbaaf
NIST_CT+=43b1cd7f598ece23881b00e3ed030688
NIST_CT+=7b0c785e27e8ad3f8223207104725dd4
HEX_ARRAY "$KEY_HEX" key_data
AES_EXPAND_KEY key_data round_keys
ASSERT_EQ 'AES-128 expanded key byte count' "${#round_keys[@]}" 176
for blocks in 1 2 3 4; do
    cipher=()
    for ((block=0; block<blocks; block++)); do
        HEX_ARRAY "${NIST_PT:block*32:32}" plain_block
        AES_ENCRYPT_16B plain_block round_keys cipher
    done
    printf -v actual_hex '%02x' "${cipher[@]}"
    ASSERT_EQ "NIST $blocks blocks published ciphertext" "$actual_hex" "${NIST_CT:0:blocks*32}"
    reference=$(EMIT_HEX "${NIST_PT:0:blocks*32}" | ORACLE -nopad) || exit 2
    actual=$(AES_B64_ENCODE cipher) || exit 2
    ASSERT_EQ "NIST $blocks blocks OpenSSL -nopad" "$actual" "$reference"
    # This NIST plaintext contains no NUL: exercise the public padding API too.
    payload=$(EMIT_HEX "${NIST_PT:0:blocks*32}")
    CHECK_TEXT "NIST $blocks blocks padded API" "$payload"
done

printf '\n=== Length sweep and decrypted PKCS#7 bytes ===\n'
for ((size=0; size<=80; size++)); do
    printf -v payload '%*s' "$size" ''; payload=${payload// /x}
    CHECK_TEXT "ASCII length=$size" "$payload"
    actual=$(AES_128_ECB_ENCRYPT "$KEY_B64" "$payload") || exit 2
    AES_B64_DECODE "$actual" cipher || exit 2
    pad=$((16-size%16))
    ASSERT_EQ "length=$size ciphertext size" "${#cipher[@]}" "$((size+pad))"
    decrypted=$(printf '%s' "$actual" | openssl enc -d -aes-128-ecb -nosalt \
        -K "$KEY_HEX" -a -A -nopad | od -An -v -tx1 | tr -d ' \n') || exit 2
    printf -v expected '%*s' "$size" ''; expected=${expected// /78}
    printf -v pad_hex '%02x' "$pad"
    for ((n=0; n<pad; n++)); do expected+=$pad_hex; done
    ASSERT_EQ "length=$size exact decrypted padding (pad=$pad)" "$decrypted" "$expected"
done
CHECK_TEXT 'embedded and trailing CR/LF/tab' $'a\r\nb\t\n\n'
CHECK_TEXT 'shell metacharacters are literal' '$(false); `false` * ? [x] " '\'' \\ %s'
payload=''
for ((byte=1; byte<256; byte++)); do
    printf -v oct '%03o' "$byte"; printf -v char '%b' "\\$oct"; payload+=$char
done
CHECK_TEXT 'every non-NUL byte including invalid UTF-8' "$payload"

printf '\n=== UTF-8 straddling boundaries under C and UTF-8 locales ===\n'
utf_locale=''
while IFS= read -r candidate; do
    if [[ ${candidate,,} == *utf* ]]; then utf_locale=$candidate; break; fi
done < <(locale -a)
[[ -n $utf_locale ]] || { echo 'No UTF-8 locale available' >&2; exit 2; }
for test_locale in C "$utf_locale"; do
    for symbol in $'\xf0\x9f\x98\x80' $'\xe4\xb8\xad' $'\xe3\x81\x82' $'\xe2\x82\xac' $'e\xcc\x81' $'\xf0\x9f\x91\xa9\xe2\x80\x8d\xf0\x9f\x92\xbb'; do
        for ((prefix=12; prefix<=17; prefix++)); do
            printf -v payload '%*s' "$prefix" ''; payload=${payload// /a}
            payload+="$symbol/$symbol"
            LC_ALL=$test_locale CHECK_TEXT "UTF8 locale=$test_locale prefix=$prefix symbol=$symbol" "$payload"
        done
    done
done

printf '\n=== Base64 valid data, all byte values and invalid grammar ===\n'
valid=('' Zg== Zm8= Zm9v Zm9vYg== Zm9vYmE= Zm9vYmFy)
decoded_hex=('' 66 666f 666f6f 666f6f62 666f6f6261 666f6f626172)
for ((n=0; n<${#valid[@]}; n++)); do
    decoded=(99)
    AES_B64_DECODE "${valid[n]}" decoded; rc=$?
    actual_hex=''; if ((${#decoded[@]})); then printf -v actual_hex '%02x' "${decoded[@]}"; fi
    ASSERT_EQ "RFC4648 vector=$n status" "$rc" 0
    ASSERT_EQ "RFC4648 vector=$n bytes" "$actual_hex" "${decoded_hex[n]}"
    actual=$(AES_B64_ENCODE decoded)
    ASSERT_EQ "RFC4648 vector=$n encode" "$actual" "${valid[n]}"
done
all_bytes=()
for ((byte=0; byte<256; byte++)); do all_bytes+=("$byte"); done
for size in 1 2 3 16 64 255 256; do
    sample=("${all_bytes[@]:0:size}")
    printf -v sample_hex '%02x' "${sample[@]}"
    reference=$(EMIT_HEX "$sample_hex" | openssl base64 -A) || exit 2
    actual=$(AES_B64_ENCODE sample)
    ASSERT_EQ "binary Base64 length=$size OpenSSL" "$actual" "$reference"
    AES_B64_DECODE "$actual" decoded; rc=$?
    ASSERT_EQ "binary Base64 length=$size decode status" "$rc" 0
    ASSERT_EQ "binary Base64 length=$size roundtrip" "${decoded[*]}" "${sample[*]}"
done
invalid=('Z' 'Zg' 'Zg=' 'Zg===' 'Zg======' '=' '====' 'A===' '=AAA' 'A=AA'
    'AA=A' 'Zg==AAAA' 'Zm8=AAAA' 'AAAA====' '!!!!' '____' '----' 'Zh==' 'Zm9='
    ' Zg==' 'Zg== ' $'Z g=' $'Z\tg=' $'Z\ng=' $'Z\rg=' $'Zg==\n'
    $'\xc3\xa9AA' $'AA\xc3\xa9' $'\xf0\x9f\x98\x80' $'\xe4\xb8\xadA' 'AAAAAA!A')
for ((n=0; n<${#invalid[@]}; n++)); do REJECT_B64 "malformed case=$n" "${invalid[n]}"; done
# Exhaustive non-alphabet non-NUL bytes in every quartet position.
for ((byte=1; byte<256; byte++)); do
    printf -v oct '%03o' "$byte"; printf -v char '%b' "\\$oct"
    [[ $char == [A-Za-z0-9+/=] ]] && continue
    for ((pos=0; pos<4; pos++)); do
        REJECT_B64 "invalid byte=$byte position=$pos" "${valid[3]:0:pos}$char${valid[3]:pos+1}"
    done
done
# Exhaustive 15 bad low-four-bit and 3 bad low-two-bit padding alternatives.
for ((n=1; n<16; n++)); do REJECT_B64 "nonzero four padding bits=$n" "A${AES_B64_CHARS:n:1}=="; done
for ((n=1; n<4; n++)); do REJECT_B64 "nonzero two padding bits=$n" "AA${AES_B64_CHARS:n:1}="; done

printf '\n=== Key validation and invocation contract ===\n'
bad_keys=('' c2hvcnQ= AAAAAAAAAAAAAAAAAAAA AAAAAAAAAAAAAAAAAAAAAAA=
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA AAAAAAAAAAAAAAAAAAAAAQ= AAAAAAAAAAAAAAAAAAAAAR==
    'AAAAAAAAAAAAAAAAAAAA!A==' $'AAAAAAAAAAAAAAAAAAAA\xc3\xa9==' "$KEY_B64 ")
for ((n=0; n<${#bad_keys[@]}; n++)); do
    actual=$(AES_128_ECB_ENCRYPT "${bad_keys[n]}" text 2>/dev/null); rc=$?
    ASSERT_EQ "invalid key=$n status" "$rc" 1
    ASSERT_EQ "invalid key=$n no ciphertext" "$actual" ''
done
for argc in 0 1 3; do
    args=(); ((argc>=1)) && args+=("$KEY_B64"); ((argc==3)) && args+=(text extra)
    actual=$(AES_128_ECB_ENCRYPT "${args[@]}" 2>/dev/null); rc=$?
    ASSERT_EQ "argc=$argc status" "$rc" 1
    ASSERT_EQ "argc=$argc no ciphertext" "$actual" ''
done
reference=$(printf '%s' smoke | ORACLE) || exit 2
actual=$(bash "$BASE_DIR/base/AES.sh" "$KEY_B64" smoke); rc=$?
ASSERT_EQ 'standalone CLI status' "$rc" 0
ASSERT_EQ 'standalone CLI ciphertext' "$actual" "$reference"
actual=$(bash -eu -c 'source "$1"; AES_128_ECB_ENCRYPT "$2" smoke' bash "$BASE_DIR/base/AES.sh" "$KEY_B64"); rc=$?
ASSERT_EQ 'caller errexit/nounset status' "$rc" 0
ASSERT_EQ 'caller errexit/nounset ciphertext' "$actual" "$reference"

printf '\n=== Deterministic differential raw-block corpus (binary keys/plaintexts) ===\n'
# Fixed LCG seed makes failures reproducible; includes NUL through array API.
seed=1234567
for ((trial=0; trial<64; trial++)); do
    key_data=() plain_block=() cipher=()
    for ((n=0; n<32; n++)); do
        seed=$(((1664525*seed+1013904223)&0xffffffff))
        byte=$(((seed>>16)&255))
        if ((n<16)); then key_data+=("$byte"); else plain_block+=("$byte"); fi
    done
    if ((trial==0)); then key_data=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0); plain_block=("${key_data[@]}"); fi
    if ((trial==1)); then key_data=(255 255 255 255 255 255 255 255 255 255 255 255 255 255 255 255); plain_block=("${key_data[@]}"); fi
    printf -v KEY_HEX '%02x' "${key_data[@]}"
    printf -v plain_hex '%02x' "${plain_block[@]}"
    AES_EXPAND_KEY key_data round_keys
    AES_ENCRYPT_16B plain_block round_keys cipher
    actual=$(AES_B64_ENCODE cipher)
    reference=$(EMIT_HEX "$plain_hex" | ORACLE -nopad) || exit 2
    ASSERT_EQ "binary differential trial=$trial" "$actual" "$reference"
done
KEY_HEX=2b7e151628aed2a6abf7158809cf4f3c

printf '\n=== Observable API/security limitations (not correctness failures) ===\n'
payload=$'A\0B'
ASSERT_EQ 'Bash strings stop at NUL: binary plaintext cannot enter string API' "${#payload}" 1
actual=$(AES_128_ECB_ENCRYPT "$KEY_B64" '0123456789abcdef0123456789abcdef') || exit 2
AES_B64_DECODE "$actual" cipher || exit 2
ASSERT_EQ 'ECB exposes repeated plaintext blocks' "${cipher[*]:0:16}" "${cipher[*]:16:16}"
printf 'NOTE ECB is deterministic and unauthenticated; no timing-resistance claim.\n'

# EPOCHREALTIME is Bash builtin: no external process in any measured region.
# Five samples of three operations; report median, min, max. Warm up first.
BENCH() {
    local label=$1 bytes=$2 blocks=$3; shift 3
    local sample rep start finish elapsed tmp a b median
    local -a times=()
    "$@" >/dev/null || exit 2
    for ((sample=0; sample<5; sample++)); do
        start=${EPOCHREALTIME/./}
        for ((rep=0; rep<3; rep++)); do "$@" >/dev/null || exit 2; done
        finish=${EPOCHREALTIME/./}; elapsed=$((finish-start))
        ((elapsed>0)) || { echo 'Clock resolution insufficient' >&2; exit 2; }
        times+=("$elapsed")
    done
    for ((a=0; a<5; a++)); do
        for ((b=a+1; b<5; b++)); do
            if ((times[b]<times[a])); then tmp=${times[a]}; times[a]=${times[b]}; times[b]=$tmp; fi
        done
    done
    median=${times[2]}
    printf 'BENCH %-22s bytes=%4d blocks=%2d median_us/op=%8d min=%8d max=%8d bytes/s=%8d us/block=%8d\n' \
        "$label" "$bytes" "$blocks" "$((median/3))" "$((times[0]/3))" "$((times[4]/3))" \
        "$((bytes*3000000/median))" "$((median/(3*blocks)))"
}
BENCH_RAW() { local -a bench_cipher=(); AES_ENCRYPT_16B plain_block round_keys bench_cipher; }
BENCH_CONVERT() {
    local LC_ALL=C bc bv
    local -a converted=()
    for ((bc=0; bc<${#payload}; bc++)); do printf -v bv '%d' "'${payload:bc:1}"; converted+=("$bv"); done
}
printf '\n=== Benchmarks: warm, median of 5 x 3 ops; payload bytes/s; padded block count ===\n'
HEX_ARRAY "$KEY_HEX" key_data
AES_EXPAND_KEY key_data round_keys
HEX_ARRAY "${NIST_PT:0:32}" plain_block
BENCH key-expansion 16 1 AES_EXPAND_KEY key_data round_keys
BENCH raw-cached-key-block 16 1 BENCH_RAW
for size in 16 64 256 1024; do
    printf -v payload '%*s' "$size" ''; payload=${payload// /x}
    CHECK_TEXT "benchmark payload=$size" "$payload"
    BENCH encrypt-end-to-end "$size" "$((size/16+1))" AES_128_ECB_ENCRYPT "$KEY_B64" "$payload"
    BENCH string-to-bytes "$size" "$((size/16))" BENCH_CONVERT
    actual=$(AES_128_ECB_ENCRYPT "$KEY_B64" "$payload") || exit 2
    AES_B64_DECODE "$actual" cipher || exit 2
    BENCH base64-encode "${#cipher[@]}" "$((size/16+1))" AES_B64_ENCODE cipher
    BENCH base64-decode "${#cipher[@]}" "$((size/16+1))" AES_B64_DECODE "$actual" decoded
done
printf '\nSUMMARY passed=%d failed=%d total=%d\n' "$PASSED" "$FAILED" "$((PASSED+FAILED))"
((FAILED==0))
