# Web-сборка «Клиники монстров №13»

Откройте эту папку через HTTP-сервер и загрузите `index.html`
(например, `../run-web-preview.sh` → `http://localhost:8080`).

| Файл | Что это |
|---|---|
| `index.html` | шелл страницы: канвас, полоса загрузки, обработка ошибок |
| `index.js` | загрузчик: грузит движок и PCK, запускает движок с `--main-pack` |
| `index.pck` | данные проекта (PCK, собран `tools/pck_pack.py`) |
| `godot.web.template_release.wasm32.nothreads.js` | JS-обвязка движка (официальный Web-шаблон) |
| `godot.web.template_release.wasm32.nothreads.wasm` | движок Godot 4.7.2, single-threaded |
| `godot.audio.worklet.js`, `godot.audio.position.worklet.js` | обработка звука |

## Сборка

1. `python3 tools/pck_pack.py --project .. --output index.pck` — упаковать ресурсы
   (исключения совпадают с `exclude_filter` из `export_presets.cfg`).
2. Файлы движка — из официального набора export templates 4.7.2 для платформы Web
   (вариант `nothreads release`), они же лежат здесь.
3. Сборка без потоков не требует заголовков COOP/COEP, поэтому подходит любой
   статический хостинг.

При наличии установленного Godot 4.7.2 с официальными export templates папку
можно пересобрать штатно:

```sh
godot --headless --path .. --export-release "Web" index.html
```

## Лицензия движка

Здесь распространяется бинарная сборка **Godot Engine 4.7.2**
(Copyright © 2014–present Godot Engine contributors; © 2007–2014 Juan Linietsky,
Ariel Manzur), лицензия MIT — <https://godotengine.org/license>.

Шрифты `DejaVu Sans Mono` в `index.pck` — см. `../assets/DejaVu-LICENSE.txt`.
