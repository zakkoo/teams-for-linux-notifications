"""Shared helpers: load the scripts as modules and speak raw MQTT to the bridge over a socketpair."""
import importlib.machinery, importlib.util, json, os, socket, threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_script(name):
    path = os.path.join(ROOT, "scripts", name + ".py")
    spec = importlib.util.spec_from_loader(name, importlib.machinery.SourceFileLoader(name, path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class FakeTeams:
    """One MQTT client talking to a bridge.Client served on a background thread."""

    def __init__(self, bridge, v5=False):
        self.b, self.v5 = bridge, v5
        self.sock, server_side = socket.socketpair()
        self.sock.settimeout(3)
        self.client = bridge.Client(server_side)
        bridge.client = self.client
        self.thread = threading.Thread(target=self._serve, daemon=True)
        self.thread.start()

    def _serve(self):
        try:
            self.client.serve()
        except OSError:
            pass
        finally:
            self.client.sock.close()

    @property
    def props(self):
        return b"\x00" if self.v5 else b""

    def send(self, type_flags, body):
        self.sock.sendall(bytes([type_flags]) + self.b.varint(len(body)) + body)

    def read(self):
        tp, fl, body = self.b.read_packet(self.sock)
        return tp, body

    def connect(self, client_id="teams-for-linux", flags=0x02, extra=b""):
        self.send(0x10, self.b.mkstr("MQTT") + bytes([5 if self.v5 else 4, flags]) + b"\x00\x3c" + self.props + self.b.mkstr(client_id) + extra)
        return self.read()

    def subscribe(self, *topics, pid=1):
        body = pid.to_bytes(2, "big") + self.props
        for t in topics:
            body += self.b.mkstr(t) + b"\x00"
        self.send(0x82, body)
        return self.read()

    def publish(self, topic, payload, qos=0, pid=7):
        body = self.b.mkstr(topic)
        if qos:
            body += pid.to_bytes(2, "big")
        body += self.props + (payload if isinstance(payload, bytes) else payload.encode())
        self.send(0x30 | (qos << 1), body)

    def read_publish(self):
        tp, body = self.read()
        assert tp == 3, tp
        topic, i = self.b.rdstr(body, 0)
        return topic, json.loads(body[i + len(self.props):])

    def ping(self):
        self.send(0xC0, b"")
        return self.read()

    def disconnect(self):
        self.send(0xE0, b"")
        self.thread.join(3)
