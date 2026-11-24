#!/usr/bin/env bash
# MDBird installer for Linux and macOS.
#
# Installs the theme into a Thunderbird profile without replacing existing
# userChrome.css or userContent.css rules. Adds a managed @import block,
# copies the theme into chrome/mdbird, enables legacy user stylesheets in
# user.js, packages the MDBird Search add-on, and clears startupCache.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_USER_CHROME="$ROOT_DIR/userChrome.css"
SRC_USER_CONTENT="$ROOT_DIR/userContent.css"
SRC_THEME="$ROOT_DIR/theme"
SRC_SEARCH="$ROOT_DIR/search-addon"
MDBIRD_VERSION="1.3"

ACCENT="blue"
ACCENT_SET=0
PROFILE_ARG=""
MODE="install"
ASSUME_YES=0

PROFILE_DIR=""
PROFILE_ROOT=""
CLEANUP_PATHS=()

IMPORT_START='/* >>> MDBird theme (managed) >>> */'
IMPORT_END='/* <<< MDBird theme (managed) <<< */'
USERJS_START='// >>> MDBird theme >>>'
USERJS_END='// <<< MDBird theme <<<'

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

cleanup() {
  local path
  if ((${#CLEANUP_PATHS[@]} > 0)); then
    for path in "${CLEANUP_PATHS[@]}"; do
      [[ -n "$path" ]] && rm -rf -- "$path"
    done
  fi
}

register_cleanup() {
  CLEANUP_PATHS+=("$1")
}

trap cleanup EXIT

list_available_accents() {
  local file name
  for file in "$SRC_THEME/palettes"/*.css; do
    [[ -f "$file" ]] || continue
    name="${file##*/}"
    printf '%s\n' "${name%.css}"
  done
}

format_available_accents() {
  list_available_accents | awk 'NR > 1 { printf ", " } { printf "%s", $0 }'
}

usage() {
  local accents
  accents="$(format_available_accents)"
  cat <<EOF
MDBird — Material Design 3 Expressive theme for Thunderbird

Usage:
  ./install.sh [options]

Options:
  --profile <path>   Target Thunderbird profile directory (auto-detected from profiles.ini if omitted).
  --accent <name>    Color palette: ${accents:-blue} (default: blue).
  --uninstall        Remove MDBird from the target profile.
  --yes, -y          Do not prompt when multiple profiles exist.
  -h, --help         Show this help message.

Examples:
  ./install.sh
  ./install.sh --profile ~/.thunderbird/xxxxxxxx.default-release --accent violet
  ./install.sh --uninstall
EOF
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --profile)
        [[ $# -ge 2 ]] || die "--profile requires a directory path."
        PROFILE_ARG="$2"
        shift 2
        ;;
      --accent)
        [[ $# -ge 2 ]] || die "--accent requires a palette name."
        ACCENT="$2"
        ACCENT_SET=1
        shift 2
        ;;
      --uninstall)
        MODE="uninstall"
        shift
        ;;
      --yes|-y)
        ASSUME_YES=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1 (run with --help for usage)."
        ;;
    esac
  done
}

validate_sources() {
  [[ -f "$SRC_USER_CHROME" ]] || die "Missing userChrome.css. Run install.sh from the repository root."
  [[ -f "$SRC_USER_CONTENT" ]] || die "Missing userContent.css."
  [[ -d "$SRC_THEME" ]] || die "Missing theme/ directory."
  if [[ "$MODE" == "install" ]]; then
    if [[ ! "$ACCENT" =~ ^[A-Za-z0-9._-]+$ ]] || [[ ! -f "$SRC_THEME/palettes/$ACCENT.css" ]]; then
      local available
      available="$(format_available_accents)"
      die "Unknown accent \"$ACCENT\". Available palettes: ${available:-none}."
    fi
  fi
}

find_profile_root() {
  local candidate
  for candidate in \
    "${THUNDERBIRD_PROFILE_ROOT:-}" \
    "${HOME}/.thunderbird" \
    "${HOME}/.mozilla-thunderbird" \
    "${HOME}/Library/Thunderbird" \
    "${HOME}/snap/thunderbird/common/.thunderbird" \
    "${HOME}/.var/app/org.mozilla.Thunderbird/.thunderbird"; do
    [[ -n "$candidate" ]] || continue
    if [[ -f "$candidate/profiles.ini" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

list_profiles() {
  local ini="$1"
  awk '
    function emit() {
      if (in_profile && path != "") {
        print name "\t" path "\t" rel
      }
      name = ""; path = ""; rel = "0"
    }
    { sub(/\r$/, "") }
    /^\[/ {
      emit()
      in_profile = ($0 ~ /^\[Profile/)
      next
    }
    in_profile {
      if ($0 ~ /^Name=/) {
        sub(/^Name=/, "", $0); name = $0
      } else if ($0 ~ /^Path=/) {
        sub(/^Path=/, "", $0); path = $0
      } else if ($0 ~ /^IsRelative=/) {
        rel = ($0 ~ /=1$/) ? "1" : "0"
      }
    }
    END { emit() }
  ' "$ini"
}

install_default_profile() {
  local ini="$1"
  awk -F= '
    { sub(/\r$/, "") }
    /^\[/ { in_install = ($0 ~ /^\[Install/); next }
    in_install && $1 == "Default" { print $2; exit }
  ' "$ini"
}

resolve_profile() {
  if [[ -n "$PROFILE_ARG" ]]; then
    [[ -d "$PROFILE_ARG" ]] || die "Profile directory does not exist: $PROFILE_ARG"
    PROFILE_DIR="$(cd -- "$PROFILE_ARG" && pwd)"
    PROFILE_ROOT="$(dirname -- "$PROFILE_DIR")"
    return 0
  fi

  PROFILE_ROOT="$(find_profile_root)" || {
    die "Could not find a Thunderbird profile root. Specify one with --profile <path>."
  }

  local ini="$PROFILE_ROOT/profiles.ini"
  local names=() paths=() rels=()
  local name path rel
  while IFS=$'\t' read -r name path rel; do
    [[ -n "$path" ]] || continue
    names+=("${name:-$path}")
    paths+=("$path")
    rels+=("$rel")
  done < <(list_profiles "$ini")

  ((${#paths[@]} > 0)) || die "No profiles found in $ini."

  local install_default
  install_default="$(install_default_profile "$ini" || true)"

  local chosen=-1 i
  if [[ -n "$install_default" ]]; then
    for i in "${!paths[@]}"; do
      if [[ "${paths[$i]}" == "$install_default" ]]; then
        chosen=$i
        break
      fi
    done
  fi

  if ((chosen < 0)) && ((${#paths[@]} == 1)); then
    chosen=0
  fi

  if ((chosen < 0)); then
    log "Multiple Thunderbird profiles found:"
    for i in "${!paths[@]}"; do
      printf '  %d) %s (%s)\n' "$((i + 1))" "${names[$i]}" "${paths[$i]}"
    done
    if ((ASSUME_YES)) || [[ ! -t 0 ]]; then
      die "Cannot auto-select a profile. Specify one with --profile <path>."
    fi
    local answer
    read -r -p "Select a profile [1-${#paths[@]}]: " answer
    [[ "$answer" =~ ^[0-9]+$ ]] || die "Invalid selection."
    chosen=$((answer - 1))
    ((chosen >= 0 && chosen < ${#paths[@]})) || die "Selection out of range."
  fi

  path="${paths[$chosen]}"
  rel="${rels[$chosen]}"
  if [[ "$rel" == "1" ]]; then
    PROFILE_DIR="${PROFILE_ROOT%/}/${path}"
  else
    PROFILE_DIR="$path"
  fi

  [[ -d "$PROFILE_DIR" ]] || die "Profile directory does not exist: $PROFILE_DIR"
  PROFILE_DIR="$(cd -- "$PROFILE_DIR" && pwd)"
}

check_running() {
  if pgrep -ix thunderbird >/dev/null 2>&1 || pgrep -ix thunderbird-bin >/dev/null 2>&1; then
    warn "Thunderbird appears to be running. Quit and restart it completely for changes to take effect."
  fi
}

ensure_user_js() {
  local file="$1/user.js"
  if [[ -f "$file" ]] && grep -qF "$USERJS_START" "$file"; then
    return 0
  fi
  local tmp
  tmp="$(mktemp "$1/.user.js.mdbird.XXXXXX")"
  register_cleanup "$tmp"
  {
    if [[ -f "$file" ]]; then
      cat -- "$file"
    fi
    printf '\n%s\nuser_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n%s\n' \
      "$USERJS_START" "$USERJS_END"
  } > "$tmp"
  mv -- "$tmp" "$file"
}

strip_import_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local dir tmp
  dir="$(dirname -- "$file")"
  tmp="$(mktemp "$dir/.mdbird-strip.XXXXXX")"
  register_cleanup "$tmp"
  awk -v start="$IMPORT_START" -v end="$IMPORT_END" '
    $0 == start { skip = 1; next }
    $0 == end   { skip = 0; drop_blank = 1; next }
    drop_blank && $0 ~ /^[[:space:]]*$/ { drop_blank = 0; next }
    { drop_blank = 0 }
    !skip { print }
  ' "$file" > "$tmp"
  mv -- "$tmp" "$file"
  if ! grep -q '[^[:space:]]' "$file"; then
    rm -f -- "$file"
  fi
}

install_import_block() {
  local file="$1" import_path="$2"
  local dir tmp
  dir="$(dirname -- "$file")"
  tmp="$(mktemp "$dir/.mdbird-import.XXXXXX")"
  register_cleanup "$tmp"
  # Rewrite the managed block on every install to prevent duplicate imports,
  # fix stale paths, and invalidate cached compiled stylesheets.
  strip_import_block "$file"
  {
    printf '%s\n' "$IMPORT_START"
    printf '/* MDBird %s */\n' "$MDBIRD_VERSION"
    printf '@import url("%s");\n' "$import_path"
    printf '%s\n' "$IMPORT_END"
    if [[ -f "$file" ]]; then
      printf '\n'
      cat -- "$file"
    fi
  } > "$tmp"
  mv -- "$tmp" "$file"
}

uninstall_theme() {
  local chrome_dir="$PROFILE_DIR/chrome"
  local target_dir="$chrome_dir/mdbird"
  local search_xpi="$PROFILE_DIR/extensions/mdbird-search@mdbird.local.xpi"

  strip_import_block "$chrome_dir/userChrome.css"
  strip_import_block "$chrome_dir/userContent.css"
  if [[ -d "$target_dir" && -f "$target_dir/userChrome.css" ]] && grep -q 'MDBird' "$target_dir/userChrome.css"; then
    rm -rf -- "$target_dir"
  elif [[ -d "$target_dir" ]]; then
    warn "chrome/mdbird exists but does not look like MDBird; leaving it untouched."
  fi
  rm -f -- "$search_xpi"
  rm -rf -- "$PROFILE_DIR/startupCache"

  log "MDBird removed from profile:"
  log "  Profile: $PROFILE_DIR"
  log "  Existing user.js preferences and backup folders were preserved."
}

install_theme() {
  local chrome_dir="$PROFILE_DIR/chrome"
  local target_dir="$chrome_dir/mdbird"
  local extensions_dir="$PROFILE_DIR/extensions"
  local search_xpi="$extensions_dir/mdbird-search@mdbird.local.xpi"

  command -v zip >/dev/null 2>&1 || die "zip is required to package MDBird Search."
  [[ -f "$SRC_SEARCH/manifest.json" ]] || die "Missing search-addon/manifest.json."

  mkdir -p -- "$extensions_dir" "$chrome_dir"
  local search_tmp
  search_tmp="$(mktemp "$extensions_dir/.mdbird-search.XXXXXX")"
  register_cleanup "$search_tmp"
  (
    cd -- "$SRC_SEARCH"
    zip -q -MM -r - manifest.json schema.json search.js search.css _locales
  ) > "$search_tmp"

  local stamp backup_dir="" backup_needed=0 f
  stamp="$(date +%Y%m%d-%H%M%S)"
  for f in userChrome.css userContent.css; do
    [[ -f "$chrome_dir/$f" ]] && backup_needed=1
  done
  [[ -d "$target_dir" ]] && backup_needed=1
  [[ -f "$search_xpi" ]] && backup_needed=1

  if ((backup_needed)); then
    backup_dir="$chrome_dir/.mdbird-backup-$stamp"
    if [[ -e "$backup_dir" ]]; then
      backup_dir="$chrome_dir/.mdbird-backup-$stamp-$$"
    fi
    mkdir -p -- "$backup_dir"
    for f in userChrome.css userContent.css; do
      [[ -f "$chrome_dir/$f" ]] && cp -p -- "$chrome_dir/$f" "$backup_dir/"
    done
    if [[ -d "$target_dir" ]]; then
      cp -Rp -- "$target_dir" "$backup_dir/mdbird"
    fi
    if [[ -f "$search_xpi" ]]; then
      cp -p -- "$search_xpi" "$backup_dir/"
    fi
  fi

  local tmp_target
  tmp_target="$(mktemp -d "$chrome_dir/.mdbird-new.XXXXXX")"
  register_cleanup "$tmp_target"
  mkdir -p -- "$tmp_target/theme"
  cp -p -- "$SRC_USER_CHROME" "$SRC_USER_CONTENT" "$tmp_target/"
  cp -Rp -- "$SRC_THEME/." "$tmp_target/theme/"

  # Preserve local customization and previously configured palettes when --accent is omitted.
  if [[ -f "$target_dir/theme/customization.css" ]]; then
    cp -p -- "$target_dir/theme/customization.css" "$tmp_target/theme/customization.css"
  fi

  local preserve_palette=0 accent_label="" palette_file palette_name previous_accent
  if ((ACCENT_SET == 0)) && [[ -f "$target_dir/theme/palette.css" ]]; then
    cp -p -- "$target_dir/theme/palette.css" "$tmp_target/theme/palette.css"
    preserve_palette=1
    if [[ -d "$target_dir/theme/palettes" ]]; then
      for palette_file in "$target_dir/theme/palettes"/*.css; do
        [[ -e "$palette_file" ]] || continue
        palette_name="${palette_file##*/}"
        if [[ ! -f "$SRC_THEME/palettes/$palette_name" ]]; then
          cp -p -- "$palette_file" "$tmp_target/theme/palettes/$palette_name"
        fi
      done
    fi
  fi

  if ((preserve_palette == 0)); then
    printf '@import url("palettes/%s.css");\n' "$ACCENT" > "$tmp_target/theme/palette.css"
    accent_label="$ACCENT"
  else
    previous_accent="$(
      grep -oE 'palettes/[A-Za-z0-9._-]+\.css' "$target_dir/theme/palette.css" \
        | head -n 1 \
        | sed -e 's#palettes/##' -e 's#\.css$##' || true
    )"
    if [[ -n "$previous_accent" ]]; then
      accent_label="$previous_accent (preserved)"
    else
      accent_label="preserved existing palette"
    fi
  fi

  if [[ -d "$target_dir" ]]; then
    rm -rf -- "$target_dir"
  fi
  mv -- "$tmp_target" "$target_dir"

  ensure_user_js "$PROFILE_DIR"
  install_import_block "$chrome_dir/userChrome.css" "mdbird/userChrome.css"
  install_import_block "$chrome_dir/userContent.css" "mdbird/userContent.css"
  mv -- "$search_tmp" "$search_xpi"

  # Clear compiled chrome caches so Thunderbird reloads every imported stylesheet.
  rm -rf -- "$PROFILE_DIR/startupCache"

  log "MDBird installed:"
  log "  Profile: $PROFILE_DIR"
  log "  Theme:   $target_dir"
  log "  Accent:  $accent_label"
  if [[ -n "$backup_dir" ]]; then
    log "  Backup:  $backup_dir"
  fi
  log ""
  log "Quit Thunderbird completely and restart it to apply the theme."
  log "On first install, confirm Enable for MDBird Search in the application menu."
  log "Local overrides live in chrome/mdbird/theme/customization.css."
}

main() {
  parse_args "$@"
  validate_sources
  resolve_profile
  check_running
  if [[ "$MODE" == "uninstall" ]]; then
    uninstall_theme
  else
    install_theme
  fi
}

main "$@"
