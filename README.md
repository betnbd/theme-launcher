# Theme Launcher Project

Personal Ubuntu theme launcher for applying a shared theme catalog across the local desktop and selected apps.

This project is now the source of truth for the launcher code.

Runtime state still lives in:

- `~/.local/share/theme-launcher`

## Goal

Apply a single named theme across the local desktop and selected apps with one local command set and one runtime state directory.

Current target apps:

- GNOME mode, icons, wallpaper, Ubuntu Dock
- GNOME Shell top bar via generated shell theme when `user-theme` is installed
- Ghostty with launcher-driven reload support
- VSCodium / VS Code family
- Neovim
- btop
- tmux
- lazygit
- fastfetch
- bat
- fzf

## Current Entry Points

For a normal local setup, the usual flow is:

```bash
theme-launcher gui
theme-launcher doctor
theme-launcher apply-default
```

- CLI: `theme-launcher`
- GUI launcher: `theme-launcher gui`
- Desktop sessions open the GTK launcher by default from `theme-launcher choose`
- Previous theme: `theme-launcher previous apply`
- Doctor checks: `theme-launcher doctor`
- Metadata: `theme-launcher metadata [THEME]`
- Favorites: `theme-launcher favorite toggle THEME`
- Default theme: `theme-launcher default THEME`
- Apply default theme: `theme-launcher apply-default`
- Apply filters: `theme-launcher apply THEME --skip ghostty,tmux`
- Apply filters: `theme-launcher apply-default --only gnome,ghostty`
- Sync themes: `theme-launcher sync`
- Desktop launcher: `~/.local/share/applications/theme-launcher.desktop`

`theme-launcher sync` now expects a configured source archive:

- `THEME_LAUNCHER_SYNC_ARCHIVE_URL`
- `THEME_LAUNCHER_SYNC_ROOT_DIR`
- Optional label: `THEME_LAUNCHER_SYNC_SOURCE_LABEL`

## Behavior Notes

- The GTK launcher previews themes as you move through the list and reverts to the starting theme on cancel
- The GTK launcher shows each theme's catalog screenshot and inferred metadata in a side preview panel
- The preview panel can switch between a workspace preview image and the selected wallpaper when both are available
- Themes with multiple wallpapers expose a wallpaper picker in the GTK launcher and remember the last wallpaper selected for each theme
- The GTK launcher preview panel follows the selected wallpaper, and multi-wallpaper themes also expose a randomize action
- The GTK launcher can filter the catalog by variant, favorites, and live search terms, and exposes quick favorite/default actions in the preview panel
- Launcher-driven Ghostty theme changes reload the running terminal and suppress the config reload toast
- Plain CLI applies update Ghostty config for new windows and sessions without forcing a live reload unless `THEME_LAUNCHER_RELOAD_GHOSTTY=1` is set
- Running tmux sessions reload the generated theme automatically after apply
- GNOME Shell panel theming now applies during normal theme changes when the `user-theme` extension is available; Chromium integration still stays opt-in unless `THEME_LAUNCHER_ENABLE_CHROMIUM=1` is set or `--only chromium` is used
- `theme-launcher doctor` checks dependencies, write access, theme asset shape, stored theme references, and common GNOME or Chromium integration gaps before apply time
- CLI apply flows support one-shot `--only` and `--skip` target filters; GUI previews still apply the full theme set
- Theme metadata is read from optional `theme.json` files and falls back to inferred values when the catalog only provides theme assets
- Custom theme overlays can live in `~/.local/share/theme-launcher/themes` and override synced catalog themes of the same name
- The launcher supports a small favorites list stored in local state and surfaced in the GTK launcher

## Theme Metadata

Each theme may provide an optional `theme.json` alongside its assets. When absent, the launcher infers:

- display name from the theme slug
- variant from `light.mode`
- preview image from `preview.png`

Supported metadata keys:

- `name`
- `variant`
- `description`
- `preview`
- `badges`
- `tags`

## Active Code

- Main library: [theme-launcher.sh](./lib/theme-launcher.sh)
- CLI entrypoint: [theme-launcher](./bin/theme-launcher)
- Sync script: [theme-sync](./bin/theme-sync)

Thin user wrappers still live in:

- `~/.local/bin/theme-launcher`
- `~/.local/bin/theme-sync`

The old runtime copies under `~/.local/share/theme-launcher/bin` and `lib` have been archived under `~/.local/share/theme-launcher/archive`.

## Project Docs


## Notes

This is intentionally a personal utility, not a general-purpose product. The project is optimized for one machine, fast iteration, and practical theme coverage rather than broad portability.
