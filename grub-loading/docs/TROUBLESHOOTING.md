# Диагностика и лечение

Ниже — реальные симптомы, причины и безопасные проверки. Начинай с
простых команд, не меняй несколько вещей одновременно.

---

## 1. GRUB

### 1.1. Меню текстовое, без темы

Симптом: чёрный/синий текстовый экран, пункты без белых плашек.

Проверь:

```bash
grep -E 'GRUB_THEME|GRUB_GFXMODE|GRUB_GFXPAYLOAD_LINUX' /etc/default/grub
ls -l /boot/grub/themes/noto_menu/theme.txt
grep -n 'noto_menu' /boot/grub/grub.cfg
```

Причины и лечение:

| Причина | Лечение |
|---|---|
| `GRUB_THEME` не задан/опечатка | прописать путь и `grub-mkconfig` |
| Тема не скопирована в `/boot` | `sudo bash grub/install-theme.sh` |
| В `theme.txt` свойство без кавычек | верхнеуровневые значения — только в кавычках |
| `GRUB_GFXMODE` не поддерживается | проверить режим, поставить рабочий |
| `/boot` не смонтирован при `grub-mkconfig` | смонтировать `/boot`, повторить |

Типичная ошибка GRUB:

```text
property value invalid; enclose literal values in quotes
```

Она означает, что строка вида `terminal-border: 0` написана без кавычек.
Нужно `terminal-border: "0"`.

### 1.2. Плашки наезжают друг на друга / слишком высокие

Симптом: белые плашки перекрываются или занимают больше 44 px.

Причина: `item_height` воспринимается как высота плашки, хотя это высота
**без** падов 9-patch.

Правильно:

```text
item_height = 12
item_spacing = 42
```

Потому что `12 + 2×16 = 44`, а шаг `12 + 42 = 54` (44 + 10 зазор).
Если поставить `item_height = 44`, получится 76 px.

### 1.3. Подписи не видны / закрыты плашками

Причина: `+ image` стоят после `+ boot_menu`. GRUB рисует компоненты в
обратном порядке файла.

Лечение: блоки `+ image` должны идти **до** `+ boot_menu`.

### 1.4. Белая рамка после выбора пункта

Симптом: при загрузке ОС по краям экрана видна светлая рамка.

Причина: `terminal-border` не равен нулю. `grub_cls()` не перерисовывает
эту полосу.

Лечение:

```text
terminal-border: "0"
```

Затем `sudo bash grub/install-theme.sh` или `grub-mkconfig`.

### 1.5. Меню смещено / не по центру

Причина: фактический видеорежим не 1600×900. Тема использует абсолютные
координаты.

Варианты:

1. Выставить `GRUB_GFXMODE=1600x900x32`, если монитор поддерживает.
2. Пересчитать тему под фактическое разрешение:
   [`../grub/tools/README.md`](../grub/tools/README.md).

Проверить режим можно в командной строке GRUB командой `videoinfo`.

### 1.6. Пунктов больше трёх

Причина: активны `10_linux`, `30_uefi-firmware`, `31_efi_bootnext`.

Проверь:

```bash
ls -l /etc/grub.d/
```

Лечение: если используешь статический `40_custom`, отключи генераторы:

```bash
sudo chmod -x /etc/grub.d/10_linux \
              /etc/grub.d/30_uefi-firmware \
              /etc/grub.d/31_efi_bootnext 2>/dev/null || true
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Если не уверен, что `40_custom` рабочий, **не отключай** `10_linux`:
сначала проверь загрузку, потом отключай.

### 1.7. После статического меню система не грузится

Симптом: пункт Arch есть, но ядро не находит root/initramfs.

Проверь:

- `__BOOT_UUID__` — UUID загрузочного раздела, не корня (если `/boot`
  отдельный);
- `__ROOT_UUID__` — UUID корня;
- пути `/vmlinuz-linux` и `/initramfs-linux.img` относительны загрузочного
  раздела;
- если `/boot` внутри корня — пути `/boot/vmlinuz-linux` и
  `/boot/initramfs-linux.img`;
- для `linux-lts` — свои имена файлов.

Быстро проверить UUID:

```bash
findmnt -no UUID /
findmnt -no UUID /boot
lsblk -f
```

Аварийно: в меню GRUB нажми `e`, исправь строку `linux`/`initrd`,
`Ctrl+X`. Если меню не появляется — live USB + `arch-chroot`.

### 1.8. Windows не запускается

`bootnext 0001` — пример. Номер нужно взять из:

```bash
efibootmgr -v
```

Найди `Windows Boot Manager` и подставь его `Boot####` без `Boot`
(например, `Boot0003` → `0003`). `bootnext` меняет только переменную
прошивки; разделы Windows не трогаются.

Если Windows нет — удали пункт, чтобы не было лишней плашки.

### 1.9. `fwsetup` не работает

`fwsetup` поддерживается не всеми UEFI-прошивками. Если пункт не нужен —
удали. На BIOS его быть не должно.

---

## 2. Plymouth

### 2.1. Plymouth не появляется, сразу логин

Проверь по порядку:

```bash
# 1. Тема выбрана?
plymouth-set-default-theme

# 2. splash есть в cmdline?
grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub
grep -nE '^[[:space:]]*linux.*splash' /etc/grub.d/40_custom 2>/dev/null

# 3. hook есть?
grep -E '^HOOKS=' /etc/mkinitcpio.conf

# 4. тема и plymouthd в initramfs?
lsinitcpio /boot/initramfs-linux.img | grep -E 'plymouthd|arch-waves'
```

Частые причины:

| Причина | Лечение |
|---|---|
| нет `splash` | добавить в cmdline и `grub-mkconfig` |
| `splash` только в `/etc/default/grub`, а меню статическое | добавить `splash` в `linux`-строку `40_custom` |
| нет hook `plymouth` | добавить после `systemd`, `mkinitcpio -P` |
| initramfs не пересобран | `sudo mkinitcpio -P` |
| тема не выбрана | `sudo plymouth-set-default-theme arch-waves` |
| Plymouth отключён параметром | убрать `plymouth.enable=0` |

### 2.2. Чёрный экран, но нет логотипа/надписи

Проверь файлы темы:

```bash
ls -l /usr/share/plymouth/themes/arch-waves/
```

Должны быть `arch-waves.plymouth`, `arch-waves.script`, `arch-logo.png`,
`wordmark.png`.

Проверь initramfs:

```bash
lsinitcpio /boot/initramfs-linux.img | grep arch-waves
```

Если файлов нет — переустанови тему и `mkinitcpio -P`.

Проверь лог Plymouth:

```bash
journalctl -b -u plymouth-start.service --no-pager
```

### 2.3. При выключении видна старая анимация/надпись

Причина: в initramfs осталась старая тема или старый скрипт.

Лечение:

```bash
sudo bash plymouth/install-theme.sh
# или вручную:
sudo rm -rf /usr/share/plymouth/themes/arch-waves
sudo cp -r plymouth/theme /usr/share/plymouth/themes/arch-waves
sudo plymouth-set-default-theme arch-waves
sudo mkinitcpio -P
```

Скрипт новой темы при `Plymouth.GetMode() != "boot"` не рисует ничего.

### 2.4. Заставка есть, но потом чёрный экран навсегда

Это не тема, а графика/ядро. Проверь:

- не удалён ли `kms` без драйвера в `MODULES`;
- не сломался ли `i915`/`amdgpu`/`nouveau`;
- нет ли ошибок в `journalctl -b -p err`.

Аварийно: в GRUB `e` → добавить `nomodeset` или `plymouth.enable=0` →
`Ctrl+X`. Затем восстановить `mkinitcpio.conf` из бэкапа и
`mkinitcpio -P`.

### 2.5. Между GRUB и Plymouth белая вспышка

Причины:

- в GRUB остался `desktop-image` (белая картинка);
- `GRUB_GFXPAYLOAD_LINUX` не `keep`;
- Plymouth рисует белый фон (старая тема);
- `kms`/режим меняется.

Проверь:

```bash
grep -E 'desktop-color|desktop-image' /boot/grub/themes/noto_menu/theme.txt
grep GRUB_GFXPAYLOAD_LINUX /etc/default/grub
grep -E 'Background|bg-waves' /usr/share/plymouth/themes/arch-waves/arch-waves.script
```

В текущей теме `desktop-image` быть не должно, а Plymouth должен задавать
`Window.SetBackground*Color(0,0,0)`.

### 2.6. Initramfs огромный

Проверь:

```bash
ls -lh /boot/initramfs-linux.img
lsinitcpio -a /boot/initramfs-linux.img | head
grep -E '^MODULES|^HOOKS' /etc/mkinitcpio.conf
```

Если в HOOKS есть `kms`, а в MODULES нет драйвера GPU — не удаляй `kms`
вслепую. Сначала выясни драйвер:

```bash
lspci -k | grep -A3 -E 'VGA|3D'
```

Для Intel — `i915`, для AMD — `amdgpu`, для NVIDIA — `nouveau`/`nvidia`.
Только потом можно убрать `kms`, добавить драйвер в `MODULES` и
`mkinitcpio -P`. См. [`INSTALL.md`](INSTALL.md), раздел 5.

---

## 3. Аварийная загрузка

### Plymouth мешает

1. В меню GRUB нажми `e`.
2. В строке `linux` добавь `plymouth.enable=0`.
3. `Ctrl+X`.

### Графика не стартует

Добавь `nomodeset`, загрузись, восстанови конфиги:

```bash
ls -d /root/grub-loading-*backup-*
```

### GRUB-меню сломано

Если есть live USB:

```bash
# найти корень и /boot, смонтировать, arch-chroot
arch-chroot /mnt
# восстановить /etc/default/grub и /etc/grub.d/40_custom из /root/...
grub-mkconfig -o /boot/grub/grub.cfg
```

Не запускай `grub-install`, пока не уверен, что проблема в конфиге, а не
в NVRAM/загрузчике.

---

## 4. Быстрые проверки одной командой

```bash
# GRUB
grep -E 'GRUB_THEME|GRUB_GFXMODE|GRUB_GFXPAYLOAD_LINUX|GRUB_TIMEOUT' /etc/default/grub
grep -E 'desktop-color|desktop-image' /boot/grub/themes/noto_menu/theme.txt
grep -n 'noto_menu' /boot/grub/grub.cfg

# Plymouth
plymouth-set-default-theme
grep -E '^HOOKS=' /etc/mkinitcpio.conf
grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub
lsinitcpio /boot/initramfs-linux.img | grep -E 'plymouthd|arch-waves'
```

Если всё сходится, но вид не тот — перезагрузись ещё раз: тема и
initramfs применяются только после перезагрузки.
