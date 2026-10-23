#!/usr/bin/env python3
# Генератор 9-segment (9-patch) PNG для БЕЛОЙ темы GRUB noto_menu. Только stdlib.
#   plate_*.png    — белая плашка обычного пункта (item_pixmap_style)
#   plate_hi_*.png — белая плашка с синей рамкой для выбранного (selected_item_pixmap_style)
# Куски (как в GRUB manual): <pattern>_c/_n/_s/_e/_w/_nw/_ne/_sw/_se.png
# Рамка рисуется ВНУТРИ плашки, толщиной border_width px; углы сглажены
# суперсэмплингом S×S. Перегенерация:  python3 make_plates.py
import zlib, struct, os

BASE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "theme"))
S = 8                    # суперсэмплинг (гладкие дуги, 64 уровня альфы)
RADIUS = 16              # радиус скругления плашки, px
BORDER = 2               # толщина рамки, px

WHITE      = (255, 255, 255, 255)   # заливка плашки
GRAY_BORD  = (222, 222, 222, 255)   # обычная рамка (#dedede)
BLUE_BORD  = (0, 122, 255, 255)     # выбранная рамка (#007aff)

def write_png(path, w, h, rgba):
    raw = bytearray()
    rowlen = w * 4
    for y in range(h):
        raw.append(0)               # фильтр 0
        raw.extend(rgba[y * rowlen:(y + 1) * rowlen])
    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    open(path, "wb").write(png)

def build(prefix, r, fill, border, bw):
    """Все девять кусков плашки. n/s тянутся по ширине, e/w по высоте, c — оба."""
    sizes = {
        "c":  (r, r),  "n": (1, r),  "s": (1, r),
        "e":  (r, 1),  "w": (r, 1),
        "nw": (r, r), "ne": (r, r), "sw": (r, r), "se": (r, r),
    }
    for name, (pw, ph) in sizes.items():
        fw, fh = pw * S, ph * S
        big = bytearray(fw * fh * 4)
        for y in range(fh):
            fy = y / S
            for x in range(fw):
                fx = x / S
                kind = 0                       # 0 прозрачно, 1 заливка, 2 рамка
                if name == "n":                # верх: рамка по верхнему краю
                    kind = 2 if fy < bw else 1
                elif name == "s":              # низ: рамка по нижнему краю
                    kind = 2 if fy >= ph - bw else 1
                elif name == "w":              # левый край: рамка слева
                    kind = 2 if fx < bw else 1
                elif name == "e":              # правый край: рамка справа
                    kind = 2 if fx >= pw - bw else 1
                elif name == "c":              # середина
                    kind = 1
                else:                          # углы: четверть дуги радиуса r
                    cx = r if name[1] == "w" else 0.0
                    cy = r if name[0] == "n" else 0.0
                    dd = ((fx - cx) ** 2 + (fy - cy) ** 2) ** 0.5
                    if dd <= r - bw:           # внутри, дальше рамки
                        kind = 1
                    elif dd <= r:              # сама рамка (внутри дуги)
                        kind = 2
                    else:                      # снаружи дуги — прозрачно
                        kind = 0
                if kind:
                    col = border if kind == 2 else fill
                    i = (y * fw + x) * 4
                    big[i:i + 4] = bytes(col)
        # усреднение S×S → сглаживание.
        # ВАЖНО: RGB усредняем ТОЛЬКО по непрозрачным сэмплам (взвешивая по
        # альфе), иначе прозрачные (0,0,0,0) подмешивают чёрный и на дуге
        # появляется тёмная кайма — углы выглядят «рваными» даже с AA.
        small = bytearray(pw * ph * 4)
        ss = S * S
        for y in range(ph):
            for x in range(pw):
                ar = ag = ab = aa = 0
                for sy in range(S):
                    row = ((y * S + sy) * fw + x * S) * 4
                    for sx in range(S):
                        i = row + sx * 4
                        a = big[i + 3]
                        if a:
                            ar += big[i] * a
                            ag += big[i + 1] * a
                            ab += big[i + 2] * a
                            aa += a
                i = (y * pw + x) * 4
                if aa:
                    small[i]     = ar // aa
                    small[i + 1] = ag // aa
                    small[i + 2] = ab // aa
                    small[i + 3] = aa // ss
        write_png(os.path.join(BASE, f"{prefix}_{name}.png"), pw, ph, small)
    print("ок:", prefix)

build("plate",    RADIUS, WHITE, GRAY_BORD, BORDER)
build("plate_hi", RADIUS, WHITE, BLUE_BORD, BORDER)
print(f"ГОТОВО: 18 PNG (r={RADIUS}, рамка {BORDER}px) в {BASE}")
