#!/bin/bash
# Build the self-contained Traditional-Chinese Exult DMG.
# ---------------------------------------------------------------------------
# Takes the already-built Exult.app (make bundle), makes it portable
# (dylibbundler), injects the Chinese localization payload from a release
# pack, installs the first-run launcher (macosx/zh_launcher.sh), ad-hoc
# signs everything and wraps it in a drag-install DMG.
#
# Usage:
#   macosx/make_zh_dmg.sh [version] [pack_dir] [src_app] [portable]
#
#   version   release version, default: 1.1
#   pack_dir  localization pack with data/ + blackgate/ + Readme.txt,
#             default: release/Ultima7_BlackGate_zhTW_vx.x_for_Mac
#   src_app   built engine bundle, default: ./Exult.app
#   portable  literal "portable" → build the fully-portable zip instead:
#             a folder with Exult.app + ExultData/ side by side. The launcher
#             detects the ExultData sibling and keeps ALL data (game files,
#             saves, config, logs) inside it — movable across disks/machines.
#
# Output: release/Ultima7_BlackGate_zhTW_v<version>_for_Mac.dmg
#     or: release/Ultima7_BlackGate_zhTW_v<version>_Portable.zip
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$PWD"

VERSION="${1:-1.1}"
PACK="${2:-release/Ultima7_BlackGate_zhTW_vx.x_for_Mac}"
SRC_APP="${3:-Exult.app}"
MODE="${4:-dmg}"

DMG_NAME="Ultima7_BlackGate_zhTW_v${VERSION}_for_Mac"
OUT_DMG="release/${DMG_NAME}.dmg"
PORTABLE_NAME="Ultima7_BlackGate_zhTW_v${VERSION}_Portable"
OUT_ZIP="release/${PORTABLE_NAME}.zip"
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
        "$PACK/exult.cfg" >"$ZH/exult.cfg.template.tmp"
    # Without explicit savegame_path/gamedat_path the engine defaults them to
    # <SAVEHOME>/<game> — a directory chain that doesn't exist in portable
    # mode, and U7mkdir is non-recursive, so entering the game dies on the
    # first gamedat/autosave write. Pin saves next to the game data.
    if ! grep -q "savegame_path" "$ZH/exult.cfg.template.tmp"; then
        awk '{
            print
            if (match($0, /<patch>@EXULT_HOME@\/(blackgate|serpentisle)\/patch<\/patch>/)) {
                game = $0
                sub(/.*<patch>@EXULT_HOME@\//, "", game)
                sub(/\/patch<\/patch>.*/, "", game)
                ind = $0
                sub(/[^ \t].*/, "", ind)
                print ind "<savegame_path>@EXULT_HOME@/" game "</savegame_path>"
                print ind "<gamedat_path>@EXULT_HOME@/" game "/gamedat</gamedat_path>"
            }
        }' "$ZH/exult.cfg.template.tmp" >"$ZH/exult.cfg.template"
        rm -f "$ZH/exult.cfg.template.tmp"
    else
        mv "$ZH/exult.cfg.template.tmp" "$ZH/exult.cfg.template"
    fi
    if grep -qE '\./Ultima|\./data|data\\' "$ZH/exult.cfg.template"; then
        echo "error: exult.cfg still contains unconverted relative/Windows paths" >&2
        exit 1
    fi
    if ! grep -q "gamedat_path" "$ZH/exult.cfg.template"; then
        echo "error: exult.cfg template missing gamedat_path" >&2
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

if [ "$MODE" = "portable" ]; then
    echo "==> Building portable zip"
    PROOT="$BUILD/$PORTABLE_NAME"
    mkdir -p "$PROOT/ExultData"
    mv "$APP" "$PROOT/Exult.app"
    cat >"$PROOT/ExultData/遊戲資料都會放在這裡.txt" <<'EOF'
這個資料夾存放 Exult 中文版的所有資料:
中文化檔案、你的正版遊戲檔 (blackgate/STATIC)、存檔與設定。
第一次執行 Exult.app 時會自動把內容準備好。
整個上層資料夾(含 Exult.app 與 ExultData)可以整包搬移、放隨身碟。
EOF
    cat >"$PROOT/使用說明.txt" <<'EOF'
# 創世紀 7 (Ultima 7) 中文化版 - macOS 可攜版 (Portable)

這是「免安裝、整包帶著走」的版本:引擎、中文化資料、遊戲檔、存檔、設定
全部住在這個資料夾裡。放隨身碟、搬別台 Mac(Apple Silicon)都可以。

## 使用方式
1. 把整個資料夾解壓縮後,搬到**家目錄下的資料夾**(例如自己建一個「Games」)或隨身碟。
   ⚠️ **不要放在「下載」「桌面」「文件」**——macOS 的隱私保護會擋下存檔寫入,導致進不了遊戲。
2. 第一次執行:對 Exult.app 按住 Control 鍵點一下 → 「打開」→ 再按「打開」。
   (沒有付費簽章的正常現象,只需做這一次)
3. 依照跳出的視窗指引,放入你的正版遊戲 STATIC 檔案(或用自動搜尋)。
4. 開始遊戲!之後雙擊即可。

## 所有東西都在 ExultData 裡
* 遊戲檔:      ExultData/blackgate/STATIC/
* 存檔與進度:  ExultData/blackgate/(gamedat 資料夾與 save 檔)
* 設定檔:      ExultData/Library/Preferences/exult.cfg
* 中文化資料:  ExultData/data/ 與 ExultData/blackgate/patch/
備份或搬家 = 複製整個資料夾,就這麼簡單。

## 注意
* Exult.app 和 ExultData 必須放在同一層;拆開的話 Exult.app 會退回
  一般安裝模式(資料改存 ~/Library/Application Support/Exult)。
* 更新版本時只要換掉 Exult.app,ExultData(含存檔)原封不動。
EOF
    rm -f "$OUT_ZIP"
    /usr/bin/ditto -c -k --keepParent "$PROOT" "$OUT_ZIP"
    rm -rf "$BUILD"
    echo "==> Done: $OUT_ZIP ($(du -h "$OUT_ZIP" | cut -f1 | tr -d ' '))"
    exit 0
fi

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
