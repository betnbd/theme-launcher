import sys

try:
    from PIL import Image
except Exception:
    raise SystemExit(1)

source_path, target_path = sys.argv[1], sys.argv[2]
image = Image.open(source_path)
if image.mode not in ("RGB", "RGBA"):
    image = image.convert("RGB")
image.save(target_path, format="PNG")
