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

import threading
import struct
import signal
import time
import asyncio
import resource

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


class TLSClientHello:
    def __init__(self, data: bytes):
        self.data = data
        self.record_type = data[0]
        self.version = data[1:3]
        self.tls_body_len = struct.unpack("!H", data[3:5])[0]
        self.handshake_type = data[5]
        self.handshake_body_len = struct.unpack("!L", b"\x00" + data[6:9])[0]
        self.protocol_version = struct.unpack("!H", data[9:11])[0]
        self.random_number = data[11:43]
        self.session_id_len = data[43]
        self.session_id = data[44 : 44 + self.session_id_len]
        self.cipher_suites_len = struct.unpack(
            "!H", data[44 + self.session_id_len : 44 + self.session_id_len + 2]
        )[0]
        self.cipher_suites = data[
            44
            + self.session_id_len
            + 2 : 44
            + self.session_id_len
            + self.cipher_suites_len
            + 4
        ]
        self.extensions_len = struct.unpack(
            "!H",
            data[
                44
                + self.session_id_len
                + self.cipher_suites_len
                + 4 : 44
                + self.session_id_len
                + self.cipher_suites_len
                + 6
            ],
        )[0]
        extensions_start = 44 + self.session_id_len + self.cipher_suites_len + 6
        self.extensions = []
        while extensions_start < len(data):
            extension_type = struct.unpack(
                "!H", data[extensions_start : extensions_start + 2]
            )[0]
            extension_len = struct.unpack(
                "!H", data[extensions_start + 2 : extensions_start + 4]
            )[0]
            self.extensions.append(
                {
                    "type": extension_type,
                    "len": extension_len,
                    "data": data[
                        extensions_start + 4 : extensions_start + 4 + extension_len
                    ],
                }
            )
            extensions_start += 4 + extension_len

    def get_host(self):
        for extension in self.extensions:
            if extension["type"] == 0x00:
                return extension["data"][5:].decode()
        return ""

    def get_len(self):
        return self.tls_body_len + 5


async def send(writer: asyncio.StreamWriter, data: bytes):
    writer.write(data)
    await writer.drain()


async def close(writer: asyncio.StreamWriter):
    writer.close()
    await writer.wait_closed()


async def relay(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    try:
        while True:
            data = await reader.read(1024)
            if not data:
                break
            await send(writer, data)
    except Exception:
        pass
    finally:
        await close(writer)


async def establishProxyConnection(
    proxy_reader: asyncio.StreamReader,
    proxy_writer: asyncio.StreamWriter,
    host: str,
    port: int,
):
    connect_request = f"CONNECT {host}:{port} HTTP/1.1\r\nHost: {host}:{port}\r\nProxy-Connection: Keep-Alive\r\n\r\n"
    await send(proxy_writer, connect_request.encode())
    while True:
        data = await proxy_reader.read(1024)
        if not data:
            break
        if data.endswith(b"\r\n\r\n"):
            break


async def handle_client(
    client_reader: asyncio.StreamReader, client_writer: asyncio.StreamWriter
):
    global connection_counter
    global heartbeat_time

    try:
        client_buffer = await client_reader.read(1024)

        if client_buffer:
            if client_buffer == b"\n\n":  # \n\n是nc命令发送的字串
                await send(client_writer, b"Hello DSXTP.")
                heartbeat_time = 0
            else:
                connection_counter += 1
                try:
                    proxy_reader, proxy_writer = await asyncio.open_connection(
                        proxy_host, proxy_port
                    )
                    if client_buffer.startswith(b"\x16\x03"):
                        tls_client_hello = TLSClientHello(client_buffer)
                        while tls_client_hello.get_len() > len(client_buffer):
                            client_buffer += await client_reader.read(1024)
                        host = tls_client_hello.get_host()
                        port = 443
                        if not host:
                            return
                        print_log(f"HTTPS Host: {host}")
                        await establishProxyConnection(
                            proxy_reader, proxy_writer, host, port
                        )

                    else:
                        host = None
                        port = 443
                        isTunnelRequest = False
                        for line in client_buffer.split(b"\r\n"):
                            if line.startswith(b"Host:"):
                                host = line[6:].decode().split(":")[0]
                                print_log(f"HTTP  Host: {host}")
                                break
                            elif line.startswith(b"Proxy-Connection:"):
                                isTunnelRequest = True
                        if not isTunnelRequest:
                            if not host:
                                return
                            await establishProxyConnection(
                                proxy_reader, proxy_writer, host, port
                            )

                    # Client Hello
                    await send(proxy_writer, client_buffer)

                    done, pending = await asyncio.wait(
                        [
                            asyncio.create_task(relay(client_reader, proxy_writer)),
                            asyncio.create_task(relay(proxy_reader, client_writer)),
                        ],
                        return_when=asyncio.FIRST_COMPLETED,
                    )
                finally:
                    await close(proxy_writer)
                    connection_counter -= 1
    finally:
        await close(client_writer)


async def start_listening():
    global connection_counter

    server = await asyncio.start_server(handle_client, listen_host, listen_port)
    async with server:
        await server.serve_forever()


def ascii_art():
    print_log()
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
    print_log()


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
        resource.setrlimit(resource.RLIMIT_NOFILE, (65535, 65535))
        timer = threading.Thread(target=heartbeat_timer)
        timer.daemon = True
        timer.start()
        print_log("开始监听...")
        asyncio.run(start_listening())
    except KeyboardInterrupt:
        on_exit()
