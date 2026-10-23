# Фон GRUB — «Белые волны» (затемнён на 25%)

| Параметр | Значение |
|---|---|
| Исходник | `waves-1600-original.jpg` (центральный кроп 16:9, 1600×900) |
| Оригинал | Wikimedia Commons: [`File:Abstract-background-white-12.jpg`](https://commons.wikimedia.org/wiki/File:Abstract-background-white-12.jpg) |
| Автор | Davmormar |
| Лицензия | **CC BY-SA 4.0** (при распространении темы нужна атрибуция и та же лицензия; полный текст — `../LICENSES/CC-BY-SA-4.0.txt`) |
| Обработка | ресайз до 1600×900, затемнение на 25% (яркость ×0.75) |
| Результат | `../theme/bg-waves.png` |
| Генератор | `../make_background.py` (константа `DARKEN = 0.25`) |

Перегенерация фона:

```bash
cd <каталог-репозитория> && python3 make_background.py
```

Если нужно вернуть исходную яркость — поставить `DARKEN = 0.0` и запустить снова.
