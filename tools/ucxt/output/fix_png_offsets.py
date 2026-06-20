import os
import subprocess
import shutil
import struct

ipack_exe = r"C:\Program Files\Exult\Tools\ipack.exe"
orig_flx = r"G:\GOG Galaxy\Games\Ultima 7\STATIC\endshape.flx"
palettes_flx = r"G:\GOG Galaxy\Games\Ultima 7\STATIC\palettes.flx"
work_dir = r"d:\git\exult\tools\ucxt\output\endshape_pngs"
temp_orig_dir = r"d:\git\exult\tools\ucxt\output\endshape_pngs_original"

def read_png_chunks(file_path):
    chunks = []
    with open(file_path, 'rb') as f:
        sig = f.read(8)
        if sig != b'\x89PNG\r\n\x1a\n':
            raise ValueError(f"Not a valid PNG file: {file_path}")
        while True:
            len_bytes = f.read(4)
            if not len_bytes:
                break
            length = struct.unpack('>I', len_bytes)[0]
            chunk_type = f.read(4)
            data = f.read(length)
            crc = f.read(4)
            chunks.append({
                'type': chunk_type,
                'data': data,
                'crc': crc
            })
            if chunk_type == b'IEND':
                break
    return chunks

def write_png_chunks(file_path, chunks):
    with open(file_path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        for chunk in chunks:
            length = len(chunk['data'])
            f.write(struct.pack('>I', length))
            f.write(chunk['type'])
            f.write(chunk['data'])
            f.write(chunk['crc'])

def main():
    # 1. 建立臨時目錄並提取原始的 FLX 圖片
    if os.path.exists(temp_orig_dir):
        shutil.rmtree(temp_orig_dir)
    os.makedirs(temp_orig_dir)

    local_flx = os.path.join(temp_orig_dir, "endshap_local.flx")
    local_pal = os.path.join(temp_orig_dir, "palettes_local.flx")
    shutil.copy2(orig_flx, local_flx)
    shutil.copy2(palettes_flx, local_pal)

    script_path = os.path.join(temp_orig_dir, "extract.txt")
    shapes = [21, 22, 23, 24, 25, 26, 28]
    with open(script_path, "w", encoding="utf-8") as f:
        f.write("archive endshap_local.flx\n")
        f.write("palette palettes_local.flx\n")
        for s in shapes:
            f.write(f"{s}/1:shape{s}\n")

    print("正在提取原始圖片以獲取座標 (oFFs) 資訊...")
    try:
        subprocess.run([ipack_exe, "-x", "extract.txt"], cwd=temp_orig_dir, check=True)
    except Exception as e:
        print(f"提取原始圖片失敗: {e}")
        return

    # 2. 遍歷修改後的 PNG，把原始 PNG 的 oFFs chunk 複製過去
    print("正在修復修改後圖片的座標資訊...")
    success_count = 0
    for s in shapes:
        # 因為每個 shape 只有 1 個 frame (00)
        filename = f"shape{s}00.png"
        orig_path = os.path.join(temp_orig_dir, filename)
        edited_path = os.path.join(work_dir, filename)

        if not os.path.exists(edited_path):
            print(f"找不到修改後的檔案: {edited_path}，跳過")
            continue

        try:
            # 讀取原始 PNG 的 chunks
            orig_chunks = read_png_chunks(orig_path)
            offs_chunk = None
            for chunk in orig_chunks:
                if chunk['type'] == b'oFFs':
                    offs_chunk = chunk
                    break
            
            if not offs_chunk:
                # 如果原始檔案沒有 oFFs，可能是 0,0 或者是 flat 屬性
                print(f"原始檔案 {filename} 中未找到 oFFs 資訊。")
                continue

            # 讀取修改後的 PNG chunks
            edited_chunks = read_png_chunks(edited_path)
            # 移除修改後 PNG 可能存在的舊 oFFs chunk
            edited_chunks = [c for c in edited_chunks if c['type'] != b'oFFs']

            # 插入原始的 oFFs chunk 到 IHDR 之後
            if edited_chunks[0]['type'] == b'IHDR':
                edited_chunks.insert(1, offs_chunk)
                write_png_chunks(edited_path, edited_chunks)
                # 解析並印出偏移量供參考
                # oFFs data: X (4 bytes), Y (4 bytes), Unit (1 byte)
                x_off, y_off, unit = struct.unpack('>iiB', offs_chunk['data'])
                print(f"已成功修復 {filename} 的座標 -> X偏移: {x_off}, Y偏移: {y_off}")
                success_count += 1
            else:
                print(f"修改後的 {filename} 結構異常（開頭不是 IHDR）。")
        except Exception as e:
            print(f"修復 {filename} 時發生錯誤: {e}")

    print(f"\n共修復了 {success_count} 個檔案的座標資訊。")
    
    # 清理臨時目錄
    try:
        shutil.rmtree(temp_orig_dir)
    except:
        pass
    print("清理臨時目錄完成。現在您可以執行 python pack_endshap_png.py 來重新打包了！")

if __name__ == '__main__':
    main()
