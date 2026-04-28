import json
import re
from pathlib import Path


def read_text(path):
    try:
        return path.read_text().strip()
    except OSError:
        return ""


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


def theme_roots(custom_root, vendor_root):
    roots = []
    for root in (custom_root, vendor_root):
        if root.exists() and root.is_dir() and root not in roots:
            roots.append(root)
    return roots


def load_favorites(favorites_file):
    try:
        return {
            line.strip()
            for line in favorites_file.read_text().splitlines()
            if line.strip()
        }
    except OSError:
        return set()


def load_theme_json(theme_dir):
    metadata_file = theme_dir / "theme.json"
    if not metadata_file.exists():
        return {}
    try:
        parsed = json.loads(metadata_file.read_text())
    except json.JSONDecodeError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def string_field(data, key, fallback=""):
    value = data.get(key)
    return value if isinstance(value, str) else fallback


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


def wallpapers_for(theme_dir):
    wallpapers = []
    backgrounds = theme_dir / "backgrounds"
    if not backgrounds.exists():
        return wallpapers

    for background in sorted(path for path in backgrounds.iterdir() if path.is_file()):
        wallpapers.append(
            {
                "name": background.name,
                "label": wallpaper_label(background.name),
                "path": str(background),
            }
        )
    return wallpapers


def collect_theme_metadata(
    custom_root,
    vendor_root,
    favorites_file,
    wallpaper_state_dir,
    current_theme_file,
    current_wallpaper_file,
):
    roots = theme_roots(custom_root, vendor_root)
    favorites = load_favorites(favorites_file)
    current_theme = read_text(current_theme_file)
    current_wallpaper = read_text(current_wallpaper_file)

    theme_dirs = {}
    for root in roots:
        for child in sorted(root.iterdir()):
            if child.is_dir():
                theme_dirs.setdefault(child.name, child)

    items = []
    for slug in sorted(theme_dirs):
        theme_dir = theme_dirs[slug]
        custom = load_theme_json(theme_dir)
        variant = theme_variant(theme_dir, custom)
        preview_abs = str(theme_dir / "preview.png") if (theme_dir / "preview.png").exists() else ""
        wallpapers = wallpapers_for(theme_dir)
        selected_wallpaper = read_text(wallpaper_state_dir / f"{slug}.name")
        wallpaper_names = {item["name"] for item in wallpapers}

        if selected_wallpaper not in wallpaper_names:
            selected_wallpaper = ""
        if not selected_wallpaper and wallpapers:
            selected_wallpaper = wallpapers[0]["name"]

        badges = [badge for badge in custom.get("badges", []) if isinstance(badge, str)]
        badges.append(variant.upper())
        preview = string_field(custom, "preview", "preview.png" if preview_abs else "")
        preview_path = string_field(custom, "previewPath", preview_abs)
        items.append(
            {
                "slug": slug,
                "name": string_field(custom, "name", display_name(slug)),
                "variant": variant,
                "description": string_field(custom, "description"),
                "preview": preview,
                "preview_path": preview_path or preview_abs,
                "badges": sorted(set(badges)),
                "tags": [tag for tag in custom.get("tags", []) if isinstance(tag, str)],
                "wallpapers": wallpapers,
                "selected_wallpaper": selected_wallpaper,
                "current_wallpaper": current_wallpaper
                if slug == current_theme and current_wallpaper
                else None,
                "favorite": slug in favorites,
                "source": "custom" if str(theme_dir).startswith(str(custom_root)) else "vendor",
                "path": str(theme_dir),
                "targets": targets(theme_dir),
            }
        )

    return items
