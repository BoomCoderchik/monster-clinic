# Промпты для генерации арта «Клиника монстров №13»

Документ для генерации спрайтов, фонов и иконок под текущий стиль игры.
Промпты даны **по-английски** (модели понимают их заметно лучше), пояснения —
по-русски. Копируйте блок целиком, включая стилевой префикс.

## Что игре нужно и в каком виде

| Что | Сколько | Формат | Размер холста | Куда я это поставлю |
|---|---|---|---|---|
| Монстр (пациент) | 10 | PNG, прозрачный фон | 512×512, персонаж ~440 px в высоту | кабинет (`_draw_monster`, масштаб 1.0) и карточка пациента (0.62) |
| Врач (игрок) | 1 | PNG, прозрачный фон | 512×512 | пока не нарисован, добавлю в кабинет и в сводку смены |
| Фон кабинета | 1 | PNG | 2560×548 (или 1920×411) | вместо процедурной отрисовки комнаты |
| Обложка «Книги патологий» | 1 | PNG, прозрачный фон | 528×968 | карточка книги в центре |
| Иконки ингредиентов | 5 | PNG, прозрачный фон | 256×256 каждая | мини-игра «Зелье» |
| Иконки методов | 3 | PNG, прозрачный фон | 256×256 каждая | панель «Запасы» (зелье, хирургия, гримуар) |
| Руны | 4 | PNG, прозрачный фон | 256×256 каждая | мини-игра «Гримуар» |

**Технические требования ко всем картинкам**

- Плоский пиксель-арт: жёсткие края, **без сглаживания и без градиентов**, тени — отдельными блоками цвета.
- Один персонаж/объект на изображение, по центру, целиком в кадре, ноги/низ у нижнего края.
- Прозрачный фон (кроме фона кабинета). Никаких надписей, подписей, рамок и водяных знаков на картинке.
- Вид спереди, слегка в три четверти. Свет тёплый сверху-справа (в кабинете лампа справа), слева — холодная подсветка.
- Логический «пиксель» спрайта — 4–6 px холста: я потом уменьшу картинку в 4–8 раз, и она попадёт в сетку игры 640×275.
- Контур: тонкий (1 логический пиксель) тёмный, цвет — не чисто чёрный, а самый тёмный оттенок кожи/материала.

## Палитра проекта (подставляйте эти hex)

Тёмный фон и мебель: `#090f10` пустота, `#172321` стена, `#22302a` светлая стена,
`#352821` дерево, `#594131` светлое дерево, `#1b2424` панель, `#32413a` светлая панель,
`#75604a` рамка-латунь, `#d4ad59` золото.
Бумага и текст: `#ddcfaa` бумага, `#c2b18b` тень бумаги, `#252a25` чернила, `#e4d9b7` светлый текст,
`#9a9b7d` приглушённый текст.
Акценты: `#88aa66` зелёный (успех/здоровье), `#b9554f` красный (стресс), `#73a8ae` голубой (холод).

## 1. Стилевой префикс (обязателен для всех промптов)

```text
Retro pixel art sprite in the style of a cozy pixel-horror night clinic game,
16-bit console look, chunky visible pixels, hard edges, no anti-aliasing, no blur,
no gradients, flat shading with 2-3 tones per material plus subtle dithered shadows,
muted desaturated palette (moss green #65724e, ochre #b39a6e, teal #172321, brass #75604a,
paper #ddcfaa, gold #d4ad59), thin dark outline in a darker tone of the material,
warm lamp light from the upper right, cool teal rim light from the left,
single character centered, full body, front view slightly turned 3/4, feet at the bottom,
clean solid transparent background, no text, no watermark, no frame, no shadow on the background,
sprite is drawn large on a 512x512 canvas for downscaling
```

**Negative (если генератор поддерживает — вставьте в negative prompt):**
```text
anti-aliasing, blurry, smooth gradients, 3d render, realistic, photo, glow, lens flare,
text, letters, signature, watermark, frame, border, multiple characters, busy background,
cropped limbs, extra heads, extra fingers, painterly brush strokes
```

## 2. Десять пациентов

Общая часть для всех — стилевой префикс выше, дальше описание конкретного монстра.
Имя, форма и цвета взяты из `scripts/game_data.gd`, так что спрайт сразу совпадёт
с логикой игры.

### ГХАТЬЯР — «Раздутый», щупальца
```text
A bloated slug-like monster with one huge glowing single eye (eye color #e5ed91),
sickly olive-green skin #65724e, six short pulsing tentacles instead of arms and legs,
drops of pale slime dripping from the tentacle tips, small dark spots where the slime falls,
sagging heavy body, apologetic posture, one eye looking up at the doctor
```
*Жалоба: «ОНО... КАПАЕТ...»; больные места — три щупальца пульсируют. Слизь светлая, чтобы её было видно на тёмной коже.*

### БАРОН КЛЫК — «Нежный», вампир
```text
An aristocratic vampire monster, gaunt, pale grey-beige skin #b5a18a, blood-red eyes #ee5d60,
two small fangs, black high-collared cape with a brass clasp, thin long fingers,
a tiny handkerchief in one hand, runny nose drop, offended dignified posture
```
*Жалоба: «Я ВАМПИР. ЭТО ИРОНИЯ.»; болезнь — чесночный насморк, поэтому в другой руке можно дать веточку чеснока.*

### САША — «Скелет»
```text
A friendly skeleton monster, bleached bone color #d3c8a7, glowing green eye sockets #9dcf78,
ribcage with visible gaps, loose shoulder joint, one arm slightly detached and hanging,
small crack lines on the skull and ribs, cheerful shy stance
```
*Жалоба: «ХРУЩУ... ВЕЗДЕ...» — трещины и зазоры в суставах должны читаться.*

### ГРОММИ — «Голем»
```text
A stone golem monster built from grey-green blocks and slabs #71877d, amber glowing eyes #e2b95e,
moss in the joints, one cobblestone in the chest noticeably newer and cleaner than the rest
(this is the extra stone to remove), heavy square shoulders, tiny stubby legs
```
*Жалоба: «Я ВЕСЬ КАМЕНЬ. НО ЭТОТ — ЛИШНИЙ.»; лишний камень обязателен — это цель хирургии.*

### ЗЁМА — «Зомби»
```text
A patched zombie monster, muddy olive skin #81936b, glowing yellow-green eyes #e9df8c,
a seam on the skull lid like an opened jar lid, tuft of pale mould growing out of the seam,
one hand raised to scratch the head, shy guilty look
```
*Жалоба: «МОЗГИ... ЧЕШУТСЯ...» — плесень на темечке должна быть видна как отдельное пятно.*

### ДВУГЛАВ — «Эттин», две головы
```text
A two-headed monster with one wide body, both heads olive-green #75855a with pale eyes #d9edaa,
the left head healthy and grumpy, the right head clearly sick with a purple-grey bruise,
bandage and drooping eyelids, the sick head turned away from the other
```
*Жалоба: «НЕ СМОТРИ НА НЕЁ. ЕЙ ХУЖЕ.» — больная голова должна отличаться цветом, а не только позой.*

### МОРГАНА — «Призрак»
```text
A floating ghost monster, translucent pale aqua body #a2c7bb, cream glow eyes #f2f0c1,
a translucent tail instead of legs, a small glowing nose (#d4ad59 bright) with an
ectoplasm droplet coming out of it, both hands holding a handkerchief, sneezing pose
```
*Жалоба: «АПЧХИ!.. СНОВА...» — светящийся нос обязателен (симптом: «светится нос»).*

### РАМЗЕС — «Мумия»
```text
A mummy monster wrapped in beige bandages #b39a6e, only the golden glowing eyes #f0d277 visible,
one bandage end loose and dragging, a small royal cobra ornament on the shoulder,
hiccup pose with a hand over the mouth, dignified but embarrassed
```
*Жалоба: «ИК... ПРОСТИТЕ... ИК...»; болезнь — проклятие икоты.*

### МИСТЕР ТЕНЬ — «Бездомный»
```text
A shadow monster shaped like a person, matte dark blue-grey body #30343f,
pale luminous eyes #d8e8f0, soft smoky edges, the body cast no shadow of its own,
a faint seam where it would have been attached to its owner, timid hunched posture
```
*Жалоба: «Я... САМ ПО СЕБЕ... СТРАШНО...» — силуэт человеческий, но края чуть «дымятся».*

### ВОЛЬФГАНГ — «Оборотень»
```text
A big scruffy werewolf monster, warm brown fur #91775d with lighter chest fur,
amber eyes #e7c76e, one ear torn, a nightcap hanging off the other ear, tangled blanket
wrapped around one leg, sleepy confused posture, paws with visible claws
```
*Жалоба: «ПРОСЫПАЮСЬ В СОСЕДНЕЙ ДЕРЕВНЕ.»; болезнь — лунатизм в новолуние.*

## 3. Врач (игрок)

```text
[style prefix] An exhausted night-shift doctor monster, gender-neutral, small horns under a
worn medical cap, dark teal scrubs #22302a with a beige apron #ddcfaa, thick round glasses
with one cracked lens, a brass name badge (#d4ad59) reading the shape of a clinic number,
holding a clipboard and a small brass lantern, standing pose, warm lamp key light from upper right
```
Отдельно, если захотите версию для финала смены: тот же доктор, но уставший, в кресле, с чашкой.

## 4. Фон кабинета

```text
[style prefix without "single character"] Side view of a tiny night clinic cabinet, 1280x274 game scene:
dark teal bare walls #172321 with vertical seam lines, two tall arched windows with wooden frames
and slanting rain streaks outside (#22302a sky), a long wooden desk #352821 with pale drawers
and brass handles #75604a along the whole width, a hanging brass lamp with a warm cone of light
on the right side, a shelf with five dusty bottles, a closed dark door on the far right,
a wall plaque with the room number, scattered papers and a folder on the desk,
no characters, empty room, flat pixel art, layered composition with the desk area clearly readable
```
Важно: середина комнаты должна остаться свободной — там стоит монстр, а над ним висит облачко с жалобой.

## 5. Предметы и иконки

**Обложка «Книги патологий»**
```text
[style prefix] A thick old medical book, worn plum-purple cover with heavy brass corner caps
#d4ad59, horizontal spine bands, no letters on the cover, only a small brass plaque and a
question-mark embossed groove in the middle, slightly open with visible pages,
sitting upright as a game inventory item icon
```

**Ингредиенты (5 отдельных картинок в одном стиле)**
```text
[style prefix] Single game item icon, centered, transparent background, 256x256:
1) a clump of forest moss, muted green #78a15c
2) a stubby brown mushroom with pale spots #b58c63
3) a preserved eyeball in a jar, sickly yellow #ead56b
4) a blob of translucent slime, pale teal #73b9a1
5) a single old bone, bone-white #ded4b3
```

**Методы лечения (3 отдельных иконки)**
```text
[style prefix] Single game item icon, centered, transparent background, 256x256:
1) a corked round potion flask with green liquid #88aa66
2) a stubby surgical scalpel with a brass handle #75604a, next to a folded bandage
3) a small purple-grey rune stone #b08cae with a carved spiral
```

**Руны (4 отдельные картинки, одна серия)**
```text
[style prefix] Single carved stone rune tablet, plum-grey stone #b08cae with a deep groove
filled with gold #d4ad59, transparent background, 256x256, series where only the carved symbol
changes: 1) spiral  2) triangle with a bar  3) three vertical ticks  4) a cross with a hook
```

## 6. Если хочется 3D-модели

Игра плоская, поэтому 3D имеет смысл только как промежуточный шаг: сгенерировать
модель, отрендерить в спрайт-лист и уменьшить до пикселей. Для этого подойдёт
промпт такого вида (Meshy / Tripo / Hunyuan3D):

```text
Stylized low-poly chunky creature, cozy pixel-horror monster, muted desaturated palette
(moss green, ochre, teal), flat untextured vertex colors, no texture maps, no PBR,
clean topology, A-pose, single model, neutral background, orthographic-friendly proportions
```
Дальше нужен рендер: **8 поворотов по 45°**, камера ортографическая, спереди/сверху
без перспективы, свет ровный без бликов — из этого я соберу спрайт-лист и уменьшу
до 2× сетки игры. Для пиксельного стиля картинки от image-моделей всё равно дадут
более цельный результат, поэтому 3D — опция, а не обязательный путь.

## Что прислать

- PNG-файлы (не JPG: нужен прозрачный фон), по одному на объект, имена по монстрам
  латиницей: `ghatyar.png`, `baron_klyk.png`, `sasha.png`, `grommi.png`, `zyoma.png`,
  `dvuglav.png`, `morgana.png`, `ramzes.png`, `mister_ten.png`, `volfgang.png`.
- Фон — `room.png`; книга — `book.png`; ингредиенты — `ing_moss.png` и т.д.
- Если генератор делает варианты — присылайте 2–3 на монстра, выберу тот, что
  лучше читается в уменьшении (главное: силуэт и одна яркая деталь, остальное
  сливается в кашу при 70×50 px).
