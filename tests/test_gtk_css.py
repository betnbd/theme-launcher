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


if __name__ == "__main__":
    unittest.main()
