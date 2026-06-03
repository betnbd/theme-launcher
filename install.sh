#!/usr/bin/env bash
# Install Theme Launcher for the current user:
#   - links bin/theme-launcher onto your PATH (~/.local/bin)
#   - installs the app icon and desktop entry so it appears in your launcher
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ICON_ROOT="$HOME/.local/share/icons/hicolor"

echo "Installing Theme Launcher from $REPO_DIR"

# 1. launcher on PATH
mkdir -p "$BIN_DIR"
ln -sfn "$REPO_DIR/bin/theme-launcher" "$BIN_DIR/theme-launcher"
echo "  linked $BIN_DIR/theme-launcher"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "  note: $BIN_DIR is not on your PATH; add it to run 'theme-launcher' directly" ;;
esac

# 2. icon: scalable SVG, plus rasterised PNG sizes when a renderer is available
install -d "$ICON_ROOT/scalable/apps"
install -m 0644 "$REPO_DIR/packaging/theme-launcher.svg" "$ICON_ROOT/scalable/apps/theme-launcher.svg"
echo "  installed scalable icon"
if /usr/bin/python3 - "$REPO_DIR/packaging/theme-launcher.svg" "$ICON_ROOT" <<'PY' 2>/dev/null
import sys, os
import gi
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf
src, root = sys.argv[1], sys.argv[2]
for s in (16, 24, 32, 48, 64, 128, 256, 512):
    d = os.path.join(root, f"{s}x{s}", "apps")
    os.makedirs(d, exist_ok=True)
    pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(src, s, s, True)
    pb.savev(os.path.join(d, "theme-launcher.png"), "png", [], [])
PY
then
  echo "  rendered PNG icon sizes"
else
  echo "  note: could not render PNG sizes; the scalable SVG is enough for most launchers"
fi

# 3. desktop entry
install -d "$APP_DIR"
install -m 0644 "$REPO_DIR/packaging/theme-launcher.desktop" "$APP_DIR/theme-launcher.desktop"
echo "  installed desktop entry"

# 4. refresh caches (best effort)
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t "$ICON_ROOT" >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

echo "Done. Run 'theme-launcher doctor' to verify, or 'theme-launcher gui' to open it."
