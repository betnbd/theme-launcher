#!/usr/bin/env bash

set -euo pipefail

THEME_LAUNCHER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_LAUNCHER_PROJECT_ROOT="$(cd "$THEME_LAUNCHER_LIB_DIR/.." && pwd)"
THEME_LAUNCHER_PYTHON_DIR="$THEME_LAUNCHER_LIB_DIR/python"
THEME_LAUNCHER_HOME="${THEME_LAUNCHER_HOME:-$HOME/.local/share/theme-launcher}"
THEME_LAUNCHER_BUNDLED_THEMES_DIR="${THEME_LAUNCHER_BUNDLED_THEMES_DIR:-$THEME_LAUNCHER_PROJECT_ROOT/catalog/themes}"
THEME_LAUNCHER_VENDOR_ROOT="$THEME_LAUNCHER_HOME/vendor"
THEME_LAUNCHER_VENDOR_CATALOG="$THEME_LAUNCHER_VENDOR_ROOT/catalog"
THEME_LAUNCHER_VENDOR_FALLBACK=""
THEME_LAUNCHER_VENDOR="$THEME_LAUNCHER_VENDOR_CATALOG"
if [[ ! -d "$THEME_LAUNCHER_VENDOR_CATALOG" && -d "$THEME_LAUNCHER_VENDOR_ROOT" ]]; then
  for candidate in "$THEME_LAUNCHER_VENDOR_ROOT"/*; do
    [[ -d "$candidate" ]] || continue
    [[ "$(basename "$candidate")" == "catalog" ]] && continue
    [[ -d "$candidate/themes" || -d "$candidate/default" ]] || continue
    THEME_LAUNCHER_VENDOR_FALLBACK="$candidate"
    THEME_LAUNCHER_VENDOR="$candidate"
    break
  done
fi
THEME_LAUNCHER_THEMES_DIR="$THEME_LAUNCHER_VENDOR/themes"
THEME_LAUNCHER_CUSTOM_THEMES_DIR="$THEME_LAUNCHER_HOME/themes"
THEME_LAUNCHER_VENDOR_TEMPLATES_DIR="$THEME_LAUNCHER_VENDOR/default/themed"
THEME_LAUNCHER_STATE_DIR="$THEME_LAUNCHER_HOME/state"
THEME_LAUNCHER_CURRENT_DIR="$THEME_LAUNCHER_STATE_DIR/current"
THEME_LAUNCHER_NEXT_DIR="$THEME_LAUNCHER_STATE_DIR/next"
THEME_LAUNCHER_THEME_NAME_FILE="$THEME_LAUNCHER_STATE_DIR/theme.name"
THEME_LAUNCHER_DEFAULT_THEME_FILE="$THEME_LAUNCHER_STATE_DIR/default-theme.name"
THEME_LAUNCHER_PREVIOUS_THEME_FILE="$THEME_LAUNCHER_STATE_DIR/previous-theme.name"
THEME_LAUNCHER_THEME_LINK="$THEME_LAUNCHER_STATE_DIR/theme"
THEME_LAUNCHER_BACKGROUND_LINK="$THEME_LAUNCHER_STATE_DIR/background"
THEME_LAUNCHER_WALLPAPER_NAME_FILE="$THEME_LAUNCHER_STATE_DIR/wallpaper.name"
THEME_LAUNCHER_WALLPAPER_STATE_DIR="$THEME_LAUNCHER_STATE_DIR/wallpapers"
THEME_LAUNCHER_FAVORITES_FILE="$THEME_LAUNCHER_STATE_DIR/favorites.list"
THEME_LAUNCHER_RANDOM_WALLPAPER_TOKEN="__THEME_LAUNCHER_RANDOM__"
THEME_LAUNCHER_MARKER_BEGIN="# theme-launcher begin"
THEME_LAUNCHER_MARKER_END="# theme-launcher end"
THEME_LAUNCHER_WARNED_RISKY_TARGETS=" "

theme_launcher_fail() {
  printf "theme-launcher: %s\n" "$*" >&2
  exit 1
}

theme_launcher_warn() {
  printf "theme-launcher: %s\n" "$*" >&2
}

theme_launcher_warn_once() {
  local key="$1"
  shift || true

  if [[ "$THEME_LAUNCHER_WARNED_RISKY_TARGETS" == *" $key "* ]]; then
    return 0
  fi

  THEME_LAUNCHER_WARNED_RISKY_TARGETS="${THEME_LAUNCHER_WARNED_RISKY_TARGETS}${key} "
  theme_launcher_warn "$@"
}

theme_launcher_doctor_print() {
  local level="$1"
  local label="$2"
  local detail="$3"
  printf "%-4s %s" "$level" "$label"
  if [[ -n "$detail" ]]; then
    printf ": %s" "$detail"
  fi
  printf "\n"
}

theme_launcher_doctor_pass() {
  theme_launcher_doctor_print "PASS" "$1" "${2:-}"
}

theme_launcher_doctor_warn() {
  THEME_LAUNCHER_DOCTOR_WARNINGS=$((THEME_LAUNCHER_DOCTOR_WARNINGS + 1))
  theme_launcher_doctor_print "WARN" "$1" "${2:-}"
}

theme_launcher_doctor_fail() {
  THEME_LAUNCHER_DOCTOR_FAILURES=$((THEME_LAUNCHER_DOCTOR_FAILURES + 1))
  theme_launcher_doctor_print "FAIL" "$1" "${2:-}"
}

theme_launcher_require() {
  command -v "$1" >/dev/null 2>&1 || theme_launcher_fail "missing required command: $1"
}

theme_launcher_in_graphical_session() {
  [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]
}

theme_launcher_in_gnome_session() {
  local current_desktop="${XDG_CURRENT_DESKTOP:-}"
  local desktop_session="${DESKTOP_SESSION:-}"

  [[ "$current_desktop" == *GNOME* ]] && return 0
  [[ "$current_desktop" == *ubuntu* ]] && return 0
  [[ "$desktop_session" == "gnome" || "$desktop_session" == "ubuntu" ]]
}

THEME_LAUNCHER_GSETTINGS_SCHEMAS=""
THEME_LAUNCHER_GSETTINGS_RELOCATABLE_SCHEMAS=""

theme_launcher_gsettings_schema_exists() {
  local schema="$1"

  command -v gsettings >/dev/null 2>&1 || return 1
  if [[ -z "$THEME_LAUNCHER_GSETTINGS_SCHEMAS" ]]; then
    THEME_LAUNCHER_GSETTINGS_SCHEMAS="$(gsettings list-schemas 2>/dev/null || true)"
    THEME_LAUNCHER_GSETTINGS_SCHEMAS="${THEME_LAUNCHER_GSETTINGS_SCHEMAS:- }"
  fi
  if [[ $'\n'"$THEME_LAUNCHER_GSETTINGS_SCHEMAS"$'\n' == *$'\n'"$schema"$'\n'* ]]; then
    return 0
  fi
  if [[ -z "$THEME_LAUNCHER_GSETTINGS_RELOCATABLE_SCHEMAS" ]]; then
    THEME_LAUNCHER_GSETTINGS_RELOCATABLE_SCHEMAS="$(gsettings list-relocatable-schemas 2>/dev/null || true)"
    THEME_LAUNCHER_GSETTINGS_RELOCATABLE_SCHEMAS="${THEME_LAUNCHER_GSETTINGS_RELOCATABLE_SCHEMAS:- }"
  fi
  [[ $'\n'"$THEME_LAUNCHER_GSETTINGS_RELOCATABLE_SCHEMAS"$'\n' == *$'\n'"$schema"$'\n'* ]]
}

theme_launcher_ubuntu_dock_schema() {
  local schema

  for schema in \
    org.gnome.shell.extensions.dash-to-dock \
    org.gnome.shell.extensions.ubuntu-dock; do
    if theme_launcher_gsettings_schema_exists "$schema"; then
      printf "%s\n" "$schema"
      return 0
    fi
  done

  return 1
}

theme_launcher_gnome_shell_major_version() {
  local version

  command -v gnome-shell >/dev/null 2>&1 || return 1
  version="$(gnome-shell --version 2>/dev/null | sed -En 's/^GNOME Shell ([0-9]+)(\..*)?$/\1/p')"
  [[ -n "$version" ]] || return 1
  printf "%s\n" "$version"
}

theme_launcher_python_gtk_available() {
  theme_launcher_python_gtk_command >/dev/null
}

theme_launcher_python_gtk_command() {
  local candidate
  local candidates=()

  if [[ -n "${THEME_LAUNCHER_PYTHON_GTK:-}" ]]; then
    candidates+=("$THEME_LAUNCHER_PYTHON_GTK")
  fi
  candidates+=("/usr/bin/python3" "python3")

  for candidate in "${candidates[@]}"; do
    command -v "$candidate" >/dev/null 2>&1 || continue
    if "$candidate" - <<'PY' >/dev/null 2>&1
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk  # noqa: F401
PY
    then
      command -v "$candidate"
      return 0
    fi
  done

  return 1
}

theme_launcher_python_pillow_command() {
  local candidate
  local candidates=()

  candidates+=("/usr/bin/python3" "python3")

  for candidate in "${candidates[@]}"; do
    command -v "$candidate" >/dev/null 2>&1 || continue
    if "$candidate" - <<'PY' >/dev/null 2>&1
from PIL import Image  # noqa: F401
PY
    then
      command -v "$candidate"
      return 0
    fi
  done

  return 1
}

theme_launcher_slugify() {
  printf "%s" "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/<[^>]+>//g; s/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

theme_launcher_display_name() {
  printf "%s" "$1" | tr '-' ' ' | sed -E 's/\b(.)/\U\1/g'
}

theme_launcher_bat_theme_name() {
  local theme_slug
  theme_slug="$(theme_launcher_slugify "$1")"

  case "$theme_slug" in
    nord) printf "Nord" ;;
    gruvbox) printf "gruvbox-dark" ;;
    white|flexoki-light|catppuccin-latte) printf "GitHub" ;;
    rose-pine) printf "Coldark-Cold" ;;
    tokyo-night|kanagawa|osaka-jade|catppuccin|ethereal|everforest|ristretto|miasma|lumon) printf "OneHalfDark" ;;
    retro-82|hackerman|matte-black|vantablack) printf "DarkNeon" ;;
    *) printf "Monokai Extended (default dark)" ;;
  esac
}

theme_launcher_theme_path() {
  local theme
  local root
  theme="$(theme_launcher_slugify "$1")"

  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    if [[ -d "$root/$theme" ]]; then
      printf "%s/%s" "$root" "$theme"
      return 0
    fi
  done < <(theme_launcher_theme_roots)

  printf "%s/%s" "$THEME_LAUNCHER_CUSTOM_THEMES_DIR" "$theme"
}

theme_launcher_theme_exists() {
  local theme
  local root

  theme="$(theme_launcher_slugify "$1")"

  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    if [[ -d "$root/$theme" ]]; then
      return 0
    fi
  done < <(theme_launcher_theme_roots)

  return 1
}

theme_launcher_theme_roots() {
  printf "%s\n" "$THEME_LAUNCHER_CUSTOM_THEMES_DIR"

  if [[ -d "$THEME_LAUNCHER_BUNDLED_THEMES_DIR" &&
    "$THEME_LAUNCHER_BUNDLED_THEMES_DIR" != "$THEME_LAUNCHER_CUSTOM_THEMES_DIR" ]]; then
    printf "%s\n" "$THEME_LAUNCHER_BUNDLED_THEMES_DIR"
  fi

  if [[ "$THEME_LAUNCHER_THEMES_DIR" != "$THEME_LAUNCHER_CUSTOM_THEMES_DIR" ]]; then
    printf "%s\n" "$THEME_LAUNCHER_THEMES_DIR"
  fi
}

theme_launcher_path_writable() {
  local path="$1"

  if [[ -e "$path" ]]; then
    [[ -w "$path" ]]
  else
    [[ -w "$(dirname "$path")" ]]
  fi
}

theme_launcher_check_required_command() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    theme_launcher_doctor_pass "command:$cmd" "$(command -v "$cmd")"
  else
    theme_launcher_doctor_fail "command:$cmd" "missing"
  fi
}

THEME_LAUNCHER_CHROMIUM_BROWSERS=(chromium-browser chromium google-chrome brave-browser)
THEME_LAUNCHER_CHROMIUM_POLICY_DIRS=(
  "/etc/chromium/policies/managed"
  "/etc/chromium/browser/policies/managed"
  "/etc/opt/chrome/policies/managed"
  "/etc/brave/policies/managed"
)

theme_launcher_chromium_installed() {
  local browser
  for browser in "${THEME_LAUNCHER_CHROMIUM_BROWSERS[@]}"; do
    command -v "$browser" >/dev/null 2>&1 && return 0
  done
  return 1
}

read -r -d '' THEME_LAUNCHER_TARGET_REGISTRY <<'EOF' || true
gnome||theme_launcher_apply_gnome||gsettings
dock||theme_launcher_apply_ubuntu_dock||gsettings
gnome-shell|theme_launcher_generate_gnome_shell_css|theme_launcher_apply_gnome_shell||gsettings,busctl
ghostty||theme_launcher_apply_ghostty|theme_launcher_reload_ghostty|ghostty
btop||theme_launcher_apply_btop||
neovim||theme_launcher_apply_neovim||
tmux|theme_launcher_generate_tmux_config|theme_launcher_apply_tmux|theme_launcher_reload_tmux|tmux
lazygit|theme_launcher_generate_lazygit_config|theme_launcher_apply_lazygit||lazygit
fastfetch|theme_launcher_generate_fastfetch_config|theme_launcher_apply_fastfetch||fastfetch
bat|theme_launcher_generate_bat_config|theme_launcher_apply_bat||bat
fzf|theme_launcher_generate_fzf_shell|theme_launcher_apply_fzf||fzf
gtk|theme_launcher_generate_gtk_css|theme_launcher_apply_gtk_css||
vscode||theme_launcher_apply_vscode_family||code|code-insiders|codium|cursor
chromium||theme_launcher_apply_chromium||chromium-browser|chromium|google-chrome|brave-browser
EOF

theme_launcher_target_registry() {
  printf "%s" "$THEME_LAUNCHER_TARGET_REGISTRY"
}

theme_launcher_for_each_target() {
  local callback="$1"
  shift || true

  while IFS='|' read -r name generate_fn apply_fn reload_fn prerequisites; do
    [[ -n "$name" ]] || continue
    "$callback" "$name" "$generate_fn" "$apply_fn" "$reload_fn" "$prerequisites" "$@"
  done < <(theme_launcher_target_registry)
}

theme_launcher_canonical_target() {
  local target
  target="$(theme_launcher_slugify "$1")"

  case "$target" in
    gnome) printf "gnome" ;;
    dock|ubuntu-dock|dash-to-dock) printf "dock" ;;
    shell|gnome-shell|user-theme) printf "gnome-shell" ;;
    ghostty) printf "ghostty" ;;
    btop) printf "btop" ;;
    nvim|neovim) printf "neovim" ;;
    tmux) printf "tmux" ;;
    lazygit) printf "lazygit" ;;
    fastfetch) printf "fastfetch" ;;
    bat) printf "bat" ;;
    fzf) printf "fzf" ;;
    gtk|gtk-css|nautilus) printf "gtk" ;;
    code|code-insiders|codium|cursor|vscode) printf "vscode" ;;
    chrome|google-chrome|chromium|brave|brave-browser) printf "chromium" ;;
    *)
      return 1
      ;;
  esac
}

theme_launcher_parse_target_filter() {
  local input="$1"
  local raw_targets=()
  local raw_target
  local target
  local normalized=()
  local seen=" "

  IFS=',' read -r -a raw_targets <<< "$input"

  for raw_target in "${raw_targets[@]}"; do
    raw_target="$(printf "%s" "$raw_target" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [[ -n "$raw_target" ]] || continue

    if ! target="$(theme_launcher_canonical_target "$raw_target")"; then
      theme_launcher_fail "unknown target in filter: $raw_target"
    fi

    if [[ "$seen" != *" $target "* ]]; then
      normalized+=("$target")
      seen="${seen}${target} "
    fi
  done

  [[ "${#normalized[@]}" -gt 0 ]] || theme_launcher_fail "target filter is empty"

  printf "%s" "${normalized[0]}"
  for target in "${normalized[@]:1}"; do
    printf ",%s" "$target"
  done
}

theme_launcher_target_in_filter() {
  local target="$1"
  local filter="$2"
  local item
  local -a items=()

  [[ -n "$filter" ]] || return 1

  IFS=',' read -r -a items <<< "$filter"
  for item in "${items[@]}"; do
    [[ "$item" == "$target" ]] && return 0
  done

  return 1
}

theme_launcher_target_enabled() {
  local target="$1"
  local only="${THEME_LAUNCHER_TARGET_ONLY:-}"
  local skip="${THEME_LAUNCHER_TARGET_SKIP:-}"

  if [[ -n "$only" ]] && ! theme_launcher_target_in_filter "$target" "$only"; then
    return 1
  fi

  if [[ -n "$skip" ]] && theme_launcher_target_in_filter "$target" "$skip"; then
    return 1
  fi

  return 0
}

theme_launcher_risky_target_enabled() {
  local target="$1"
  local env_name=""

  case "$target" in
    gnome-shell) env_name="THEME_LAUNCHER_ENABLE_GNOME_SHELL" ;;
    chromium) env_name="THEME_LAUNCHER_ENABLE_CHROMIUM" ;;
    *)
      return 0
      ;;
  esac

  # If the user already excluded this target via --skip, stay silent.
  if theme_launcher_target_in_filter "$target" "${THEME_LAUNCHER_TARGET_SKIP:-}"; then
    return 1
  fi

  if theme_launcher_target_in_filter "$target" "${THEME_LAUNCHER_TARGET_ONLY:-}"; then
    return 0
  fi

  if [[ "${!env_name:-0}" == "1" ]]; then
    return 0
  fi

  theme_launcher_warn_once \
    "risky-target:$target" \
    "$target integration is disabled by default; re-run with --only $target or set $env_name=1 to enable it"
  return 1
}

theme_launcher_theme_variant() {
  local theme_dir="$1"

  if [[ -f "$theme_dir/theme.json" ]]; then
    local variant
    variant="$(jq -r '.variant // empty' "$theme_dir/theme.json" 2>/dev/null || true)"
    if [[ "$variant" == "light" || "$variant" == "dark" ]]; then
      printf "%s\n" "$variant"
      return 0
    fi
  fi

  if [[ -f "$theme_dir/light.mode" ]]; then
    printf "light\n"
  else
    printf "dark\n"
  fi
}

theme_launcher_theme_is_favorite() {
  local theme="$1"

  [[ -f "$THEME_LAUNCHER_FAVORITES_FILE" ]] || return 1
  grep -Fxq "$theme" "$THEME_LAUNCHER_FAVORITES_FILE"
}

theme_launcher_wallpaper_state_file() {
  local theme
  theme="$(theme_launcher_slugify "$1")"
  printf "%s/%s.name\n" "$THEME_LAUNCHER_WALLPAPER_STATE_DIR" "$theme"
}

theme_launcher_current_wallpaper() {
  [[ -f "$THEME_LAUNCHER_WALLPAPER_NAME_FILE" ]] && cat "$THEME_LAUNCHER_WALLPAPER_NAME_FILE" || true
}

theme_launcher_saved_wallpaper() {
  local file
  file="$(theme_launcher_wallpaper_state_file "$1")"
  [[ -f "$file" ]] && cat "$file" || true
}

theme_launcher_set_saved_wallpaper() {
  local theme="$1"
  local wallpaper_name="$2"
  local file

  file="$(theme_launcher_wallpaper_state_file "$theme")"
  mkdir -p "$THEME_LAUNCHER_WALLPAPER_STATE_DIR"
  if [[ -n "$wallpaper_name" ]]; then
    printf "%s\n" "$wallpaper_name" >"$file"
  else
    rm -f "$file"
  fi
}

theme_launcher_list_backgrounds() {
  local theme_dir="$1"
  find "$theme_dir/backgrounds" -maxdepth 1 -type f 2>/dev/null | sort
}

theme_launcher_random_background() {
  local theme_dir="$1"
  local backgrounds=()
  local index=0

  mapfile -t backgrounds < <(theme_launcher_list_backgrounds "$theme_dir")
  [[ "${#backgrounds[@]}" -gt 0 ]] || return 0

  if command -v shuf >/dev/null 2>&1; then
    printf "%s\n" "${backgrounds[@]}" | shuf -n 1
    return 0
  fi

  index=$((RANDOM % ${#backgrounds[@]}))
  printf "%s\n" "${backgrounds[$index]}"
}

theme_launcher_materialize_background() {
  local source_file="$1"
  local target_file="$2"

  mkdir -p "$(dirname "$target_file")"

  case "${source_file,,}" in
    *.png)
      cp -f "$source_file" "$target_file"
      return 0
      ;;
  esac

  if command -v python3 >/dev/null 2>&1; then
    if python3 "$THEME_LAUNCHER_PYTHON_DIR/normalize_png.py" "$source_file" "$target_file"; then
      return 0
    fi
  fi

  cp -f "$source_file" "$target_file"
}

theme_launcher_wallpaper_path() {
  local theme_dir="$1"
  local requested="$2"
  local background

  [[ -n "$requested" ]] || return 1

  while IFS= read -r background; do
    [[ -n "$background" ]] || continue
    if [[ "$(basename "$background")" == "$requested" || "$background" == "$requested" ]]; then
      printf "%s\n" "$background"
      return 0
    fi
  done < <(theme_launcher_list_backgrounds "$theme_dir")

  return 1
}

theme_launcher_resolve_wallpaper() {
  local theme="$1"
  local theme_dir="$2"
  local requested="${3:-}"
  local wallpaper=""
  local saved=""

  if [[ "$requested" == "$THEME_LAUNCHER_RANDOM_WALLPAPER_TOKEN" ]]; then
    theme_launcher_random_background "$theme_dir"
    return 0
  fi

  if wallpaper="$(theme_launcher_wallpaper_path "$theme_dir" "$requested" 2>/dev/null)"; then
    printf "%s\n" "$wallpaper"
    return 0
  fi

  saved="$(theme_launcher_saved_wallpaper "$theme")"
  if wallpaper="$(theme_launcher_wallpaper_path "$theme_dir" "$saved" 2>/dev/null)"; then
    printf "%s\n" "$wallpaper"
    return 0
  fi

  theme_launcher_list_backgrounds "$theme_dir" | head -n 1
}

theme_launcher_list_favorites() {
  [[ -f "$THEME_LAUNCHER_FAVORITES_FILE" ]] || return 0
  sort -u "$THEME_LAUNCHER_FAVORITES_FILE"
}

theme_launcher_set_favorite() {
  local requested_theme="$1"
  local enabled="$2"
  local theme
  local entry
  local -a entries=()
  local -a filtered=()

  theme="$(theme_launcher_slugify "$requested_theme")"
  theme_launcher_theme_exists "$theme" || theme_launcher_fail "unknown theme: $requested_theme"

  mkdir -p "$THEME_LAUNCHER_STATE_DIR"

  if [[ -f "$THEME_LAUNCHER_FAVORITES_FILE" ]]; then
    mapfile -t entries < "$THEME_LAUNCHER_FAVORITES_FILE"
  fi

  for entry in "${entries[@]}"; do
    [[ -n "$entry" && "$entry" != "$theme" ]] && filtered+=("$entry")
  done

  if [[ "$enabled" == "1" ]]; then
    filtered+=("$theme")
  fi

  if [[ "${#filtered[@]}" -eq 0 ]]; then
    rm -f "$THEME_LAUNCHER_FAVORITES_FILE"
  else
    printf "%s\n" "${filtered[@]}" | sort -u >"$THEME_LAUNCHER_FAVORITES_FILE"
  fi
}

theme_launcher_toggle_favorite() {
  local requested_theme="$1"
  local theme

  theme="$(theme_launcher_slugify "$requested_theme")"
  if theme_launcher_theme_is_favorite "$theme"; then
    theme_launcher_set_favorite "$theme" 0
    printf "removed\n"
  else
    theme_launcher_set_favorite "$theme" 1
    printf "added\n"
  fi
}

theme_launcher_theme_metadata() {
  local requested_theme="${1:-}"
  local theme
  local theme_dir
  local variant
  local default_name
  local preview_rel=""
  local preview_abs=""
  local metadata_file
  local custom_json="{}"
  local favorite_json="false"
  local wallpaper_json="[]"
  local selected_wallpaper=""
  local current_wallpaper=""
  local current_theme=""

  if [[ -n "$requested_theme" ]]; then
    theme="$(theme_launcher_slugify "$requested_theme")"
    theme_dir="$(theme_launcher_theme_path "$theme")"
    [[ -d "$theme_dir" ]] || theme_launcher_fail "unknown theme: $requested_theme"
  else
    theme_launcher_fail "missing theme name"
  fi

  metadata_file="$theme_dir/theme.json"
  if [[ -f "$metadata_file" ]]; then
    custom_json="$(jq -c '.' "$metadata_file" 2>/dev/null || printf '{}')"
  fi
  variant="$(theme_launcher_theme_variant "$theme_dir")"
  default_name="$(theme_launcher_display_name "$theme")"

  if [[ -f "$theme_dir/preview.png" ]]; then
    preview_rel="preview.png"
    preview_abs="$theme_dir/preview.png"
  fi

  if theme_launcher_theme_is_favorite "$theme"; then
    favorite_json="true"
  fi

  wallpaper_json="$(
    theme_launcher_list_backgrounds "$theme_dir" | while IFS= read -r background; do
      [[ -n "$background" ]] || continue
      jq -cn \
        --arg name "$(basename "$background")" \
        --arg label "$(basename "$background" | sed -E 's/\.[^.]+$//; s/^[0-9]+[-_]?//; s/[-_]+/ /g; s/\b(.)/\U\1/g')" \
        --arg path "$background" \
        '{name: $name, label: $label, path: $path}'
    done | jq -cs '.'
  )"

  selected_wallpaper="$(theme_launcher_saved_wallpaper "$theme")"
  if ! theme_launcher_wallpaper_path "$theme_dir" "$selected_wallpaper" >/dev/null 2>&1; then
    selected_wallpaper=""
  fi
  if [[ -z "$selected_wallpaper" ]]; then
    selected_wallpaper="$(printf "%s\n" "$wallpaper_json" | jq -r '.[0].name // ""')"
  fi

  current_theme="$(theme_launcher_current)"
  if [[ "$theme" == "$current_theme" ]]; then
    current_wallpaper="$(theme_launcher_current_wallpaper)"
  fi

  jq -n \
    --arg slug "$theme" \
    --arg default_name "$default_name" \
    --arg variant "$variant" \
    --arg preview_rel "$preview_rel" \
    --arg preview_abs "$preview_abs" \
    --argjson custom "$custom_json" \
    --argjson favorite "$favorite_json" \
    --argjson wallpapers "$wallpaper_json" \
    --arg selected_wallpaper "$selected_wallpaper" \
    --arg current_wallpaper "$current_wallpaper" \
    '
    {
        slug: $slug,
        name: ($custom.name // $default_name),
        variant: ($custom.variant // $variant),
        description: ($custom.description // ""),
        preview: ($custom.preview // $preview_rel),
        preview_path: (
          if ($custom.previewPath? // "") != "" then
            $custom.previewPath
          elif ($custom.preview // $preview_rel) != "" then
            $preview_abs
          else
            ""
          end
        ),
        badges: (
          (($custom.badges // []) | map(select(type == "string")))
          + [((($custom.variant // $variant) | ascii_upcase))]
        ),
        tags: (($custom.tags // []) | map(select(type == "string"))),
        wallpapers: $wallpapers,
        selected_wallpaper: $selected_wallpaper,
        current_wallpaper: (
          if $current_wallpaper != "" then $current_wallpaper else null end
        ),
        favorite: $favorite,
        source: (
          if ($custom | length) > 0 then "theme.json" else "inferred" end
        )
      }
    | .badges |= unique
    '
}

theme_launcher_all_theme_metadata() {
  theme_launcher_require python3
  python3 "$THEME_LAUNCHER_PYTHON_DIR/all_theme_metadata.py" \
    "$THEME_LAUNCHER_CUSTOM_THEMES_DIR" \
    "$THEME_LAUNCHER_BUNDLED_THEMES_DIR" \
    "$THEME_LAUNCHER_THEMES_DIR" \
    "$THEME_LAUNCHER_FAVORITES_FILE" \
    "$THEME_LAUNCHER_WALLPAPER_STATE_DIR" \
    "$THEME_LAUNCHER_THEME_NAME_FILE" \
    "$THEME_LAUNCHER_WALLPAPER_NAME_FILE"
}

theme_launcher_generate_previews() {
  local dry_run=0
  local replace=0
  local arg
  local python_cmd

  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      --dry-run|--list)
        dry_run=1
        ;;
      --replace)
        replace=1
        ;;
      *)
        theme_launcher_fail "unknown generate-previews option: $arg"
        ;;
    esac
    shift || true
  done

  python_cmd="$(theme_launcher_python_pillow_command)" || theme_launcher_fail "missing python3 with Pillow image support"

  "$python_cmd" "$THEME_LAUNCHER_PYTHON_DIR/generate_previews.py" \
    "$THEME_LAUNCHER_CUSTOM_THEMES_DIR" \
    "$THEME_LAUNCHER_THEMES_DIR" \
    "$THEME_LAUNCHER_STATE_DIR" \
    "$dry_run" \
    "$replace"
}


theme_launcher_audit_themes() {
  theme_launcher_require python3
  python3 "$THEME_LAUNCHER_PYTHON_DIR/audit_themes.py" \
    "$THEME_LAUNCHER_CUSTOM_THEMES_DIR" \
    "$THEME_LAUNCHER_THEMES_DIR"
}

theme_launcher_check_path_write() {
  local label="$1"
  local path="$2"

  if theme_launcher_path_writable "$path"; then
    theme_launcher_doctor_pass "$label" "$path"
  else
    theme_launcher_doctor_fail "$label" "not writable: $path"
  fi
}

theme_launcher_check_theme_assets() {
  local theme_dir="$1"
  local theme_name="$2"
  local colors_file="$theme_dir/colors.toml"
  local background
  local foreground
  local accent
  local background_dir="$theme_dir/backgrounds"
  local background_count
  local icon_theme
  local cursor_theme
  local chromium_theme_file="$theme_dir/chromium.theme"
  local vscode_json="$theme_dir/vscode.json"
  local metadata_file="$theme_dir/theme.json"
  local invalid=0
  local python_cmd=""

  if [[ ! -f "$colors_file" ]]; then
    theme_launcher_doctor_fail "theme:$theme_name" "missing colors.toml"
    return
  fi

  background="$(theme_launcher_color_value "$colors_file" background)"
  foreground="$(theme_launcher_color_value "$colors_file" foreground)"
  accent="$(theme_launcher_color_value "$colors_file" accent)"

  if [[ -z "$background" || -z "$foreground" || -z "$accent" ]]; then
    theme_launcher_doctor_fail "theme:$theme_name" "colors.toml must define background, foreground, and accent"
    return
  fi

  if [[ -d "$background_dir" ]]; then
    background_count="$(find "$background_dir" -maxdepth 1 -type f | wc -l | tr -d ' ')"
    if [[ "$background_count" -eq 0 ]]; then
      theme_launcher_doctor_warn "theme:$theme_name" "backgrounds directory is empty"
    fi
  fi

  if [[ -f "$theme_dir/icons.theme" ]]; then
    icon_theme="$(tr -d '[:space:]' <"$theme_dir/icons.theme")"
    if [[ -z "$icon_theme" ]]; then
      theme_launcher_doctor_fail "theme:$theme_name" "icons.theme is empty"
      invalid=1
    fi
  fi

  if [[ -f "$theme_dir/cursor.theme" ]]; then
    cursor_theme="$(tr -d '[:space:]' <"$theme_dir/cursor.theme")"
    if [[ -z "$cursor_theme" ]]; then
      theme_launcher_doctor_fail "theme:$theme_name" "cursor.theme is empty"
      invalid=1
    fi
  fi

  if [[ -f "$chromium_theme_file" ]]; then
    if [[ ! "$(<"$chromium_theme_file")" =~ ^[[:space:]]*[0-9]{1,3}[[:space:]]*,[[:space:]]*[0-9]{1,3}[[:space:]]*,[[:space:]]*[0-9]{1,3}[[:space:]]*$ ]]; then
      theme_launcher_doctor_fail "theme:$theme_name" "chromium.theme must be an r,g,b triplet"
      invalid=1
    fi
  fi

  if [[ -f "$vscode_json" ]]; then
    if ! jq -e '.name and (.name | type == "string") and ((.extension // "") | type == "string")' "$vscode_json" >/dev/null 2>&1; then
      theme_launcher_doctor_fail "theme:$theme_name" "vscode.json must contain a string name and optional string extension"
      invalid=1
    fi
  fi

  if [[ -f "$metadata_file" ]]; then
    if ! jq -e '
      type == "object"
      and ((.name // "") | type == "string")
      and ((.description // "") | type == "string")
      and ((.variant // "dark") | IN("light", "dark"))
      and ((.preview // "") | type == "string")
      and ((.badges // []) | type == "array")
      and ((.tags // []) | type == "array")
    ' "$metadata_file" >/dev/null 2>&1; then
      theme_launcher_doctor_fail "theme:$theme_name" "theme.json has an invalid shape"
      invalid=1
    fi
  fi

  if [[ ! -f "$theme_dir/preview.png" ]]; then
    theme_launcher_doctor_warn "theme:$theme_name" "missing preview.png"
  elif python_cmd="$(theme_launcher_python_pillow_command 2>/dev/null)"; then
    if ! "$python_cmd" "$THEME_LAUNCHER_PYTHON_DIR/check_preview_size.py" "$theme_dir/preview.png" >/dev/null 2>&1; then
      theme_launcher_doctor_warn "theme:$theme_name" "preview.png should be the standard 1366x768 workspace preview"
    fi
  fi

  if [[ -d "$background_dir" ]] && find "$background_dir" -maxdepth 1 -type f -iname '*omarchy*' | grep -q .; then
    theme_launcher_doctor_warn "theme:$theme_name" "background filename contains omarchy"
  fi

  if [[ "$invalid" -eq 0 ]]; then
    theme_launcher_doctor_pass "theme:$theme_name" "core assets look valid"
  fi
}

theme_launcher_doctor() {
  local themes=()
  local theme
  local theme_dir
  local current_theme
  local previous_theme
  local default_theme
  local desktop_session=0
  local gnome_session=0
  local user_theme_extension="user-theme@gnome-shell-extensions.gcampax.github.com"
  local user_ext_dir="$HOME/.local/share/gnome-shell/extensions/$user_theme_extension"
  local system_ext_dir="/usr/share/gnome-shell/extensions/$user_theme_extension"
  local user_theme_metadata=""
  local shell_major=""
  local user_theme_supported=0
  local ubuntu_dock_schema=""
  local has_chromium=0
  local policy_dir
  local chromium_policy_writable=0

  THEME_LAUNCHER_DOCTOR_FAILURES=0
  THEME_LAUNCHER_DOCTOR_WARNINGS=0

  printf "Theme Launcher doctor\n"
  printf "home: %s\n" "$THEME_LAUNCHER_HOME"

  theme_launcher_check_required_command "awk"
  theme_launcher_check_required_command "cp"
  theme_launcher_check_required_command "find"
  theme_launcher_check_required_command "jq"
  theme_launcher_check_required_command "ln"
  theme_launcher_check_required_command "mktemp"
  theme_launcher_check_required_command "mv"
  theme_launcher_check_required_command "python3"
  theme_launcher_check_required_command "sed"

  theme_launcher_check_path_write "launcher-home" "$THEME_LAUNCHER_HOME"
  theme_launcher_check_path_write "state-dir" "$THEME_LAUNCHER_STATE_DIR"

  if [[ -n "$THEME_LAUNCHER_VENDOR_FALLBACK" ]]; then
    theme_launcher_doctor_warn "theme-catalog-path" "using fallback vendor path: $THEME_LAUNCHER_VENDOR_FALLBACK"
  fi

  if [[ -d "$THEME_LAUNCHER_BUNDLED_THEMES_DIR" ]]; then
    theme_launcher_doctor_pass "bundled-themes-dir" "$THEME_LAUNCHER_BUNDLED_THEMES_DIR"
  else
    theme_launcher_doctor_warn "bundled-themes-dir" "missing: $THEME_LAUNCHER_BUNDLED_THEMES_DIR"
  fi

  if [[ -d "$THEME_LAUNCHER_THEMES_DIR" ]]; then
    theme_launcher_doctor_pass "synced-themes-dir" "$THEME_LAUNCHER_THEMES_DIR"
  else
    theme_launcher_doctor_warn "synced-themes-dir" "missing: $THEME_LAUNCHER_THEMES_DIR"
  fi

  if [[ -d "$THEME_LAUNCHER_CUSTOM_THEMES_DIR" ]]; then
    theme_launcher_doctor_pass "custom-themes-dir" "$THEME_LAUNCHER_CUSTOM_THEMES_DIR"
  else
    theme_launcher_doctor_warn "custom-themes-dir" "missing: $THEME_LAUNCHER_CUSTOM_THEMES_DIR"
  fi

  mapfile -t themes < <(theme_launcher_list)
  if [[ "${#themes[@]}" -eq 0 ]]; then
    theme_launcher_doctor_fail "theme-catalog" "no themes installed; run: theme-launcher sync"
  else
    theme_launcher_doctor_pass "theme-catalog" "${#themes[@]} theme(s)"
  fi

  for theme in "${themes[@]}"; do
    theme_dir="$(theme_launcher_theme_path "$theme")"
    theme_launcher_check_theme_assets "$theme_dir" "$theme"
  done

  current_theme="$(theme_launcher_current)"
  previous_theme="$(theme_launcher_previous)"
  default_theme="$(theme_launcher_default)"

  if [[ -n "$current_theme" ]]; then
    if theme_launcher_theme_exists "$current_theme"; then
      theme_launcher_doctor_pass "current-theme" "$current_theme"
    else
      theme_launcher_doctor_fail "current-theme" "stored theme is missing from catalog: $current_theme"
    fi
  else
    theme_launcher_doctor_warn "current-theme" "no active theme stored yet"
  fi

  if [[ -n "$previous_theme" ]]; then
    if theme_launcher_theme_exists "$previous_theme"; then
      theme_launcher_doctor_pass "previous-theme" "$previous_theme"
    else
      theme_launcher_doctor_fail "previous-theme" "stored theme is missing from catalog: $previous_theme"
    fi
  fi

  if [[ -n "$default_theme" ]]; then
    if theme_launcher_theme_exists "$default_theme"; then
      theme_launcher_doctor_pass "default-theme" "$default_theme"
    else
      theme_launcher_doctor_fail "default-theme" "stored theme is missing from catalog: $default_theme"
    fi
  fi

  if theme_launcher_in_graphical_session; then
    desktop_session=1
  fi

  if theme_launcher_in_gnome_session; then
    gnome_session=1
  fi

  if command -v gsettings >/dev/null 2>&1; then
    if [[ "$desktop_session" -eq 1 && "$gnome_session" -eq 1 ]]; then
      if gsettings get org.gnome.desktop.interface color-scheme >/dev/null 2>&1; then
        theme_launcher_doctor_pass "gsettings" "GNOME settings writable in this session"
      else
        theme_launcher_doctor_warn "gsettings" "installed, but GNOME settings are not accessible right now"
      fi
    elif [[ "$desktop_session" -eq 1 ]]; then
      theme_launcher_doctor_warn "gsettings" "graphical session detected, but it does not look like GNOME"
    else
      theme_launcher_doctor_warn "gsettings" "no graphical GNOME session detected"
    fi
  else
    theme_launcher_doctor_warn "gsettings" "GNOME integration will be skipped because gsettings is missing"
  fi

  if theme_launcher_python_gtk_available; then
    theme_launcher_doctor_pass "gtk-gui" "python3-gi with GTK 4 is available"
  else
    theme_launcher_doctor_warn "gtk-gui" "theme-launcher gui needs python3-gi and GTK 4 bindings"
  fi

  if [[ -d "$user_ext_dir" || -d "$system_ext_dir" ]]; then
    theme_launcher_doctor_pass "gnome-shell:user-theme" "extension files found"
  else
    theme_launcher_doctor_warn "gnome-shell:user-theme" "missing extension files; GNOME Shell top bar theming will not apply"
  fi

  user_theme_metadata="$user_ext_dir/metadata.json"
  if [[ ! -f "$user_theme_metadata" ]]; then
    user_theme_metadata="$system_ext_dir/metadata.json"
  fi
  if [[ -f "$user_theme_metadata" ]] && shell_major="$(theme_launcher_gnome_shell_major_version)"; then
    if jq -e --arg shell_major "$shell_major" '
      .["shell-version"] // []
      | map(tostring | split(".")[0])
      | index($shell_major)
    ' "$user_theme_metadata" >/dev/null 2>&1; then
      user_theme_supported=1
    fi
    if [[ "$user_theme_supported" -eq 1 ]]; then
      theme_launcher_doctor_pass "gnome-shell:user-theme-version" "declares GNOME Shell $shell_major support"
    else
      theme_launcher_doctor_warn "gnome-shell:user-theme-version" "extension metadata does not list GNOME Shell $shell_major"
    fi
  fi

  theme_launcher_doctor_pass "gnome-shell" "panel theming runs during normal applies when the user-theme extension is available"

  if ubuntu_dock_schema="$(theme_launcher_ubuntu_dock_schema)"; then
    theme_launcher_doctor_pass "ubuntu-dock" "settings schema available: $ubuntu_dock_schema"
  else
    theme_launcher_doctor_warn "ubuntu-dock" "dock settings schema is unavailable on this GNOME build; dock color tweaks will be skipped"
  fi

  if [[ -x "$HOME/.local/bin/ghostty" || -x "/snap/bin/ghostty" || -x "$(command -v ghostty 2>/dev/null || true)" ]]; then
    theme_launcher_doctor_pass "ghostty" "$(command -v ghostty 2>/dev/null || printf "installed")"
  else
    theme_launcher_doctor_warn "ghostty" "not installed; Ghostty integration will be skipped"
  fi

  if theme_launcher_chromium_installed; then
    has_chromium=1
  fi

  if [[ "$has_chromium" -eq 1 ]]; then
    for policy_dir in "${THEME_LAUNCHER_CHROMIUM_POLICY_DIRS[@]}"; do
      if [[ -d "$policy_dir" && -w "$policy_dir" ]]; then
        chromium_policy_writable=1
        break
      fi
      if [[ -d "$(dirname "$policy_dir")" && -w "$(dirname "$policy_dir")" ]]; then
        chromium_policy_writable=1
        break
      fi
    done

    if [[ "$chromium_policy_writable" -eq 1 ]]; then
      theme_launcher_doctor_pass "chromium-policy" "writable policy directory available"
    else
      theme_launcher_doctor_warn "chromium-policy" "browser is installed but managed policy directories are not writable"
    fi

    if [[ "${THEME_LAUNCHER_ENABLE_CHROMIUM:-0}" == "1" ]]; then
      theme_launcher_doctor_pass "chromium:opt-in" "enabled by THEME_LAUNCHER_ENABLE_CHROMIUM=1"
    else
      theme_launcher_doctor_warn "chromium:opt-in" "disabled by default; use --only chromium or set THEME_LAUNCHER_ENABLE_CHROMIUM=1"
    fi
  fi

  printf "\nSummary: %s failure(s), %s warning(s)\n" \
    "$THEME_LAUNCHER_DOCTOR_FAILURES" \
    "$THEME_LAUNCHER_DOCTOR_WARNINGS"

  [[ "$THEME_LAUNCHER_DOCTOR_FAILURES" -eq 0 ]]
}

theme_launcher_list() {
  local root
  local -a roots=()

  while IFS= read -r root; do
    [[ -d "$root" ]] || continue
    roots+=("$root")
  done < <(theme_launcher_theme_roots)

  [[ "${#roots[@]}" -gt 0 ]] || return 0

  find "${roots[@]}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -u
}

theme_launcher_current() {
  [[ -f "$THEME_LAUNCHER_THEME_NAME_FILE" ]] && cat "$THEME_LAUNCHER_THEME_NAME_FILE" || true
}

theme_launcher_default() {
  [[ -f "$THEME_LAUNCHER_DEFAULT_THEME_FILE" ]] && cat "$THEME_LAUNCHER_DEFAULT_THEME_FILE" || true
}

theme_launcher_bootstrap() {
  theme_launcher_require python3
  python3 "$THEME_LAUNCHER_PYTHON_DIR/bootstrap.py" \
    "$THEME_LAUNCHER_CUSTOM_THEMES_DIR" \
    "$THEME_LAUNCHER_BUNDLED_THEMES_DIR" \
    "$THEME_LAUNCHER_THEMES_DIR" \
    "$THEME_LAUNCHER_FAVORITES_FILE" \
    "$THEME_LAUNCHER_WALLPAPER_STATE_DIR" \
    "$THEME_LAUNCHER_THEME_NAME_FILE" \
    "$THEME_LAUNCHER_WALLPAPER_NAME_FILE" \
    "$THEME_LAUNCHER_DEFAULT_THEME_FILE"
}

theme_launcher_set_default_theme() {
  local theme

  theme="$(theme_launcher_slugify "$1")"
  theme_launcher_theme_exists "$theme" || theme_launcher_fail "unknown theme: $1"

  mkdir -p "$THEME_LAUNCHER_STATE_DIR"
  printf "%s\n" "$theme" >"$THEME_LAUNCHER_DEFAULT_THEME_FILE"
}

theme_launcher_apply_default_theme() {
  local theme
  local requested_wallpaper="${1:-}"

  theme="$(theme_launcher_default)"
  [[ -n "$theme" ]] || theme_launcher_fail "no default theme set"
  theme_launcher_apply_theme "$theme" "$requested_wallpaper"
}

theme_launcher_previous() {
  [[ -f "$THEME_LAUNCHER_PREVIOUS_THEME_FILE" ]] && cat "$THEME_LAUNCHER_PREVIOUS_THEME_FILE" || true
}

theme_launcher_apply_previous_theme() {
  local theme
  local requested_wallpaper="${1:-}"

  theme="$(theme_launcher_previous)"
  [[ -n "$theme" ]] || theme_launcher_fail "no previous theme available"
  theme_launcher_apply_theme "$theme" "$requested_wallpaper"
}

theme_launcher_theme_json_field() {
  local json_file="$1"
  local field="$2"
  [[ -f "$json_file" ]] || return 1
  jq -r ".$field // empty" "$json_file"
}

theme_launcher_color_value() {
  local colors_file="$1"
  local key="$2"
  [[ -f "$colors_file" ]] || return 1
  awk -F '=' -v key="$key" '
    {
      gsub(/[ "'"'"'\t]/, "", $1)
      if ($1 == key) {
        value=$2
        gsub(/^[^#a-zA-Z0-9"]+/, "", value)
        gsub(/[ "'"'"'\t]/, "", value)
        print value
        exit
      }
    }
  ' "$colors_file"
}

theme_launcher_load_colors_into() {
  local colors_file="$1"
  local -n target="$2"
  local line key value

  [[ -f "$colors_file" ]] || return 1
  target=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    key="${key//[\"\'[:space:]]/}"
    [[ -n "$key" && "${key:0:1}" != "#" ]] || continue
    value="${line#*=}"
    value="${value//[\"\'[:space:]]/}"
    [[ -n "$value" ]] || continue
    target[$key]="$value"
  done <"$colors_file"
}

theme_launcher_fastfetch_color() {
  local value="$1"
  local fallback="$2"

  value="${value//[[:space:]]/}"
  fallback="${fallback//[[:space:]]/}"

  if [[ "$value" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    printf "%s\n" "$value"
    return 0
  fi

  if [[ "$value" =~ ^[0-9a-fA-F]{6}$ ]]; then
    printf "#%s\n" "$value"
    return 0
  fi

  if [[ "$fallback" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    printf "%s\n" "$fallback"
    return 0
  fi

  printf "#ffffff\n"
}

theme_launcher_fastfetch_format_color() {
  local value
  value="$(theme_launcher_fastfetch_color "$1" "$2")"
  printf "%s\n" "${value#\#}"
}

theme_launcher_escape_sed_replacement() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\//\\/}"
  s="${s//&/\\&}"
  s="${s//|/\\|}"
  printf "%s" "$s"
}

theme_launcher_write_marked_block() {
  local file="$1"
  local block="$2"
  local begin="$3"
  local end="$4"
  local legacy_begin="${5:-}"
  local legacy_end="${6:-}"
  local tmp

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : >"$file"

  if ! grep -Fqx "$begin" "$file" 2>/dev/null &&
    { [[ -z "$legacy_begin" ]] || ! grep -Fqx "$legacy_begin" "$file" 2>/dev/null; }; then
    cp -a "$file" "$file.theme-launcher.bak" 2>/dev/null || true
  fi

  tmp="$(mktemp)"
  awk \
    -v begin="$begin" \
    -v end="$end" \
    -v legacy_begin="$legacy_begin" \
    -v legacy_end="$legacy_end" \
    '
    $0 == begin || (legacy_begin != "" && $0 == legacy_begin) { skip=1; next }
    $0 == end || (legacy_end != "" && $0 == legacy_end) { skip=0; next }
    skip == 1 { next }
    /^[[:space:]]*$/ { blanks=blanks $0 "\n"; next }
    { printf "%s%s\n", blanks, $0; blanks="" }
  ' "$file" >"$tmp"

  if [[ -s "$tmp" ]]; then
    printf "\n" >>"$tmp"
  fi

  {
    cat "$tmp"
    printf "%s\n" "$begin"
    printf "%s\n" "$block"
    printf "%s\n" "$end"
  } >"$file"

  rm -f "$tmp"
}

theme_launcher_write_managed_block() {
  theme_launcher_write_marked_block \
    "$1" \
    "$2" \
    "$THEME_LAUNCHER_MARKER_BEGIN" \
    "$THEME_LAUNCHER_MARKER_END"
}

theme_launcher_write_css_managed_block() {
  local file="$1"
  local block="$2"
  local css_begin="/* theme-launcher begin */"
  local css_end="/* theme-launcher end */"

  theme_launcher_write_marked_block \
    "$file" \
    "$block" \
    "$css_begin" \
    "$css_end" \
    "$THEME_LAUNCHER_MARKER_BEGIN" \
    "$THEME_LAUNCHER_MARKER_END"
}

theme_launcher_update_jsonc_setting() {
  local file="$1"
  local key="$2"
  local value_json="$3"
  local tmp
  local key_pattern

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || printf "{\n}\n" >"$file"
  cp -a "$file" "$file.theme-launcher.bak" 2>/dev/null || true

  tmp="$(mktemp)"
  key_pattern="$(printf "%s" "$key" | sed -E 's/[][(){}.^$*+?|\\/]/\\&/g')"

  if grep -Eq "\"$key_pattern\"[[:space:]]*:" "$file"; then
    sed -E "s|(\"$key_pattern\"[[:space:]]*:[[:space:]]*)[^,}]*([[:space:]]*,?)|\1${value_json}\2|" "$file" >"$tmp"
  elif grep -Eq '^[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$file"; then
    printf "{\n  \"%s\": %s\n}\n" "$key" "$value_json" >"$tmp"
  else
    awk -v key="$key" -v value_json="$value_json" '
      BEGIN { inserted = 0 }
      /^\{/ && inserted == 0 {
        print
        print "  \"" key "\": " value_json ","
        inserted = 1
        next
      }
      { print }
    ' "$file" >"$tmp"
  fi

  mv "$tmp" "$file"
}

theme_launcher_try_gsettings() {
  gsettings set "$1" "$2" "$3" >/dev/null 2>&1
}

theme_launcher_update_line_setting() {
  local file="$1"
  local key="$2"
  local value="$3"

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : >"$file"
  cp -a "$file" "$file.theme-launcher.bak" 2>/dev/null || true

  if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
  else
    printf "%s = %s\n" "$key" "$value" >>"$file"
  fi
}

theme_launcher_generate_templates() {
  local colors_file="$THEME_LAUNCHER_NEXT_DIR/colors.toml"
  local sed_script
  local tpl
  local output_path
  local rgb
  local key
  local value

  [[ -f "$colors_file" ]] || return 0
  mkdir -p "$THEME_LAUNCHER_NEXT_DIR"
  sed_script="$(mktemp)"

  while IFS='=' read -r key value; do
    key="${key//[\"\' $'\t']/}"
    [[ -n "$key" ]] || continue
    [[ "$key" != \#* ]] || continue

    value="${value#*[\"\']}"
    value="${value%%[\"\']*}"

    local escaped_value escaped_strip escaped_key
    escaped_key="$(theme_launcher_escape_sed_replacement "$key")"
    escaped_value="$(theme_launcher_escape_sed_replacement "$value")"
    escaped_strip="$(theme_launcher_escape_sed_replacement "${value#\#}")"
    printf 's|{{ %s }}|%s|g\n' "$escaped_key" "$escaped_value"
    printf 's|{{ %s_strip }}|%s|g\n' "${escaped_key}" "$escaped_strip"
    if [[ "$value" =~ ^#[0-9a-fA-F]{6}$ ]]; then
      rgb="$(printf '%d,%d,%d' "0x${value:1:2}" "0x${value:3:2}" "0x${value:5:2}")"
      printf 's|{{ %s_rgb }}|%s|g\n' "${escaped_key}" "$rgb"
    fi
  done <"$colors_file" >"$sed_script"

  shopt -s nullglob
  for tpl in "$THEME_LAUNCHER_VENDOR_TEMPLATES_DIR"/*.tpl; do
    output_path="$THEME_LAUNCHER_NEXT_DIR/$(basename "$tpl" .tpl)"
    [[ -f "$output_path" ]] && continue
    sed -f "$sed_script" "$tpl" >"$output_path"
  done
  shopt -u nullglob

  rm -f "$sed_script"
}

theme_launcher_generate_tmux_config() {
  local colors_file="$THEME_LAUNCHER_NEXT_DIR/colors.toml"
  local accent
  local foreground
  local background
  local muted
  local active
  local -A _colors

  [[ -f "$colors_file" ]] || return 0
  theme_launcher_load_colors_into "$colors_file" _colors

  accent="${_colors[accent]:-}"
  foreground="${_colors[foreground]:-}"
  background="${_colors[background]:-}"
  muted="${_colors[color8]:-}"
  active="${_colors[color4]:-}"

  cat >"$THEME_LAUNCHER_NEXT_DIR/tmux.conf" <<EOF
# Generated by theme-launcher
set -g status-position top
set -g status-interval 5
set -g status-left-length 30
set -g status-right-length 50
set -g window-status-separator ""
set -gw automatic-rename on
set -gw automatic-rename-format '#{b:pane_current_path}'

set -g status-style "bg=${background},fg=${foreground}"
set -g status-left "#[fg=${background},bg=${active},bold] #S #[fg=${foreground},bg=${background}] "
set -g status-right "#[fg=${accent}]#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}#[fg=${muted}]#h "
set -g window-status-format "#[fg=${muted}] #I:#W "
set -g window-status-current-format "#[fg=${active},bold] #I:#W "
set -g pane-border-style "fg=${muted}"
set -g pane-active-border-style "fg=${accent}"
set -g message-style "bg=${background},fg=${accent}"
set -g message-command-style "bg=${background},fg=${accent}"
set -g mode-style "bg=${accent},fg=${background}"
setw -g clock-mode-colour "${active}"
EOF
}

theme_launcher_generate_lazygit_config() {
  local colors_file="$THEME_LAUNCHER_NEXT_DIR/colors.toml"
  local accent
  local foreground
  local background
  local muted
  local success
  local warning
  local danger
  local secondary
  local -A _colors

  [[ -f "$colors_file" ]] || return 0
  theme_launcher_load_colors_into "$colors_file" _colors

  accent="${_colors[accent]:-}"
  foreground="${_colors[foreground]:-}"
  background="${_colors[background]:-}"
  muted="${_colors[color8]:-}"
  success="${_colors[color2]:-}"
  warning="${_colors[color3]:-}"
  danger="${_colors[color1]:-}"
  secondary="${_colors[color6]:-}"

  cat >"$THEME_LAUNCHER_NEXT_DIR/lazygit.yml" <<EOF
# Generated by theme-launcher
gui:
  nerdFontsVersion: "3"
  authorColors:
    "*": "${success}"
  branchColorPatterns:
    "main|master": "${accent}"
    "^release/": "${warning}"
    "^hotfix/": "${danger}"
  theme:
    activeBorderColor:
      - "${accent}"
      - bold
    inactiveBorderColor:
      - "${muted}"
    searchingActiveBorderColor:
      - "${warning}"
      - bold
    optionsTextColor:
      - "${secondary}"
    selectedLineBgColor:
      - "${background}"
    selectedRangeBgColor:
      - "${muted}"
    cherryPickedCommitBgColor:
      - "${muted}"
    cherryPickedCommitFgColor:
      - "${accent}"
    unstagedChangesColor:
      - "${warning}"
    defaultFgColor:
      - "${foreground}"
git:
  paging:
    colorArg: always
os:
  editPreset: codium
refresher:
  refreshInterval: 10
update:
  method: never
confirmOnQuit: false
notARepository: skip
customCommands: []
EOF
}

theme_launcher_generate_fastfetch_config() {
  local theme_slug="$1"
  local colors_file="$THEME_LAUNCHER_NEXT_DIR/colors.toml"
  local accent
  local foreground
  local success
  local warning
  local danger
  local secondary
  local muted
  local accent_ff
  local foreground_ff
  local success_ff
  local warning_ff
  local danger_ff
  local secondary_ff
  local muted_ff
  local accent_format
  local foreground_format
  local muted_format
  local theme_name
  local -A _colors

  [[ -f "$colors_file" ]] || return 0
  theme_launcher_load_colors_into "$colors_file" _colors

  accent="${_colors[accent]:-}"
  foreground="${_colors[foreground]:-}"
  success="${_colors[color2]:-}"
  warning="${_colors[color3]:-}"
  danger="${_colors[color1]:-}"
  secondary="${_colors[color6]:-}"
  muted="${_colors[color8]:-}"
  theme_name="$(theme_launcher_display_name "$theme_slug")"

  accent_ff="$(theme_launcher_fastfetch_color "$accent" "#00aaff")"
  foreground_ff="$(theme_launcher_fastfetch_color "$foreground" "#ffffff")"
  success_ff="$(theme_launcher_fastfetch_color "$success" "$accent_ff")"
  warning_ff="$(theme_launcher_fastfetch_color "$warning" "$accent_ff")"
  danger_ff="$(theme_launcher_fastfetch_color "$danger" "$accent_ff")"
  secondary_ff="$(theme_launcher_fastfetch_color "$secondary" "$accent_ff")"
  muted_ff="$(theme_launcher_fastfetch_color "$muted" "$foreground_ff")"
  accent_format="$(theme_launcher_fastfetch_format_color "$accent_ff" "#00aaff")"
  foreground_format="$(theme_launcher_fastfetch_format_color "$foreground_ff" "#ffffff")"
  muted_format="$(theme_launcher_fastfetch_format_color "$muted_ff" "$foreground_ff")"

  cat >"$THEME_LAUNCHER_NEXT_DIR/fastfetch.jsonc" <<EOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "display": {
    "separator": "  "
  },
  "modules": [
    "break",
    {
      "type": "custom",
      "format": "{#${muted_format}}theme-launcher"
    },
    {
      "type": "custom",
      "format": "{#${accent_format}}Theme{#${foreground_format}}  ${theme_name}"
    },
    {
      "type": "os",
      "key": "OS",
      "keyColor": "${accent_ff}"
    },
    {
      "type": "kernel",
      "key": "Kernel",
      "keyColor": "${secondary_ff}"
    },
    {
      "type": "wm",
      "key": "WM",
      "keyColor": "${secondary_ff}"
    },
    {
      "type": "de",
      "key": "DE",
      "keyColor": "${secondary_ff}"
    },
    {
      "type": "terminal",
      "key": "Terminal",
      "keyColor": "${success_ff}"
    },
    {
      "type": "shell",
      "key": "Shell",
      "keyColor": "${success_ff}"
    },
    {
      "type": "packages",
      "key": "Packages",
      "keyColor": "${warning_ff}"
    },
    {
      "type": "uptime",
      "key": "Uptime",
      "keyColor": "${warning_ff}"
    },
    {
      "type": "memory",
      "key": "Memory",
      "keyColor": "${danger_ff}"
    },
    "break",
    {
      "type": "colors"
    }
  ]
}
EOF
}

theme_launcher_generate_bat_config() {
  local theme_slug="$1"
  local bat_theme

  bat_theme="$(theme_launcher_bat_theme_name "$theme_slug")"

  cat >"$THEME_LAUNCHER_NEXT_DIR/bat.conf" <<EOF
# Generated by theme-launcher
--theme="${bat_theme}"
--style="numbers,changes,header"
--paging=never
EOF
}

theme_launcher_generate_fzf_shell() {
  local colors_file="$THEME_LAUNCHER_NEXT_DIR/colors.toml"
  local accent
  local foreground
  local background
  local selection_fg
  local selection_bg
  local muted
  local warning
  local danger
  local success
  local secondary
  local color_spec
  local -A _colors

  [[ -f "$colors_file" ]] || return 0
  theme_launcher_load_colors_into "$colors_file" _colors

  accent="${_colors[accent]:-}"
  foreground="${_colors[foreground]:-}"
  background="${_colors[background]:-}"
  selection_fg="${_colors[selection_foreground]:-}"
  selection_bg="${_colors[selection_background]:-}"
  muted="${_colors[color8]:-}"
  warning="${_colors[color3]:-}"
  danger="${_colors[color1]:-}"
  success="${_colors[color2]:-}"
  secondary="${_colors[color6]:-}"

  color_spec="bg:${background},bg+:${selection_bg},fg:${foreground},fg+:${selection_fg},hl:${accent},hl+:${accent},info:${secondary},prompt:${accent},pointer:${danger},marker:${warning},spinner:${success},header:${muted},border:${muted},label:${secondary},query:${foreground}"

  cat >"$THEME_LAUNCHER_NEXT_DIR/fzf.bash" <<EOF
# Generated by theme-launcher
export FZF_DEFAULT_OPTS="\${FZF_DEFAULT_OPTS:-} --style=full --layout=reverse --border=rounded --height=80% --preview-border=rounded --color=${color_spec}"
EOF
}

theme_launcher_generate_gtk_css() {
  local colors_file="$THEME_LAUNCHER_NEXT_DIR/colors.toml"
  local accent
  local foreground
  local background
  local selection_fg
  local selection_bg
  local muted
  local secondary_bg
  local -A _colors

  [[ -f "$colors_file" ]] || return 0
  theme_launcher_load_colors_into "$colors_file" _colors

  accent="${_colors[accent]:-}"
  foreground="${_colors[foreground]:-}"
  background="${_colors[background]:-}"
  selection_fg="${_colors[selection_foreground]:-}"
  selection_bg="${_colors[selection_background]:-}"
  muted="${_colors[color8]:-}"
  secondary_bg="${_colors[color0]:-}"

  cat >"$THEME_LAUNCHER_NEXT_DIR/gtk-3.0.css" <<EOF
/* Generated by theme-launcher */
@define-color accent_color ${accent};
@define-color accent_bg_color ${accent};
@define-color accent_fg_color ${selection_fg};
@define-color window_bg_color ${background};
@define-color window_fg_color ${foreground};
@define-color view_bg_color ${background};
@define-color view_fg_color ${foreground};
@define-color headerbar_bg_color ${secondary_bg};
@define-color headerbar_fg_color ${foreground};
@define-color sidebar_bg_color ${secondary_bg};
@define-color sidebar_fg_color ${foreground};
@define-color dialog_bg_color ${secondary_bg};
@define-color card_bg_color ${secondary_bg};
@define-color borders ${muted};

window.nautilus-window,
window.nautilus-window > widget,
window.nautilus-window .background,
window.nautilus-window .view,
window.nautilus-window listview,
window.nautilus-window gridview,
window.nautilus-window columnview {
  background-color: @window_bg_color;
  color: @window_fg_color;
}

window.nautilus-window headerbar,
window.nautilus-window .titlebar {
  background-color: @headerbar_bg_color;
  color: @headerbar_fg_color;
  box-shadow: none;
}

window.nautilus-window headerbar:backdrop,
window.nautilus-window .titlebar:backdrop {
  background-color: @sidebar_bg_color;
  color: @headerbar_fg_color;
}

window.nautilus-window placessidebar,
window.nautilus-window .sidebar,
window.nautilus-window navigation-sidebar {
  background-color: @sidebar_bg_color;
  color: @sidebar_fg_color;
}

window.nautilus-window row:selected,
window.nautilus-window item:selected,
window.nautilus-window .view:selected,
window.nautilus-window .view text:selected,
window.nautilus-window treeview.view:selected,
window.nautilus-window listview row:selected,
window.nautilus-window gridview child:selected,
window.nautilus-window columnview row:selected {
  background-color: ${selection_bg};
  color: ${selection_fg};
}

window.nautilus-window button.suggested-action,
window.nautilus-window progressbar progress,
window.nautilus-window tab:selected,
window.nautilus-window tab:checked {
  background-color: @accent_bg_color;
  color: @accent_fg_color;
}

window.nautilus-window separator,
window.nautilus-window border,
window.nautilus-window undershoot {
  color: @borders;
}
EOF
  cp -f "$THEME_LAUNCHER_NEXT_DIR/gtk-3.0.css" "$THEME_LAUNCHER_NEXT_DIR/gtk-4.0.css"
}

theme_launcher_generate_gnome_shell_css() {
  local colors_file="$THEME_LAUNCHER_NEXT_DIR/colors.toml"
  local accent
  local foreground
  local background
  local selection_fg
  local selection_bg
  local muted
  local shell_css
  local -A _colors

  [[ -f "$colors_file" ]] || return 0
  theme_launcher_load_colors_into "$colors_file" _colors

  accent="${_colors[accent]:-}"
  foreground="${_colors[foreground]:-}"
  background="${_colors[background]:-}"
  selection_fg="${_colors[selection_foreground]:-}"
  selection_bg="${_colors[selection_background]:-}"
  muted="${_colors[color8]:-}"
  shell_css="$THEME_LAUNCHER_NEXT_DIR/gnome-shell.css"

  cat >"$shell_css" <<EOF
/* Generated by theme-launcher */
#panel {
  background-color: ${background};
  color: ${foreground};
  box-shadow: inset 0 -1px ${muted};
}

#panel .panel-button,
#panel .panel-button .clock,
#panel .panel-button .panel-status-indicators-box,
#panel .panel-button .system-status-icon,
#panel .panel-button .popup-menu-icon {
  color: ${foreground};
}

#panel .panel-button:hover,
#panel .panel-button:focus,
#panel .panel-button:active,
#panel .panel-button:checked,
#panel .panel-button:overview,
#panel .panel-button:focus:hover,
#panel .panel-button:active:hover,
#panel .panel-button:checked:hover,
#panel .panel-button:overview:hover,
#panel .panel-button:hover .clock,
#panel .panel-button:focus .clock,
#panel .panel-button:active .clock,
#panel .panel-button:checked .clock,
#panel .panel-button:overview .clock,
#panel .panel-button:hover .system-status-icon,
#panel .panel-button:focus .system-status-icon,
#panel .panel-button:active .system-status-icon,
#panel .panel-button:checked .system-status-icon,
#panel .panel-button:overview .system-status-icon,
#panel .panel-button:hover .popup-menu-icon,
#panel .panel-button:focus .popup-menu-icon,
#panel .panel-button:active .popup-menu-icon,
#panel .panel-button:checked .popup-menu-icon,
#panel .panel-button:overview .popup-menu-icon {
  background-color: ${selection_bg};
  color: ${selection_fg};
  box-shadow: none;
}

#dashtodockContainer #dash .dash-background {
  background-color: ${background};
  border: 1px solid ${muted};
}

#dashtodockContainer .app-well-app-running-dot,
#dashtodockContainer .app-grid-running-dot {
  background-color: ${accent};
}

#dashtodockContainer .overview-icon,
#dashtodockContainer .show-apps .overview-icon {
  color: ${foreground};
}

#dashtodockContainer .app-well-app:hover .overview-icon,
#dashtodockContainer .app-well-app:focus .overview-icon,
#dashtodockContainer .app-well-app:active .overview-icon,
#dashtodockContainer .app-well-app.focused .overview-icon,
#dashtodockContainer .show-apps:hover .overview-icon,
#dashtodockContainer .show-apps:focus .overview-icon,
#dashtodockContainer .show-apps:active .overview-icon {
  background-color: ${selection_bg};
  color: ${selection_fg};
}
EOF
}

theme_launcher_select_background() {
  local theme="$1"
  local theme_dir="$2"
  local requested_wallpaper="${3:-}"
  local selected_background
  local wallpaper_name=""
  local materialized_background="$theme_dir/wallpaper.png"

  selected_background="$(theme_launcher_resolve_wallpaper "$theme" "$theme_dir" "$requested_wallpaper")"
  if [[ -z "$selected_background" ]]; then
    rm -f "$THEME_LAUNCHER_BACKGROUND_LINK"
    rm -f "$THEME_LAUNCHER_WALLPAPER_NAME_FILE"
    theme_launcher_set_saved_wallpaper "$theme" ""
    return 0
  fi

  wallpaper_name="$(basename "$selected_background")"
  mkdir -p "$THEME_LAUNCHER_STATE_DIR"
  theme_launcher_materialize_background "$selected_background" "$materialized_background"
  ln -nsf "$materialized_background" "$THEME_LAUNCHER_BACKGROUND_LINK"
  printf "%s\n" "$wallpaper_name" >"$THEME_LAUNCHER_WALLPAPER_NAME_FILE"
  theme_launcher_set_saved_wallpaper "$theme" "$wallpaper_name"
}

theme_launcher_apply_gnome() {
  local gtk_theme_light="Yaru"
  local gtk_theme_dark="Yaru-dark"
  local icon_theme
  local cursor_theme
  local wallpaper

  command -v gsettings >/dev/null 2>&1 || return 0

  if [[ -f "$THEME_LAUNCHER_CURRENT_DIR/light.mode" ]]; then
    theme_launcher_try_gsettings org.gnome.desktop.interface color-scheme "prefer-light" || theme_launcher_warn "failed to set GNOME color-scheme"
    theme_launcher_try_gsettings org.gnome.desktop.interface gtk-theme "$gtk_theme_light" || theme_launcher_warn "failed to set GNOME gtk-theme"
  else
    theme_launcher_try_gsettings org.gnome.desktop.interface color-scheme "prefer-dark" || theme_launcher_warn "failed to set GNOME color-scheme"
    theme_launcher_try_gsettings org.gnome.desktop.interface gtk-theme "$gtk_theme_dark" || theme_launcher_warn "failed to set GNOME gtk-theme"
  fi

  if [[ -f "$THEME_LAUNCHER_CURRENT_DIR/icons.theme" ]]; then
    icon_theme="$(<"$THEME_LAUNCHER_CURRENT_DIR/icons.theme")"
    if [[ -n "$icon_theme" ]]; then
      theme_launcher_try_gsettings org.gnome.desktop.interface icon-theme "$icon_theme" || theme_launcher_warn "failed to set GNOME icon-theme"
    fi
  fi

  if [[ -f "$THEME_LAUNCHER_CURRENT_DIR/cursor.theme" ]]; then
    cursor_theme="$(<"$THEME_LAUNCHER_CURRENT_DIR/cursor.theme")"
    if [[ -n "$cursor_theme" ]]; then
      theme_launcher_try_gsettings org.gnome.desktop.interface cursor-theme "$cursor_theme" || theme_launcher_warn "failed to set GNOME cursor-theme"
    fi
  fi

  if [[ -L "$THEME_LAUNCHER_BACKGROUND_LINK" ]]; then
    wallpaper="file://$(readlink -f "$THEME_LAUNCHER_BACKGROUND_LINK")"
    theme_launcher_try_gsettings org.gnome.desktop.background picture-uri "$wallpaper" || theme_launcher_warn "failed to set GNOME wallpaper"
    theme_launcher_try_gsettings org.gnome.desktop.background picture-uri-dark "$wallpaper" || theme_launcher_warn "failed to set GNOME dark wallpaper"
  fi
}

theme_launcher_apply_ubuntu_dock() {
  local colors_file="$THEME_LAUNCHER_CURRENT_DIR/colors.toml"
  local dock_schema
  local background
  local accent
  local opacity

  command -v gsettings >/dev/null 2>&1 || return 0
  dock_schema="$(theme_launcher_ubuntu_dock_schema || true)"
  if [[ -z "$dock_schema" ]]; then
    return 0
  fi
  [[ -f "$colors_file" ]] || return 0

  background="$(theme_launcher_color_value "$colors_file" background)"
  accent="$(theme_launcher_color_value "$colors_file" accent)"
  [[ -n "$background" ]] || return 0

  if [[ -f "$THEME_LAUNCHER_CURRENT_DIR/light.mode" ]]; then
    opacity="0.92"
  else
    opacity="0.85"
  fi

  theme_launcher_try_gsettings "$dock_schema" custom-background-color "true" || theme_launcher_warn "failed to enable Ubuntu Dock custom background"
  theme_launcher_try_gsettings "$dock_schema" background-color "$background" || theme_launcher_warn "failed to set Ubuntu Dock background color"
  theme_launcher_try_gsettings "$dock_schema" background-opacity "$opacity" || theme_launcher_warn "failed to set Ubuntu Dock background opacity"
  theme_launcher_try_gsettings "$dock_schema" transparency-mode "'FIXED'" || theme_launcher_warn "failed to set Ubuntu Dock transparency mode"
  theme_launcher_try_gsettings "$dock_schema" apply-glossy-effect "false" || theme_launcher_warn "failed to disable Ubuntu Dock glossy effect"

  if [[ -n "$accent" ]]; then
    theme_launcher_try_gsettings "$dock_schema" custom-theme-customize-running-dots "true" || theme_launcher_warn "failed to enable Ubuntu Dock running indicator customization"
    theme_launcher_try_gsettings "$dock_schema" custom-theme-running-dots-color "$accent" || theme_launcher_warn "failed to set Ubuntu Dock running indicator color"
    theme_launcher_try_gsettings "$dock_schema" custom-theme-running-dots-border-color "$accent" || theme_launcher_warn "failed to set Ubuntu Dock running indicator border color"
  fi
}

theme_launcher_gnome_shell_extension_running() {
  local uuid="$1"
  command -v busctl >/dev/null 2>&1 || return 1
  local info
  info="$(busctl --user call org.gnome.Shell /org/gnome/Shell \
    org.gnome.Shell.Extensions GetExtensionInfo s "$uuid" 2>/dev/null || true)"
  # Running extension returns a non-empty dict; unknown/stopped returns "a{sv} 0"
  [[ "$info" != "a{sv} 0" && -n "$info" ]]
}

theme_launcher_install_user_theme_extension() {
  local uuid="$1"
  local user_ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
  local system_ext_dir="/usr/share/gnome-shell/extensions/$uuid"

  [[ -d "$user_ext_dir" ]] && return 0
  [[ -d "$system_ext_dir" ]] || return 1

  mkdir -p "$(dirname "$user_ext_dir")"
  cp -r "$system_ext_dir" "$user_ext_dir"
}

theme_launcher_apply_gnome_shell() {
  local generated_file="$THEME_LAUNCHER_CURRENT_DIR/gnome-shell.css"
  local shell_theme_dir="$HOME/.themes/ThemeLauncher/gnome-shell"
  local shell_theme_name="ThemeLauncher"
  local user_theme_extension="user-theme@gnome-shell-extensions.gcampax.github.com"

  [[ -f "$generated_file" ]] || return 0

  mkdir -p "$shell_theme_dir"
  cp -f "$generated_file" "$shell_theme_dir/gnome-shell.css"

  theme_launcher_install_user_theme_extension "$user_theme_extension"

  # Add to enabled-extensions so it loads on next login if not already running
  local current_enabled
  local new_list
  current_enabled="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true)"
  if [[ -n "$current_enabled" ]] && ! printf "%s" "$current_enabled" | grep -Fq "$user_theme_extension"; then
    current_enabled="${current_enabled#@as }"
    if [[ "$current_enabled" == "[]" ]]; then
      new_list="['$user_theme_extension']"
    else
      new_list="${current_enabled%]}"
      new_list="${new_list}, '$user_theme_extension']"
    fi
    gsettings set org.gnome.shell enabled-extensions "$new_list" 2>/dev/null || true
  fi

  if theme_launcher_gnome_shell_extension_running "$user_theme_extension"; then
    # Toggle the name to force a reload even if it was already set to ThemeLauncher
    theme_launcher_try_gsettings org.gnome.shell.extensions.user-theme name "''" || true
    sleep 0.1
    theme_launcher_try_gsettings org.gnome.shell.extensions.user-theme name "'$shell_theme_name'" || \
      theme_launcher_warn "failed to set GNOME Shell theme"
  else
    # Set the name so it's ready when the extension loads after next login
    theme_launcher_try_gsettings org.gnome.shell.extensions.user-theme name "'$shell_theme_name'" || true
    theme_launcher_warn "GNOME Shell top bar will update after logging out and back in (one-time setup)"
  fi
}

theme_launcher_apply_ghostty() {
  local config_file="$HOME/.config/ghostty/config.ghostty"
  local block

  mkdir -p "$HOME/.config/ghostty"
  block="$(cat <<EOF
config-file = $THEME_LAUNCHER_CURRENT_DIR/ghostty.conf
app-notifications = no-config-reload
EOF
)"
  theme_launcher_write_managed_block "$config_file" "$block"
}

theme_launcher_reload_ghostty() {
  # Reloading a live terminal while it is still painting output can leave
  # partially re-rendered content on screen. Update the config in place and
  # let new windows/sessions pick it up unless the user explicitly opts in.
  if [[ "${THEME_LAUNCHER_RELOAD_GHOSTTY:-0}" != "1" ]]; then
    return 0
  fi

  command -v systemctl >/dev/null 2>&1 || return 0

  if systemctl --user --quiet is-active app-com.mitchellh.ghostty.service >/dev/null 2>&1; then
    systemctl --user reload app-com.mitchellh.ghostty.service >/dev/null 2>&1 || \
      theme_launcher_warn "failed to reload Ghostty service"
    return 0
  fi

  command -v pkill >/dev/null 2>&1 || return 0

  if pgrep -x ghostty >/dev/null 2>&1; then
    pkill -USR2 -x ghostty >/dev/null 2>&1 || \
      theme_launcher_warn "failed to signal running Ghostty process"
  fi
}

theme_launcher_apply_btop() {
  local target_theme="$HOME/.config/btop/themes/theme-launcher.theme"
  local conf="$HOME/.config/btop/btop.conf"

  [[ -f "$THEME_LAUNCHER_CURRENT_DIR/btop.theme" ]] || return 0

  mkdir -p "$(dirname "$target_theme")"
  cp -f "$THEME_LAUNCHER_CURRENT_DIR/btop.theme" "$target_theme"
  theme_launcher_update_line_setting "$conf" "color_theme" "\"theme-launcher\""
}

theme_launcher_apply_neovim() {
  local target="$HOME/.config/nvim/lua/plugins/theme-launcher.lua"

  [[ -d "$HOME/.config/nvim" ]] || return 0
  [[ -f "$THEME_LAUNCHER_CURRENT_DIR/neovim.lua" ]] || return 0

  mkdir -p "$(dirname "$target")"
  cp -f "$THEME_LAUNCHER_CURRENT_DIR/neovim.lua" "$target"
}

theme_launcher_apply_tmux() {
  local config_file="$HOME/.config/tmux/tmux.conf"
  local generated_file="$THEME_LAUNCHER_CURRENT_DIR/tmux.conf"
  local block

  [[ -f "$generated_file" ]] || return 0

  mkdir -p "$HOME/.config/tmux"
  block="source-file $generated_file"
  theme_launcher_write_managed_block "$config_file" "$block"
}

theme_launcher_reload_tmux() {
  local config_file="$HOME/.config/tmux/tmux.conf"

  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$config_file" >/dev/null 2>&1 || theme_launcher_warn "failed to reload tmux config"
  fi
}

theme_launcher_apply_lazygit() {
  local target="$HOME/.config/lazygit/config.yml"
  local generated_file="$THEME_LAUNCHER_CURRENT_DIR/lazygit.yml"

  [[ -f "$generated_file" ]] || return 0

  mkdir -p "$(dirname "$target")"
  cp -f "$generated_file" "$target"
}

theme_launcher_apply_fastfetch() {
  local target="$HOME/.config/fastfetch/config.jsonc"
  local generated_file="$THEME_LAUNCHER_CURRENT_DIR/fastfetch.jsonc"

  [[ -f "$generated_file" ]] || return 0

  mkdir -p "$(dirname "$target")"
  cp -f "$generated_file" "$target"
}

theme_launcher_apply_bat() {
  local target="$HOME/.config/bat/config"
  local generated_file="$THEME_LAUNCHER_CURRENT_DIR/bat.conf"

  [[ -f "$generated_file" ]] || return 0

  mkdir -p "$(dirname "$target")"
  cp -f "$generated_file" "$target"
}

theme_launcher_apply_fzf() {
  local shell_file="$HOME/.config/fzf/theme-launcher.bash"
  local generated_file="$THEME_LAUNCHER_CURRENT_DIR/fzf.bash"
  local block

  [[ -f "$generated_file" ]] || return 0

  mkdir -p "$(dirname "$shell_file")"
  cp -f "$generated_file" "$shell_file"
  block='[ -f "$HOME/.config/fzf/theme-launcher.bash" ] && . "$HOME/.config/fzf/theme-launcher.bash"'
  theme_launcher_write_managed_block "$HOME/.bashrc" "$block"
}

theme_launcher_apply_gtk_css() {
  local target_dir
  local target
  local generated
  local block

  for target_dir in gtk-3.0 gtk-4.0; do
    target="$HOME/.config/$target_dir/gtk.css"
    generated="$THEME_LAUNCHER_CURRENT_DIR/$target_dir.css"
    [[ -f "$generated" ]] || continue

    mkdir -p "$(dirname "$target")"
    block="$(<"$generated")"
    theme_launcher_write_css_managed_block "$target" "$block"
  done
}

theme_launcher_set_editor_theme() {
  local editor_cmd="$1"
  local settings_path="$2"
  local theme_json="$THEME_LAUNCHER_CURRENT_DIR/vscode.json"
  local theme_name
  local extension

  command -v "$editor_cmd" >/dev/null 2>&1 || return 0
  [[ -f "$theme_json" ]] || return 0

  theme_name="$(theme_launcher_theme_json_field "$theme_json" name)"
  extension="$(theme_launcher_theme_json_field "$theme_json" extension)"

  [[ -n "$theme_name" ]] || return 0

  if [[ -n "$extension" ]]; then
    local ext_id="${extension#id:}"
    ext_id="${ext_id,,}"
    local marker_dir="$THEME_LAUNCHER_STATE_DIR/extensions"
    local marker_file="$marker_dir/${editor_cmd}.${ext_id}"
    if [[ ! -f "$marker_file" ]]; then
      if "$editor_cmd" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -Fxq "$ext_id"; then
        mkdir -p "$marker_dir"
        : >"$marker_file"
      else
        if "$editor_cmd" --install-extension "$extension" >/dev/null 2>&1; then
          mkdir -p "$marker_dir"
          : >"$marker_file"
        else
          theme_launcher_warn "failed to install $extension for $editor_cmd"
        fi
      fi
    fi
  fi

  theme_launcher_update_jsonc_setting "$settings_path" "workbench.colorTheme" "\"$(theme_launcher_escape_sed_replacement "$theme_name")\""
}

theme_launcher_apply_vscode_family() {
  theme_launcher_set_editor_theme "code" "$HOME/.config/Code/User/settings.json"
  theme_launcher_set_editor_theme "code-insiders" "$HOME/.config/Code - Insiders/User/settings.json"
  theme_launcher_set_editor_theme "codium" "$HOME/.config/VSCodium/User/settings.json"
  theme_launcher_set_editor_theme "cursor" "$HOME/.config/Cursor/User/settings.json"
}

theme_launcher_apply_chromium() {
  local chromium_theme_file="$THEME_LAUNCHER_CURRENT_DIR/chromium.theme"
  local rgb_value r g b background_hex
  local policy_json
  local applied=0
  local dir

  theme_launcher_risky_target_enabled "chromium" || return 0
  theme_launcher_chromium_installed || return 0

  [[ -f "$chromium_theme_file" ]] || return 0
  rgb_value="$(<"$chromium_theme_file")"
  [[ -n "$rgb_value" ]] || return 0

  IFS=',' read -r r g b <<< "$rgb_value"
  background_hex="$(printf '#%02x%02x%02x' "${r// /}" "${g// /}" "${b// /}")"

  policy_json="{\"BrowserThemeColor\": \"${background_hex}\"}"

  for dir in "${THEME_LAUNCHER_CHROMIUM_POLICY_DIRS[@]}"; do
    if [[ -d "$dir" && -w "$dir" ]]; then
      printf "%s\n" "$policy_json" >"$dir/theme-launcher.json"
      applied=1
      break
    elif [[ -d "$(dirname "$dir")" && -w "$(dirname "$dir")" ]]; then
      mkdir -p "$dir"
      printf "%s\n" "$policy_json" >"$dir/theme-launcher.json"
      applied=1
      break
    fi
  done

  if [[ "$applied" -eq 0 ]]; then
    theme_launcher_warn "Chromium policy directory not writable; to enable browser theming run: sudo mkdir -p /etc/chromium/policies/managed && sudo chmod o+w /etc/chromium/policies/managed"
    if snap list chromium >/dev/null 2>&1; then
      theme_launcher_warn "For snap Chromium, also run: sudo snap connect chromium:etc-chromium-browser-policies"
    fi
  fi
}

theme_launcher_generate_target() {
  local name="$1"
  local generate_fn="$2"
  local _apply_fn="$3"
  local _reload_fn="$4"
  local _prerequisites="$5"
  local theme="$6"

  if [[ -n "$generate_fn" ]] && theme_launcher_target_enabled "$name"; then
    "$generate_fn" "$theme"
  fi
}

theme_launcher_apply_target() {
  local name="$1"
  local _generate_fn="$2"
  local apply_fn="$3"
  local _reload_fn="$4"
  local _prerequisites="$5"

  if [[ -n "$apply_fn" ]] && theme_launcher_target_enabled "$name"; then
    "$apply_fn"
  fi
}

theme_launcher_reload_target() {
  local name="$1"
  local _generate_fn="$2"
  local _apply_fn="$3"
  local reload_fn="$4"
  local _prerequisites="$5"

  if [[ -n "$reload_fn" ]] && theme_launcher_target_enabled "$name"; then
    "$reload_fn"
  fi
}

theme_launcher_apply_theme() {
  local requested_theme="$1"
  local requested_wallpaper="${2:-}"
  local theme
  local theme_dir
  local previous_dir="$THEME_LAUNCHER_STATE_DIR/previous"
  local previous_theme

  theme="$(theme_launcher_slugify "$requested_theme")"
  theme_dir="$(theme_launcher_theme_path "$theme")"

  [[ -d "$theme_dir" ]] || theme_launcher_fail "unknown theme: $requested_theme"

  rm -rf "$THEME_LAUNCHER_NEXT_DIR"
  mkdir -p "$THEME_LAUNCHER_NEXT_DIR"
  cp -a "$theme_dir"/. "$THEME_LAUNCHER_NEXT_DIR/"

  theme_launcher_generate_templates
  theme_launcher_for_each_target theme_launcher_generate_target "$theme"
  mkdir -p "$THEME_LAUNCHER_STATE_DIR"
  previous_theme="$(theme_launcher_current)"

  rm -rf "$previous_dir"
  if [[ -d "$THEME_LAUNCHER_CURRENT_DIR" ]]; then
    mv "$THEME_LAUNCHER_CURRENT_DIR" "$previous_dir"
  fi
  mv "$THEME_LAUNCHER_NEXT_DIR" "$THEME_LAUNCHER_CURRENT_DIR"
  if [[ -n "$previous_theme" ]]; then
    printf "%s\n" "$previous_theme" >"$THEME_LAUNCHER_PREVIOUS_THEME_FILE"
  else
    rm -f "$THEME_LAUNCHER_PREVIOUS_THEME_FILE"
  fi
  printf "%s\n" "$theme" >"$THEME_LAUNCHER_THEME_NAME_FILE"
  ln -nsf "$THEME_LAUNCHER_CURRENT_DIR" "$THEME_LAUNCHER_THEME_LINK"
  theme_launcher_select_background "$theme" "$THEME_LAUNCHER_CURRENT_DIR" "$requested_wallpaper"

  theme_launcher_for_each_target theme_launcher_apply_target
  theme_launcher_for_each_target theme_launcher_reload_target
}

theme_launcher_choose_theme() {
  local themes=()
  local selected=""
  local theme

  mapfile -t themes < <(theme_launcher_list)
  [[ "${#themes[@]}" -gt 0 ]] || theme_launcher_fail "no themes installed; run: theme-launcher sync"

  if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v zenity >/dev/null 2>&1; then
    selected="$(zenity --list --title="Theme Launcher" --column="Theme" "${themes[@]}" 2>/dev/null || true)"
  elif [[ -t 0 && -t 1 ]] && command -v gum >/dev/null 2>&1; then
    selected="$(printf "%s\n" "${themes[@]}" | gum choose --header "Choose theme" 2>/dev/null || true)"
  else
    printf "Available themes:\n"
    select theme in "${themes[@]}"; do
      selected="$theme"
      break
    done
  fi

  [[ -n "$selected" ]] || return 0
  theme_launcher_theme_exists "$selected" || theme_launcher_fail "theme picker returned invalid selection: $selected"
  printf "%s\n" "$selected"
}
