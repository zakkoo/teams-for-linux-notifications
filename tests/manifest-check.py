#!/usr/bin/env python3
"""python3 tests/manifest-check.py — the checks `omarchy plugin validate` runs, plus plugin-specific ones, without Omarchy installed."""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
m = json.load(open(os.path.join(ROOT, "manifest.json")))

assert m["schemaVersion"] == 1
for f in ("id", "name", "version", "kinds", "entryPoints"):
    assert f in m, f"missing {f}"
assert re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", m["id"]) and ".." not in m["id"] and not m["id"].startswith("omarchy."), m["id"]
assert re.fullmatch(r"\d+\.\d+\.\d+", m["version"]), m["version"]
assert isinstance(m["kinds"], list) and m["kinds"]
for kind, ep in {"bar-widget": "barWidget", "service": "service", "panel": "panel", "menu": "menu", "overlay": "overlay", "bar": "bar"}.items():
    if kind in m["kinds"]:
        assert ep in m["entryPoints"], f"kind {kind} needs entryPoints.{ep}"
for ep in m["entryPoints"].values():
    assert not ep.startswith("/") and ".." not in ep and os.path.isfile(os.path.join(ROOT, ep)), ep
assert m["barWidget"]["defaultSection"] in ("left", "center", "right")

# Every schema entry has a default, every default is in the schema, enum defaults are valid options.
schema = {e["key"]: e for e in m["barWidget"]["schema"]}
defaults = m["barWidget"]["defaults"]
assert set(schema) == set(defaults), set(schema) ^ set(defaults)
for k, e in schema.items():
    assert e["defaultValue"] == defaults[k], k
    if e["type"] == "enum":
        assert e["defaultValue"] in e["options"], k
    if e["type"] == "integer":
        assert e["min"] <= e["defaultValue"] <= e["max"], k

# Settings the QML reads must be declared.
qml = "".join(open(os.path.join(ROOT, f)).read() for f in ("BarWidget.qml", "Panel.qml"))
for key in set(re.findall(r'setting\("(\w+)"', qml)):
    assert key in schema, f"{key} read in QML but not in manifest schema"

# No symlinks anywhere outside .git; the installer refuses them.
for d, dirs, files in os.walk(ROOT):
    dirs[:] = [x for x in dirs if x != ".git"]
    for n in dirs + files:
        assert not os.path.islink(os.path.join(d, n)), os.path.join(d, n)

# CHANGELOG mentions the manifest version.
assert m["version"] in open(os.path.join(ROOT, "CHANGELOG.md")).read(), "CHANGELOG.md lacks the current version"
print("manifest-check ok")
