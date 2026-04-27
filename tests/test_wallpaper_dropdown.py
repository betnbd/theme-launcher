import os
import subprocess
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def gtk_python_command():
    script = "source ./lib/theme-launcher.sh && theme_launcher_python_gtk_command"
    result = subprocess.run(
        ["bash", "-c", script],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


class WallpaperDropdownTest(unittest.TestCase):
    @unittest.skipUnless(
        os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"),
        "GTK display is not available",
    )
    def test_wallpaper_selection_does_not_rebuild_dropdown_during_notify(self):
        harness = textwrap.dedent(
            """
            import importlib.machinery

            mod = importlib.machinery.SourceFileLoader(
                "theme_launcher_gui", "bin/theme-launcher-gui"
            ).load_module()
            from gi.repository import GLib, Gtk

            app = Gtk.Application(application_id="local.theme-launcher.dropdown-test")
            state = {}

            def activate(app):
                win = mod.ThemeLauncherWindow(app)
                state["win"] = win
                win.select_theme("aetheria")
                win.refresh_preview()

                def choose_wallpaper():
                    if len(win._wallpaper_choices) > 1:
                        win.wallpaper_dropdown.set_selected(1)
                    return False

                def finish():
                    app.quit()
                    return False

                GLib.timeout_add(250, choose_wallpaper)
                GLib.timeout_add(1200, finish)
                win.present()

            app.connect("activate", activate)
            app.run([])
            """
        )

        result = subprocess.run(
            [gtk_python_command(), "-c", harness],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("g_object_notify_by_pspec", result.stderr)

    @unittest.skipUnless(
        os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"),
        "GTK display is not available",
    )
    def test_workspace_preview_uses_fixed_texture_size_across_theme_details(self):
        harness = textwrap.dedent(
            """
            import importlib.machinery

            mod = importlib.machinery.SourceFileLoader(
                "theme_launcher_gui", "bin/theme-launcher-gui"
            ).load_module()
            from gi.repository import GLib, Gtk

            app = Gtk.Application(application_id="local.theme-launcher.preview-size-test")
            state = {}

            def capture(label):
                texture = state["win"].preview_picture.get_paintable()
                state[label] = (
                    texture.get_intrinsic_width(),
                    texture.get_intrinsic_height(),
                )

            def activate(app):
                win = mod.ThemeLauncherWindow(app)
                state["win"] = win
                win.present()

                def select_latte():
                    win.select_theme("catppuccin-latte")
                    win.refresh_preview()
                    capture("latte")
                    return False

                def select_dark():
                    win.select_theme("catppuccin-dark")
                    win.refresh_preview()
                    capture("dark")
                    app.quit()
                    return False

                GLib.timeout_add(250, select_latte)
                GLib.timeout_add(500, select_dark)

            app.connect("activate", activate)
            app.run([])

            expected = (mod.PREVIEW_IMAGE_WIDTH, mod.PREVIEW_IMAGE_HEIGHT)
            if state.get("latte") != expected:
                raise AssertionError(f"latte preview size {state.get('latte')} != {expected}")
            if state.get("dark") != expected:
                raise AssertionError(f"dark preview size {state.get('dark')} != {expected}")
            """
        )

        result = subprocess.run(
            [gtk_python_command(), "-c", harness],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
