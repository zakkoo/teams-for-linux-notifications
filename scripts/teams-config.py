#!/usr/bin/env python3
"""Wire Teams for Linux to the plugin's broker, or undo it.
usage: teams-config.py connect|disconnect|status [--port 1883] [--prefix teams] [--config PATH]
status prints "connected" or "disconnected"; connect/disconnect print the backup path (if any) and exit 0."""
import argparse, json, os, sys, time

DEFAULT = os.path.expanduser("~/.config/teams-for-linux/config.json")


def managed(port, prefix):
    return {
        "mqtt": {"enabled": True, "brokerUrl": f"mqtt://127.0.0.1:{port}", "topicPrefix": prefix, "commandTopic": "command"},
        "graphApi": {"enabled": True},
        "meetingStartDetection": {"enabled": True},
    }


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save(path, cfg):
    backup = ""
    if os.path.exists(path):
        backup = f"{path}.bak-{time.strftime('%Y%m%d-%H%M%S')}"
        os.replace(path, backup)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    return backup


def is_connected(cfg, port, prefix):
    want = managed(port, prefix)
    return all(isinstance(cfg.get(k), dict) and all(cfg[k].get(kk) == vv for kk, vv in v.items()) for k, v in want.items())


def connect(cfg, port, prefix):
    for k, v in managed(port, prefix).items():
        cfg[k] = {**(cfg.get(k) if isinstance(cfg.get(k), dict) else {}), **v}
    return cfg


def disconnect(cfg, port, prefix):
    for k, v in managed(port, prefix).items():
        section = cfg.get(k)
        if not isinstance(section, dict):
            continue
        for kk in v:
            section.pop(kk, None)
        if not section:
            cfg.pop(k)
    return cfg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["connect", "disconnect", "status"])
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--prefix", default="teams")
    ap.add_argument("--config", default=DEFAULT)
    a = ap.parse_args()
    cfg = load(a.config)
    if a.action == "status":
        print("connected" if is_connected(cfg, a.port, a.prefix) else "disconnected")
        return
    cfg = (connect if a.action == "connect" else disconnect)(cfg, a.port, a.prefix)
    print(save(a.config, cfg))


if __name__ == "__main__":
    main()
