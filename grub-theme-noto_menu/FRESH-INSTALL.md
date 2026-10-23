# GRUB «noto_menu» — установка на свежую систему

> Белая тема «волны», три белые плашки по центру, подписи с настоящим сглаживанием,
> выбранный пункт — синяя рамка. Меню: `Arch Linux` / `Windows` / `UEFI BIOS`,
> без шапки, таймаут бесконечный.
>
> Это единственный поддерживаемый вид. Для другой машины достаточно клонировать
> репозиторий: UUID корня и `/boot` определяются автоматически.

---

## Быстрый путь (для нетерпеливых)

```bash
git clone <URL-репозитория> ~/grub-theme-noto_menu
cd ~/grub-theme-noto_menu

sudo bash apply.sh          # на вопрос ответить: да
sudo bash update-theme.sh   # синк темы, чистка лишнего в /boot, grub-mkconfig
sudo reboot
```

`apply.sh` сам вызывает `configure.sh`, который подставит UUID текущей машины
и номер Windows Boot Manager. Если Windows нет — см. §10.1.

Дальше — подробности с проверками и вариантами (2 пункта, другое разрешение, Windows).

---

## 0. Что должно получиться

| Элемент | Значение |
|---|---|
| Фон | `bg-waves.png` — белые волны 1600×900, затемнение 25 % |
| Плашки | белые, скругление 16 px, рамка #dedede 2 px, размер 184×44, зазор 10 px |
| Выбранный пункт | та же плашка с синей рамкой #007aff |
| Подписи | PNG с прозрачностью (полный AA), цвет #2b2b2b, 24 px |
| Положение | по центру экрана: `left = 708`, `top = 374` (для 1600×900) |
| Терминал | чёрный на весь экран, без белой рамки после выбора пункта |
| Пункты | ровно 3, вручную, без нумерации и без «GNU GRUB» сверху |
| После выбора | чёрный экран без текста до приглашения логина |

---

## 1. Требования

| Компонент | Зачем | Обязателен |
|---|---|---|
| Arch Linux с **GRUB (UEFI)** | тема ставится в `/boot/grub` | да |
| `grub` (2.12+; проверено на 2.16) | `grub-mkconfig`, `grub-mkfont` | да |
| `efibootmgr` | найти номер загрузчика Windows для `bootnext` | да, если нужен пункт Windows |
| `noto-fonts` | TTF для пересборки `pf2` и подписей | только для перегенерации |
| `python-pillow` | `make_labels.py` (подписи) и `make_background.py` | только для перегенерации |

В комплекте уже лежат готовые `NotoSans-Regular-24.pf2`, `caption_*.png`, плашки и фон,
поэтому **для простой установки Pillow и noto-fonts не нужны** — хватит `grub`.
Скрипты сами определяют свой каталог, так что комплект можно положить куда угодно.

Проверка, что GRUB вообще UEFI и `/boot` смонтирован:

```bash
[ -d /sys/firmware/efi ] && echo "UEFI ok"
findmnt /boot
```

---

## 2. Что где лежит

```
grub-theme-noto_menu/
├── README.md             ← краткое описание и быстрый старт
├── FRESH-INSTALL.md      ← этот подробный гайд
├── LICENSE               ← MIT для кода и конфигов темы
├── NOTICE.md             ← сторонние ассеты: фон CC BY-SA 4.0, шрифт OFL 1.1
├── apply.sh              ← установка темы + 3 пункта + параметры /etc/default/grub
├── configure.sh          ← генерация 40_custom под текущую машину (UUID, ФС, Windows)
├── update-theme.sh       ← синк theme/ → /boot, пересборка pf2/подписей, grub-mkconfig
├── revert.sh             ← откат к состоянию до apply.sh (из backup-*)
├── 40_custom.example     ← шаблон ручных пунктов меню (рабочий 40_custom создаёт configure.sh)
├── theme/                ← готовая тема: theme.txt, фон, плашки, подписи, pf2
├── make_labels.py        ← генератор подписей-картинок (Pillow)
├── make_plates.py        ← генератор 9-patch плашек (stdlib)
├── make_background.py    ← генератор фона из backgrounds/*.jpg (Pillow)
├── backgrounds/          ← исходник фона + лицензия CC BY-SA 4.0
├── docs/preview.png      ← макет вида (рендер из ассетов темы)
├── LICENSES/             ← полные тексты OFL 1.1 и CC BY-SA 4.0
└── preview-white.html    ← живой макет вида в браузере (без ребута)
```

---

## 3. Собери данные о системе (для проверки)

`configure.sh` делает это автоматически, но полезно понимать, что он ищет:

```bash
lsblk -f                       # разделы, ФС, UUID
sudo blkid                     # UUID крупным шрифтом
sudo efibootmgr                # список загрузчиков UEFI (Boot0000, Boot0001, ...)
```

Нужны три вещи:

1. **UUID раздела `/boot`** — из него GRUB читает ядро. Если `/boot` не отдельный
   раздел, берётся UUID корня и пути `/boot/vmlinuz-linux`.
2. **UUID корня `/`** — подставляется в `root=UUID=...`.
3. **Номер загрузчика Windows** в `efibootmgr` (например `Boot0001`) — только если
   Windows есть.

`configure.sh` определяет всё это через `findmnt` и `efibootmgr`, выбирает нужный
`insmod` (fat/ext2/btrfs/xfs/f2fs) и пишет рабочий `40_custom`. Ручная правка нужна
только для нестандартных схем (LUKS/LVM/btrfs subvolumes) — см. §5.

---

## 4. Скопируй комплект

```bash
git clone <URL-репозитория> ~/grub-theme-noto_menu
cd ~/grub-theme-noto_menu
```

Если репозитория ещё нет, просто распакуй архив и зайди в его каталог. Дальше все
команды — из этого каталога; скрипты сами определяют свой путь, так что имя каталога
может быть любым.

---

## 5. Настройка `40_custom` (UUID и Windows)

Обычно ничего делать не нужно: `apply.sh` вызывает `configure.sh`, и тот создаёт
`40_custom` под текущую машину. Проверить/пересоздать можно вручную:

```bash
bash configure.sh
grep -nE 'search --no-floppy|linux[[:space:]]|bootnext' 40_custom
```

В результате в `40_custom` будут реальные UUID, например:

```
search --no-floppy --fs-uuid --set=root <UUID_РАЗДЕЛА_BOOT>
linux  /vmlinuz-linux root=UUID=<UUID_КОРНЯ> rw quiet loglevel=0 systemd.show_status=no udev.log_level=0
```

`40_custom` содержит UUID текущей машины и поэтому **не коммитится** (он в
`.gitignore`). В репозитории лежит только шаблон `40_custom.example`.

> Если корень на LUKS/LVM/btrfs с субволюмами — автоматики мало: нужны свои `insmod`
> (`cryptodisk`, `lvm`) и параметры ядра (`cryptdevice=...`, `rootflags=subvol=...`).
> Возьми готовую строку `linux` из рабочего `grub.cfg` и перенеси её в `40_custom`.

---

## 6. Пункт Windows (если Windows нет — см. §10)

В `40_custom` пункт Windows делает `bootnext 0001` — просит прошивку загрузить
**Boot0001** при следующей перезагрузке. `configure.sh` сам находит номер:

```bash
sudo efibootmgr | grep -i windows
# Boot0001* Windows Boot Manager
```

Если номер другой, `configure.sh` подставит его автоматически. Если Windows не
найден, скрипт оставит `0001` и предупредит — тогда пункт Windows надо удалить
и переделать тему на два пункта (§10.1). Содержимое диска Windows не трогается:
меняется только переменная прошивки на один запуск.

---

## 7. Применение

```bash
sudo bash apply.sh
```

Скрипт покажет, что будет делать, и спросит `Продолжить? [да/нет]:` — нужно ввести `да`.
Перед этим он вызовет `configure.sh` (если `40_custom` ещё нет) и сверит UUID
в `40_custom` с текущими `/` и `/boot`; при несовпадении предупредит.

Он:

* делает бэкап в `backup-<дата>/` (там `grub.cfg`, `default.grub`, `40_custom`);
* копирует тему в `/boot/grub/themes/noto_menu`;
* отключает генераторы `10_linux`, `30_uefi-firmware`, `31_efi_bootnext` (chmod −x, файлы остаются);
* ставит `40_custom` с тремя пунктами;
* прописывает в `/etc/default/grub`: `GRUB_THEME`, `GRUB_GFXMODE=1600x900x32`,
  `GRUB_GFXPAYLOAD_LINUX=keep`, `GRUB_TIMEOUT=-1`, `GRUB_TIMEOUT_STYLE=menu`,
  тихий `GRUB_CMDLINE_LINUX_DEFAULT`;
* пересобирает `grub.cfg`.

Затем синхронизируй тему (заодно проверяет целостность и чистит лишнее в `/boot`):

```bash
sudo bash update-theme.sh
```

> `update-theme.sh` пересобирает `pf2` и подписи, если есть `noto-fonts` и `python-pillow`.
> Если их нет — берёт готовые файлы из `theme/` и предупреждает об этом.

Тишина при загрузке уже включена: параметры ядра — в `40_custom`, а
`terminal-border: "0"` — в `theme.txt`. Отдельный скрипт для тишины не нужен.

---

## 8. Проверка до перезагрузки

```bash
grep -E '^menuentry' /boot/grub/grub.cfg          # ровно 3: Arch Linux / Windows / UEFI BIOS
grep -c 'set theme=' /boot/grub/grub.cfg          # 1
grep '^GRUB_THEME=' /etc/default/grub             # путь к theme.txt
grep -n 'loadfont' /boot/grub/grub.cfg            # NotoSans-Regular-24.pf2, путь не обрезан
grep 'terminal-border' /boot/grub/themes/noto_menu/theme.txt   # "0"
ls /boot/grub/themes/noto_menu                    # theme.txt + 18 плашек + 3 caption + pf2 + фон
```

`update-theme.sh` в конце сам печатает такой же чек-лист и предупреждает, если число
подписей не совпало с числом пунктов меню.

---

## 9. Перезагрузка: что должно быть

1. Меню ждёт выбора **бесконечно** (`GRUB_TIMEOUT=-1`), по умолчанию подсвечен Arch.
2. Фон — белые волны, сверху ничего нет.
3. Три белые плашки по центру, подписи тёмные, у выбранной — синяя рамка.
4. После Enter — чёрный экран без единой строки, затем приглашение логина.

Если вид другой — см. §11.

---

## 10. Адаптация под другую машину

### 10.1. Нет Windows — два пункта

1. В `40_custom` удали блок `menuentry 'Windows' { ... }` целиком.
2. В `make_labels.py`: `TEXTS = ["Arch Linux", "UEFI BIOS"]` и `PLATE_TOP = 401`
   (две плашки: высота `2*54-10 = 98`, `(900-98)//2 = 401`).
3. В `theme/theme.txt`:
   * удали третий блок `+ image { file = "caption_2.png" ... }`;
   * у `boot_menu` поставь `top = 401`, `height = 98`.
4. Перегенерируй подписи и тему:

```bash
python3 make_labels.py        # напечатает 2 блока + рекомендацию ширины
# вставь напечатанные блоки в theme.txt вместо трёх старых
sudo bash update-theme.sh
```

### 10.2. Другие подписи

`make_labels.py` печатает для каждой подписи готовый блок `+ image { ... }` с точными
`left/top/width/height` и рекомендованную ширину плашки. Порядок:

1. `TEXTS = [...]` — в том же порядке, что `menuentry` в `40_custom`.
2. `python3 make_labels.py` → заменить блоки `+ image` в `theme.txt`.
3. В `boot_menu`: `width` = напечатанная ширина, `left = (1600 - width) // 2`.
4. `sudo bash update-theme.sh`.

Ширина плашки = самая длинная подпись + 2×32 px полей (скрипт округляет до чётного).

### 10.3. Другое разрешение экрана

Геометрия темы — в **пикселях**, без процентов, поэтому координаты надо пересчитать.
Формулы (N — число пунктов):

```
высота блока   = N*54 - 10
top            = (H - высота блока) // 2
left           = (W - ширина плашки) // 2
```

Порядок:

1. Узнай поддерживаемый режим: в меню GRUB нажми `c`, в консоли — `videoinfo`.
2. Пропиши его в `/etc/default/grub` (`GRUB_GFXMODE=...`); если установка ещё впереди —
   сразу в `apply.sh` (строка `set_kv GRUB_GFXMODE ...`).
3. Пересчитай `left/top/width/height` в `theme.txt` (блок `+ boot_menu`).
4. В `make_labels.py` поставь `W = <ширина экрана>`, `PLATE_TOP = <top из п.3>`.
5. При желании перегенерируй фон под своё разрешение:
   в `make_background.py` поменяй `SIZE = (W, H)` и запусти `python3 make_background.py`
   (нужен Pillow; исходник `backgrounds/waves-1600-original.jpg`).
6. `python3 make_labels.py` → вставь блоки в `theme.txt` → `sudo bash update-theme.sh`.

Пример для 1366×768 и трёх пунктов: `left = (1366-184)//2 = 591`,
`top = (768-152)//2 = 308`, `W = 1366`, `PLATE_TOP = 308`.

### 10.4. Другой размер шрифта

Размер задаёт `item_font` в `theme.txt` (и `terminal-font` — держи их одинаковыми).
Высота плашки 44 px рассчитана на 24 px: при другом размере пересчитай
`PLATE_H`, `item_height = PLATE_H - 2*16`, `item_spacing = PLATE_H + 10 - item_height`,
а также `PX` в `make_labels.py`. `update-theme.sh` соберёт `pf2` ровно под `item_font`.

---

## 11. Если что-то не так

| Симптом | Причина и лечение |
|---|---|
| Меню текстовое, без картинки | Нет `set theme=` в `grub.cfg` (не выполнен `apply.sh` / нет `GRUB_THEME`) или неверный путь. Проверь `grep '^GRUB_THEME' /etc/default/grub` и наличие `theme.txt`. |
| Тема не грузится, ошибка `property value invalid` | В `theme.txt` свойство верхнего уровня без кавычек. Все верхнеуровневые значения — **только в кавычках** (`terminal-border: "0"`). `update-theme.sh` проверяет это до копирования. |
| Шрифт «не применился» / другой | Имя `pf2` должно совпадать с `item_font` посимвольно. `grub-mkfont -n "Noto Sans" -s 24` даёт внутреннее имя `Noto Sans Regular 24`. Размер парсится из `item_font`, руками `pf2` не подменять. |
| Плашки наезжают друг на друга / слишком высокие | `item_height` — это **не** высота плашки: плашка = `item_height + 2*радиус` = 12+32 = 44. Шаг = `item_height + item_spacing` = 54. |
| Подписей не видно | Блоки `+ image` должны идти в `theme.txt` **до** `+ boot_menu`: компоненты рисуются в обратном порядке файла. |
| Подписи смещены | Константы `make_labels.py` (`W`, `PLATE_TOP`, `PLATE_H`, `GAP`) должны совпадать с геометрией `boot_menu` в `theme.txt`. |
| После выбора пункта белая рамка | `terminal-border` не равен нулю. Должно быть `terminal-border: "0"`; затем `sudo bash update-theme.sh`. |
| Меню исчезает сразу | `GRUB_TIMEOUT` не `-1` или `GRUB_TIMEOUT_STYLE` не `menu`. |
| Пункт Windows возвращает в Arch | Неверный номер в `bootnext` — сверь `efibootmgr`. Если Windows удалён, пункт надо убрать. |
| `failed to preserve ownership` при копировании в `/boot` | `/boot` — FAT32, владельцев не хранит. Копируй обычным `cp` (в скриптах так и сделано), не `cp -a/-p`. |
| Пропали пункты `linux-lts` и т.п. | Пункты статичные: `40_custom` знает только `/vmlinuz-linux`. Для другого ядра добавь свой `menuentry`. |
| Появились лишние пункты (снапшоты и пр.) | Их добавляет сторонний скрипт в `/etc/grub.d/` (например `grub-btrfs`). Отключи его `chmod -x` или настрой. |

Диагностика «на месте»: в меню GRUB нажми `e` (правка пункта) или `c` (консоль).
Ошибки темы видны на экране; `ls ($root)/grub/themes/noto_menu` покажет, что реально
лежит в разделе.

---

## 12. Откат

```bash
cd ~/grub-theme-noto_menu
sudo bash revert.sh
```

Скрипт берёт самый свежий **полный** `backup-*` (в нём есть `grub.cfg`; его создал
`apply.sh`), возвращает `grub.cfg`, `/etc/default/grub`, `40_custom`, включает обратно
генераторы и пересобирает конфиг.
Тема остаётся в `/boot/grub/themes/noto_menu`, но на неё никто не ссылается.
Удалить её совсем (только после `revert.sh`):

```bash
sudo rm -rf /boot/grub/themes/noto_menu
```

Если система не грузится (ошибка UUID, «no such device»), загрузи live-USB Arch,
подключись к интернету и выполни:

```bash
# 1. Смонтировать корень и /boot (пример для /dev/sda2 и /dev/sda5 — проверь lsblk!)
mount /dev/sda2 /mnt
mount /dev/sda5 /mnt/boot
# 2. Войти в систему
arch-chroot /mnt
# 3. Откатить конфиг (репозиторий должен быть доступен внутри)
cd /home/<user>/grub-theme-noto_menu && bash revert.sh
# 4. Выйти и перезагрузиться
exit
umount -R /mnt
reboot
```

Если `backup-*` доступен, но запускать скрипт не хочется, верни `/etc/default/grub` и
`/boot/grub/grub.cfg` из него вручную и выполни `grub-mkconfig -o /boot/grub/grub.cfg`.

---

## 13. Технические ловушки (коротко)

* **FAT32 и владельцы.** `/boot` — vfat: `cp -a`/`cp -p` падают на ownership. Только обычный `cp`.
* **Кавычки.** Верхнеуровневые свойства `theme.txt` — в кавычках, иначе тема падает в текст.
* **Порядок отрисовки.** Позже в файле = ниже на экране. `+ image` раньше `+ boot_menu`.
* **`item_height` ≠ высота плашки.** Плашка = `item_height + 2*radius`.
* **Один `pf2`.** В теме должен быть ровно один шрифт — того размера, что в `item_font`;
  `update-theme.sh` чистит остальные и работает как зеркало для `/boot`.
* **AA только в PNG.** `grub-mkfont` не умеет сглаживание, поэтому подписи — картинки;
  `pf2` нужен лишь для терминала и скрытого текста меню.
* **UUID — свои.** `40_custom` генерируется `configure.sh` под текущую машину;
  в репозитории лежит только шаблон. Если правишь вручную — сверь UUID с `lsblk -f`,
  иначе будет «error: no such device» / `unknown filesystem`.
* **`grub-install` не нужен.** Меняется только конфиг; загрузчик и BootOrder не трогаем.

---

## 14. «Оставить только эту тему»

`update-theme.sh` чистит только каталог `noto_menu` (он работает как зеркало).
Другие каталоги в `/boot/grub/themes` — старые эксперименты или стоковая тема
`starfield` из пакета `grub`; на них никто не ссылается (`GRUB_THEME` указывает
только на `noto_menu`). Их можно удалить:

```bash
ls /boot/grub/themes
sudo rm -rf /boot/grub/themes/starfield   # и другие старые каталоги, если есть
```

После этого остаётся ровно один каталог — `noto_menu`. На свежей системе этих
каталогов обычно нет, и делать ничего не нужно.

---

## 15. Лицензии

* Код, скрипты и конфиги темы — **MIT** (`LICENSE`).
* Фон `backgrounds/waves-1600-original.jpg` и производный `theme/bg-waves.png` —
  **CC BY-SA 4.0**, автор Davmormar (`NOTICE.md`, `LICENSES/CC-BY-SA-4.0.txt`).
* Шрифт Noto Sans и производный `NotoSans-Regular-24.pf2` — **OFL 1.1**
  (`LICENSES/OFL-1.1.txt`).

При распространении темы сохраняй атрибуцию и лицензии из `NOTICE.md`.
