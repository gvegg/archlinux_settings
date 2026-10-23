#!/usr/bin/env bash
# ============================================================================
# install-theme.sh — установка заставки Plymouth «arch-waves».
#
# Что делает:
#   1. Проверяет Arch и наличие mkinitcpio.
#   2. Делает резервную копию /etc/mkinitcpio.conf, /etc/default/grub,
#      /etc/grub.d/40_custom и старого каталога темы.
#   3. При необходимости ставит пакет plymouth из official-репозитория.
#   4. Копирует тему в /usr/share/plymouth/themes/arch-waves.
#   5. Вставляет hook `plymouth` в HOOKS сразу после `systemd`
#      (или после `udev`/`base`, если systemd-hook отсутствует).
#   6. Добавляет `splash` в GRUB_CMDLINE_LINUX_DEFAULT, если файл есть.
#   7. Выбирает тему и пересобирает initramfs: mkinitcpio -P.
#   8. Пересобирает grub.cfg, чтобы splash попал в обычное меню GRUB.
#
# Чего НЕ делает (намеренно):
#   * не удаляет hook `kms` (это может оставить систему без раннего KMS);
#   * не меняет MODULES и не добавляет i915/amdgpu/nouveau;
#   * не блэклистит nouveau и не трогает NVIDIA;
#   * не устанавливает статическое меню 40_custom;
#   * не запускает grub-install и не меняет NVRAM;
#   * не трогает Windows/SSD.
#
# Запуск:
#   sudo bash install-theme.sh
# ============================================================================
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_SRC="$BASE/theme"
THEME_DST="/usr/share/plymouth/themes/arch-waves"
MKINIT="/etc/mkinitcpio.conf"
DEFAULT_GRUB="/etc/default/grub"
GRUB_CFG="/boot/grub/grub.cfg"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/grub-loading-plymouth-backup-$STAMP"

die() { echo "ОШИБКА: $*" >&2; exit 1; }
say() { echo; echo "== $* =="; }

[ "$(id -u)" -eq 0 ] || die "запускай с sudo: sudo bash install-theme.sh"
[ -f /etc/arch-release ] || echo "ПРЕДУПРЕЖДЕНИЕ: это не похоже на Arch Linux."
command -v pacman >/dev/null 2>&1 || die "нет pacman — это не Arch?"
command -v mkinitcpio >/dev/null 2>&1 || die "нет mkinitcpio (пакет mkinitcpio)"
[ -f "$MKINIT" ] || die "нет $MKINIT"
[ -d "$THEME_SRC" ] || die "нет каталога темы: $THEME_SRC"

for f in arch-waves.plymouth arch-waves.script arch-logo.png wordmark.png; do
  [ -f "$THEME_SRC/$f" ] || die "в комплекте нет $f — тема неполная"
done

say "Шаг 1. Резервная копия"
mkdir -p "$BACKUP"
cp "$MKINIT" "$BACKUP/mkinitcpio.conf"
[ -f "$DEFAULT_GRUB" ] && cp "$DEFAULT_GRUB" "$BACKUP/default.grub"
[ -f /etc/grub.d/40_custom ] && cp /etc/grub.d/40_custom "$BACKUP/40_custom"
if [ -d "$THEME_DST" ]; then
  cp -r "$THEME_DST" "$BACKUP/theme-old"
fi
echo "  сохранено в: $BACKUP"

say "Шаг 2. Пакет plymouth"
if pacman -Qq plymouth >/dev/null 2>&1; then
  echo "  plymouth уже установлен: $(pacman -Q plymouth)"
else
  echo "  ставлю plymouth из official-репозитория..."
  pacman -S --needed --noconfirm plymouth
fi
command -v plymouth-set-default-theme >/dev/null 2>&1 \
  || die "после установки нет plymouth-set-default-theme"
command -v plymouthd >/dev/null 2>&1 \
  || die "после установки нет plymouthd"

say "Шаг 3. Установка темы"
rm -rf "$THEME_DST"
cp -r "$THEME_SRC" "$THEME_DST"
chmod 755 "$THEME_DST"
chmod 644 "$THEME_DST"/*.plymouth "$THEME_DST"/*.script "$THEME_DST"/*.png
echo "  тема: $THEME_DST"

say "Шаг 4. Hook plymouth в mkinitcpio"
python3 - "$MKINIT" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
m = re.search(r"(?m)^\s*HOOKS=\((.*?)\)", text, re.S)
if not m:
    sys.exit("в mkinitcpio.conf не найден HOOKS=(...)")

hooks = m.group(1).split()
if "plymouth" not in hooks:
    if "systemd" in hooks:
        pos = hooks.index("systemd") + 1
    elif "udev" in hooks:
        pos = hooks.index("udev") + 1
    elif "base" in hooks:
        pos = hooks.index("base") + 1
    else:
        pos = 0
    hooks.insert(pos, "plymouth")
else:
    # Если plymouth уже есть, но стоит раньше systemd — переставить.
    if "systemd" in hooks and hooks.index("plymouth") < hooks.index("systemd"):
        hooks.remove("plymouth")
        hooks.insert(hooks.index("systemd") + 1, "plymouth")

new = "HOOKS=(" + " ".join(hooks) + ")"
text = text[:m.start()] + new + text[m.end():]
path.write_text(text, encoding="utf-8")
PY

echo "  HOOKS сейчас:"
grep -nE '^[[:space:]]*HOOKS=' "$MKINIT"

say "Шаг 5. splash в командной строке GRUB"
if [ -f "$DEFAULT_GRUB" ]; then
  python3 - "$DEFAULT_GRUB" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
key = "GRUB_CMDLINE_LINUX_DEFAULT"
pattern = re.compile(r"(?m)^(\s*" + key + r"\s*=\s*)(.*)$")
m = pattern.search(text)

if m is None:
    text = text.rstrip() + "\n" + key + '="splash"\n'
else:
    prefix, raw = m.group(1), m.group(2).strip()
    quote = ""
    if len(raw) >= 2 and raw[0] in "\"'" and raw[-1] == raw[0]:
        quote = raw[0]
        inner = raw[1:-1]
    else:
        inner = raw
    tokens = inner.split()
    if "splash" not in tokens:
        tokens.append("splash")
    new_line = prefix + quote + " ".join(tokens) + quote
    text = text[:m.start()] + new_line + text[m.end():]

path.write_text(text, encoding="utf-8")
PY
  echo "  строка сейчас:"
  grep -nE '^GRUB_CMDLINE_LINUX_DEFAULT=' "$DEFAULT_GRUB" || true
else
  echo "  ПРЕДУПРЕЖДЕНИЕ: нет $DEFAULT_GRUB."
  echo "  Если используешь статический 40_custom, добавь splash в его linux-строку."
fi

# Если есть статический 40_custom, предупредить, что splash в
# GRUB_CMDLINE_LINUX_DEFAULT на него не действует.
if [ -f /etc/grub.d/40_custom ] && grep -qE '^[[:space:]]*linux' /etc/grub.d/40_custom; then
  if ! grep -qE '^[[:space:]]*linux.*[[:space:]]splash([[:space:]]|$)' /etc/grub.d/40_custom; then
    echo "  ПРЕДУПРЕЖДЕНИЕ: в /etc/grub.d/40_custom есть linux-строка без splash."
    echo "  Для статического меню добавь splash прямо в эту строку."
  fi
fi

say "Шаг 6. Выбор темы"
plymouth-set-default-theme arch-waves
echo "  выбрано: $(plymouth-set-default-theme)"

say "Шаг 7. Пересборка initramfs"
mkinitcpio -P

say "Шаг 8. Пересборка grub.cfg (если GRUB есть)"
if command -v grub-mkconfig >/dev/null 2>&1 && [ -f "$GRUB_CFG" ]; then
  grub-mkconfig -o "$GRUB_CFG"
else
  echo "  grub-mkconfig или $GRUB_CFG не найдены — пропускаю."
  echo "  Если используешь статический 40_custom, splash уже должен быть в нём."
fi

say "Шаг 9. Проверка"
grep -qE '^[[:space:]]*HOOKS=.*plymouth' "$MKINIT" \
  || die "plymouth не попал в HOOKS"
grep -qE '^[[:space:]]*GRUB_CMDLINE_LINUX_DEFAULT=.*splash' "$DEFAULT_GRUB" 2>/dev/null \
  || echo "ПРЕДУПРЕЖДЕНИЕ: splash не найден в $DEFAULT_GRUB (для статического 40_custom это нормально)."
if command -v lsinitcpio >/dev/null 2>&1; then
  lsinitcpio /boot/initramfs-linux.img 2>/dev/null | grep -q 'arch-waves' \
    || die "в initramfs нет темы arch-waves"
  lsinitcpio /boot/initramfs-linux.img 2>/dev/null | grep -q 'plymouthd' \
    || die "в initramfs нет plymouthd"
  echo "  initramfs: plymouthd и arch-waves на месте"
else
  echo "  lsinitcpio не найден — проверка initramfs пропущена."
fi

echo
echo "ГОТОВО. Заставка Plymouth установлена."
echo "Резервная копия: $BACKUP"
echo
echo "Дальше:"
echo "  1) Перезагрузка: sudo reboot."
echo "  2) Проверить: после GRUB должен быть чёрный фон, логотип и белая надпись."
echo "  3) Выключение/перезагрузка: чёрный экран без анимации."
echo
echo "Если Plymouth не появился:"
echo "  * проверь, что в linux-строке есть splash;"
echo "  * проверь HOOKS: plymouth после systemd;"
echo "  * пересобери initramfs: sudo mkinitcpio -P;"
echo "  * аварийно: в GRUB нажми e и добавь plymouth.enable=0."
echo
echo "Откат: восстанови $BACKUP/mkinitcpio.conf и $BACKUP/default.grub,"
echo "затем sudo mkinitcpio -P и sudo grub-mkconfig -o /boot/grub/grub.cfg."
