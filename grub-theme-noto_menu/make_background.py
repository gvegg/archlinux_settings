#!/usr/bin/env python3
# Генератор фона GRUB из исходной картинки: затемнение + сохранение в PNG.
#   backgrounds/waves-1600-original.jpg  →  theme/bg-waves.png
# GRUB_GFXMODE = 1600x900x32, поэтому картинка кладётся 1:1 без масштабирования.
# Перегенерация:  python3 make_background.py
import os
from PIL import Image, ImageEnhance, ImageStat

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE, "backgrounds", "waves-1600-original.jpg")
OUT = os.path.join(BASE, "theme", "bg-waves.png")

DARKEN = 0.25          # затемнить на 25% (яркость ×0.75)
SIZE = (1600, 900)     # GRUB_GFXMODE

def main():
    im = Image.open(SRC).convert("RGB")
    if im.size != SIZE:
        # страховка: центральный кроп под 16:9 и ресайз
        w, h = SIZE
        r = max(w / im.width, h / im.height)
        im = im.resize((round(im.width * r), round(im.height * r)), Image.LANCZOS)
        x = (im.width - w) // 2
        y = (im.height - h) // 2
        im = im.crop((x, y, x + w, y + h))
    im = ImageEnhance.Brightness(im).enhance(1.0 - DARKEN)
    im.save(OUT, optimize=True)
    avg = tuple(round(v) for v in ImageStat.Stat(im).mean)
    print(f"ок: {OUT}")
    print(f"  {im.width}x{im.height}, затемнение {DARKEN:.0%}, средний RGB {avg}")

if __name__ == "__main__":
    main()
