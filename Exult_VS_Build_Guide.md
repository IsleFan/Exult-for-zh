# Exult 專案建置完整指南 (Visual Studio 環境)

這是一份為 Windows (使用 Visual Studio) 環境整理的 Exult 專案建置完整指南。這份指南可以讓團隊中的其他人順利從零開始建立開發環境。

## 1. 系統需求與開發工具準備

要順利編譯 Exult，請務必確認安裝了以下工具：

* **Visual Studio 2019 或 2022 (Community 版本即可)**：
  * 安裝時請務必勾選 **「使用 C++ 的桌面開發」 (Desktop development with C++)**。
  * 請確認有安裝 **MSVC v142 (VS 2019) 或 v143 (VS 2022) 的 C++ 建置工具**。
  * > [!WARNING]
    > **不支援 Visual Studio 2017**，因為其編譯器無法完全支援 Exult 所需的 C++17 語法。
* **Git**：用來取得原始碼與套件管理工具。

## 2. 取得 Exult 原始碼

使用 Git 將專案解包（Clone）到你想要的本機目錄下：

```bash
git clone https://github.com/exult/exult.git
cd exult
```

## 3. 安裝與設定 vcpkg (第三方函式庫管理器)

Exult 使用微軟官方的 **vcpkg** 來自動管理所有的 C++ 第三方函式庫。設定好之後，所有的套件安裝都會自動化。

如果你還沒有安裝過 vcpkg，請在終端機 (或 PowerShell) 執行以下指令來全域安裝：

```cmd
# 1. 將 vcpkg 原始碼 clone 到你的電腦上 (可以放在任意路徑，例如 C:\vcpkg)
git clone https://github.com/microsoft/vcpkg.git C:\vcpkg

# 2. 進入該目錄並執行安裝腳本
cd C:\vcpkg
.\bootstrap-vcpkg.bat

# 3. 將 vcpkg 整合進 Visual Studio (這一步很重要！)
.\vcpkg integrate install
```

> [!NOTE]
> 執行完 `integrate install` 後，Visual Studio 就具備自動辨識與下載專案套件的能力了。

## 4. 專案依賴的第三方函式庫 (會自動安裝)

有了 vcpkg 之後，**你不需要手動下指令安裝單一函式庫**。Exult 已經在專案裡的 `msvcstuff\vs2019\vcpkg.json` 定義了清單，包含：

* `sdl3` (核心的影音/視窗框架)
* `libpng`、`zlib`、`freetype` (圖片處理與字型)
* `libogg`、`libvorbis` (音訊格式)
* `libmt32emu`、`fluidsynth` (MIDI 聲音模擬)
* `dirent` (目錄操作)

當你第一次在 VS 啟動建置時，vcpkg 會自動在背景抓取這些函式庫的原始碼並進行編譯。

## 5. 使用 Visual Studio 編譯專案

1. 開啟 Visual Studio。
2. 點擊「開啟專案或方案」，選擇 Exult 原始碼目錄下的 `msvcstuff\vs2019\Exult.sln` 方案檔。
3. 在 VS 上方的工具列，選擇你要的建置組態：
   * 一般開發除錯選 **`Debug`**，要封裝釋出選 **`Release`**。
   * 平台可選擇 **`x64`** 或 **`x86`**。
4. 在右側的方案總管中，右鍵點擊整個方案，選擇 **「建置方案」(Build Solution)** (或按下 `Ctrl + Shift + B`)。

> [!WARNING]
> **第一次建置會花費非常長的時間**。因為 vcpkg 會在背後從零開始編譯 SDL3、Freetype 等所有相依套件。第二次以後建置就會非常快了。

## 6. 編譯結果與如何執行

建置成功後：

1. 產生的執行檔（如 `Exult.exe` 以及編輯器 `exult_studio.exe`）與所有用到的 DLL 檔案，都會被**自動輸出到 Exult 的專案根目錄下**。
2. 建置過程也會一併執行內部工具 (例如 expack)，自動幫你產生好遊戲需要的 `.flx` 資料檔。
3. **要測試遊戲的話**：
   你需要有原版 Ultima VII (黑月之門 或 巨蛇島) 的遊戲檔案。將原版遊戲資料夾內的 `STATIC` 目錄，複製到 Exult 根目錄下對應的 `blackgate` 或 `serpentisle` 資料夾中。
4. 雙擊根目錄的 `Exult.exe`，就可以成功啟動並享受遊戲了！

## 7. 常見問題與排除 (Troubleshooting)

### Q: 建置時出現「找不到 v145 的建置工具 (平台工具集 = 'v145')」錯誤？
**A:** 這是因為專案檔可能被設定為使用較新的或測試版的工具集（v145），而一般的 Visual Studio 2022 最高通常只包含 `v143` 或 `v144`。在 Visual Studio Installer 中是找不到 v145 的。

**解決方法一 (重定方案目標 - 如果有的話)：**
1. 在 Visual Studio 右側的 **「方案總管」(Solution Explorer)** 中，找到最上方的 **「方案 'Exult'」**。
2. 對它 **按一下滑鼠右鍵**，選擇 **「重定方案目標」(Retarget solution)**。
3. 在跳出的視窗中，確認「平台工具集」(Platform Toolset) 設定為升級到您目前的版本 (例如 v143)，然後點擊「確定」。

**解決方法二 (手動更改專案屬性 - 如果找不到方法一)：**
1. 在「方案總管」中，**按住 `Ctrl` 鍵** 並用滑鼠左鍵點選所有發生錯誤的專案（例如 `Exult`, `exult_studio`, `exconfig`, `expack`, `textpack` 等）。
2. 對這些選取的專案 **按一下滑鼠右鍵**，選擇最下方的 **「屬性」(Properties)**。
3. 在左側選單選擇 **「組態屬性」(Configuration Properties) -> 「一般」(General)**。
4. （非常重要）將最上方的「組態」(Configuration) 設為 **「所有組態」(All Configurations)**，將「平台」(Platform) 設為 **「所有平台」(All Platforms)**。
5. 在右側找到 **「平台工具集」(Platform Toolset)**，點擊旁邊的下拉選單。
6. 選擇您目前安裝的版本，通常是 **`Visual Studio 2022 (v143)`**。
7. 點擊「套用」並「確定」。

完成後重新建置方案即可解決。
### Q: 建置時出現一堆「沒有 xxx 的版本資料庫項目」錯誤？
**(例如：沒有 sdl3、icu、gtk3 的版本資料庫項目)**

**A:** 這個錯誤是因為您電腦上的 `vcpkg` 版本庫太舊了，找不到專案要求安裝的最新套件版本。

**解決方法 (更新 vcpkg)：**
1. 開啟終端機 (PowerShell 或命令提示字元)。
2. 進入您原本安裝 vcpkg 的目錄 (例如 `C:\vcpkg` 或 `D:\git\vcpkg`)。
3. 執行更新指令：
   ```cmd
   git pull
   .\bootstrap-vcpkg.bat
   ```
4. 更新完成後，回到 Visual Studio 重新點擊「建置方案」，vcpkg 就會開始下載並編譯最新版的套件了。

### Q: 建置時出現「建置 libiconv:x64-windows 失敗，原因: BUILD_FAILED」？
**A:** 這是 Windows 上使用 vcpkg 非常知名的問題。`libiconv` 等依賴 MSYS2 的套件在編譯時，會去解析編譯器 (`cl.exe`) 的輸出訊息。如果您的編譯器吐出中文訊息，MSYS2 讀不懂就會直接報錯失敗。更麻煩的是，只要您安裝了中文套件，編譯器就會強制使用中文輸出。

**解決方法 (強制編譯器說英文)：**
1. 開啟 **Visual Studio Installer**。
2. 找到您的 Visual Studio 2022，點擊 **「修改」(Modify)**。
3. 在上方標籤頁切換到 **「語言套件」(Language packs)**。
4. **【關鍵步驟】取消勾選「繁體中文」**，並且**只勾選「英文」(English)**。
5. 點擊「修改」並等待解除安裝中文套件完成。
6. 重新開啟 Visual Studio，再次建置方案即可順利通過。
### Q: 已經切換英文介面了，建置時卻還是出現奇怪的路徑錯誤或 libtool 崩潰？
**(例如出現 `Is a directory`, `missing source filename`, 或 `BUILD_FAILED`)**

**A:** 這是開發者自訂環境時最容易踩到的「終極地雷」。如果您曾經為了方便，在 Windows 登錄檔中設定了 `AutoRun` 腳本（例如每次開 cmd 自動載入 `doskey` 快捷鍵或 Anaconda 環境），每次呼叫編譯器時，這些腳本的畫面輸出字串就會被硬塞進編譯指令裡，導致指令全毀。vcpkg 官方亦明文表示不支援有修改 AutoRun 的環境。

**解決方法 (清除 AutoRun 登錄檔)：**
1. 點擊 Windows 開始按鈕，搜尋 `cmd`。
2. 對著「命令提示字元」按一下滑鼠右鍵，選擇 **「以系統管理員身分執行」**。
3. 貼上以下指令並按 Enter 執行：
   ```cmd
   reg delete "HKLM\Software\Microsoft\Command Processor" /v AutoRun /f
   ```
4. 如果有設定在目前使用者層級，也請執行：
   ```cmd
   reg delete "HKCU\Software\Microsoft\Command Processor" /v AutoRun /f
   ```
5. 出現「作業順利完成」後，回到 Visual Studio 重新建置方案即可順利通過。
