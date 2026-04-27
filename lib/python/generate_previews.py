import datetime
import json
import math
import re
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except Exception as exc:
    raise SystemExit(f"theme-launcher: Pillow is required to generate previews: {exc}")

custom_root = Path(sys.argv[1])
vendor_root = Path(sys.argv[2])
state_dir = Path(sys.argv[3])
dry_run = sys.argv[4] == "1"
replace = sys.argv[5] == "1"

roots = []
for root in (custom_root, vendor_root):
    if root.exists() and root.is_dir() and root not in roots:
        roots.append(root)

backup_root = state_dir / "preview-backups" / (datetime.datetime.now().strftime("%Y%m%d-%H%M%S-generate-previews"))
manifest = []

def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()

title_font = font("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28)
heading_font = font("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
ui_font = font("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
mono_font = font("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 14)
tiny_font = font("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 11)

def parse_colors(path):
    colors = {}
    pattern = re.compile(r'^\s*([A-Za-z0-9_]+)\s*=\s*["\']?(#[0-9A-Fa-f]{6})')
    if path.exists():
        for line in path.read_text(errors="ignore").splitlines():
            match = pattern.match(line)
            if match:
                colors.setdefault(match.group(1), match.group(2))
    return colors

def rgb(value, fallback):
    if not value:
        return fallback
    value = value.strip().lstrip("#")
    if not re.fullmatch(r"[0-9A-Fa-f]{6}", value):
        return fallback
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4))

def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))

def lum(color):
    return (0.2126 * color[0] + 0.7152 * color[1] + 0.0722 * color[2]) / 255

def text_on(color):
    return (242, 242, 242) if lum(color) < 0.56 else (22, 22, 22)

def title(slug):
    return " ".join(part.capitalize() for part in slug.split("-"))

def fit(draw, text, font_obj, width):
    if draw.textlength(text, font=font_obj) <= width:
        return text
    out = text
    while out and draw.textlength(out + "...", font=font_obj) > width:
        out = out[:-1]
    return out + "..."

def rounded(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)

def preview_for(theme_dir):
    colors = parse_colors(theme_dir / "colors.toml")
    bg = rgb(colors.get("background"), (18, 18, 22))
    fg = rgb(colors.get("foreground"), (232, 232, 232))
    accent = rgb(colors.get("accent") or colors.get("color4") or colors.get("color5"), (122, 162, 247))
    c1 = rgb(colors.get("color1"), mix(accent, (245, 95, 95), 0.5))
    c2 = rgb(colors.get("color2"), mix(accent, (110, 220, 155), 0.5))
    c3 = rgb(colors.get("color3"), mix(accent, (245, 200, 95), 0.5))
    c4 = rgb(colors.get("color4"), accent)
    c5 = rgb(colors.get("color5"), accent)
    c6 = rgb(colors.get("color6"), mix(accent, (100, 220, 220), 0.5))
    light = lum(bg) > 0.66 or (theme_dir / "light.mode").exists()
    image = Image.new("RGB", (1366, 768), (36, 36, 36))
    draw = ImageDraw.Draw(image)
    frame = (42, 42, 1324, 726)
    rounded(draw, frame, 20, fill=(48, 48, 48), outline=(118, 118, 118), width=2)
    draw.rounded_rectangle((44, 44, 1322, 84), radius=18, fill=(56, 56, 56))
    draw.rectangle((44, 66, 1322, 84), fill=(56, 56, 56))
    for i, color in enumerate([(238, 95, 91), (245, 188, 80), accent]):
        draw.ellipse((62 + i * 24, 57, 76 + i * 24, 71), fill=color)
    draw.text((154, 56), f"{theme_dir.name} workspace preview", fill=(226, 226, 226), font=ui_font)
    draw.text((1142, 57), "10:34  60%", fill=(174, 174, 174), font=tiny_font)

    panel = mix(bg, (255, 255, 255) if light else (0, 0, 0), 0.08)
    panel2 = mix(bg, fg, 0.11 if not light else 0.08)
    outline = mix(accent, (180, 180, 180), 0.45)
    text = text_on(panel)
    code_bg = mix(bg, (0, 0, 0), 0.36 if not light else 0.05)
    code_text = text_on(code_bg)
    muted = mix(text, panel, 0.45)

    left = (70, 98, 858, 686)
    right = (890, 98, 1296, 686)
    rounded(draw, left, 16, fill=panel, outline=outline, width=2)
    rounded(draw, right, 16, fill=panel, outline=outline, width=2)
    sidebar = (92, 128, 258, 658)
    editor = (282, 128, 832, 658)
    rounded(draw, sidebar, 10, fill=panel2, outline=mix(outline, panel, 0.5))
    rounded(draw, editor, 10, fill=code_bg, outline=mix(outline, panel, 0.4))
    draw.text((110, 150), "THEME", fill=accent, font=heading_font)
    for idx, filename in enumerate(["colors.toml", "hyprland.conf", "waybar.css", "ghostty.conf", "btop.theme", "neovim.lua", "preview.png"]):
        y = 190 + idx * 43
        active = filename == "colors.toml"
        fill = mix(accent, bg, 0.42) if active else mix(panel2, text, 0.06)
        rounded(draw, (106, y, 244, y + 30), 7, fill=fill)
        draw.text((118, y + 7), filename, fill=text_on(fill), font=tiny_font)

    lines = [
        "# Theme Launcher workspace preview",
        f'name = "{theme_dir.name}"',
        "",
        f'background = "{colors.get("background", "#121216")}"',
        f'foreground = "{colors.get("foreground", "#e6e6e6")}"',
        f'accent = "{colors.get("accent", colors.get("color4", "#7aa2f7"))}"',
        "",
        "[palette]",
    ]
    for key in ["color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7", "color8", "color9", "color10", "color11"]:
        if key in colors:
            lines.append(f'{key:<8} = "{colors[key]}"')
    lines += ["", "[workspace]", 'panel = "waybar.css"', 'terminal = "ghostty.conf"', 'editor = "neovim.lua"', 'preview = "generated"']
    y = 148
    for idx, line in enumerate(lines[:22], start=1):
        draw.text((302, y), f"{idx:>2}", fill=mix(muted, code_bg, 0.25), font=mono_font)
        color = muted if line.startswith("#") else c5 if line.startswith("[") else c2 if "color" in line or "accent" in line else code_text
        draw.text((342, y), fit(draw, line, mono_font, 474), fill=color, font=mono_font)
        y += 23

    swatches = [bg, fg, accent, c1, c2, c3, c4, c5, c6]
    draw.text((914, 126), "system monitor", fill=text, font=heading_font)
    for idx, color in enumerate(swatches):
        x = 914 + idx * 38
        draw.rounded_rectangle((x, 162, x + 26, 188), radius=5, fill=color, outline=mix(color, (220, 220, 220), 0.26))
    graph = (914, 212, 1272, 326)
    rounded(draw, graph, 10, fill=code_bg, outline=mix(outline, panel, 0.4))
    points = []
    for idx in range(50):
        value = 0.50 + 0.27 * math.sin(idx / 4.2) + 0.10 * math.sin(idx / 1.8)
        points.append((graph[0] + 14 + idx * (graph[2] - graph[0] - 28) / 49, graph[3] - 18 - value * (graph[3] - graph[1] - 36)))
    draw.line(points, fill=accent, width=3)
    term = (914, 352, 1272, 520)
    rounded(draw, term, 10, fill=code_bg, outline=mix(outline, panel, 0.4))
    terminal = [f"~/themes/{theme_dir.name} $ ls", "colors.toml  preview.png  theme.json", "waybar.css   btop.theme    neovim.lua", "", f"~/themes/{theme_dir.name} $ inspect", "workspace: generated", "status: ready"]
    y = 370
    for line in terminal:
        color = accent if line.startswith("~/") else c2 if "ready" in line else code_text
        draw.text((934, y), fit(draw, line, mono_font, 318), fill=color, font=mono_font)
        y += 20
    card = (914, 548, 1272, 658)
    rounded(draw, card, 12, fill=panel2, outline=mix(outline, panel, 0.4))
    draw.text((934, 570), fit(draw, title(theme_dir.name), title_font, 310), fill=text, font=title_font)
    draw.text((934, 606), ("Light" if light else "Dark") + " theme - workspace preview", fill=muted, font=tiny_font)
    for idx, color in enumerate(swatches):
        x = 934 + idx * 36
        draw.rounded_rectangle((x, 628, x + 24, 652), radius=6, fill=color, outline=mix(color, (220, 220, 220), 0.30))
    return image

theme_dirs = []
seen = set()
for root in roots:
    for child in sorted(root.iterdir()):
        if child.is_dir() and child.name not in seen:
            seen.add(child.name)
            theme_dirs.append(child)

for theme_dir in theme_dirs:
    preview = theme_dir / "preview.png"
    manifest.append({"theme": theme_dir.name, "preview": str(preview), "action": "would-generate" if dry_run else "generated"})
    if dry_run:
        print(f"would generate {preview}")
        continue
    backup_dir = backup_root / theme_dir.name
    backup_dir.mkdir(parents=True, exist_ok=True)
    if preview.exists():
        shutil.copy2(preview, backup_dir / "preview.png")
    preview_for(theme_dir).save(preview, "PNG", optimize=True)
    print(f"generated {preview}")

if not dry_run:
    (backup_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"backup {backup_root}")
