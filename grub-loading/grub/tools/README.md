# tools — пересчёт GRUB-темы (опционально)

Эти скрипты **не нужны** для установки на 1600×900: готовые PNG и pf2 уже
лежат в `../theme/`. Они нужны, только если:

- у новой системы другое разрешение;
- меняются тексты пунктов;
- меняется размер/цвет подписей;
- меняется радиус или толщина рамки плашек.

---

## 1. Зависимости

```bash
sudo pacman -S --needed noto-fonts python-pillow
```

- `make_labels.py` — Pillow + TTF Noto Sans;
- `make_plates.py` — только стандартная библиотека Python.

Для сборки pf2 (если меняется размер шрифта) нужен `grub-mkfont` из
пакета `grub`.

---

## 2. Геометрия: формулы

Пусть:

- `W`, `H` — разрешение (сейчас 1600×900);
- `PLATE_H` — видимая высота плашки (44);
- `GAP` — зазор (10);
- `RADIUS` — радиус (16);
- `N` — число пунктов (3);
- `PAD` — поля слева/справа от текста (32).

Тогда:

```text
высота меню       = N*PLATE_H + (N-1)*GAP
                  = 3*44 + 2*10 = 152

верх меню         = (H - высота меню) / 2
                  = (900 - 152) / 2 = 374

item_height       = PLATE_H - 2*RADIUS
                  = 44 - 32 = 12

item_spacing      = PLATE_H + GAP - item_height
                  = 44 + 10 - 12 = 42

ширина плашки     = max(ширина подписи) + 2*PAD
                  = 119 + 64 = 183 → 184 (чётное)

left меню         = (W - ширина плашки) / 2
                  = (1600 - 184) / 2 = 708
```

Важно: `item_height` — **не** высота плашки. 9-patch добавляет пады,
равные радиусу. Если поставить `item_height=44`, плашка станет 76 px.

---

## 3. `make_labels.py`

Скрипт:

1. рендерит каждый текст Noto Sans в RGBA;
2. обрезает по чернилам (включая AA);
3. сохраняет `../theme/caption_N.png`;
4. печатает готовые блоки `+ image { ... }` с координатами.

Что менять:

```python
PX = 24                    # размер em в px
COLOR = (43, 43, 43, 255)  # #2b2b2b
TEXTS = ["Arch Linux", "Windows", "UEFI BIOS"]
W = 1600                   # ширина
PLATE_TOP = 374            # верх меню
PLATE_H = 44               # видимая плашка
GAP = 10                   # зазор
PAD = 32                   # поля
```

Запуск:

```bash
cd grub-loading/grub/tools
python3 make_labels.py
```

Вывод:

```text
  caption_0.png: 'Arch Linux' 119x18px
  ...
  плашка: width = 184, left = 708, height = 44 ...
  + image { ... }
```

Перенеси напечатанные блоки `+ image` в `../theme/theme.txt` вместо
старых. Не забудь обновить `boot_menu`:

```text
left = 708
top = 374
width = 184
height = 152
```

и `item_height`/`item_spacing` по формулам.

---

## 4. `make_plates.py`

Генерирует 18 PNG: 9 обычных и 9 выбранных. Менять:

```python
RADIUS = 16
BORDER = 2
WHITE = (255, 255, 255, 255)
GRAY_BORD = (222, 222, 222, 255)
BLUE_BORD = (0, 122, 255, 255)
```

Запуск:

```bash
cd grub-loading/grub/tools
python3 make_plates.py
```

Скрипт пишет в `../theme/`. Если меняешь радиус, обязательно пересчитай
`item_height = PLATE_H - 2*RADIUS` и `item_spacing`.

---

## 5. Шрифт pf2 (только если меняется размер)

Готовый `NotoSans-Regular-24.pf2` уже в теме. Если нужен другой размер:

```bash
grub-mkfont -n "Noto Sans" -s 24 \
  -o ../theme/NotoSans-Regular-24.pf2 \
  /usr/share/fonts/noto/NotoSans-Regular.ttf
```

Правила:

- имя файла — без пробелов;
- внутреннее имя (`-n "Noto Sans"` + `-s 24`) должно совпадать с
  `terminal-font` и `item_font` в `theme.txt`;
- не используй `-n "Noto Sans Regular"`: получится двойной стиль.

---

## 6. После пересчёта

1. Проверь `theme.txt`: верхнеуровневые значения в кавычках.
2. Скопируй тему в `/boot` и пересобери конфиг:

```bash
cd ../..                 # вернуться в корень grub-loading
sudo bash grub/install-theme.sh
# или вручную:
sudo rm -rf /boot/grub/themes/noto_menu
sudo cp -r grub/theme /boot/grub/themes/noto_menu
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

3. Перезагрузись и проверь.

Если менял число пунктов, не забудь:

- `TEXTS` в `make_labels.py`;
- `N` в формулах;
- `height` меню;
- число `menuentry` в `40_custom.example`;
- число блоков `+ image` (должно совпадать с числом пунктов).

---

## 7. Чего эти скрипты не делают

- не ставят тему в `/boot`;
- не меняют `/etc/default/grub`;
- не трогают `40_custom`;
- не запускают `grub-mkconfig`;
- не создают фон (фон отключён; `make_background.py` в комплект не входит).

Это осознанно: инструменты только пересчитывают ассеты, установка —
отдельный шаг.
