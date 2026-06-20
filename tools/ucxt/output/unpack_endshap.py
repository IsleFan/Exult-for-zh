import os
import subprocess
import shutil

# 請根據您實際的路徑修改以下變數
expack_exe = r"D:\U7_project\Ultima 7 - Serpent Isle\mods\glimmerscape\usecode\tools\expack.exe"
# endshap.flx 所在的位置 (原版遊戲的 STATIC 目錄)
orig_flx = r"D:\U7_project\Ultima 7\STATIC\endshap.flx"
# 解包後存放檔案的工作目錄
work_dir = r"d:\git\exult\tools\ucxt\output\endshap_tmp"

if os.path.exists(work_dir):
    shutil.rmtree(work_dir)
os.makedirs(work_dir)

print(f"正在從 {orig_flx} 解包 endshap.flx...")
try:
    subprocess.run([expack_exe, "-x", orig_flx], cwd=work_dir, check=True)
    print(f"\n解包完成！")
    print(f"請前往 {work_dir} 目錄，")
    print(f"您會看到 21.u7o ~ 28.u7o。")
    print(f"請把它們複製出來，改名為 .shp，丟進遊戲 STATIC 資料夾讓 Exult Studio 讀取修改。")
except Exception as e:
    print(f"發生錯誤: {e}")
    print("請確認 expack_exe 和 orig_flx 的路徑是否正確！")
