import json
import re
import sys
from pathlib import Path

try:
    from PIL import Image
except Exception:
    Image = None

roots = []
for raw in sys.argv[1:3]:
    root = Path(raw)
    if root.exists() and root.is_dir() and root not in roots:
        roots.append(root)

required_colors = {"background", "foreground", "accent"}
color_pattern = re.compile(r'^\s*([A-Za-z0-9_]+)\s*=\s*["\']?(#[0-9A-Fa-f]{6})')

def colors_for(path):
    colors = {}
    if not path.exists():
        return colors
    for line in path.read_text(errors="ignore").splitlines():
        match = color_pattern.match(line)
        if match:
            colors[match.group(1)] = match.group(2)
    return colors

seen = set()
issues = []
for root in roots:
    for theme_dir in sorted(path for path in root.iterdir() if path.is_dir()):
        if theme_dir.name in seen:
            continue
        seen.add(theme_dir.name)
        colors = colors_for(theme_dir / "colors.toml")
        missing_colors = sorted(required_colors - set(colors))
        if missing_colors:
            issues.append({"theme": theme_dir.name, "level": "fail", "issue": "missing-colors", "detail": ", ".join(missing_colors)})

        preview = theme_dir / "preview.png"
        if not preview.exists():
            issues.append({"theme": theme_dir.name, "level": "warn", "issue": "missing-preview", "detail": str(preview)})
        elif Image is not None:
            try:
                size = Image.open(preview).size
                if size != (1366, 768):
                    issues.append({"theme": theme_dir.name, "level": "warn", "issue": "nonstandard-preview-size", "detail": f"{size[0]}x{size[1]}"})
            except Exception as exc:
                issues.append({"theme": theme_dir.name, "level": "fail", "issue": "invalid-preview", "detail": str(exc)})

        metadata = {}
        metadata_file = theme_dir / "theme.json"
        if metadata_file.exists():
            try:
                parsed = json.loads(metadata_file.read_text())
                metadata = parsed if isinstance(parsed, dict) else {}
            except Exception as exc:
                issues.append({"theme": theme_dir.name, "level": "fail", "issue": "invalid-theme-json", "detail": str(exc)})
        if not metadata.get("description") or metadata.get("description") == "Imported theme.":
            issues.append({"theme": theme_dir.name, "level": "info", "issue": "weak-description", "detail": "description is missing or generic"})

        backgrounds = theme_dir / "backgrounds"
        if backgrounds.exists():
            for item in backgrounds.iterdir():
                if item.is_file() and "omarchy" in item.name.lower():
                    issues.append({"theme": theme_dir.name, "level": "warn", "issue": "branded-background-name", "detail": item.name})

for item in issues:
    print(f"{item['level'].upper()} {item['theme']}: {item['issue']} - {item['detail']}")
if not issues:
    print("No import cleanup issues found.")
