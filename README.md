# Theme Launcher

Local Ubuntu theme switcher for GNOME and a small set of desktop apps.

Theme Launcher ships with a bundled catalog of ready-to-use themes under
`catalog/themes`. It can also read local theme overrides from
`~/.local/share/theme-launcher/themes`.

## Install

Install the runtime packages:

```bash
sudo apt install bash jq python3 python3-gi gir1.2-gtk-4.0 gir1.2-gdkpixbuf-2.0 python3-pil
```

Put the launcher on your `PATH`:

```bash
mkdir -p ~/.local/bin
ln -sfn "$PWD/bin/theme-launcher" ~/.local/bin/theme-launcher
```

Run the checks, then open the GTK launcher:

```bash
theme-launcher doctor
theme-launcher gui
```

From the repository checkout you can also run:

```bash
./bin/theme-launcher doctor
./bin/theme-launcher gui
```

## Commands

```text
theme-launcher choose
theme-launcher gui
theme-launcher apply THEME
theme-launcher list
theme-launcher current
theme-launcher previous
theme-launcher previous apply
theme-launcher doctor
theme-launcher metadata [THEME]
theme-launcher favorite list|add|remove|toggle THEME
theme-launcher default [THEME]
theme-launcher apply-default
```

Apply filters:

```text
--only TARGETS
--skip TARGETS
--wallpaper NAME
--random-wallpaper
```

Examples:

```bash
theme-launcher apply rose-pine --only gnome,ghostty
theme-launcher apply-default --skip brave
theme-launcher previous apply
```

Common targets:

```text
gnome, dock, gnome-shell, ghostty, btop, neovim, tmux, lazygit,
fastfetch, bat, fzf, gtk, firefox, thunderbird, brave, vscode
```

Aliases include `ff` for Firefox, `tbird` for Thunderbird, and
`brave-browser` for Brave.

## Theme Storage

Runtime state lives in:

```text
~/.local/share/theme-launcher
```

Theme sources are searched in this order:

```text
~/.local/share/theme-launcher/themes
~/.local/share/theme-launcher/vendor/catalog/themes
catalog/themes
```

Local themes override bundled themes with the same slug. Applying a theme writes
generated state under `~/.local/share/theme-launcher/state`.

## Theme Format

Each theme directory needs a `colors.toml`:

```toml
background = "#1e1e2e"
foreground = "#cdd6f4"
accent = "#89b4fa"
```

Optional files:

```text
theme.json
light.mode
preview.png
backgrounds/
gtk.css
ghostty.conf
btop.theme
neovim.lua
vscode.json
icons.theme
cursor.theme
```

`theme.json` may include:

```json
{
  "name": "My Theme",
  "variant": "dark",
  "description": "Cool muted contrast",
  "badges": ["custom"],
  "tags": ["blue", "minimal"]
}
```

## Risky Integrations

GNOME Shell panel theming is disabled during full applies unless you explicitly
request it:

```bash
theme-launcher apply rose-pine --only gnome-shell
```

Or set:

```text
THEME_LAUNCHER_ENABLE_GNOME_SHELL=1
```

## Development Checks

```bash
bash -n bin/theme-launcher lib/theme-launcher.sh
python3 -m py_compile bin/theme-launcher-gui lib/python/*.py tests/*.py
python3 -m unittest discover -s tests
```

GTK interaction tests are opt-in because they need a live graphical session:

```bash
THEME_LAUNCHER_RUN_GTK_TESTS=1 python3 -m unittest tests.test_wallpaper_dropdown -v
```

## License

MIT. See [LICENSE](LICENSE).
