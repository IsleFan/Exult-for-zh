#!/bin/bash
# Build the self-contained Traditional-Chinese Exult DMG.
# ---------------------------------------------------------------------------
# Takes the already-built Exult.app (make bundle), makes it portable
# (dylibbundler), injects the Chinese localization payload from a release
# pack, installs the first-run launcher (macosx/zh_launcher.sh), ad-hoc
# signs everything and wraps it in a drag-install DMG.
#
# Usage:
#   macosx/make_zh_dmg.sh [version] [pack_dir] [src_app]
#
#   version   release version, default: 1.1
#   pack_dir  localization pack with data/ + blackgate/ + Readme.txt,
#             default: release/Ultima7_BlackGate_zhTW_vx.x_for_Mac
#   src_app   built engine bundle, default: ./Exult.app
#
# Output: release/Ultima7_BlackGate_zhTW_v<version>_for_Mac.dmg
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$PWD"

VERSION="${1:-1.1}"
PACK="${2:-release/Ultima7_BlackGate_zhTW_vx.x_for_Mac}"
SRC_APP="${3:-Exult.app}"

DMG_NAME="Ultima7_BlackGate_zhTW_v${VERSION}_for_Mac"
OUT_DMG="release/${DMG_NAME}.dmg"
BUILD="release/.build_zh_dmg"
APP="$BUILD/Exult.app"

for tool in dylibbundler create-dmg; do
    command -v "$tool" >/dev/null || {
        echo "error: '$tool' not found (brew install $tool)" >&2
        exit 1
    }
done
[ -d "$SRC_APP" ] || { echo "error: source app '$SRC_APP' not found (run 'make bundle' first)" >&2; exit 1; }
[ -d "$PACK/data" ] && [ -d "$PACK/blackgate" ] || { echo "error: '$PACK' is not a localization pack (needs data/ + blackgate/)" >&2; exit 1; }

echo "==> Staging $SRC_APP"
rm -rf "$BUILD"
mkdir -p "$BUILD"
/usr/bin/ditto "$SRC_APP" "$APP"
# strip anything Finder/quarantine related from previous handling
xattr -cr "$APP" 2>/dev/null || true
find "$APP" -name .DS_Store -delete

echo "==> Folding Homebrew dylibs into the bundle"
rm -rf "$APP/Contents/Resources/lib"
dylibbundler -ns -od -b \
    -x "$APP/Contents/MacOS/exult" \
    -d "$APP/Contents/Resources/lib" \
    -p @executable_path/../Resources/lib \
    -i /usr/lib >/dev/null
if otool -L "$APP/Contents/MacOS/exult" | grep -q /opt/homebrew; then
    echo "error: engine binary still links /opt/homebrew after dylibbundler" >&2
    exit 1
fi

echo "==> Injecting Chinese localization payload"
ZH="$APP/Contents/Resources/zh-content"
mkdir -p "$ZH"
/usr/bin/rsync -a \
    --exclude .DS_Store \
    --exclude Makefile.am \
    --exclude flx.in \
    --exclude '*.h' \
    --exclude '*.uc' \
    --exclude '*.glade' \
    "$PACK/data/" "$ZH/data/"
/usr/bin/rsync -a --exclude .DS_Store \
    "$PACK/blackgate/" "$ZH/blackgate/"
mkdir -p "$ZH/blackgate/STATIC" "$ZH/blackgate/mods"
# The engine's zero-config CJK font path is <PATCH>/chinese.ttf — make sure
# the patch actually carries the font (the packs keep it in data/ only).
if [ ! -f "$ZH/blackgate/patch/chinese.ttf" ]; then
    [ -f "$PACK/data/chinese.ttf" ] || { echo "error: chinese.ttf not found in pack" >&2; exit 1; }
    cp "$PACK/data/chinese.ttf" "$ZH/blackgate/patch/chinese.ttf"
    echo "    added chinese.ttf -> blackgate/patch/ (engine default font path)"
fi
# Preset exult.cfg: the pack ships a Windows-flavored cfg (relative paths,
# backslashes). Rewrite those for the macOS layout, leaving all tuning values
# (font sizes, shadows, brightness boosts...) untouched. @EXULT_HOME@ is
# substituted with the real Application Support path by the launcher at
# install time.
if [ -f "$PACK/exult.cfg" ]; then
    sed \
        -e 's|>\./data<|>@EXULT_HOME@/data<|g' \
        -e 's|\./Ultima_7_SI|@EXULT_HOME@/serpentisle|g' \
        -e 's|\./Ultima_7|@EXULT_HOME@/blackgate|g' \
        -e 's|data\\|@EXULT_HOME@/data/|g' \
        "$PACK/exult.cfg" >"$ZH/exult.cfg.template"
    if grep -qE '\./Ultima|\./data|data\\' "$ZH/exult.cfg.template"; then
        echo "error: exult.cfg still contains unconverted relative/Windows paths" >&2
        exit 1
    fi
    echo "    converted exult.cfg -> zh-content/exult.cfg.template"
fi
printf '%s\n' "$VERSION" >"$ZH/VERSION"

echo "==> Installing first-run launcher"
install -m 755 macosx/zh_launcher.sh "$APP/Contents/MacOS/ExultLauncher"
PB=/usr/libexec/PlistBuddy
PLIST="$APP/Contents/Info.plist"
$PB -c "Set :CFBundleExecutable ExultLauncher" "$PLIST"
$PB -c "Set :CFBundleIdentifier info.exult.zh" "$PLIST"
$PB -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
$PB -c "Set :CFBundleVersion $VERSION" "$PLIST"
$PB -c "Add :CFBundleDisplayName string 'Exult 中文版'" "$PLIST" 2>/dev/null \
    || $PB -c "Set :CFBundleDisplayName 'Exult 中文版'" "$PLIST"
[ -f "$PACK/Readme.txt" ] && cp "$PACK/Readme.txt" "$APP/Contents/Documents/Readme_中文版.txt"

echo "==> Ad-hoc code signing"
find "$APP/Contents/Resources/lib" -name '*.dylib' -exec codesign --force --sign - {} \; 2>/dev/null
codesign --force --sign - "$APP/Contents/MacOS/exult"
codesign --force --sign - "$APP"
codesign --verify --deep "$APP"

echo "==> Building DMG"
DMG_ROOT="$BUILD/dmgroot"
mkdir -p "$DMG_ROOT"
mv "$APP" "$DMG_ROOT/Exult.app"
[ -f "$PACK/Readme.txt" ] && cp "$PACK/Readme.txt" "$DMG_ROOT/安裝說明.txt"
rm -f "$OUT_DMG"
create-dmg \
    --volname "Exult 中文版 v${VERSION}" \
    --volicon macosx/exult.icns \
    --window-pos 200 120 \
    --window-size 640 420 \
    --text-size 14 \
    --icon-size 100 \
    --icon "Exult.app" 160 200 \
    --app-drop-link 480 200 \
    --icon "安裝說明.txt" 320 70 \
    --hdiutil-quiet \
    --no-internet-enable \
    "$OUT_DMG" \
    "$DMG_ROOT" >/dev/null

rm -rf "$BUILD"
echo "==> Done: $OUT_DMG ($(du -h "$OUT_DMG" | cut -f1 | tr -d ' '))"
