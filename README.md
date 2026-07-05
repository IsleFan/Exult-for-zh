# Exult-for-zh · macOS 安裝與打包工具

在 **macOS (Apple Silicon)** 上編譯、組裝、打包 *Ultima VII* 繁體中文版的完整流程與一鍵工具。

本倉庫在 [pmanyeh/Exult-for-zh](https://github.com/pmanyeh/Exult-for-zh) 的繁中化成果之上,
補上 macOS 端的**打包工具**(`macosx/make_zh_dmg.sh`)與**完整建置/疑難排解文件**。

---

## 🎮 直接下載玩(免編譯)

到 [**Releases**](../../releases) 下載 **`Ultima7_BlackGate_zhTW_v1.1_Portable.zip`**(可攜版):

1. 解壓縮後搬到**家目錄下的資料夾**(例如 `~/Games`)或隨身碟。
   ⚠️ 別放「下載/桌面/文件」——macOS 隱私保護會擋存檔寫入,進不了遊戲。
2. 第一次執行:對 `Exult.app` 按住 **Control 鍵點一下** → 「打開」→ 再按「打開」。
3. 依跳出的視窗指引放入你的**正版**遊戲 STATIC 檔案(有裝 GOG 版可用「自動搜尋」一鍵複製)。
4. 開始遊戲!

**所有東西**(中文化資料、遊戲檔、存檔、設定)都住在旁邊的 `ExultData/` 資料夾——
備份、搬機、換路徑就是複製整個資料夾;更新版本只要換掉 `Exult.app`,存檔不動。
詳見包內的 `使用說明.txt`。

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

- **`macosx/make_zh_dmg.sh`** — 一鍵把「已編譯的引擎 + 中文化整合包」打包成:
  - 拖曳安裝 **DMG**(資料放家目錄 Application Support)
  - 完全**可攜 zip**(`Exult.app` + `ExultData/` 同層,整包任意搬移)
- **`macosx/zh_launcher.sh`** — App 首次啟動器:自動展開中文化資料、對話框引導
  放入正版 STATIC(含 Spotlight 自動搜尋)、絕不覆蓋使用者存檔與設定。
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

## 🚀 打包發佈 (`macosx/make_zh_dmg.sh`)

把「已編譯的引擎 + 中文化整合包」打包成發佈用安裝檔,一條指令:

```bash
# 拖曳安裝 DMG(資料放 ~/Library/Application Support/Exult)
./macosx/make_zh_dmg.sh 1.1

# 完全可攜 zip(Exult.app + ExultData 同層,整包帶著走)
./macosx/make_zh_dmg.sh 1.1 release/Ultima7_BlackGate_zhTW_vx.x_for_Mac Exult.app portable
```

腳本會自動完成:

1. **dylibbundler** 把 Homebrew 動態庫收進 `.app`(跨機可攜,免裝 Homebrew)。
2. 注入中文化 payload(`data/`、`blackgate/patch`、mods)到 `Contents/Resources/zh-content/`,
   並把 `chinese.ttf` 補進 `patch/`(引擎零設定的預設字型路徑)。
3. 把整合包的 `exult.cfg` 轉成 macOS 模板(修正 Windows 相對路徑/反斜線,
   補上 `savegame_path`/`gamedat_path`),調校值原封保留。
4. 安裝**首次啟動器**(`macosx/zh_launcher.sh`):自動展開中文化資料、
   對話框引導放入正版 STATIC(含 Spotlight 自動搜尋)、擷取引擎輸出到紀錄檔。
5. ad-hoc 簽名 → `create-dmg` / `ditto` 打包。

### 可攜版運作原理

啟動器偵測到 `Exult.app` 旁有 **`ExultData/`** 資料夾即切換可攜模式:
`HOME` 重導向進去、設定檔用 `./` 相對路徑、以 `ExultData` 為工作目錄啟動引擎。
整個資料夾搬到哪都能跑;拆開則自動退回一般安裝模式。

```
Ultima7_BlackGate_zhTW_v1.1_Portable/
├── Exult.app            ← 雙擊啟動
├── ExultData/
│   ├── blackgate/{STATIC,patch,mods,gamedat}/   ← 遊戲檔/中文化/存檔
│   ├── data/                                    ← 引擎資料、字型、音樂
│   └── Library/Preferences/exult.cfg            ← 設定檔(預先調校)
└── 使用說明.txt
```

除錯:引擎的錯誤輸出在 `ExultData/Library/Logs/Exult_engine.log`
(一般安裝模式在 `~/Library/Logs/`)。

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

> **本 fork 的 macOS 預設已改**:引擎資料與遊戲全部集中在**家目錄**
> `~/Library/Application Support/Exult/`,**不需 sudo、不碰系統層 `/Library`**。
> (改動於 `files/utils.cc` 的 `Get_gamehome_dir()` 與 `setup_data_dir()`;原版預設是系統層
> `/Library/Application Support/Exult`,需 sudo。)

預設目錄結構(全部在你的家目錄下,可寫):

```
~/Library/Application Support/Exult/
├── data/                       ← 引擎資料:exult.flx / exult_bg.flx / exult_si.flx
│                                  + 音效包 sqsfxbg.flx / sqsfxsi.flx / jmsfx.flx …
├── blackgate/
│   ├── static/ (或 STATIC)     ← Black Gate 遊戲檔(自備正版)
│   ├── patch/                  ← chinese.ttf / usecode / mainshp.flx / ENDSHAPE.FLX …
│   └── gamedat/                ← 引擎產生(進度/存檔)
└── serpentisle/{static,patch,gamedat}/
```

| 內容 | 系統路徑變數 | 預設位置 | sudo |
|---|---|---|---|
| 引擎資料 | `<DATA>` | `~/Library/Application Support/Exult/data` | 不用 |
| 遊戲 static / patch | `<GAMEHOME>` | `~/Library/Application Support/Exult/<遊戲>` | 不用 |
| 存檔 / gamedat | `<SAVEHOME>` | `~/Library/Application Support/Exult/<遊戲>` | 不用 |
| 設定檔 `exult.cfg` | — | `~/Library/Preferences/exult.cfg` | 不用 |

想放別處?在 `~/Library/Preferences/exult.cfg` 用 `<path>` / `<data_path>` 覆蓋預設:

```xml
<?xml version="1.0"?>
<config>
  <disk>
    <data_path>/your/engine/data</data_path>
    <game>
      <blackgate><path>/Users/you/Games/U7/blackgate</path></blackgate>
      <serpentisle><path>/Users/you/Games/U7/serpentisle</path></serpentisle>
    </game>
  </disk>
</config>
```

對應放成 `<path>/static`(遊戲檔)與 `<path>/patch`(中文 patch)。

> **找不到 `exult.cfg`?** 它在 **`~/Library/Preferences/exult.cfg`**(不是 Application Support)。
> `~/Library` 在 Finder 預設隱藏 —— 用 `open ~/Library/Preferences/exult.cfg`,或在 Finder 按
> `⌘⇧G` 貼上路徑。且 Exult **不會一啟動就建立它**,只在乾淨結束或於選單改設定時才寫出。

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
| `exult.cfg` 找不到 | 在 **`~/Library/Preferences/exult.cfg`**(隱藏);啟動不會自動建立,乾淨結束後才寫出 |
| 遊戲讀不到 / 要 sudo | 確認資料在**家目錄** `~/Library/Application Support/Exult/`(本 fork 新預設),不是系統層 `/Library` |
| App **閃退**(無 crash report) | 多半是引擎乾淨例外退出。看引擎紀錄:可攜版 `ExultData/Library/Logs/Exult_engine.log`,安裝版 `~/Library/Logs/Exult_engine.log` |
| 輸入角色名後退出 | 存檔目錄建不起來(舊版 cfg 缺 `savegame_path`/`gamedat_path`)→ 換 v1.1 以上的包,或刪掉 `exult.cfg` 重新啟動讓它重建 |
| 可攜版進不了遊戲、log 出現 `Operation not permitted` | 資料夾放在「下載/桌面/文件」等 macOS 隱私保護區 → 整包搬到家目錄下的資料夾(例:`~/Games`)即解 |

### 技術備註

- 引擎以 **UTF-8** 解碼(`shapes/ttf_font.cc`),codepage 預設 `UTF8`。
- 中文字型固定讀 `<PATCH>/chinese.ttf`;對話讀 `<PATCH>/usecode`(無副檔名)。
- 引擎本身的 `-p` portable 旗標僅 Windows 編譯有;macOS 的可攜模式由啟動器實現
  (偵測 `ExultData/` → 重導向 `HOME` + 相對路徑 cfg),不需引擎旗標。
- **本 fork 已把 macOS 預設資料路徑(`<DATA>` 與 `<GAMEHOME>`)改到家目錄**
  `~/Library/Application Support/Exult/`,使其與 `<SAVEHOME>` 一致、免 sudo(見「遊戲資料放哪」)。

---

## 📜 授權

- Exult 引擎與本 fork 引擎程式碼:**GPL-2.0**。
- 繁體中文翻譯與 CJK 修改:版權屬 [pmanyeh/Exult-for-zh](https://github.com/pmanyeh/Exult-for-zh) 作者。
- 遊戲資料 *Ultima VII*:版權屬原權利人,使用者需自備正版,本倉庫不散布。
- 本倉庫之 macOS 工具腳本:沿用上游 GPL-2.0。
