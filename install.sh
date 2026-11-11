#!/usr/bin/env bash
# MDBird installer for Linux and other Unix-like systems.
#
# The script installs the theme into a Thunderbird profile without replacing
# an existing userChrome.css or userContent.css. It adds a managed @import
# block, copies the theme into chrome/mdbird, and enables custom stylesheets
# through the profile's user.js. Thunderbird handles activation of the search
# add-on through its add-on manager.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_USER_CHROME="$ROOT_DIR/userChrome.css"
SRC_USER_CONTENT="$ROOT_DIR/userContent.css"
SRC_THEME="$ROOT_DIR/theme"
SRC_SEARCH="$ROOT_DIR/search-addon"
MDBIRD_VERSION="1.2"

ACCENT="blue"
ACCENT_SET=0
PROFILE_ARG=""
MODE="install"
ASSUME_YES=0

IMPORT_START='/* >>> MDBird theme (managed) >>> */'
IMPORT_END='/* <<< MDBird theme (managed) <<< */'
USERJS_START='// >>> MDBird theme >>>'
USERJS_END='// <<< MDBird theme <<<'

usage() {
  cat <<'EOF'
MDBird — Material Design 3 Expressive 主题 for Thunderbird

用法:
  ./install.sh [选项]

选项:
  --profile <路径>   指定 Thunderbird 配置目录。省略时自动读取 profiles.ini。
  --accent <名称>    配色方案: blue（默认）、violet、mint。
  --uninstall        从配置目录移除主题。
  --yes              在存在多个配置目录时使用默认配置，不询问。
  -h, --help         显示本帮助。

示例:
  ./install.sh
  ./install.sh --profile ~/.thunderbird/xxxxxxxx.default-release --accent violet
  ./install.sh --uninstall
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf '注意: %s\n' "$*" >&2; }
die() { printf '错误: %s\n' "$*" >&2; exit 1; }

while (($# > 0)); do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || die "--profile 需要一个路径。"
      PROFILE_ARG="$2"
      shift 2
      ;;
    --accent)
      [[ $# -ge 2 ]] || die "--accent 需要一个名称。"
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
      die "未知选项: $1（使用 --help 查看帮助）"
      ;;
  esac
done

case "$ACCENT" in
  blue|violet|mint) ;;
  *) die "未知配色 \"$ACCENT\"。可用值: blue, violet, mint。" ;;
esac

[[ -f "$SRC_USER_CHROME" ]] || die "缺少 userChrome.css，安装脚本应位于主题仓库内。"
[[ -f "$SRC_USER_CONTENT" ]] || die "缺少 userContent.css。"
[[ -d "$SRC_THEME" ]] || die "缺少 theme 目录。"
[[ -f "$SRC_THEME/palettes/$ACCENT.css" ]] || die "缺少 theme/palettes/$ACCENT.css。"

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
    /^\[/ { in_install = ($0 ~ /^\[Install/); next }
    in_install && $1 == "Default" { print $2; exit }
  ' "$ini"
}

resolve_profile() {
  if [[ -n "$PROFILE_ARG" ]]; then
    if [[ ! -d "$PROFILE_ARG" ]]; then
      die "配置目录不存在: $PROFILE_ARG"
    fi
    PROFILE_DIR="$(cd -- "$PROFILE_ARG" && pwd)"
    PROFILE_ROOT="$(dirname -- "$PROFILE_DIR")"
    return 0
  fi

  PROFILE_ROOT="$(find_profile_root)" || {
    die "没有找到 Thunderbird 配置目录。请使用 --profile <路径> 指定。"
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

  ((${#paths[@]} > 0)) || die "profiles.ini 中没有找到配置。"

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
    log "找到多个 Thunderbird 配置："
    for i in "${!paths[@]}"; do
      printf '  %d) %s (%s)\n' "$((i + 1))" "${names[$i]}" "${paths[$i]}"
    done
    if ((ASSUME_YES)) || [[ ! -t 0 ]]; then
      die "无法自动选择配置，请使用 --profile <路径>。"
    fi
    local answer
    read -r -p "请输入编号 [1-${#paths[@]}]: " answer
    [[ "$answer" =~ ^[0-9]+$ ]] || die "无效编号。"
    chosen=$((answer - 1))
    ((chosen >= 0 && chosen < ${#paths[@]})) || die "编号超出范围。"
  fi

  path="${paths[$chosen]}"
  rel="${rels[$chosen]}"
  if [[ "$rel" == "1" ]]; then
    PROFILE_DIR="${PROFILE_ROOT%/}/${path}"
  else
    PROFILE_DIR="$path"
  fi

  [[ -d "$PROFILE_DIR" ]] || die "配置目录不存在: $PROFILE_DIR"
  PROFILE_DIR="$(cd -- "$PROFILE_DIR" && pwd)"
}

check_running() {
  if pgrep -x thunderbird >/dev/null 2>&1 || pgrep -x thunderbird-bin >/dev/null 2>&1; then
    warn "Thunderbird 正在运行。请完全退出并重新启动，主题才会生效。"
  fi
}

ensure_user_js() {
  local file="$1/user.js"
  if [[ -f "$file" ]] && grep -qF "$USERJS_START" "$file"; then
    return 0
  fi
  local tmp="${file}.mdbird-tmp.$$"
  {
    if [[ -f "$file" ]]; then
      cat -- "$file"
    fi
    printf '\n%s\nuser_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n%s\n' \
      "$USERJS_START" "$USERJS_END"
  } > "$tmp"
  mv -- "$tmp" "$file"
}

install_import_block() {
  local file="$1" import_path="$2"
  local tmp="${file}.mdbird-tmp.$$"
  # Rewrite the managed block on every install. This keeps a single canonical
  # block, fixes stale import paths, and changes the file so Thunderbird cannot
  # reuse an older cached copy of the stylesheet.
  strip_import_block "$file"
  {
    printf '%s\n' "$IMPORT_START"
    printf '/* MDBird %s */\n' "$MDBIRD_VERSION"
    printf '@import url("%s");\n' "$import_path"
    printf '%s\n\n' "$IMPORT_END"
    if [[ -f "$file" ]]; then
      cat -- "$file"
    fi
  } > "$tmp"
  mv -- "$tmp" "$file"
}

strip_import_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local tmp="${file}.mdbird-tmp.$$"
  awk -v start="$IMPORT_START" -v end="$IMPORT_END" '
    $0 == start { skip = 1; next }
    $0 == end   { skip = 0; next }
    !skip       { print }
  ' "$file" > "$tmp"
  mv -- "$tmp" "$file"
  if ! grep -q '[^[:space:]]' "$file"; then
    rm -f -- "$file"
  fi
}

resolve_profile
check_running

CHROME_DIR="$PROFILE_DIR/chrome"
TARGET_DIR="$CHROME_DIR/mdbird"
EXTENSIONS_DIR="$PROFILE_DIR/extensions"
SEARCH_XPI="$EXTENSIONS_DIR/mdbird-search@mdbird.local.xpi"

if [[ "$MODE" == "uninstall" ]]; then
  strip_import_block "$CHROME_DIR/userChrome.css"
  strip_import_block "$CHROME_DIR/userContent.css"
  if [[ -d "$TARGET_DIR" && -f "$TARGET_DIR/userChrome.css" ]] && grep -q 'MDBird' "$TARGET_DIR/userChrome.css"; then
    rm -rf -- "$TARGET_DIR"
  elif [[ -d "$TARGET_DIR" ]]; then
    warn "chrome/mdbird 存在，但看起来不是 MDBird，已保留。"
  fi
  rm -f -- "$SEARCH_XPI"
  rm -rf -- "$PROFILE_DIR/startupCache"
  log "MDBird 已从配置中移除："
  log "  配置: $PROFILE_DIR"
  log "  保留的 user.js 偏好不会被删除。"
  exit 0
fi

command -v zip >/dev/null 2>&1 || die "打包 MDBird Search 需要 zip。"
[[ -f "$SRC_SEARCH/manifest.json" ]] || die "缺少 search-addon/manifest.json。"
mkdir -p -- "$EXTENSIONS_DIR"
SEARCH_TMP="$(mktemp "$EXTENSIONS_DIR/.mdbird-search.XXXXXX")"
trap 'rm -f -- "$SEARCH_TMP"' EXIT
(
  cd -- "$SRC_SEARCH"
  zip -q -MM -r - manifest.json schema.json search.js search.css _locales
) > "$SEARCH_TMP"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR=""
backup_needed=0
for f in userChrome.css userContent.css; do
  [[ -f "$CHROME_DIR/$f" ]] && backup_needed=1
done
[[ -d "$TARGET_DIR" ]] && backup_needed=1
[[ -f "$SEARCH_XPI" ]] && backup_needed=1

mkdir -p -- "$CHROME_DIR"
if ((backup_needed)); then
  BACKUP_DIR="$CHROME_DIR/.mdbird-backup-$STAMP"
  if [[ -e "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$CHROME_DIR/.mdbird-backup-$STAMP-$$"
  fi
  mkdir -p -- "$BACKUP_DIR"
  for f in userChrome.css userContent.css; do
    [[ -f "$CHROME_DIR/$f" ]] && cp -p -- "$CHROME_DIR/$f" "$BACKUP_DIR/"
  done
  if [[ -d "$TARGET_DIR" ]]; then
    cp -Rp -- "$TARGET_DIR" "$BACKUP_DIR/mdbird"
  fi
  if [[ -f "$SEARCH_XPI" ]]; then
    cp -p -- "$SEARCH_XPI" "$BACKUP_DIR/"
  fi
fi

TMP_TARGET="$CHROME_DIR/.mdbird-new-$$"
rm -rf -- "$TMP_TARGET"
mkdir -p -- "$TMP_TARGET/theme"
cp -p -- "$SRC_USER_CHROME" "$SRC_USER_CONTENT" "$TMP_TARGET/"
cp -Rp -- "$SRC_THEME/." "$TMP_TARGET/theme/"

# Keep local customization and, when --accent is omitted, the previously
# selected accent. Uninstall/reinstall should not silently discard user work.
if [[ -f "$TARGET_DIR/theme/customization.css" ]]; then
  cp -p -- "$TARGET_DIR/theme/customization.css" "$TMP_TARGET/theme/customization.css"
fi

PRESERVE_PALETTE=0
if ((ACCENT_SET == 0)) && [[ -f "$TARGET_DIR/theme/palette.css" ]]; then
  cp -p -- "$TARGET_DIR/theme/palette.css" "$TMP_TARGET/theme/palette.css"
  PRESERVE_PALETTE=1
  # Keep palette files that are not shipped by the theme (custom palettes).
  if [[ -d "$TARGET_DIR/theme/palettes" ]]; then
    for palette_file in "$TARGET_DIR/theme/palettes"/*.css; do
      [[ -e "$palette_file" ]] || continue
      palette_name="${palette_file##*/}"
      if [[ ! -f "$SRC_THEME/palettes/$palette_name" ]]; then
        cp -p -- "$palette_file" "$TMP_TARGET/theme/palettes/$palette_name"
      fi
    done
  fi
fi

if ((PRESERVE_PALETTE == 0)); then
  printf '@import url("palettes/%s.css");\n' "$ACCENT" > "$TMP_TARGET/theme/palette.css"
  ACCENT_LABEL="$ACCENT"
else
  previous_accent="$(grep -oE 'palettes/[A-Za-z0-9._-]+\.css' "$TARGET_DIR/theme/palette.css" | head -n 1 | sed -e 's#palettes/##' -e 's#\.css$##' || true)"
  if [[ -n "$previous_accent" ]]; then
    ACCENT_LABEL="$previous_accent（沿用）"
  else
    ACCENT_LABEL="沿用安装前配置"
  fi
fi

if [[ -d "$TARGET_DIR" ]]; then
  rm -rf -- "$TARGET_DIR"
fi
mv -- "$TMP_TARGET" "$TARGET_DIR"

ensure_user_js "$PROFILE_DIR"
install_import_block "$CHROME_DIR/userChrome.css" "mdbird/userChrome.css"
install_import_block "$CHROME_DIR/userContent.css" "mdbird/userContent.css"
mv -- "$SEARCH_TMP" "$SEARCH_XPI"

# Thunderbird keeps compiled chrome stylesheets in startupCache. Removing it
# makes the next launch read every imported theme file from disk, which avoids
# a partially themed window after an install or an update.
rm -rf -- "$PROFILE_DIR/startupCache"

log "MDBird 已安装："
log "  配置:   $PROFILE_DIR"
log "  主题:   $TARGET_DIR"
log "  配色:   $ACCENT_LABEL"
if [[ -n "$BACKUP_DIR" ]]; then
  log "  备份:   $BACKUP_DIR"
fi
log ""
log "请完全退出并重新启动 Thunderbird。"
log "首次安装时，在 Thunderbird 的应用菜单中确认启用 MDBird Search。"
log "可在 theme/customization.css（安装后为 chrome/mdbird/theme/customization.css）中调整外观。"
