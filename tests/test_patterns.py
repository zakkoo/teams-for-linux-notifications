"""The fallback toast patterns: each language matches its real Teams wording and nothing else obviously wrong."""
import re, unittest

from _bridge_helpers import load_script

tc = load_script("teams-config")

# Toast text as Teams shows it (lowercased by Teams for Linux before matching), per UI language.
TOASTS = {
    "en": ["Meeting started", "Anna Example started the meeting"],
    "de": ["Besprechung gestartet", "Anna Example hat die Besprechung gestartet"],
    "es": ["Reunión iniciada", "Anna Example ha iniciado la reunión", "Anna Example inició la reunión", "La reunión ha comenzado"],
    "fr": ["La réunion a commencé", "Anna Example a démarré la réunion", "Une réunion a commencé"],
    "pt": ["Reunião iniciada", "Anna Example iniciou a reunião", "A reunião começou", "Nova reunião começou"],
}
NOT_A_START = ["Anna Example joined the meeting", "Meeting ended", "Besprechung beendet", "Reunión finalizada",
               "La réunion est terminée", "Reunião encerrada", "Meeting starts in 5 minutes"]


def matches(text):
    return any(re.search(p, text.lower()) for p in tc.ALL_PATTERNS)


class Patterns(unittest.TestCase):
    def test_every_pattern_compiles(self):
        for p in tc.ALL_PATTERNS:
            re.compile(p)

    def test_each_language_toast_is_detected(self):
        for lang, toasts in TOASTS.items():
            for text in toasts:
                with self.subTest(lang=lang, text=text):
                    self.assertTrue(any(re.search(p, text.lower()) for p in tc.PATTERNS[lang]))

    def test_unaccented_typing_still_matches(self):
        for text in ("Anna ha iniciado la reunion", "Anna a demarre la reunion", "Anna iniciou a reuniao"):
            self.assertTrue(matches(text), text)

    def test_non_start_toasts_are_not_detected(self):
        for text in NOT_A_START:
            with self.subTest(text=text):
                self.assertFalse(matches(text))

    def test_supported_languages_match_the_popup_list(self):
        import os
        panel = open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Panel.qml")).read()
        m = re.search(r'supportedLanguages:\s*\[([^\]]+)\]', panel)
        self.assertIsNotNone(m, "Panel.qml must declare supportedLanguages")
        self.assertEqual(set(re.findall(r'"(\w+)"', m.group(1))), set(tc.PATTERNS))


if __name__ == "__main__":
    unittest.main()
