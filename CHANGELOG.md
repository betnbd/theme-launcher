# Changelog

## 2026-04-23

- Hardened GNOME session and schema detection for Ubuntu 26.04 / GNOME 50.
- Added doctor checks for GTK 4 Python bindings and surfaced GNOME Shell extension-version mismatches more clearly.
- Skipped Ubuntu Dock color tweaks cleanly on GNOME builds that no longer expose the old dock schema.
- Sanitized imported extra themes by removing upstream Omarchy references from local metadata and text assets.
- Removed branded wallpapers and dropped themes that no longer had usable preview/background images after cleanup.

## 2026-04-20

- Added wallpaper selection for themes that ship multiple wallpapers.
- Added launcher-side wallpaper randomization and CLI support via `--random-wallpaper`.
- Split launcher preview into `Workspace` and `Wallpaper` modes so both the theme mockup and selected wallpaper are available.
- Normalized applied wallpapers into generated runtime PNGs to avoid blank GNOME backgrounds from source asset quirks.
