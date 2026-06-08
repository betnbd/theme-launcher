# AGENTS.md

## Purpose

Local Ubuntu/GNOME theme switcher. A Bash CLI plus a GTK4 GUI apply a bundled catalog of color themes across GNOME and a set of desktop apps (Ghostty, btop, neovim, tmux, lazygit, fastfetch, bat, fzf, GTK, Firefox, Thunderbird, Brave, VS Code).

## Stack

- Bash (CLI + core engine), Python 3 + PyGObject/GTK4 (GUI), Pillow (preview handling)
- `jq` for JSON, `gsettings`/`busctl` for GNOME integration
- No build step; runs from the checkout. Tests use `unittest`.

## Build / Run / Test

```bash
./bin/theme-launcher doctor          # environment + catalog health check
./bin/theme-launcher gui             # GTK4 picker
./bin/theme-launcher apply THEME [--only T | --skip T | --wallpaper N | --random-wallpaper]

# checks
bash -n bin/theme-launcher lib/theme-launcher.sh
python3 -m py_compile bin/theme-launcher-gui lib/python/*.py tests/*.py
python3 -m unittest discover -s tests
```

Runtime deps (Ubuntu): `bash jq python3 python3-gi gir1.2-gtk-4.0 gir1.2-gdkpixbuf-2.0 python3-pil`.

GTK interaction tests are opt-in (need a live graphical session):

```bash
THEME_LAUNCHER_RUN_GTK_TESTS=1 python3 -m unittest tests.test_wallpaper_dropdown -v
```

## Layout

- `bin/theme-launcher` — CLI entry: arg/filter parsing + dispatch. Sources `lib/theme-launcher.sh`.
- `lib/theme-launcher.sh` — core engine (~3k lines): theme resolution, per-target apply functions, `doctor`, state/favorites/default handling. Most logic lives here.
- `bin/theme-launcher-gui` — standalone GTK4 app; shells out to the CLI via `run_cli()`.
- `lib/gui-style.css` — GUI styling.
- `lib/python/` — helpers: `theme_metadata.py`/`all_theme_metadata.py` (metadata emitted to the GUI), `normalize_png.py`/`check_preview_size.py` (preview images), `bootstrap.py`.
- `catalog/themes/<slug>/` — bundled themes. `colors.toml` is required (must define `background`, `foreground`, `accent`); optional `theme.json`, `light.mode`, `preview.png`, `backgrounds/`, and per-app files (`ghostty.conf`, `btop.theme`, `neovim.lua`, `vscode.json`, `icons.theme`, etc.).
- `tests/` — `unittest` suite; shell tests invoke the CLI in a temp `THEME_LAUNCHER_HOME`.

## Gotchas

- Theme sources resolve in order: `~/.local/share/theme-launcher/themes` → `…/vendor/catalog/themes` → repo `catalog/themes`. Local themes override bundled ones by slug. Runtime state writes to `~/.local/share/theme-launcher/state` (override root with `THEME_LAUNCHER_HOME`).
- GNOME Shell panel theming is gated off during full applies; enable per-run with `--only gnome-shell` or `THEME_LAUNCHER_ENABLE_GNOME_SHELL=1`. Each target has a corresponding `THEME_LAUNCHER_ENABLE_<TARGET>` opt-in.
- `--only` and `--skip` are mutually exclusive; so are `--wallpaper` and `--random-wallpaper`.
- The GUI calls the sibling CLI by path and applies with `THEME_LAUNCHER_RELOAD_GHOSTTY=1`; keep the CLI's flags/output stable when changing it.
- Apply touches the live desktop (gsettings, dconf, app config files). Use a throwaway `THEME_LAUNCHER_HOME` and `bash -n` / the test suite rather than running real applies to verify.
