import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class GtkCssTest(unittest.TestCase):
    def test_gtk_css_managed_block_uses_css_comments(self):
        script = r'''
          set -euo pipefail
          source ./lib/theme-launcher.sh
          css_file="$1"
          cat >"$css_file" <<'CSS'
window {
  border-radius: 0;
}

# theme-launcher begin
old-css
# theme-launcher end
CSS
          theme_launcher_write_css_managed_block "$css_file" 'window { color: red; }'
          ! grep -Fxq '# theme-launcher begin' "$css_file"
          ! grep -Fxq '# theme-launcher end' "$css_file"
          grep -Fxq '/* theme-launcher begin */' "$css_file"
          grep -Fxq '/* theme-launcher end */' "$css_file"
        '''

        with tempfile.TemporaryDirectory() as tmpdir:
            css_file = Path(tmpdir) / "gtk.css"
            result = subprocess.run(
                ["bash", "-c", script, "bash", str(css_file)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_gtk_css_includes_ghostty_window_chrome(self):
        script = r'''
          set -euo pipefail
          tmpdir="$1"
          export THEME_LAUNCHER_HOME="$tmpdir/theme-home"
          mkdir -p "$THEME_LAUNCHER_HOME/state/next"
          cat >"$THEME_LAUNCHER_HOME/state/next/colors.toml" <<'TOML'
accent = "#36a166"
foreground = "#dcd9d6"
background = "#22221b"
selection_foreground = "#22221b"
selection_background = "#5f9182"
color0 = "#302f27"
color8 = "#6c6b5a"
TOML
          source ./lib/theme-launcher.sh
          theme_launcher_generate_gtk_css
          grep -Fq 'window.ghostty headerbar' "$THEME_LAUNCHER_NEXT_DIR/gtk-4.0.css"
          grep -Fq 'window.ghostty .titlebar' "$THEME_LAUNCHER_NEXT_DIR/gtk-4.0.css"
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
