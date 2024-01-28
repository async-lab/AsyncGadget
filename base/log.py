import os
import threading
import datetime
import subprocess


class Logger:
    def __init__(self, name: str):
        self.log_file_path = f"/var/log/{name}.log"
        self.log_lock = threading.Lock()
        self.state_lock = threading.Lock()
        self.limit = 1000

        if "INVOCATION_ID" in os.environ:
            self.env = "systemd"
        else:
            self.env = "console"

    def fresh_line(self):
        print("\r\033[K", end="", flush=True)

    def stdout(self, message: str = "", end: str = "\n", flush: bool = True):
        if self.env == "console":
            self.fresh_line()

        print(message, end=end, flush=flush)

    def stdfile(self, message: str = "", end: str = "\n", flush: bool = True):
        if os.path.splitext(self.log_file_path)[1].lower() != ".log":
            raise Exception("File extension name must be .log")

        if (
            os.path.exists(self.log_file_path)
            and os.path.getsize(self.log_file_path) > 0
        ):
            line_count = int(
                subprocess.getoutput(f"wc -l {self.log_file_path}").split()[0]
            )
            if line_count > self.limit - 1:
                os.system(f"sed -i '1,{line_count - self.limit}d' {self.log_file_path}")

            with open(self.log_file_path, "rb+") as f:
                f.seek(-1, 2)
                while f.tell() > 0 and f.read(1) != b"\n":
                    f.seek(-2, 1)
                f.truncate()

        with open(self.log_file_path, "a") as f:
            f.write(message + end)
            f.flush()

    def log(self, message: str = ""):
        if self.env == "console":
            with self.log_lock:
                now_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                self.stdout(f"[{now_time}] {message}")
        elif self.env == "systemd":
            with self.log_lock:
                now_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                self.stdout(f"{message}")
                self.stdfile(f"[{now_time}] {message}")

    def state(self, state: str = ""):
        if self.env == "console":
            with self.state_lock:
                self.stdout(f"[ 状态 ] {state}", end="")
        elif self.env == "systemd":
            with self.state_lock:
                self.stdfile(f"[ 状态 ] {state}", end="")
