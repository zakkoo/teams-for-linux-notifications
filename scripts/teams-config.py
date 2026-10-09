#!/usr/bin/env python3
"""Wire Teams for Linux to the plugin's broker, or undo it.
usage: teams-config.py connect|disconnect|status [--port 1883] [--prefix teams] [--config PATH]
status prints "connected" or "disconnected"; connect/disconnect print the backup path (if any) and exit 0."""
import argparse, json, os, sys, time

CANDIDATES = [  # vanilla, Flatpak, Snap — first existing wins, vanilla when none exists yet
    "~/.config/teams-for-linux/config.json",
    "~/.var/app/com.github.IsmaelMartinez.teams_for_linux/config/teams-for-linux/config.json",
    "~/snap/teams-for-linux/current/.config/teams-for-linux/config.json",
]
DEFAULT = next((p for p in map(os.path.expanduser, CANDIDATES) if os.path.exists(p)), os.path.expanduser(CANDIDATES[0]))

# Fallback patterns for Teams' "meeting started" toast, per UI language. Teams for Linux lowercases the
# toast text and compiles these as case-insensitive regexes; its primary detection path is locale-independent.
PATTERNS = {
    "en": ["meeting started", "started the meeting"],
    "de": ["besprechung gestartet", "hat die besprechung gestartet"],
    "es": [r"reuni[óo]n (ha )?(iniciad|comenzad)", r"(ha )?(iniciado|comenzado|inici[óo]|comenz[óo]) la reuni[óo]n"],
    "fr": [r"r[ée]union a (d[ée]marr[ée]|commenc[ée])", r"a (d[ée]marr[ée]|commenc[ée]) la r[ée]union"],
    "pt": [r"reuni[ãa]o (foi )?(iniciada|come[çc]ou)", r"(iniciou|come[çc]ou) a reuni[ãa]o"],
}
ALL_PATTERNS = [p for lang in PATTERNS.values() for p in lang]


def managed(port, prefix):
    return {
        "mqtt": {
            "enabled": True, "brokerUrl": f"mqtt://127.0.0.1:{port}", "topicPrefix": prefix, "commandTopic": "command",
            "meetingStartDetection": {"enabled": True, "patterns": ALL_PATTERNS},
        },
        "graphApi": {"enabled": True},
    }


def load(path):
    try:
        with open(path) as f:
            cfg = json.load(f)
    except FileNotFoundError:
        return {}
    return cfg if isinstance(cfg, dict) else {}  # a non-object root is replaced (the backup keeps it)


def save(path, cfg):
    backup = ""
    mode = 0o600  # the config may hold inline credentials: private unless the user chose otherwise
    if os.path.exists(path):
        mode = os.stat(path).st_mode & 0o777
        backup = f"{path}.bak-{time.strftime('%Y%m%d-%H%M%S')}"
        os.replace(path, backup)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode), "w") as f:  # created with its mode, never briefly wider
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return backup


def _matches(have, want):
    if isinstance(want, dict):
        return isinstance(have, dict) and all(_matches(have.get(k), v) for k, v in want.items())
    if isinstance(want, list):
        return isinstance(have, list) and all(p in have for p in want)
    return have == want


def is_connected(cfg, port, prefix):
    return _matches(cfg, managed(port, prefix))


def _merge(into, want):
    for k, v in want.items():
        if isinstance(v, dict):
            into[k] = _merge(into[k] if isinstance(into.get(k), dict) else {}, v)
        elif isinstance(v, list):  # keep the user's own patterns, add ours once
            into[k] = [p for p in (into.get(k) if isinstance(into.get(k), list) else []) if p not in v] + v
        else:
            into[k] = v
    return into


def _strip(from_, want):
    for k, v in want.items():
        if k not in from_:
            continue
        if isinstance(v, dict) and isinstance(from_[k], dict):
            _strip(from_[k], v)
            if not from_[k]:
                del from_[k]
        elif isinstance(v, list) and isinstance(from_[k], list):
            from_[k] = [p for p in from_[k] if p not in v]
            if not from_[k]:
                del from_[k]
        else:
            del from_[k]
    return from_


def connect(cfg, port, prefix):
    if cfg.get("meetingStartDetection") == {"enabled": True}:  # the proof of concept wrote it at the wrong level
        del cfg["meetingStartDetection"]
    return _merge(cfg, managed(port, prefix))


def disconnect(cfg, port, prefix):
    return _strip(cfg, managed(port, prefix))


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
