"""Static checks across manifest and QML: what `omarchy plugin validate` enforces, plus the contracts between our own files."""
import json, os, re, unittest

from _bridge_helpers import ROOT

M = json.load(open(os.path.join(ROOT, "manifest.json")))
read = lambda *p: open(os.path.join(ROOT, *p)).read()
SCHEMA = {e["key"]: e for e in M["barWidget"]["schema"]}


class Manifest(unittest.TestCase):
    def test_required_fields_and_id_rules(self):
        self.assertEqual(M["schemaVersion"], 1)
        for f in ("id", "name", "version", "author", "description", "license", "homepage", "kinds", "entryPoints"):
            self.assertIn(f, M)
        self.assertRegex(M["id"], r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
        self.assertNotIn("..", M["id"])
        self.assertFalse(M["id"].startswith("omarchy."))
        self.assertRegex(M["version"], r"^\d+\.\d+\.\d+$")

    def test_every_kind_has_an_existing_entry_point(self):
        needed = {"bar-widget": "barWidget", "service": "service", "panel": "panel", "menu": "menu", "overlay": "overlay", "bar": "bar"}
        for kind in M["kinds"]:
            ep = M["entryPoints"][needed[kind]]
            self.assertFalse(ep.startswith("/") or ".." in ep, ep)
            self.assertTrue(os.path.isfile(os.path.join(ROOT, ep)), ep)

    def test_default_section_valid(self):
        self.assertIn(M["barWidget"]["defaultSection"], ("left", "center", "right"))

    def test_schema_and_defaults_agree(self):
        defaults = M["barWidget"]["defaults"]
        self.assertEqual(set(SCHEMA), set(defaults))
        for k, e in SCHEMA.items():
            self.assertEqual(e["defaultValue"], defaults[k], k)
            self.assertTrue(e["label"] and e.get("description"), f"{k} needs a label and a description for the settings form")
            if e["type"] == "enum":
                self.assertIn(e["defaultValue"], e["options"], k)
            elif e["type"] == "integer":
                self.assertLessEqual(e["min"], e["defaultValue"]); self.assertLessEqual(e["defaultValue"], e["max"])
            elif e["type"] == "boolean":
                self.assertIsInstance(e["defaultValue"], bool)

    def test_marketplace_files_present(self):
        for f in ("README.md", "LICENSE", "CHANGELOG.md", "preview.png"):
            self.assertTrue(os.path.isfile(os.path.join(ROOT, f)), f)
        self.assertIn(M["version"], read("CHANGELOG.md"))

    def test_no_symlinks(self):
        for d, dirs, files in os.walk(ROOT):
            dirs[:] = [x for x in dirs if x != ".git"]
            for n in dirs + files:
                self.assertFalse(os.path.islink(os.path.join(d, n)), os.path.join(d, n))


class QmlContracts(unittest.TestCase):
    bw, panel, svc = read("BarWidget.qml"), read("Panel.qml"), read("Service.qml")

    def test_module_ids_match_manifest(self):
        for src in (self.bw, self.panel):
            self.assertIn(f'moduleName: "{M["id"]}"', src)
        self.assertIn(f'ipcTarget: "{M["id"]}"', self.panel)

    def test_every_setting_read_in_qml_is_declared(self):
        for key in set(re.findall(r'setting\("(\w+)"', self.bw + self.panel)):
            self.assertIn(key, SCHEMA, key)

    def test_every_schema_key_is_used_somewhere(self):
        for key in SCHEMA:
            self.assertRegex(self.bw + self.panel, rf'setting\("{key}"', f"{key} declared but never read")

    def test_widget_pushes_bridge_settings_the_service_declares(self):
        pushed = dict(re.findall(r'svc\.(\w+) = (?:String\()?setting\("(\w+)"', self.bw))
        for prop, key in pushed.items():
            self.assertEqual(prop, key)
            self.assertRegex(self.svc, rf'(?m)^\s+property \w+ {prop}:', f"Service lacks property {prop}")
        for prop in ("horizonMinutes", "leadMinutes", "toast", "pollMinutes", "mqttPort", "mqttPrefix"):
            self.assertIn(prop, pushed, f"{prop} must reach the service")

    def test_service_passes_bridge_arguments_the_script_accepts(self):
        for flag in ("--port", "--prefix", "--poll-minutes"):
            self.assertIn(f'"{flag}"', self.svc)
            self.assertIn(f'"{flag}"', read("scripts", "bridge.py"))
        for action in ("status", "connect", "disconnect"):
            self.assertIn(f'"{action}"', read("scripts", "teams-config.py"))
        self.assertIn('"status"', self.svc)
        self.assertRegex(self.panel, r'"connect"|"disconnect"')

    def test_referenced_files_exist(self):
        for src in (self.bw, self.panel, self.svc):
            for ref in re.findall(r'(?:Qt\.resolvedUrl|import)\s*\(?\s*"([^"]+\.(?:qml|js))"', src):
                self.assertTrue(os.path.isfile(os.path.join(ROOT, ref)), ref)
        for script in ("bridge.py", "teams-config.py"):
            self.assertTrue(os.path.isfile(os.path.join(ROOT, "scripts", script)))
        self.assertIn("ServiceRegistry.qml", read("qmldir"))

    def test_service_registers_singleton_and_cleans_up(self):
        self.assertIn("Plugin.ServiceRegistry.instance = root", self.svc)
        self.assertIn("Plugin.ServiceRegistry.instance = null", self.svc)
        self.assertIn("bridge.running = false", self.svc, "the bridge must die with the service")

    def test_widget_exposes_what_the_bar_needs(self):
        for name in ("opened", "popoutSwitchClosing", "tooltipHovered"):
            self.assertRegex(self.bw, rf'property bool {name}\b', name)
        for fn in ("open", "close", "closeForPopoutSwitch"):
            self.assertIn(f"function {fn}()", self.bw)

    def test_braces_balanced(self):
        for name in ("BarWidget.qml", "Panel.qml", "Service.qml", "ServiceRegistry.qml", "Model.js"):
            src = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*', "", read(name))
            self.assertEqual(src.count("{"), src.count("}"), name)
            self.assertEqual(src.count("("), src.count(")"), name)


if __name__ == "__main__":
    unittest.main()
