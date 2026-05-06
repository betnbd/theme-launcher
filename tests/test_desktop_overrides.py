import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class DesktopOverridesTest(unittest.TestCase):
    def test_mozilla_overrides_disable_startup_notification(self):
        script = r'''
          set -euo pipefail
          tmpdir="$1"
          source_dir="$tmpdir/snap-applications"
          home_dir="$tmpdir/home"
          mkdir -p "$source_dir" "$home_dir"
          cat >"$source_dir/firefox_firefox.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Firefox
Exec=/snap/bin/firefox %u
StartupWMClass=firefox_firefox
StartupNotify=true

[Desktop Action new-window]
Name=New Window
Exec=/snap/bin/firefox --new-window %u
DESKTOP
          cat >"$source_dir/thunderbird_thunderbird.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Thunderbird Mail
Exec=/snap/bin/thunderbird %u
StartupNotify=true

[Desktop Action compose]
Name=Compose New Message
Exec=/snap/bin/thunderbird -compose
DESKTOP
          export HOME="$home_dir"
          export THEME_LAUNCHER_DESKTOP_SOURCE_DIRS="$source_dir"
          source ./lib/theme-launcher.sh
          theme_launcher_write_mozilla_desktop_overrides
          grep -Fxq 'StartupNotify=false' "$home_dir/.local/share/applications/firefox_firefox.desktop"
          grep -Fxq 'StartupNotify=false' "$home_dir/.local/share/applications/thunderbird_thunderbird.desktop"
          grep -Fxq 'StartupWMClass=firefox_firefox' "$home_dir/.local/share/applications/firefox_firefox.desktop"
          grep -Fxq 'StartupWMClass=thunderbird' "$home_dir/.local/share/applications/thunderbird_thunderbird.desktop"
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
