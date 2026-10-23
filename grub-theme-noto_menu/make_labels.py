#!/usr/bin/env python3
"""Генерирует подписи пунктов меню как PNG с прозрачностью (RGBA).

Зачем: pf2-шрифты GRUB — 1-bit bitmap БЕЗ сглаживания (grub-mkfont не умеет
antialiasing). Пункты у нас статичны, поэтому текст рендерится здесь обычным
TTF через FreeType с полноценным grayscale-AA и кладётся в тему как `+ image`
поверх белых плашек (тема умеет PNG с альфой и блендинг).

Геометрия ниже должна совпадать с theme.txt:
  boot_menu: top/height, item_height + item_spacing (видимая плашка и шаг).
Меняешь тексты/размер/геометрию — правь константы и запускай заново:
  python3 make_labels.py
Скрипт печатает готовые блоки `+ image { ... }` для theme.txt.

Запуск update-theme.sh делает это автоматически.
"""
import os

from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/noto/NotoSans-Regular.ttf"
PX = 24                    # em в px; ≈24pt GRUB: чернила 18px
COLOR = (43, 43, 43, 255)  # #2b2b2b
TEXTS = ["Arch Linux", "Windows", "UEFI BIOS"]

W = 1600                   # GRUB_GFXMODE
PLATE_TOP = 374            # boot_menu top
PLATE_H = 44               # видимая плашка = item_height + 2*radius
GAP = 10                   # зазор между плашками
CENTER_X = W // 2
PAD = 32                   # поля плашки слева/справа от текста

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "theme")
PREFIX = "caption_"


def render_caption(text, font):
    """Текст на прозрачном фоне, обрезанный точно по чернилам (включая AA)."""
    bbox = font.getbbox(text)
    pad = 4
    im = Image.new("RGBA", (bbox[2] - bbox[0] + 2 * pad,
                            bbox[3] - bbox[1] + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.text((pad - bbox[0], pad - bbox[1]), text, font=font, fill=COLOR)
    ink = im.getchannel("A").getbbox()
    return im.crop(ink)


def main():
    font = ImageFont.truetype(FONT, PX)
    blocks = []
    maxw = 0
    for i, text in enumerate(TEXTS):
        im = render_caption(text, font)
        path = os.path.join(OUT, f"{PREFIX}{i}.png")
        im.save(path)
        w, h = im.size
        maxw = max(maxw, w)
        left = CENTER_X - w // 2
        top = PLATE_TOP + i * (PLATE_H + GAP) + PLATE_H // 2 - h // 2
        blocks.append(
            f'+ image {{\n'
            f'  file = "{PREFIX}{i}.png"\n'
            f'  left = {left}\n'
            f'  top = {top}\n'
            f'  width = {w}\n'
            f'  height = {h}\n'
            f'}}'
        )
        print(f"  {PREFIX}{i}.png: {text!r} {w}x{h}px")
    plate_w = maxw + 2 * PAD
    if plate_w % 2:
        plate_w += 1
    print(f"\n  плашка: width = {plate_w}, left = {(W - plate_w) // 2}, "
          f"height = {PLATE_H} (+ item_height/spacing в theme.txt)")
    print()
    print("\n\n".join(blocks))


if __name__ == "__main__":
    main()
