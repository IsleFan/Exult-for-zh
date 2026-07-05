# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a downstream fork of the **Exult** engine (an open-source re-implementation of the *Ultima VII* game engine, C++/SDL2, GPL-2.0). It is **not** generic Exult — it layers a **Traditional Chinese (繁體中文) localization** on top of upstream, plus macOS packaging tooling. Three layers of attribution, from upstream to here:

- `exult/exult` — the original engine.
- `pmanyeh/Exult-for-zh` — the CJK rendering + dialogue/item translation work (the substance of the localization).
- This fork (`IsleFan/Exult-for-zh`) — macOS build/package automation and docs on top of pmanyeh.

Git remotes reflect this: **`origin` points at the upstream `pmanyeh/Exult-for-zh`**, and **`fork` points at this repo (`IsleFan/Exult-for-zh`)**. The local `main` tracks `fork/main`. To pull upstream localization work: `git fetch origin && git merge origin/main`. Push goes to `fork` by default.

## Building (macOS / Apple Silicon)

Standard autotools, but with **two fork-specific traps** that will bite a fresh build:

```bash
autoreconf -v -i
# Trap 1: this fork added ttf_font.cc (FreeType) but configure.ac does not
# auto-detect FreeType. Inject the freetype2 include path manually:
export CPPFLAGS="-I/opt/homebrew/include -I/opt/homebrew/include/freetype2"
export CFLAGS="$CPPFLAGS"; export CXXFLAGS="$CPPFLAGS"
export LDFLAGS="-L/opt/homebrew/lib"; export LIBS="-lfreetype"
./configure
```

```bash
# Trap 2: data/exult_flx.h is GENERATED from flx.in as a side effect of
# rebuilding exult.flx (no standalone recipe). A stale header causes
# "use of undeclared identifier 'EXULT_FLX_SHORTCUTBAR_VGA'". Rebuild in order,
# SINGLE-THREADED — parallel make races on the generated header:
make -C tools expack       # build the generator first
make -C data exult.flx     # regenerate the header from current flx.in
make                       # do NOT use make -j
```

Homebrew deps: `autoconf automake libtool pkg-config autoconf-archive sdl2 libvorbis libpng fluid-synth freetype dylibbundler create-dmg`.

There is no unit-test suite (`make check` defines no TESTS); verification is done by running the engine against game data.

### Packaging

```bash
make bundle          # Exult.app linked against Homebrew dylibs (local use)
make bundle_shared   # dylibbundler folds dylibs into the .app (portable)
make osxdmg          # build a drag-install .dmg
```

`make bundle` produces **engine-only** `Exult.app` — it contains no game data and no Chinese patch; those are positioned separately at runtime.

**`macosx/make_zh_dmg.sh [version] [pack_dir] [src_app]`** builds the actual release DMG: it takes the `make bundle` app, folds Homebrew dylibs in via dylibbundler (the raw bundle still links `/opt/homebrew` — not portable), injects the localization pack as `Contents/Resources/zh-content/` (copying `chinese.ttf` into `patch/`, the engine's zero-config font path), installs `macosx/zh_launcher.sh` as `CFBundleExecutable` (first-run sync to `~/Library/Application Support/Exult` + STATIC-placement dialogs; test hooks `EXULT_ZH_NONINTERACTIVE` / `EXULT_ZH_NO_EXEC`), ad-hoc signs, and wraps it with create-dmg.

The older **v1.0-style deliverable** was not the bare `.app` but an *integration pack* — see `release/Ultima7_BlackGate_zhTW_macOSv1.0/` for the reference layout: `Exult.dmg` (drag-install engine) + per-game `blackgate/` and `serpentisle/` dirs (each with `STATIC/`, `patch/`, `mods/`) + a shared `data/` holding the CJK fonts and repacked assets. Legit game `STATIC` data is user-supplied; the pack ships everything else. `Readme.txt` there is the Traditional-Chinese end-user install guide.

Two things the README will mislead you on: (1) the CJK fonts ship under `data/` with real filenames (`NotoSerifTC-Light.ttf`, `WangHanZongWeiBeiTiFan-2.ttf`) referenced via config `font_path` — not literally `chinese.ttf`; the `<PATCH>/chinese.ttf` name in the pipeline section is only the hard-coded default when no config path is set. (2) `README.md` documents a one-shot assembly script `setup-exult-zh.sh` (`--portable`/`--system`), but **that script is not present in the repo** — the `release/` pack was assembled by other means. Don't send a user to a script that isn't there.

## Localization architecture

The localization is a set of targeted edits to upstream subsystems plus an out-of-tree asset/translation pipeline. **`Exult_Changes_Summary.md` is the authoritative index of every functional code change** — consult it before touching localization code. The major touch points:

- **Font rendering** — `shapes/ttf_font.cc` (TTF/CJK loading, anti-clipping, separate "small font" for books/scrolls), `shapes/font.{cc,h}` (custom font paths from config, CJK line-height/spacing), `shapeid.{cc,h}` / `shapes/fontvga.h` (the `force_cjk` param threaded through `paint_text` overloads — easy to break when merging upstream).
- **Dialogue** — `usecode/conversation.{cc,h}` (NPC-portrait collision layout, CJK choice wrapping, `get_choice_rect()`), `usecode/ucinternal.cc` (CJK choice string matching, plus arrow-key/Enter navigation of dialogue choices in `get_user_choice_num()`).
- **Input plumbing** — `exult.{cc,h}`: `Get_click()` gained an `int* keycode` out-param so motion keys can drive dialogue navigation instead of being swallowed by `IsMotionEvent`. This is the foundation the dialogue keyboard-nav depends on.
- **UI** — `gumps/Spellbook_gump.{cc,h}` (translated spell names), `effects.cc` (`Font::is_painting_bark` so overhead bark text reads `font_size_bark`).

When merging from `origin`, upstream signature changes to `paint_text`, `Get_click`, and the conversation/usecode code are the recurring conflict zones — the summary doc explains what each fork hook protects.

## Translation / asset pipeline

The engine is built to decode **UTF-8** (codepage default `UTF8` in `shapes/ttf_font.cc`). Localized content is delivered as a game **patch** directory, not compiled into the engine:

- `<PATCH>/chinese.ttf` — the CJK font (hard-coded patch filename; overridable via config paths below).
- `<PATCH>/usecode` (no extension) — translated dialogue scripts. **Must be UTF-8**; the older Big5 builds render as mojibake. Use the `usecode.2026*` builds under `tools/ucxt/output/usecode_builds/`.
- `STATIC/TEXT.FLX` — item names; repackaged with the `textpack` tool (added to the VS solution in this fork) over a translated source.
- `tools/ucxt/output/` — the usecode decompile→translate workspace (`blackgate_translation.xml`, decompiled scripts, dated build outputs). Pure-translation content here is intentionally excluded from `Exult_Changes_Summary.md`.
- `tools/Magic_voices/` — custom spell-voice SFX repacked into `.flx`, with generated index headers (`new_jmsfx_flx.h`, `sqsfxbg_custom_flx.h`).

## Runtime configuration

CJK rendering is tuned via a `<chinese>` block inside `<video>` in `exult.cfg` (font paths, sizes, `line_spacing`, `letter_spacing`, `font_weight`, shadow/outline, separate `sign_font_path` for in-world signs, `font_size_bark` for overhead text). **`README_Chinese_Config.md` documents every parameter** — point users there rather than re-deriving defaults.

On macOS there is no `-p`/portable flag (Windows-only build); use `-c <config>` to point at a specific `exult.cfg`. Exult writes `exult.cfg` only on clean exit or when settings change in-menu — not on first launch — so a missing config usually means it was never created, not an error.

## Reference docs

- `README.md` — macOS build/package/troubleshooting walkthrough (the build traps above expanded, plus where game data and `exult.cfg` must live).
- `Exult_Changes_Summary.md` — every functional code change in the fork, with rationale.
- `README_Chinese_Config.md` — the `<chinese>` config reference.
- `Exult_Sync_Guide.md` / `Exult_VS_Build_Guide.md` / `DevLog_202606_Runic_and_UI.md` — upstream-sync procedure, Windows/VS build, and runic-text/UI dev notes.
