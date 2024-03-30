#!/usr/bin/env python3

# 将DSXTP转发过来的数据转发到HTTP代理服务器

##############################################

import os
import sys

current_dir = os.path.abspath(os.path.dirname(__file__))
lib_dir = os.path.join(current_dir, "../../base")

if lib_dir not in sys.path:
    sys.path.append(lib_dir)

import log

##############################################

# env
# export proxy_host="127.0.0.1"
# export proxy_port=15777
# export listen_host="127.0.0.1"
# export listen_port=15777

##############################################

import socket
import threading
import ssl
import struct
import selectors
import datetime
import signal
import time

proxy_host = os.environ.get("proxy_host")
proxy_port = int(os.environ.get("proxy_port"))

listen_host = os.environ.get("listen_host")
listen_port = int(os.environ.get("listen_port"))

connection_counter = 0
heartbeat_time = 0

logger = log.Logger("dsxhf")


def print_log(message: str = ""):
    logger.log(f"{message}")
    print_state()


def print_state():
    logger.state(f"连接数: {connection_counter}; 距离上次心跳时间: {heartbeat_time}")


def heartbeat_timer():
    global heartbeat_time
    while True:
        heartbeat_time += 1
        print_state()
        time.sleep(1)


def get_tls_len(block: bytes):
    tls_len = struct.unpack("!H", block[3:5])[0] + 5
    return tls_len


def get_tls_host(data: bytes):
    record_type = data[0]
    version = data[1:3]
    tls_body_len = struct.unpack("!H", data[3:5])[0]
    handshake_type = data[5]
    handshake_body_len = struct.unpack("!L", b"\x00" + data[6:9])[0]
    protocol_version = struct.unpack("!H", data[9:11])[0]
    random_number = data[11:43]
    session_id_len = data[43]
    session_id = data[44 : 44 + session_id_len]
    cipher_suites_len = struct.unpack(
        "!H", data[44 + session_id_len : 44 + session_id_len + 2]
    )[0]
    cipher_suites = data[
        44 + session_id_len + 2 : 44 + session_id_len + cipher_suites_len + 4
    ]
    extensions_len = struct.unpack(
        "!H",
        data[
            44
            + session_id_len
            + cipher_suites_len
            + 4 : 44
            + session_id_len
            + cipher_suites_len
            + 6
        ],
    )[0]

    extensions_start = 44 + session_id_len + cipher_suites_len + 6
    while extensions_start < len(data):
        extension_type = struct.unpack(
            "!H", data[extensions_start : extensions_start + 2]
        )[0]
        extension_len = struct.unpack(
            "!H", data[extensions_start + 2 : extensions_start + 4]
        )[0]
        if extension_type == 0x00:
            extension_body = data[
                extensions_start + 4 : extensions_start + 4 + extension_len
            ]
            return extension_body[5:].decode()
        extensions_start += 4 + extension_len


def ascii_art():
    print_log("")
    print_log("")
    print_log("▓█████▄   ██████ ▒██   ██▒ ██░ ██   █████▒")
    print_log("▒██▀ ██▌▒██    ▒ ▒▒ █ █ ▒░▓██░ ██▒▓██   ▒ ")
    print_log("░██   █▌░ ▓██▄   ░░  █   ░▒██▀▀██░▒████ ░ ")
    print_log("░▓█▄   ▌  ▒   ██▒ ░ █ █ ▒ ░▓█ ░██ ░▓█▒  ░ ")
    print_log("░▒████▓ ▒██████▒▒▒██▒ ▒██▒░▓█▒░██▓░▒█░    ")
    print_log("▒▒▓  ▒ ▒ ▒▓▒ ▒ ░▒▒ ░ ░▓ ░ ▒ ░░▒░▒ ▒ ░     ")
    print_log("░ ▒  ▒ ░ ░▒  ░ ░░░   ░▒ ░ ▒ ░▒░ ░ ░       ")
    print_log("░ ░  ░ ░  ░  ░   ░    ░   ░  ░░ ░ ░ ░     ")
    print_log("░          ░   ░    ░   ░  ░  ░           ")
    print_log("░                                         ")
    print_log("")


def handler(client_socket: socket.socket, client_addr: str):
    global connection_counter
    global heartbeat_time
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as proxy_socket:
        client_socket.settimeout(5)
        proxy_socket.settimeout(5)
        proxy_socket.connect((proxy_host, proxy_port))

        selector = selectors.DefaultSelector()
        selector.register(client_socket, selectors.EVENT_READ)
        selector.register(proxy_socket, selectors.EVENT_READ)

        try:
            client_buffer = client_socket.recv(1024)

            if client_buffer:
                if client_buffer == b"\n\n":  # \n\n是nc命令发送的字串
                    client_socket.sendall(b"Hello DSXTP.")
                    heartbeat_time = 0
                elif client_buffer.startswith(b"\x16\x03"):
                    while get_tls_len(client_buffer) > len(client_buffer):
                        client_buffer += client_socket.recv(1024)
                    host = get_tls_host(client_buffer)
                    port = 443
                    if not host:
                        raise socket.timeout
                    print_log(f"HTTPS Host: {host}")
                    connect_request = f"CONNECT {host}:{port} HTTP/1.1\r\nHost: {host}\r\nProxy-Connection: Keep-Alive\r\n\r\n"
                    proxy_socket.sendall(connect_request.encode())
                    while True:
                        data = proxy_socket.recv(1024)
                        if not data:
                            break
                        if data.endswith(b"\r\n\r\n"):
                            break
                else:
                    for line in client_buffer.split(b"\r\n"):
                        if line.startswith(b"Host:"):
                            print_log(f"HTTP  Host: {line[6:].decode()}")
                            break

                # Client Hello
                proxy_socket.sendall(client_buffer)

                while len(selector.get_map()) == 2:
                    events = selector.select(timeout=5)
                    if not events:
                        break
                    for key, mask in events:
                        if key.fileobj is client_socket:
                            data = client_socket.recv(1024)
                            if not data:
                                selector.unregister(client_socket)
                                break
                            proxy_socket.sendall(data)
                        elif key.fileobj is proxy_socket:
                            data = proxy_socket.recv(1024)
                            if not data:
                                selector.unregister(proxy_socket)
                                break
                            client_socket.sendall(data)
                        else:
                            raise Exception("Unknown socket")
        except socket.timeout:
            pass
    client_socket.close()
    connection_counter -= 1


def start_listening():
    global connection_counter

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((listen_host, listen_port))

        s.listen(100)
        while True:
            client_handler = threading.Thread(target=handler, args=(s.accept()))
            client_handler.daemon = True
            connection_counter += 1
            client_handler.start()


def on_exit():
    print_log("停止...")
    print_log()
    exit(0)


signal.signal(signal.SIGINT, lambda signum, frame: on_exit())
signal.signal(signal.SIGTERM, lambda signum, frame: on_exit())

if __name__ == "__main__":
    try:
        print_log()
        print_log(f"本地监听地址:     {listen_host}:{listen_port}")
        print_log(f"代理服务器地址:   {proxy_host}:{proxy_port}")
        ascii_art()
        print_log("初始化...")
        timer = threading.Thread(target=heartbeat_timer)
        timer.daemon = True
        timer.start()
        print_log("开始监听...")
        start_listening()
    except KeyboardInterrupt:
        on_exit()
