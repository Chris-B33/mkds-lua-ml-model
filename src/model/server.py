import socket

from src.model import config as C

class Server:
    def __init__(self, host, port) -> None:
        self.buffer = ""

        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.bind((host, port))
        self.server.listen(1)
        print(f"Listening on {host}:{port}...")

    def accept_connection(self) -> None:
        self.conn, self.addr = self.server.accept()
        print("Connected by", self.addr)

    def send_action(self, action_idx) -> None:
        controls = {"A": 0, "B": 0, "Left": 0, "Right": 0}
        controls.update(list(C.ACTIONS.values())[action_idx])

        payload = ";".join(f"{k}={v}" for k, v in controls.items())
        message = f"{len(payload)} {payload}"
        self.conn.sendall(message.encode("utf-8"))

    def read_stats(self) -> dict:
        try:
            self.buffer += self.conn.recv(1024).decode("utf-8")
        except socket.timeout:
            return None

        if "\n" not in self.buffer:
            return None

        line, self.buffer = self.buffer.split("\n", 1)
        parts = line.split(" ", 1)
        if len(parts) == 2:
            line = parts[1]
        else:
            line = parts[0]

        stats = {}
        for pair in line.split(";"):
            if "=" in pair:
                k, v = pair.split("=", 1)
                
                if v.isdigit():
                    stats[k] = int(v)
                else:
                    try:
                        stats[k] = float(v)
                    except ValueError:
                        stats[k] = v

        return stats