# Changelog

## 2026-04-27

- Added public install, dependency, theme-catalog, and validation notes to the README.
- Kept GTK preview images on a fixed-size canvas so theme details do not resize when previews have different aspect ratios.
- Updated GUI tests to use the same GTK-capable Python interpreter discovery as the launcher.

## 2026-04-23

- Hardened GNOME session and schema detection for Ubuntu 26.04 / GNOME 50.
- Added doctor checks for GTK 4 Python bindings and surfaced GNOME Shell extension-version mismatches more clearly.
- Skipped Ubuntu Dock color tweaks cleanly on GNOME builds that no longer expose the old dock schema.

## 2026-04-20

- Added wallpaper selection for themes that ship multiple wallpapers.
- Added launcher-side wallpaper randomization and CLI support via `--random-wallpaper`.
- Split launcher preview into `Workspace` and `Wallpaper` modes so both the theme mockup and selected wallpaper are available.
- Normalized applied wallpapers into generated runtime PNGs to avoid blank GNOME backgrounds from source asset quirks.
