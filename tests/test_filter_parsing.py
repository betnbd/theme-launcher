import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "theme-launcher"


class FilterParsingTest(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run(
            [str(CLI), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_only_and_skip_are_mutually_exclusive(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--only", "gnome", "--skip", "ghostty")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot combine --only and --skip", result.stderr)

    def test_wallpaper_and_random_are_mutually_exclusive(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--random-wallpaper", "--wallpaper", "foo.png")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot combine --wallpaper and --random-wallpaper", result.stderr)

    def test_wallpaper_requires_argument(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--wallpaper")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing wallpaper name after --wallpaper", result.stderr)

    def test_only_requires_argument(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--only")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing target list after --only", result.stderr)

    def test_unknown_option_is_rejected(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--no-such-flag")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown option", result.stderr)

    def test_firefox_and_thunderbird_targets_are_recognized(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--only", "firefox,thunderbird")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown theme", result.stderr)
        self.assertNotIn("unknown target", result.stderr)

    def test_mozilla_target_aliases_are_recognized(self):
        result = self.run_cli("apply", "nonexistent-theme-xyz", "--only", "ff,tbird")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown theme", result.stderr)
        self.assertNotIn("unknown target", result.stderr)

    def test_mozilla_targets_have_reload_hooks(self):
        script = r'''
          set -euo pipefail
          source ./lib/theme-launcher.sh
          theme_launcher_target_registry | grep -Fxq 'firefox||theme_launcher_apply_firefox|theme_launcher_reload_firefox|firefox'
          theme_launcher_target_registry | grep -Fxq 'thunderbird||theme_launcher_apply_thunderbird|theme_launcher_reload_thunderbird|thunderbird'
          declare -F theme_launcher_reload_firefox >/dev/null
          declare -F theme_launcher_reload_thunderbird >/dev/null
        '''
        result = subprocess.run(
            ["bash", "-c", script],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_brave_theme_does_not_require_chromium_theme_file(self):
        script = r'''
          set -euo pipefail
          tmpdir="$1"
          mkdir -p "$tmpdir/bin" "$tmpdir/theme-home/state/current"
          printf '#!/usr/bin/env bash\nexit 0\n' >"$tmpdir/bin/brave-browser"
          chmod +x "$tmpdir/bin/brave-browser"
          cat >"$tmpdir/theme-home/state/current/colors.toml" <<'TOML'
background = "#112233"
foreground = "#ddeeff"
accent = "#4477aa"
selection_background = "#6688aa"
color8 = "#334455"
TOML
          export HOME="$tmpdir/home"
          export PATH="$tmpdir/bin:$PATH"
          export THEME_LAUNCHER_HOME="$tmpdir/theme-home"
          source ./lib/theme-launcher.sh
          theme_launcher_apply_chromium
          test -f "$THEME_LAUNCHER_STATE_DIR/brave-theme-extension/manifest.json"
          grep -Fq '"frame": [17, 34, 51]' "$THEME_LAUNCHER_STATE_DIR/brave-theme-extension/manifest.json"
        '''

        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run(
                ["bash", "-c", script, "bash", tmpdir],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
