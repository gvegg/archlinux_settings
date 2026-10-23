#!/bin/bash
# ============================================================================
# update-theme.sh — синхронизирует папку темы → /boot/grub/themes/noto_menu
# и перегенерирует grub.cfg. Безопасно запускать многократно.
#   * pf2-шрифт собирается заново с размером, взятым из theme.txt (item_font)
#   * синхронизирует ассеты темы: плашки (9-patch PNG), фон, подписи и пр.
#   * работает как зеркало: лишние файлы из /boot/grub/themes/noto_menu удаляются
# Запуск:  cd <каталог-репозитория> && sudo bash update-theme.sh
# ============================================================================
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DST="/boot/grub/themes/noto_menu"
CFG="/boot/grub/grub.cfg"

TTF="/usr/share/fonts/noto/NotoSans-Regular.ttf"

[ "$(id -u)" -eq 0 ] || { echo "ОШИБКА: запускай с sudo (sudo bash update-theme.sh)"; exit 1; }

echo "== Шаг 0. Проверка theme.txt =="
# ЛОВУШКА (проверено 2026-10-23): верхнеуровневые свойства темы GRUB принимает
# ТОЛЬКО в кавычках. Строка `terminal-border: 0` без кавычек роняет загрузку
# темы с ошибкой «property value invalid; enclose literal values in quotes»
# и меню уходит в текстовый режим. Внутри объектов (left = 741) кавычки не нужны.
BADPROPS=$(grep -nE '^[[:alpha:]][[:alnum:]_-]*:[[:space:]]*[^"[:space:]]' "$BASE/theme/theme.txt" || true)
if [ -n "$BADPROPS" ]; then
  echo "ОШИБКА: свойства верхнего уровня без кавычек:"
  echo "$BADPROPS"
  echo "Оберни значения в кавычки (например: terminal-border: \"0\") и запусти снова."
  exit 1
fi
echo "  ок: все значения верхнего уровня в кавычках"

echo "== Шаг 1. Шрифт нужного размера (парсим из theme.txt) =="
# ВАЖНО: размер берём ИМЕННО из строки item_font. Раньше брали первое
# совпадение «Noto Sans Regular N» во всём файле — а первым идёт terminal-font,
# из-за чего при смене только item_font/label pf2 собирался старым размером,
# GRUB не находил нужное имя и подставлял старый шрифт («шрифт не применился»).
SIZE=$(grep -E '^[[:space:]]*item_font' "$BASE/theme/theme.txt" \
       | grep -oE 'Noto Sans Regular [0-9]+' | head -n1 \
       | grep -oE '[0-9]+' | tail -n1 || true)
[ -n "${SIZE:-}" ] || { echo "ОШИБКА: в theme.txt нет строки item_font"; exit 1; }
ALLSIZES=$(grep -oE 'Noto Sans Regular [0-9]+' "$BASE/theme/theme.txt" | grep -oE '[0-9]+' | sort -nu | tr '\n' ' ' || true)
echo "  размер шрифта из theme.txt: $SIZE pt"
[ "$(echo "$ALLSIZES" | wc -w)" -eq 1 ] || \
  echo "  ВНИМАНИЕ: в theme.txt разные размеры шрифтов ($ALLSIZES) — pf2 будет один, на $SIZE pt; остальные размеры вызовут подстановку этого шрифта"
if [ -f "$TTF" ]; then
  grub-mkfont -n "Noto Sans" -s "$SIZE" -o "$BASE/theme/NotoSans-Regular-$SIZE.pf2" \
    "$TTF" 2>/dev/null \
    || { echo "ОШИБКА: grub-mkfont не собрал pf2"; exit 1; }
else
  # На свежей системе noto-fonts может быть не установлен — в комплекте уже
  # лежит готовый pf2, его достаточно.
  [ -f "$BASE/theme/NotoSans-Regular-$SIZE.pf2" ] \
    || { echo "ОШИБКА: нет $TTF и нет готового pf2 на $SIZE pt (pacman -S noto-fonts)"; exit 1; }
  echo "  TTF нет — использую готовый NotoSans-Regular-$SIZE.pf2"
fi

echo "== Шаг 1b. Подписи-картинки с AA (make_labels.py) =="
if python3 -c 'import PIL' 2>/dev/null && [ -f "$TTF" ]; then
  python3 "$BASE/make_labels.py" \
    || { echo "ОШИБКА: make_labels.py не сработал (нужен python-pillow)"; exit 1; }
else
  # Необязательные зависимости: подписи уже собраны в theme/.
  [ -f "$BASE/theme/caption_0.png" ] \
    || { echo "ОШИБКА: нет Pillow/TTF и нет готовых caption_*.png (pacman -S python-pillow noto-fonts)"; exit 1; }
  echo "  нет Pillow или TTF — использую готовые caption_*.png"
fi
CAP_N=$(ls "$BASE/theme"/caption_*.png 2>/dev/null | wc -l || true)
[ "$CAP_N" -ge 1 ] || { echo "ОШИБКА: caption_*.png не созданы"; exit 1; }

echo "== Шаг 2. Синхронизация темы (зеркало) =="
# ВАЖНО: /boot — vfat (FAT32), он не хранит смысла ownership групп Linux.
# cp -a/-p сюда даёт 'failed to preserve ownership' и (с set -e) обрывает скрипт.
# Поэтому — обычный cp (без preserve). На FAT32 это канонический способ.
# В теме должен остаться ровно один pf2 — текущего размера.
for f in "$BASE/theme"/NotoSans-Regular-*.pf2; do
  [ -e "$f" ] || continue
  [ "$(basename "$f")" = "NotoSans-Regular-$SIZE.pf2" ] || rm -f "$f"
done
mkdir -p "$(dirname "$DST")" "$DST"
cp -r "$BASE/theme"/. "$DST"/

# Зеркало: удаляем из /boot всё, чего нет в theme/ (остатки старых тем,
# лишние размеры шрифта, артефакты с пробелами в имени). Каталог noto_menu
# принадлежит только этой теме, поэтому удаление безопасно.
while IFS= read -r f; do
  if [ ! -e "$BASE/theme/$f" ]; then
    rm -f "$DST/$f" && echo "  удалён лишний $f"
  fi
done < <(cd "$DST" && find . -maxdepth 1 -type f -printf '%P\n')
ls -la "$DST"

echo "== Шаг 3. Перегенерация grub.cfg =="
grub-mkconfig -o "$CFG" 2>&1 | tail -3

echo "== Шаг 4. Самопроверка =="
echo "loadfont-строки (шрифт должен указывать на NotoSans-Regular-$SIZE.pf2, строка НЕ обрезана):"
grep -n "loadfont" "$CFG" || echo "  ВНИМАНИЕ: loadfont в cfg не найден!"
echo
echo "Пункты меню (число должно совпадать с числом подписей):"
grep -E "^menuentry" "$CFG" || true
echo
echo "Строк тем: $(grep -c 'set theme=' "$CFG") (ожидается 1)"
echo
# целостность 9-patch плашек (theme.txt ссылается на plate_*/plate_hi_*)
for p in plate plate_hi; do
  miss=""
  for part in c n s e w nw ne sw se; do
    [ -f "$DST/${p}_${part}.png" ] || miss="$miss ${p}_${part}.png"
  done
  if [ -n "$miss" ]; then echo "ВНИМАНИЕ: нет кусков 9-patch:$miss"; else echo "9-patch $p: все 9 кусков на месте"; fi
done
echo
# фон: если задан desktop-image, файл должен лежать рядом с theme.txt в /boot
BG=$(grep -E '^[[:space:]]*desktop-image' "$DST/theme.txt" \
     | sed -E 's/.*"(.*)".*/\1/' | head -n1 || true)
if [ -n "${BG:-}" ]; then
  if [ -f "$DST/$BG" ]; then
    echo "Фон: $BG на месте ($(stat -c%s "$DST/$BG" 2>/dev/null || echo '?') байт)"
  else
    echo "ВНИМАНИЕ: в theme.txt указан фон '$BG', но файла нет в $DST"
  fi
else
  echo "Фон: desktop-image не задан (только desktop-color)"
fi
echo
# подписи-картинки должны совпадать числом с пунктами меню
CAPS=$(grep -c 'file = "caption_' "$DST/theme.txt" || true)
MEN=$(grep -c '^menuentry' "$CFG" || true)
echo "Подписи-картинки: $CAPS (ожидается $MEN — по числу пунктов меню)"
[ "$CAPS" -eq "$MEN" ] || echo "  ВНИМАНИЕ: число подписей не совпадает с числом пунктов — правь make_labels.py!"
for i in $(seq 0 $((MEN - 1))); do
  [ -f "$DST/caption_$i.png" ] || echo "  ВНИМАНИЕ: нет caption_$i.png"
done
echo
echo "ГОТОВО. Перезагрузись для проверки вида."
