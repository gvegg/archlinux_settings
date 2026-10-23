#!/bin/bash
# ============================================================================
# apply.sh — установка финальной темы GRUB noto_menu (белые плашки)
# Сначала всё бэкапим, потом меняем. БЕЗ rm, БЕЗ grub-install.
# Запуск:  cd <каталог-репозитория> && sudo bash apply.sh
# Откат:   sudo bash revert.sh
# Свежая система (пошагово): FRESH-INSTALL.md
# ============================================================================
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BKP="$BASE/backup-$(date +%Y%m%d-%H%M%S)"
THEME_SRC="$BASE/theme"
THEME_DST="/boot/grub/themes/noto_menu"
CFG="/boot/grub/grub.cfg"

echo "== Шаг 0. Проверки перед началом =="
[ "$(id -u)" -eq 0 ] || { echo "ОШИБКА: запускай с sudo (sudo bash apply.sh)"; exit 1; }
[ -f "$THEME_SRC/theme.txt" ] || { echo "ОШИБКА: нет $THEME_SRC/theme.txt"; exit 1; }
[ -f "/etc/grub.d/10_linux" ] || echo "ПРЕДУПРЕЖДЕНИЕ: нет /etc/grub.d/10_linux (уже отключён?)"
[ -f /usr/bin/grub-mkconfig ] || { echo "ОШИБКА: нет grub-mkconfig"; exit 1; }
[ -f "$CFG" ] || { echo "ОШИБКА: нет $CFG — сначала установи GRUB и выполни grub-mkconfig"; exit 1; }
if [ -e "$THEME_DST" ]; then
  echo "ОШИБКА: $THEME_DST уже существует. Сначала sudo bash revert.sh, или удали каталог вручную."
  exit 1
fi

# 40_custom генерируется под текущую машину (UUID корня и /boot, номер Windows).
if [ ! -f "$BASE/40_custom" ] || grep -q '@[A-Z_]*@' "$BASE/40_custom"; then
  echo "== Шаг 0b. Настройка 40_custom под текущую машину =="
  [ -f "$BASE/configure.sh" ] || { echo "ОШИБКА: нет $BASE/configure.sh"; exit 1; }
  bash "$BASE/configure.sh"
  # apply.sh запускается через sudo: вернём сгенерированному файлу владельца
  # репозитория, чтобы его можно было пересоздать без sudo.
  if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
    chown "$SUDO_UID:$SUDO_GID" "$BASE/40_custom" 2>/dev/null || true
  fi
fi

# Защита от запуска с UUID чужой машины: сверяем 40_custom с текущими разделами.
ROOT_UUID_NOW=$(findmnt -no UUID / 2>/dev/null || true)
BOOT_UUID_NOW=$(findmnt -no UUID /boot 2>/dev/null || true)
if [ -n "$ROOT_UUID_NOW" ] && ! grep -qi "$ROOT_UUID_NOW" "$BASE/40_custom"; then
  echo "ПРЕДУПРЕЖДЕНИЕ: в 40_custom нет UUID текущего корня ($ROOT_UUID_NOW)."
  echo "  Замени UUID в 40_custom (FRESH-INSTALL.md, §5), иначе система не загрузится!"
fi
if [ -n "$BOOT_UUID_NOW" ] && ! grep -qi "$BOOT_UUID_NOW" "$BASE/40_custom"; then
  echo "ПРЕДУПРЕЖДЕНИЕ: в 40_custom нет UUID текущего /boot ($BOOT_UUID_NOW)."
  echo "  Замени UUID в 40_custom (FRESH-INSTALL.md, §5), иначе ядро не найдётся!"
fi

echo "== Шаг 1. Бэкапы → $BKP =="
mkdir -p "$BKP"
cp -a /etc/default/grub            "$BKP/default.grub"
cp -a /etc/grub.d/40_custom        "$BKP/40_custom" 2>/dev/null || echo "  40_custom не было — ок"
cp -a "$CFG"                       "$BKP/grub.cfg"
ls -l /etc/grub.d > "$BKP/grub.d-listing.txt" 2>&1
( cd /etc/grub.d && for f in 10_linux 30_uefi-firmware 31_efi_bootnext; do
    if [ -x "$f" ]; then echo "$f"; fi
  done ) > "$BKP/enabled-scripts.txt"
echo "  Список скриптов, которые будут отключены: $(paste -sd' ' "$BKP/enabled-scripts.txt")"

echo "== Шаг 2. Подтверждение =="
echo "Сейчас будет:"
echo "  * скопировать тему → $THEME_DST"
echo "  * отключить (chmod -x, скрипты НЕ удаляются): 10_linux 30_uefi-firmware 31_efi_bootnext"
echo "  * заменить /etc/grub.d/40_custom на наш с 3 пунктами"
echo "  * прописать в /etc/default/grub: GRUB_THEME, GFXMODE 1600x900, TIMEOUT=-1, тихий cmdline"
echo "  * перегенерировать grub.cfg"
printf 'Продолжить? [да/нет]: '; read -r ans
[ "$ans" = "да" ] || { echo "Отмена. Ничего не сделано."; exit 0; }

echo "== Шаг 3. Тема =="
# на свежей системе каталога /boot/grub/themes может не быть
mkdir -p "$(dirname "$THEME_DST")"
cp -r "$THEME_SRC" "$THEME_DST"
for f in theme.txt bg-waves.png caption_0.png plate_c.png plate_hi_c.png; do
  [ -f "$THEME_DST/$f" ] || { echo "ОШИБКА: в теме нет $f — комплект неполный"; exit 1; }
done
ls -la "$THEME_DST"

echo "== Шаг 4. Отключаем генераторы лишних пунктов (скрипты сохраняются) =="
for f in 10_linux 30_uefi-firmware 31_efi_bootnext; do
  if [ -e "/etc/grub.d/$f" ]; then
    chmod -x "/etc/grub.d/$f" && echo "  chmod -x $f"
  fi
done

echo "== Шаг 5. Ручные пункты (40_custom) =="
cp -a "$BASE/40_custom" /etc/grub.d/40_custom
chmod +x /etc/grub.d/40_custom

echo "== Шаг 6. Параметры темы в /etc/default/grub =="
# Ключи, без которых тема не встанет как задумано (актуально для свежей системы).
# set_kv убирает и закомментированные примеры, и старые значения, затем
# дописывает ключ один раз в конец — так не бывает дублей (например GRUB_THEME
# есть и в примере-комментарии, и реальной строкой).
set_kv() {
  local k="$1" v="$2"
  sed -i "/^[#[:space:]]*${k}=/d" /etc/default/grub
  printf '%s=%s\n' "$k" "$v" >> /etc/default/grub
  echo "  $k=$v"
}
set_kv GRUB_TIMEOUT                 -1
set_kv GRUB_TIMEOUT_STYLE           menu
set_kv GRUB_GFXMODE                 1600x900x32
set_kv GRUB_GFXPAYLOAD_LINUX        keep
set_kv GRUB_CMDLINE_LINUX_DEFAULT   '"quiet loglevel=0 systemd.show_status=no udev.log_level=0"'
set_kv GRUB_THEME                   '"/boot/grub/themes/noto_menu/theme.txt"'

echo "== Шаг 7. Перегенерация grub.cfg =="
trap 'echo "!!!! grub-mkconfig провалился. ОТКАТ: sudo bash $BASE/revert.sh"; exit 1' ERR
grub-mkconfig -o "$CFG" 2>&1 | tee "$BKP/mkconfig.log"
trap - ERR

echo "== Итог. Пункты меню: =="
grep -E "^menuentry" "$CFG" || true
echo "Тема подключена: $(grep -c 'set theme=' "$CFG") (ожидается 1)"
CAPS=$(grep -c 'file = "caption_' "$THEME_DST/theme.txt" || true)
MEN=$(grep -c '^menuentry' "$CFG" || true)
if [ "$CAPS" -ne "$MEN" ]; then
  echo "ВНИМАНИЕ: подписей-картинок $CAPS, а пунктов меню $MEN."
  echo "  Поправь TEXTS в make_labels.py и блоки + image в theme.txt (FRESH-INSTALL.md, §10)."
fi
echo
echo "ГОТОВО. Если вид не понравится: cd $BASE && sudo bash revert.sh — вернёт всё как было."
