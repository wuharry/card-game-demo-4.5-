# pad_tiles.py
# 放在跟 gress_*.png 同一個資料夾執行

from PIL import Image
import os

INPUT_DIR = '.'       # 當前資料夾
OUTPUT_DIR = './padded'  # 輸出到 padded 資料夾
TARGET_SIZE = (96, 96)   # 統一大小

os.makedirs(OUTPUT_DIR, exist_ok=True)

for filename in os.listdir(INPUT_DIR):
    if filename.startswith('gress_') and filename.endswith('.png'):
        img = Image.open(os.path.join(INPUT_DIR, filename)).convert('RGBA')
        
        # 建立透明背景
        new_img = Image.new('RGBA', TARGET_SIZE, (0, 0, 0, 0))
        
        # 置中貼上
        x = (TARGET_SIZE[0] - img.width) // 2
        y = (TARGET_SIZE[1] - img.height) // 2
        new_img.paste(img, (x, y))
        
        new_img.save(os.path.join(OUTPUT_DIR, filename))
        print(f'處理完成: {filename}')

print('全部完成！')