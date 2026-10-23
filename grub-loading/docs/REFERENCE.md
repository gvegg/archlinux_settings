# Справочник: файлы, пакеты, лицензии

---

## 1. Полный состав

### GRUB

| Путь | Что это | Обязателен |
|---|---|---|
| `grub/install-theme.sh` | установщик темы (без меню) | да |
| `grub/40_custom.example` | шаблон меню из 3 пунктов | нет, по желанию |
| `grub/theme/theme.txt` | описание темы | да |
| `grub/theme/NotoSans-Regular-24.pf2` | bitmap-шрифт GRUB | да |
| `grub/theme/caption_0.png` | «Arch Linux», 119×18 | да |
| `grub/theme/caption_1.png` | «Windows», 102×18 | да |
| `grub/theme/caption_2.png` | «UEFI BIOS», 111×17 | да |
| `grub/theme/plate_*.png` | 9 фрагментов обычной плашки | да |
| `grub/theme/plate_hi_*.png` | 9 фрагментов выбранной плашки | да |
| `grub/tools/make_labels.py` | пересчёт подписей (опционально) | нет |
| `grub/tools/make_plates.py` | пересчёт плашек (опционально) | нет |

### Plymouth

| Путь | Что это | Обязателен |
|---|---|---|
| `plymouth/install-theme.sh` | установщик заставки | да |
| `plymouth/theme/arch-waves.plymouth` | описание темы | да |
| `plymouth/theme/arch-waves.script` | скрипт отрисовки | да |
| `plymouth/theme/arch-logo.png` | логотип 200×200 | да |
| `plymouth/theme/wordmark.png` | надпись 357×57 | да |

### Документация

| Путь | О чём |
|---|---|
| `README.md` | обзор, быстрый старт |
| `docs/INSTALL.md` | установка на новую систему |
| `docs/GRUB.md` | устройство GRUB-темы |
| `docs/PLYMOUTH.md` | устройство заставки |
| `docs/TROUBLESHOOTING.md` | симптомы и лечение |
| `docs/REFERENCE.md` | этот файл |
| `docs/preview-grub.png` | макет меню |
| `docs/preview-plymouth.png` | макет заставки |
| `checksums.sha256` | SHA-256 всех файлов |

---

## 2. Пакеты

### На системе, где собран комплект

| Пакет | Версия | Роль |
|---|---|---|
| `grub` | `2:2.16-1` | GRUB, `grub-mkconfig` |
| `plymouth` | `26.134.222-3` | Plymouth, `plymouthd` |
| `mkinitcpio` | `42.2-1` | сборка initramfs |
| `noto-fonts` | `1:2026.10.01-1` | TTF Noto Sans (для сборки PNG/pf2) |
| `python-pillow` | `13.0.0-1` | рендер подписей (только при пересчёте) |
| `filesystem` | `2025.10.12-1` | `/usr/share/pixmaps/archlinux-logo.*` |

Версии могут отличаться на новой системе; тема использует стабильные
возможности GRUB/Plymouth, а не конкретные версии.

### Что скачивает установщик

- `plymouth` — если его нет:
  `pacman -S --needed --noconfirm plymouth`.
- Больше ничего. Все PNG, pf2 и скрипты уже в комплекте.

### Что НЕ нужно для установки

- `noto-fonts`, `python-pillow` — только для пересчёта подписей;
- `librsvg` — не используется этим комплектом (логотип уже PNG);
- AUR-пакеты, DKMS, NVIDIA — не используются;
- дисплей-менеджер, фоновый сервис — не используются.

---

## 3. Цвета и метрики

### GRUB

| Элемент | Значение |
|---|---|
| Фон | `#000000` |
| Плашка | `#ffffff` |
| Рамка | `#dedede` |
| Выбранная рамка | `#007aff` |
| Подпись | `#2b2b2b` |
| Шрифт подписи | Noto Sans Regular, 24 px |
| Плашка | 184×44, radius 16, border 2 |
| Зазор | 10 |
| Меню | left 708, top 374, width 184, height 152 |
| `item_height` | 12 |
| `item_spacing` | 42 |

### Plymouth

| Элемент | Значение |
|---|---|
| Фон | `(0, 0, 0)` |
| Логотип | 200×200, `#1793d1` |
| Надпись | 357×57, `#ffffff`, Noto Sans 72 px |
| Отступ | 30 px |
| Группа | по центру |
| Fade | 25 кадров × 20 мс ≈ 0.5 с |
| Спиннер | нет |

---

## 4. Лицензии и происхождение

### Noto Sans

- Пакет: `noto-fonts`.
- Лицензия: **SIL Open Font License 1.1**.
- `NotoSans-Regular-24.pf2` — производный bitmap-шрифт, собранный
  `grub-mkfont` из `NotoSans-Regular.ttf`.
- `caption_*.png` и `wordmark.png` — растровые изображения текста,
  отрендеренные Noto Sans; при распространении соблюдай OFL.

### Логотип Arch Linux

- Файл: `/usr/share/pixmaps/archlinux-logo.svg` (пакет `filesystem`).
- Логотип Arch Linux — товарный знак Arch Linux. Это не свободная
  лицензия на использование логотипа как бренда.
- В комплекте логотип перерисован в PNG 200×200 без TM для заставки.

### Плашки, подписи, скрипты

- Сгенерированы для этого проекта.
- Не содержат кода/картинок из старых тем.
- Фоновая картинка с волнами **не используется**; лицензия CC BY-SA
  к этому комплекту не применяется.

### Plymouth/GRUB

- Скрипты используют штатные API Plymouth и формат темы GRUB.
- Пакеты `grub` и `plymouth` распространяются под их собственными
  лицензиями (GPL и др.); комплект их не перелицензирует.

---

## 5. Checksums

Проверка целостности:

```bash
cd grub-loading
sha256sum -c checksums.sha256
```

`checksums.sha256` содержит относительные пути. Если менял файлы
(например, пересчитывал тему), пересоздай:

```bash
find . -type f ! -name checksums.sha256 -print0 \
  | sort -z \
  | xargs -0 sha256sum > checksums.sha256
```

---

## 6. Решения и почему

| Решение | Почему |
|---|---|
| Чёрный фон без картинки | нет белой вспышки, меньше файлов, не нужна лицензия фона |
| Белые плашки | контраст на чёрном, сохраняют утверждённую геометрию |
| Подписи PNG | pf2 без AA; PNG даёт полноценное сглаживание |
| 9-patch | маленькие файлы, гладкие углы, растяжение под пункт |
| `terminal-border: "0"` | иначе светлая рамка после выбора |
| Статический `40_custom` | ровно 3 пункта и контроль cmdline |
| `bootnext` для Windows | не трогает разделы SSD, только переменная прошивки |
| `GRUB_GFXPAYLOAD_LINUX=keep` | меньше смены режима/мигания |
| Plymouth `script` | не нужен готовый движок, всё в PNG |
| Нет спиннера | требование владельца, меньше шума |
| `Plymouth.GetMode() != boot` → ничего | чёрный экран при выключении |
| `kms` не удаляется автоматически | на другой GPU это может дать чёрный экран |
| Установщик не делает `grub-install` | тема не должна ломать загрузчик |
| Установщик не отключает генераторы | иначе можно остаться без пункта Arch |

---

## 7. Совместимость

- **Arch Linux**, GRUB 2.x, Plymouth из official.
- **UEFI** — основной сценарий (BootNext, `fwsetup`, FAT `/boot`).
- **BIOS** — тема работает; из `40_custom.example` нужно убрать UEFI-модули
  и `fwsetup`, оставить свои `part_msdos`/`ext2`.
- **Разрешение** — GRUB-тема пиксельная под 1600×900; Plymouth
  центрируется сам.
- **Ядро** — шаблон под `linux` (`/vmlinuz-linux`); для `linux-lts` и
  других — добавить пункт.
- **/boot** — отдельный FAT32 или внутри корня; пути и UUID
  настраиваются в `40_custom.example`.

---

## 8. Безопасность

- Все изменения — в `/boot/grub`, `/etc/default/grub`,
  `/etc/mkinitcpio.conf`, `/usr/share/plymouth/themes`.
- Перед изменениями создаются бэкапы в `/root/grub-loading-*backup-*`.
- Windows/SSD не затрагиваются.
- `grub-install`, NVRAM/BootOrder не меняются.
- Сетевой доступ — только `pacman` для `plymouth` (если его нет).
