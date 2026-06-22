# Exult-for-zh · macOS 安裝與打包工具

在 **macOS (Apple Silicon)** 上編譯、組裝、打包 *Ultima VII* 繁體中文版的完整流程與一鍵工具。

本倉庫在 [pmanyeh/Exult-for-zh](https://github.com/pmanyeh/Exult-for-zh) 的繁中化成果之上,
補上 macOS 端的**自動組裝腳本** (`setup-exult-zh.sh`) 與**完整建置/疑難排解文件**。

---

## 📌 來源與致謝 (Attribution)

| 層級 | 專案 | 內容 |
|---|---|---|
| 本倉庫 | (你的 fork) | macOS 安裝/可攜/打包工具與文件 |
| 上游 fork | **[pmanyeh/Exult-for-zh](https://github.com/pmanyeh/Exult-for-zh)** | *Ultima VII* 繁體中文化:CJK 渲染引擎修改 + 對話/物品翻譯 |
| 原始引擎 | **[exult/exult](https://github.com/exult/exult)** | Exult — 開源的 *Ultima VII* 遊戲引擎 (GPL-2.0) |

> 繁體中文化的引擎修改與全部翻譯成果,皆為 **pmanyeh/Exult-for-zh** 專案作者所完成,
> 在此致謝。本倉庫僅將其在 macOS 上的安裝與打包流程自動化,**不含任何遊戲版權檔**。
>
> 遊戲資料 (`STATIC`) 需自備**正版**(例如於 GOG 購買的 *Ultima VII: The Black Gate /
> Serpent Isle*),本工具不散布遊戲內容。

---

## 🧩 本倉庫提供什麼

- **`setup-exult-zh.sh`** — 一鍵把「已編譯的引擎 + 繁中字型/對話/圖檔 + 你的正版遊戲檔」
  組裝成可執行環境,支援兩種模式:
  - `--portable` 組成自帶引擎與遊戲、整包可搬移的資料夾(預設)
  - `--system` 安裝到 macOS 標準路徑
- 完整的**建置流程**與**疑難排解**文件(見下)。

---

## ✅ 前置需求

1. **Xcode**(完整版,bundle 階段會用到)。
2. **Homebrew 套件**:
   ```bash
   brew install autoconf automake libtool pkg-config autoconf-archive \
     sdl2 libvorbis libpng fluid-synth freetype dylibbundler create-dmg
   ```
3. **正版遊戲**:GOG 版 *Ultima VII* 的兩個 `.app`(Black Gate / Serpent Isle)。

---

## 🔨 編譯引擎

從 clone 下來的原始碼建置。**有兩個此 fork 特有的坑**要注意:

```bash
git clone https://github.com/<你的帳號>/Exult-for-zh.git
cd Exult-for-zh
autoreconf -v -i
```

### 坑 1:FreeType 標頭找不到 (`ft2build.h file not found`)

此 fork 為了渲染 TTF 中文字型新增了 `ttf_font.cc`,但 `configure.ac` 沒加入 FreeType
偵測。需手動注入路徑(FreeType 的 header 在 `freetype2/` 子目錄):

```bash
export CPPFLAGS="-I/opt/homebrew/include -I/opt/homebrew/include/freetype2"
export CFLAGS="$CPPFLAGS"; export CXXFLAGS="$CPPFLAGS"
export LDFLAGS="-L/opt/homebrew/lib"; export LIBS="-lfreetype"
./configure
```

### 坑 2:`use of undeclared identifier 'EXULT_FLX_SHORTCUTBAR_VGA'`

`data/exult_flx.h` 由 `expack` 從 `flx.in` 自動生成(無獨立 recipe,只在 `exult.flx`
重建時當副產物產生)。若殘留 stale header 就會缺常數。**請依序、單執行緒建置**:

```bash
make -C tools expack          # 先建生成工具
make -C data exult.flx        # 用現在的 flx.in 重新生成 header
grep -i shortcutbar data/exult_flx.h   # 應看到 EXULT_FLX_SHORTCUTBAR_VGA
make                          # ⚠️ 不要用 make -j(平行會 race)
```

---

## 🚀 一鍵組裝 (`setup-exult-zh.sh`)

```bash
chmod +x setup-exult-zh.sh
```

### 可攜版(預設,推薦)

```bash
./setup-exult-zh.sh --portable ~/ExultZH --src ~/git/Exult-for-zh \
  --bg "/path/to/Ultima VII™  - The Black Gate + The Forge of Virtue.app" \
  --si "/path/to/Ultima VII™  - Serpent Isle + The Silver Seed.app"
```

不指定 `--bg/--si` 時會自動到 `~/Downloads` 找;找不到則建立空的 `STATIC/` 供你手動放入。

啟動:雙擊資料夾內的 **`ExultZH.command`**(或終端機執行)。它會依資料夾位置即時產生
設定檔並把存檔鎖在資料夾內,所以整包可任意搬移。

### 安裝到系統路徑

```bash
sudo EXULT_SRC=~/git/Exult-for-zh ./setup-exult-zh.sh --system
```

### 參數

| 參數 | 說明 |
|---|---|
| `--portable [DEST]` | 可攜模式(預設 `~/ExultZH-Portable`) |
| `--system` | 安裝到 `/Library/Application Support/Exult`(需 sudo) |
| `--src PATH` | Exult-for-zh 原始碼/建置目錄 |
| `--bg PATH` / `--si PATH` | GOG 兩款遊戲 `.app` 路徑 |

可攜版資料夾結構:

```
ExultZH/
├── exult                ← 引擎執行檔
├── data/                ← 引擎資料 (exult.flx / exult_bg.flx / exult_si.flx …)
├── blackgate/
│   ├── STATIC/          ← Black Gate 遊戲檔
│   └── patch/           ← chinese.ttf / usecode / mainshp.flx / endshape.flx
├── serpentisle/{STATIC,patch}/
├── exult.cfg            ← 啟動器自動產生(勿手改)
└── ExultZH.command      ← 雙擊啟動
```

---

## 📦 打包成 .app / DMG

在已 `make` 成功的建置目錄:

```bash
make bundle          # 本機自用(連結 Homebrew 動態庫)
make bundle_shared   # 跨機可攜(dylibbundler 把動態庫收進 .app)
make osxdmg          # 連同拖曳安裝介面打包成 .dmg
```

輸出為建置目錄下的 `Exult.app`。注意 `make bundle` **只含引擎**,不含遊戲與中文 patch
——這些要另外就定位(見下)。未啟用 code signing 時首次開啟需右鍵 →「打開」過 Gatekeeper。

---

## 🗂️ 遊戲資料放哪 / `exult.cfg`

遊戲**不一定**要放 `/Library/Application Support/Exult`。路徑解析(macOS):

- **遊戲 STATIC 預設搜尋位置**:`/Library/Application Support/Exult/<遊戲>`(系統,需 sudo)
- **設定檔與存檔**:`~/Library/Application Support/Exult/`(你的家目錄)

要放別處(免 sudo),在 `~/Library/Application Support/Exult/exult.cfg` 指定 `path`:

```xml
<?xml version="1.0"?>
<config>
  <disk>
    <game>
      <blackgate><path>/Users/you/Games/U7/blackgate</path></blackgate>
      <serpentisle><path>/Users/you/Games/U7/serpentisle</path></serpentisle>
    </game>
  </disk>
</config>
```

對應放成 `<path>/static`(遊戲檔)與 `<path>/patch`(中文 patch)。

> **`exult.cfg` 不見?** Exult **不會一啟動就建立它**——只在乾淨結束或於選單改設定時才寫出。
> 且 `~/Library` 在 Finder 預設隱藏。最可靠是自己用終端機建立此檔。

| 放哪 | sudo | 怎麼讓 .app 找到 |
|---|---|---|
| `/Library/Application Support/Exult`(預設) | 要 | 不用設定 |
| 任意資料夾 | 不用 | `~/Library/.../exult.cfg` 設 `path` |
| 完全自包在 .app 內 | 不用 | 執行檔換成 wrapper,用 `-c` 指 app 內設定 |

---

## 🔧 疑難排解

| 症狀 | 原因 / 解法 |
|---|---|
| `ft2build.h file not found` | FreeType 沒進 configure → 見「坑 1」注入 `freetype2` 路徑 |
| `EXULT_FLX_SHORTCUTBAR_VGA` undeclared | stale 生成 header → 見「坑 2」依序重建、勿平行 |
| **SFX 顯示 Disabled** | 原版無 Exult 格式音效,需自 [exult.info](https://exult.info) 下載 SFX pack 放進 data 夾 |
| 遊戲**全英文**、看不到中文 | patch 未安裝;`patch/usecode`(無副檔名)+ `patch/chinese.ttf` 要就位 |
| 中文變**亂碼** | 用到 **Big5** 版 usecode。本引擎吃 **UTF-8**,只能用 `usecode_builds/usecode.2026*` |
| 物品名仍英文 | 物品名在 `STATIC/TEXT.FLX`,需以 `textpack` 重打包翻譯版覆蓋 |
| `npc.dat … errno 2`(建 gamedat 失敗) | 可寫目錄鏈不存在 / `$HOME` 被污染。可攜啟動器已 `mkdir -p` 預建 |
| `exult.cfg` 不存在 | 見上節:啟動不會建立、`~/Library` 隱藏;自行建立即可 |

### 技術備註

- 引擎以 **UTF-8** 解碼(`shapes/ttf_font.cc`),codepage 預設 `UTF8`。
- 中文字型固定讀 `<PATCH>/chinese.ttf`;對話讀 `<PATCH>/usecode`(無副檔名)。
- macOS **沒有** `-p` portable 旗標(僅 Windows 編譯),改用 `-c <設定檔>`。

---

## 📜 授權

- Exult 引擎與本 fork 引擎程式碼:**GPL-2.0**。
- 繁體中文翻譯與 CJK 修改:版權屬 [pmanyeh/Exult-for-zh](https://github.com/pmanyeh/Exult-for-zh) 作者。
- 遊戲資料 *Ultima VII*:版權屬原權利人,使用者需自備正版,本倉庫不散布。
- 本倉庫之 macOS 工具腳本:沿用上游 GPL-2.0。
