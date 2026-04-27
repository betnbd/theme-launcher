import json
import re
import sys
from pathlib import Path

custom_root = Path(sys.argv[1])
vendor_root = Path(sys.argv[2])
favorites_file = Path(sys.argv[3])
wallpaper_state_dir = Path(sys.argv[4])
current_theme_file = Path(sys.argv[5])
current_wallpaper_file = Path(sys.argv[6])
default_theme_file = Path(sys.argv[7])

roots = []
for root in (custom_root, vendor_root):
    if root.exists() and root.is_dir() and root not in roots:
        roots.append(root)

favorites = set()
try:
    favorites = {line.strip() for line in favorites_file.read_text().splitlines() if line.strip()}
except OSError:
    pass

def read_text(path):
    try:
        return path.read_text().strip()
    except OSError:
        return ""

current_theme = read_text(current_theme_file)
current_wallpaper = read_text(current_wallpaper_file)
default_theme = read_text(default_theme_file)

def display_name(slug):
    return " ".join(part.capitalize() for part in slug.split("-"))

def wallpaper_label(name):
    stem = Path(name).stem
    cleaned = re.sub(r"^[0-9]+[-_]?", "", stem).replace("-", " ").replace("_", " ")
    return (cleaned or stem).title()

def theme_variant(theme_dir, custom):
    variant = custom.get("variant")
    if variant in {"light", "dark"}:
        return variant
    return "light" if (theme_dir / "light.mode").exists() else "dark"

def saved_wallpaper(slug):
    return read_text(wallpaper_state_dir / f"{slug}.name")

def targets(theme_dir):
    checks = [
        ("GNOME", "icons.theme"),
        ("GTK", "gtk.css"),
        ("Ghostty", "ghostty.conf"),
        ("btop", "btop.theme"),
        ("Neovim", "neovim.lua"),
        ("VS Code", "vscode.json"),
        ("Chromium", "chromium.theme"),
        ("Waybar", "waybar.css"),
        ("Hyprland", "hyprland.conf"),
        ("Kitty", "kitty.conf"),
    ]
    return [label for label, filename in checks if (theme_dir / filename).exists()]

theme_dirs = {}
for root in roots:
    for child in sorted(root.iterdir() if root.exists() else []):
        if child.is_dir():
            theme_dirs.setdefault(child.name, child)

items = []
for slug in sorted(theme_dirs):
    theme_dir = theme_dirs[slug]
    metadata_file = theme_dir / "theme.json"
    custom = {}
    if metadata_file.exists():
        try:
            parsed = json.loads(metadata_file.read_text())
            if isinstance(parsed, dict):
                custom = parsed
        except Exception:
            custom = {}

    variant = theme_variant(theme_dir, custom)
    preview_abs = str(theme_dir / "preview.png") if (theme_dir / "preview.png").exists() else ""
    wallpapers = []
    backgrounds = theme_dir / "backgrounds"
    if backgrounds.exists():
        for background in sorted(path for path in backgrounds.iterdir() if path.is_file()):
            wallpapers.append({
                "name": background.name,
                "label": wallpaper_label(background.name),
                "path": str(background),
            })

    selected_wallpaper = saved_wallpaper(slug)
    wallpaper_names = {item["name"] for item in wallpapers}
    if selected_wallpaper not in wallpaper_names:
        selected_wallpaper = ""
    if not selected_wallpaper and wallpapers:
        selected_wallpaper = wallpapers[0]["name"]

    badges = [badge for badge in custom.get("badges", []) if isinstance(badge, str)]
    badges.append(variant.upper())
    item = {
        "slug": slug,
        "name": custom.get("name") if isinstance(custom.get("name"), str) else display_name(slug),
        "variant": variant,
        "description": custom.get("description") if isinstance(custom.get("description"), str) else "",
        "preview": custom.get("preview") if isinstance(custom.get("preview"), str) else ("preview.png" if preview_abs else ""),
        "preview_path": custom.get("previewPath") if isinstance(custom.get("previewPath"), str) and custom.get("previewPath") else preview_abs,
        "badges": sorted(set(badges)),
        "tags": [tag for tag in custom.get("tags", []) if isinstance(tag, str)],
        "wallpapers": wallpapers,
        "selected_wallpaper": selected_wallpaper,
        "current_wallpaper": current_wallpaper if slug == current_theme and current_wallpaper else None,
        "favorite": slug in favorites,
        "source": "custom" if str(theme_dir).startswith(str(custom_root)) else "vendor",
        "path": str(theme_dir),
        "targets": targets(theme_dir),
    }
    items.append(item)

print(json.dumps({
    "metadata": items,
    "current": current_theme,
    "default": default_theme,
}, separators=(",", ":")))
