"""teams-config.py: wiring Teams for Linux to the bridge and undoing it, without touching anything else."""
import json, os, subprocess, sys, tempfile, unittest

from _bridge_helpers import ROOT

HELPER = os.path.join(ROOT, "scripts", "teams-config.py")


class TeamsConfig(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.cfg = os.path.join(self.dir, "config.json")

    def cli(self, *args, env=None, check=True):
        return subprocess.run([sys.executable, HELPER, *args], capture_output=True, text=True, check=check, env=env).stdout.strip()

    def read(self):
        return json.load(open(self.cfg))

    def test_fresh_file_connect_creates_only_managed_keys(self):
        self.assertEqual(self.cli("status", "--config", self.cfg), "disconnected")
        self.assertEqual(self.cli("connect", "--config", self.cfg), "", "no backup when there was nothing to back up")
        cfg = self.read()
        self.assertEqual(set(cfg), {"mqtt", "graphApi"}, "meetingStartDetection lives under mqtt, where Teams for Linux reads it")
        self.assertEqual({k: v for k, v in cfg["mqtt"].items() if k != "meetingStartDetection"},
                         {"enabled": True, "brokerUrl": "mqtt://127.0.0.1:1883", "topicPrefix": "teams", "commandTopic": "command"})
        self.assertTrue(cfg["mqtt"]["meetingStartDetection"]["enabled"])
        self.assertIn("meeting started", cfg["mqtt"]["meetingStartDetection"]["patterns"])
        self.assertEqual(cfg["graphApi"], {"enabled": True})
        self.assertEqual(self.cli("status", "--config", self.cfg), "connected")

    def test_connect_keeps_unrelated_keys_and_backs_up(self):
        json.dump({"mqtt": {"username": "u", "enabled": False, "meetingStartDetection": {"patterns": ["mine"], "resetSeconds": 20}}, "closeAppOnCross": True}, open(self.cfg, "w"))
        backup = self.cli("connect", "--config", self.cfg, "--port", "1999", "--prefix", "tfl")
        self.assertTrue(os.path.exists(backup) and backup.startswith(self.cfg + ".bak-"))
        cfg = self.read()
        msd = cfg["mqtt"].pop("meetingStartDetection")
        self.assertEqual(cfg["mqtt"], {"username": "u", "enabled": True, "brokerUrl": "mqtt://127.0.0.1:1999", "topicPrefix": "tfl", "commandTopic": "command"})
        self.assertEqual((msd["enabled"], msd["resetSeconds"], msd["patterns"][0]), (True, 20, "mine"), "user's own pattern and resetSeconds survive")
        self.assertTrue(cfg["closeAppOnCross"])

    def test_status_checks_port_and_prefix(self):
        self.cli("connect", "--config", self.cfg, "--port", "1999")
        self.assertEqual(self.cli("status", "--config", self.cfg, "--port", "1999"), "connected")
        self.assertEqual(self.cli("status", "--config", self.cfg), "disconnected", "different port means not wired to this bridge")
        self.assertEqual(self.cli("status", "--config", self.cfg, "--port", "1999", "--prefix", "x"), "disconnected")

    def test_connect_is_idempotent(self):
        self.cli("connect", "--config", self.cfg)
        first = self.read()
        self.cli("connect", "--config", self.cfg)
        self.assertEqual(self.read(), first, "no duplicated patterns on a second Connect")

    def test_legacy_top_level_detection_block_is_moved(self):
        json.dump({"meetingStartDetection": {"enabled": True}}, open(self.cfg, "w"))
        self.cli("connect", "--config", self.cfg)
        self.assertNotIn("meetingStartDetection", self.read())
        self.cli("disconnect", "--config", self.cfg)
        self.assertEqual(self.read(), {})

    def test_disconnect_keeps_users_own_patterns(self):
        json.dump({"mqtt": {"meetingStartDetection": {"patterns": ["mine"]}}}, open(self.cfg, "w"))
        self.cli("connect", "--config", self.cfg)
        self.cli("disconnect", "--config", self.cfg)
        self.assertEqual(self.read(), {"mqtt": {"meetingStartDetection": {"patterns": ["mine"]}}})

    def test_disconnect_round_trips(self):
        original = {"mqtt": {"username": "u"}, "closeAppOnCross": True}
        json.dump(original, open(self.cfg, "w"))
        self.cli("connect", "--config", self.cfg)
        self.cli("disconnect", "--config", self.cfg)
        self.assertEqual(self.read(), original)
        self.assertEqual(self.cli("status", "--config", self.cfg), "disconnected")

    def test_disconnect_removes_empty_sections_and_tolerates_missing(self):
        self.cli("connect", "--config", self.cfg)
        self.cli("disconnect", "--config", self.cfg)
        self.assertEqual(self.read(), {})
        self.cli("disconnect", "--config", self.cfg)  # idempotent
        self.assertEqual(self.read(), {})

    def test_non_object_sections_are_replaced_not_crashed(self):
        json.dump({"mqtt": "broken"}, open(self.cfg, "w"))
        self.cli("connect", "--config", self.cfg)
        self.assertTrue(self.read()["mqtt"]["enabled"])

    def test_default_path_detects_flatpak_and_snap(self):
        home = tempfile.mkdtemp()
        env = {**os.environ, "HOME": home}
        flat = os.path.join(home, ".var/app/com.github.IsmaelMartinez.teams_for_linux/config/teams-for-linux/config.json")
        os.makedirs(os.path.dirname(flat)); json.dump({}, open(flat, "w"))
        self.cli("connect", env=env)
        self.assertTrue(json.load(open(flat))["mqtt"]["enabled"], "existing Flatpak config is used")
        self.assertFalse(os.path.exists(os.path.join(home, ".config/teams-for-linux/config.json")))

    def test_default_path_falls_back_to_vanilla(self):
        home = tempfile.mkdtemp()
        self.cli("connect", env={**os.environ, "HOME": home})
        self.assertTrue(os.path.exists(os.path.join(home, ".config/teams-for-linux/config.json")))

    def test_invalid_json_fails_loudly(self):
        open(self.cfg, "w").write("{oops")
        r = subprocess.run([sys.executable, HELPER, "connect", "--config", self.cfg], capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(open(self.cfg).read(), "{oops", "a broken config is never overwritten")


if __name__ == "__main__":
    unittest.main()
