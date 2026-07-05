#!/bin/bash
# Exult 中文版 first-run launcher
# ---------------------------------------------------------------------------
# Installed into Exult.app/Contents/MacOS/ExultLauncher and set as the
# bundle's CFBundleExecutable (the real engine binary stays at MacOS/exult).
#
# What it does on every launch:
#   1. Syncs the bundled Chinese localization payload
#      (Contents/Resources/zh-content/{data,blackgate}) into
#      ~/Library/Application Support/Exult — the fork's default <DATA> /
#      <GAMEHOME> / <SAVEHOME> — whenever the payload version marker changes.
#      User data (STATIC, gamedat, save*.gam, exult.cfg) is never touched.
#   2. If blackgate/STATIC has no game data (INITGAME.DAT missing), shows a
#      dialog guiding the user to drop in their own legally-owned game files,
#      with an optional Spotlight auto-search for a GOG install.
#   3. exec's the real exult binary.
#
# Test hooks (used by make_zh_dmg.sh self-test, harmless otherwise):
#   EXULT_ZH_NONINTERACTIVE=1  never show dialogs; exit 3 if STATIC missing
#   EXULT_ZH_NO_EXEC=1         print the engine path instead of exec'ing it
# ---------------------------------------------------------------------------
set -u

MACOS_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES="$MACOS_DIR/../Resources"
PAYLOAD="$RESOURCES/zh-content"
SUPPORT="$HOME/Library/Application Support/Exult"
STATIC_DIR="$SUPPORT/blackgate/STATIC"
MARKER="$SUPPORT/.zh_content_version"
APP_TITLE="Exult 中文版"

LOG_DIR="$HOME/Library/Logs"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/Exult_zh_launcher.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG" 2>/dev/null; }

dialog() {
    # dialog <text> <button1> [button2] [button3]  -> echoes clicked button
    local text=$1; shift
    local buttons="\"$1\""
    local default=$1
    shift
    while [ $# -gt 0 ]; do
        buttons="$buttons, \"$1\""
        default=$1
        shift
    done
    /usr/bin/osascript 2>>"$LOG" <<EOF
tell application "System Events"
    activate
    set r to display dialog "$text" buttons {$buttons} default button "$default" with title "$APP_TITLE" with icon note
    return button returned of r
end tell
EOF
}

alert() {
    /usr/bin/osascript 2>>"$LOG" <<EOF >/dev/null
tell application "System Events"
    activate
    display dialog "$1" buttons {"知道了"} default button "知道了" with title "$APP_TITLE" with icon caution
end tell
EOF
}

# --------------------------------------------------------------------------
# 1. Sync localization payload into Application Support
# --------------------------------------------------------------------------
payload_version=""
[ -f "$PAYLOAD/VERSION" ] && payload_version="$(cat "$PAYLOAD/VERSION")"
installed_version=""
[ -f "$MARKER" ] && installed_version="$(cat "$MARKER")"

if [ -d "$PAYLOAD" ] && [ "$payload_version" != "$installed_version" ]; then
    log "syncing zh-content '$installed_version' -> '$payload_version' into $SUPPORT"
    mkdir -p "$SUPPORT" "$STATIC_DIR" "$SUPPORT/serpentisle/STATIC" || {
        alert "無法建立資料夾:
$SUPPORT

請檢查磁碟空間與權限後再試一次。"
        exit 1
    }
    # Overwrite engine data + Chinese patch/mods; never delete user additions,
    # never touch STATIC / gamedat / saves / exult.cfg.
    if ! /usr/bin/rsync -a "$PAYLOAD/data/" "$SUPPORT/data/" >>"$LOG" 2>&1; then
        alert "複製中文化資料失敗(data)。
請檢查磁碟空間後再試一次。詳見:
$LOG"
        exit 1
    fi
    if [ -d "$PAYLOAD/blackgate" ]; then
        for sub in patch mods; do
            if [ -d "$PAYLOAD/blackgate/$sub" ]; then
                /usr/bin/rsync -a "$PAYLOAD/blackgate/$sub/" "$SUPPORT/blackgate/$sub/" >>"$LOG" 2>&1 || {
                    alert "複製中文化資料失敗(blackgate/$sub)。詳見:
$LOG"
                    exit 1
                }
            fi
        done
    fi
    echo "$payload_version" >"$MARKER"
    log "sync done"
else
    mkdir -p "$SUPPORT" "$STATIC_DIR" 2>/dev/null
fi

# --------------------------------------------------------------------------
# 2. Make sure the user's own game data is in place
# --------------------------------------------------------------------------
has_static() {
    [ -n "$(find "$STATIC_DIR" -maxdepth 1 -iname 'initgame.dat' 2>/dev/null)" ]
}

auto_search() {
    # Look for a Black Gate STATIC folder via Spotlight (e.g. a GOG install).
    /usr/bin/mdfind -name 'INITGAME.DAT' 2>/dev/null \
        | /usr/bin/grep -i '/static/initgame\.dat$' \
        | /usr/bin/grep -iv 'serpent\|/Exult/' \
        | head -n 1
}

if ! has_static; then
    if [ "${EXULT_ZH_NONINTERACTIVE:-0}" = "1" ]; then
        log "STATIC missing (non-interactive) -> exit 3"
        exit 3
    fi
    while ! has_static; do
        choice=$(dialog "歡迎使用《創世紀 7:黑門》中文版!

還差最後一步:需要你自己準備的正版遊戲檔。
請把原版遊戲(例如 GOG 版)STATIC 資料夾內的【所有檔案】複製到:

~/Library/Application Support/Exult/blackgate/STATIC/

也可以讓我用 Spotlight 幫你找找已安裝的遊戲。" \
            "結束" "自動搜尋遊戲檔" "打開 STATIC 資料夾")
        case "$choice" in
        "打開 STATIC 資料夾")
            /usr/bin/open "$STATIC_DIR"
            next=$(dialog "已在 Finder 打開 STATIC 資料夾。

把原版 STATIC 裡的所有檔案複製進去後,按「重新檢查」繼續。" \
                "結束" "重新檢查")
            [ "$next" = "結束" ] && exit 0
            ;;
        "自動搜尋遊戲檔")
            found=$(auto_search)
            if [ -n "$found" ]; then
                src_dir=$(dirname "$found")
                ok=$(dialog "找到疑似《黑門》的遊戲檔:

$src_dir

要把裡面的檔案複製到 Exult 的 STATIC 資料夾嗎?" \
                    "取消" "複製")
                if [ "$ok" = "複製" ]; then
                    if /usr/bin/rsync -a "$src_dir/" "$STATIC_DIR/" >>"$LOG" 2>&1; then
                        log "auto-copied STATIC from $src_dir"
                    else
                        alert "複製失敗,請改用手動方式放入檔案。詳見:
$LOG"
                    fi
                fi
            else
                alert "找不到已安裝的遊戲檔。

請改用「打開 STATIC 資料夾」手動放入
原版遊戲 STATIC 內的所有檔案。"
            fi
            ;;
        *)
            exit 0
            ;;
        esac
    done
fi

# --------------------------------------------------------------------------
# 3. Hand over to the real engine
# --------------------------------------------------------------------------
log "launching engine"
if [ "${EXULT_ZH_NO_EXEC:-0}" = "1" ]; then
    echo "WOULD_EXEC:$MACOS_DIR/exult"
    exit 0
fi
exec "$MACOS_DIR/exult" "$@"
