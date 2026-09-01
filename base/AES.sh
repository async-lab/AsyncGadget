#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# 纯 Bash 实现 AES-128-ECB 与 Base64 编解码

AES_SBOX=(
  0x63 0x7c 0x77 0x7b 0xf2 0x6b 0x6f 0xc5 0x30 0x01 0x67 0x2b 0xfe 0xd7 0xab 0x76
  0xca 0x82 0xc9 0x7d 0xfa 0x59 0x47 0xf0 0xad 0xd4 0xa2 0xaf 0x9c 0xa4 0x72 0xc0
  0xb7 0xfd 0x93 0x26 0x36 0x3f 0xf7 0xcc 0x34 0xa5 0xe5 0xf1 0x71 0xd8 0x31 0x15
  0x04 0xc7 0x23 0xc3 0x18 0x96 0x05 0x9a 0x07 0x12 0x80 0xe2 0xeb 0x27 0xb2 0x75
  0x09 0x83 0x2c 0x1a 0x1b 0x6e 0x5a 0xa0 0x52 0x3b 0xd6 0xb3 0x29 0xe3 0x2f 0x84
  0x53 0xd1 0x00 0xed 0x20 0xfc 0xb1 0x5b 0x6a 0xcb 0xbe 0x39 0x4a 0x4c 0x58 0xcf
  0xd0 0xef 0xaa 0xfb 0x43 0x4d 0x33 0x85 0x45 0xf9 0x02 0x7f 0x50 0x3c 0x9f 0xa8
  0x51 0xa3 0x40 0x8f 0x92 0x9d 0x38 0xf5 0xbc 0xb6 0xda 0x21 0x10 0xff 0xf3 0xd2
  0xcd 0x0c 0x13 0xec 0x5f 0x97 0x44 0x17 0xc4 0xa7 0x7e 0x3d 0x64 0x5d 0x19 0x73
  0x60 0x81 0x4f 0xdc 0x22 0x2a 0x90 0x88 0x46 0xee 0xb8 0x14 0xde 0x5e 0x0b 0xdb
  0xe0 0x32 0x3a 0x0a 0x49 0x06 0x24 0x5c 0xc2 0xd3 0xac 0x62 0x91 0x95 0xe4 0x79
  0xe7 0xc8 0x37 0x6d 0x8d 0xd5 0x4e 0xa9 0x6c 0x56 0xf4 0xea 0x65 0x7a 0xae 0x08
  0xba 0x78 0x25 0x2e 0x1c 0xa6 0xb4 0xc6 0xe8 0xdd 0x74 0x1f 0x4b 0xbd 0x8b 0x8a
  0x70 0x3e 0xb5 0x66 0x48 0x03 0xf6 0x0e 0x61 0x35 0x57 0xb9 0x86 0xc1 0x1d 0x9e
  0xe1 0xf8 0x98 0x11 0x69 0xd9 0x8e 0x94 0x9b 0x1e 0x87 0xe9 0xce 0x55 0x28 0xdf
  0x8c 0xa1 0x89 0x0d 0xbf 0xe6 0x42 0x68 0x41 0x99 0x2d 0x0f 0xb0 0x54 0xbb 0x16
)

AES_RCON=(0 0x01 0x02 0x04 0x08 0x10 0x20 0x40 0x80 0x1b 0x36)

# 预计算 xtime 表 (256 元素)
AES_XTIME=()
for ((_i=0; _i<256; _i++)); do
  if (( (_i & 0x80) != 0 )); then
    AES_XTIME[_i]=$(( ((_i << 1) & 0xff) ^ 0x1b ))
  else
    AES_XTIME[_i]=$(( (_i << 1) & 0xff ))
  fi
done

AES_B64_CHARS="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
AES_B64_DEC_LUT=()
for ((_i=0; _i<128; _i++)); do AES_B64_DEC_LUT[_i]=0; done
for ((_i=0; _i<64; _i++)); do
  LC_CTYPE=C printf -v _ascii '%d' "'${AES_B64_CHARS:_i:1}"
  AES_B64_DEC_LUT[_ascii]=$_i
done

function AES_B64_DECODE() {
  local str="$1"
  local -n _out_ref="$2"
  _out_ref=()

  local len=${#str}
  local i=0 c1 c2 c3 c4 a1 a2 a3 a4

  for ((i=0; i<len; i+=4)); do
    LC_CTYPE=C printf -v a1 '%d' "'${str:i:1}"
    LC_CTYPE=C printf -v a2 '%d' "'${str:i+1:1}"
    c1=${AES_B64_DEC_LUT[a1]:-0}
    c2=${AES_B64_DEC_LUT[a2]:-0}

    _out_ref+=( $(( ((c1 << 2) | (c2 >> 4)) & 0xff )) )

    if [ "${str:i+2:1}" != "=" ] && [ $((i + 2)) -lt $len ]; then
      LC_CTYPE=C printf -v a3 '%d' "'${str:i+2:1}"
      c3=${AES_B64_DEC_LUT[a3]:-0}
      _out_ref+=( $(( ((c2 << 4) | (c3 >> 2)) & 0xff )) )
    fi

    if [ "${str:i+3:1}" != "=" ] && [ $((i + 3)) -lt $len ]; then
      LC_CTYPE=C printf -v a4 '%d' "'${str:i+3:1}"
      c4=${AES_B64_DEC_LUT[a4]:-0}
      _out_ref+=( $(( ((c3 << 6) | c4) & 0xff )) )
    fi
  done
}

function AES_B64_ENCODE() {
  local -n _in_ref="$1"
  local len=${#_in_ref[@]}
  local out=""
  local i=0 b1 b2 b3 n

  for ((i=0; i<len; i+=3)); do
    b1=${_in_ref[i]}
    b2=${_in_ref[i+1]:-0}
    b3=${_in_ref[i+2]:-0}
    n=$(( (b1 << 16) | (b2 << 8) | b3 ))

    out+="${AES_B64_CHARS:$(( (n >> 18) & 0x3f )):1}"
    out+="${AES_B64_CHARS:$(( (n >> 12) & 0x3f )):1}"

    if [ $((i + 1)) -lt $len ]; then
      out+="${AES_B64_CHARS:$(( (n >> 6) & 0x3f )):1}"
    else
      out+="="
    fi

    if [ $((i + 2)) -lt $len ]; then
      out+="${AES_B64_CHARS:$(( n & 0x3f )):1}"
    else
      out+="="
    fi
  done
  echo "$out"
}

function AES_EXPAND_KEY() {
  local -n _k_in="$1"
  local -n _w_out="$2"
  _w_out=()

  local i temp0 temp1 temp2 temp3 t
  for ((i=0; i<16; i++)); do
    _w_out[i]=${_k_in[i]}
  done

  for ((i=4; i<44; i++)); do
    temp0=${_w_out[$(( (i - 1) * 4 + 0 ))]}
    temp1=${_w_out[$(( (i - 1) * 4 + 1 ))]}
    temp2=${_w_out[$(( (i - 1) * 4 + 2 ))]}
    temp3=${_w_out[$(( (i - 1) * 4 + 3 ))]}

    if (( i % 4 == 0 )); then
      t=$temp0
      temp0=${AES_SBOX[$temp1]}
      temp1=${AES_SBOX[$temp2]}
      temp2=${AES_SBOX[$temp3]}
      temp3=${AES_SBOX[$t]}
      temp0=$(( temp0 ^ AES_RCON[i / 4] ))
    fi

    _w_out[$(( i * 4 + 0 ))]=$(( _w_out[$(( (i - 4) * 4 + 0 ))] ^ temp0 ))
    _w_out[$(( i * 4 + 1 ))]=$(( _w_out[$(( (i - 4) * 4 + 1 ))] ^ temp1 ))
    _w_out[$(( i * 4 + 2 ))]=$(( _w_out[$(( (i - 4) * 4 + 2 ))] ^ temp2 ))
    _w_out[$(( i * 4 + 3 ))]=$(( _w_out[$(( (i - 4) * 4 + 3 ))] ^ temp3 ))
  done
}

function AES_ENCRYPT_16B() {
  local -n _b_in="$1"
  local -n _rk="$2"
  local -n _res_out="$3"

  local s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 sa sb sc sd se sf
  s0=$(( _b_in[0] ^ _rk[0] ))
  s1=$(( _b_in[1] ^ _rk[1] ))
  s2=$(( _b_in[2] ^ _rk[2] ))
  s3=$(( _b_in[3] ^ _rk[3] ))
  s4=$(( _b_in[4] ^ _rk[4] ))
  s5=$(( _b_in[5] ^ _rk[5] ))
  s6=$(( _b_in[6] ^ _rk[6] ))
  s7=$(( _b_in[7] ^ _rk[7] ))
  s8=$(( _b_in[8] ^ _rk[8] ))
  s9=$(( _b_in[9] ^ _rk[9] ))
  sa=$(( _b_in[10] ^ _rk[10] ))
  sb=$(( _b_in[11] ^ _rk[11] ))
  sc=$(( _b_in[12] ^ _rk[12] ))
  sd=$(( _b_in[13] ^ _rk[13] ))
  se=$(( _b_in[14] ^ _rk[14] ))
  sf=$(( _b_in[15] ^ _rk[15] ))

  local round k_idx a0 a1 a2 a3 t
  local n0 n1 n2 n3 n4 n5 n6 n7 n8 n9 na nb nc nd ne nf

  for ((round=1; round<=9; round++)); do
    s0=${AES_SBOX[s0]}; s1=${AES_SBOX[s1]}; s2=${AES_SBOX[s2]}; s3=${AES_SBOX[s3]}
    s4=${AES_SBOX[s4]}; s5=${AES_SBOX[s5]}; s6=${AES_SBOX[s6]}; s7=${AES_SBOX[s7]}
    s8=${AES_SBOX[s8]}; s9=${AES_SBOX[s9]}; sa=${AES_SBOX[sa]}; sb=${AES_SBOX[sb]}
    sc=${AES_SBOX[sc]}; sd=${AES_SBOX[sd]}; se=${AES_SBOX[se]}; sf=${AES_SBOX[sf]}

    k_idx=$(( round * 16 ))

    a0=$s0; a1=$s5; a2=$sa; a3=$sf
    t=$(( a0 ^ a1 ^ a2 ^ a3 ))
    n0=$(( a0 ^ t ^ AES_XTIME[a0 ^ a1] ^ _rk[k_idx + 0] ))
    n1=$(( a1 ^ t ^ AES_XTIME[a1 ^ a2] ^ _rk[k_idx + 1] ))
    n2=$(( a2 ^ t ^ AES_XTIME[a2 ^ a3] ^ _rk[k_idx + 2] ))
    n3=$(( a3 ^ t ^ AES_XTIME[a3 ^ a0] ^ _rk[k_idx + 3] ))

    a0=$s4; a1=$s9; a2=$se; a3=$s3
    t=$(( a0 ^ a1 ^ a2 ^ a3 ))
    n4=$(( a0 ^ t ^ AES_XTIME[a0 ^ a1] ^ _rk[k_idx + 4] ))
    n5=$(( a1 ^ t ^ AES_XTIME[a1 ^ a2] ^ _rk[k_idx + 5] ))
    n6=$(( a2 ^ t ^ AES_XTIME[a2 ^ a3] ^ _rk[k_idx + 6] ))
    n7=$(( a3 ^ t ^ AES_XTIME[a3 ^ a0] ^ _rk[k_idx + 7] ))

    a0=$s8; a1=$sd; a2=$s2; a3=$s7
    t=$(( a0 ^ a1 ^ a2 ^ a3 ))
    n8=$(( a0 ^ t ^ AES_XTIME[a0 ^ a1] ^ _rk[k_idx + 8] ))
    n9=$(( a1 ^ t ^ AES_XTIME[a1 ^ a2] ^ _rk[k_idx + 9] ))
    na=$(( a2 ^ t ^ AES_XTIME[a2 ^ a3] ^ _rk[k_idx + 10] ))
    nb=$(( a3 ^ t ^ AES_XTIME[a3 ^ a0] ^ _rk[k_idx + 11] ))

    a0=$sc; a1=$s1; a2=$s6; a3=$sb
    t=$(( a0 ^ a1 ^ a2 ^ a3 ))
    nc=$(( a0 ^ t ^ AES_XTIME[a0 ^ a1] ^ _rk[k_idx + 12] ))
    nd=$(( a1 ^ t ^ AES_XTIME[a1 ^ a2] ^ _rk[k_idx + 13] ))
    ne=$(( a2 ^ t ^ AES_XTIME[a2 ^ a3] ^ _rk[k_idx + 14] ))
    nf=$(( a3 ^ t ^ AES_XTIME[a3 ^ a0] ^ _rk[k_idx + 15] ))

    s0=$n0; s1=$n1; s2=$n2; s3=$n3
    s4=$n4; s5=$n5; s6=$n6; s7=$n7
    s8=$n8; s9=$n9; sa=$na; sb=$nb
    sc=$nc; sd=$nd; se=$ne; sf=$nf
  done

  # 第 10 轮
  s0=${AES_SBOX[s0]}; s1=${AES_SBOX[s1]}; s2=${AES_SBOX[s2]}; s3=${AES_SBOX[s3]}
  s4=${AES_SBOX[s4]}; s5=${AES_SBOX[s5]}; s6=${AES_SBOX[s6]}; s7=${AES_SBOX[s7]}
  s8=${AES_SBOX[s8]}; s9=${AES_SBOX[s9]}; sa=${AES_SBOX[sa]}; sb=${AES_SBOX[sb]}
  sc=${AES_SBOX[sc]}; sd=${AES_SBOX[sd]}; se=${AES_SBOX[se]}; sf=${AES_SBOX[sf]}

  _res_out+=(
    $(( s0 ^ _rk[160] )) $(( s5 ^ _rk[161] )) $(( sa ^ _rk[162] )) $(( sf ^ _rk[163] ))
    $(( s4 ^ _rk[164] )) $(( s9 ^ _rk[165] )) $(( se ^ _rk[166] )) $(( s3 ^ _rk[167] ))
    $(( s8 ^ _rk[168] )) $(( sd ^ _rk[169] )) $(( s2 ^ _rk[170] )) $(( s7 ^ _rk[171] ))
    $(( sc ^ _rk[172] )) $(( s1 ^ _rk[173] )) $(( s6 ^ _rk[174] )) $(( sb ^ _rk[175] ))
  )
}

function AES_128_ECB_ENCRYPT() {
  local key_b64="$1"
  local text="$2"

  local key_bytes=()
  AES_B64_DECODE "$key_b64" key_bytes

  local rk=()
  AES_EXPAND_KEY key_bytes rk

  local text_len=${#text}
  local pad=$(( 16 - (text_len % 16) ))
  local plain_bytes=()
  local i c

  for ((i=0; i<text_len; i++)); do
    LC_CTYPE=C printf -v c '%d' "'${text:i:1}"
    plain_bytes+=( "$c" )
  done
  for ((i=0; i<pad; i++)); do
    plain_bytes+=( "$pad" )
  done

  local total_len=${#plain_bytes[@]}
  local cipher_bytes=()
  local blk=()

  for ((i=0; i<total_len; i+=16)); do
    blk=( "${plain_bytes[@]:i:16}" )
    AES_ENCRYPT_16B blk rk cipher_bytes
  done

  AES_B64_ENCODE cipher_bytes
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  AES_128_ECB_ENCRYPT "$1" "$2"
fi
