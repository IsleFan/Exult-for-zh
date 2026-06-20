import os
import subprocess
import shutil

# 請根據您實際的路徑修改以下變數
expack_exe = r"D:\U7_project\Ultima 7 - Serpent Isle\mods\glimmerscape\usecode\tools\expack.exe"
# 我們準備產生的中文版 flx 檔案名稱
output_flx = r"d:\git\exult\tools\ucxt\output\ENDSHAP_ZH.FLX"
# 這是剛剛 unpack_endshap.py 產生出來並存放著所有 u7o 檔案的目錄
work_dir = r"d:\git\exult\tools\ucxt\output\endshap_tmp"
# 存放您修改好的中文 .u7o 檔案的目錄 (請將做好的 21.u7o ~ 28.u7o 放在這裡)
edited_dir = r"d:\git\exult\tools\ucxt\output\endshap_edited"

# 確保輸出目錄存在
if not os.path.exists(edited_dir):
    os.makedirs(edited_dir)
    print(f"請將您用 Exult Studio 修改好並改名回 .u7o 的檔案 (例如 21.u7o) 放進 {edited_dir} 目錄中！")
    print("然後再執行一次本腳本。")
    exit()

print("準備覆蓋修改過的檔案...")
has_files = False
for file in os.listdir(edited_dir):
    if file.endswith(".u7o"):
        shutil.copy2(os.path.join(edited_dir, file), os.path.join(work_dir, file))
        print(f"已替換: {file}")
        has_files = True

if not has_files:
    print(f"警告：在 {edited_dir} 中沒有找到任何 .u7o 檔案。這會打包原版的內容！")

print("\n產生打包用的 manifest.txt...")
# 產生打包清單 (需要包含 0 到最大的檔案編號，endshap 通常有數十個檔案)
manifest_path = os.path.join(work_dir, "manifest.txt")
files_to_pack = [f for f in os.listdir(work_dir) if f.endswith('.u7o')]
# 找到最大的編號
max_num = 0
for f in files_to_pack:
    try:
        num = int(f.split('.')[0])
        if num > max_num:
            max_num = num
    except:
        pass

with open(manifest_path, 'w', encoding='utf-8') as f:
    f.write(output_flx + "\n")
    for i in range(max_num + 1):
        # 如果該檔案存在才寫入，否則可能會有缺號 (U7 flx 允許有空洞)
        if os.path.exists(os.path.join(work_dir, f"{i}.u7o")):
            f.write(f"{i}.u7o\n")
        else:
            f.write("\n") # 空行代表這個 index 沒有內容

print("開始打包 ENDSHAP_ZH.FLX...")
if os.path.exists(output_flx):
    os.remove(output_flx)

try:
    subprocess.run([expack_exe, "-i", "manifest.txt"], cwd=work_dir, check=True)
    print(f"\n打包成功！新的檔案位於：{output_flx}")
    print("請將它複製到遊戲中（根據需求改名為 endshap.flx 或透過 patch 機制讀取）！")
except Exception as e:
    print(f"發生錯誤: {e}")
