extends RefCounted

const METHODS: Array[String] = ["potion", "surgery", "grimoire"]
const INGREDIENTS: Array[String] = ["МХИ", "ГРИБ", "ГЛАЗ", "СЛИЗЬ", "КОСТЬ"]
const INGREDIENT_COLORS: Array[Color] = [
	Color("#78a15c"), Color("#b58c63"), Color("#ead56b"), Color("#73b9a1"), Color("#ded4b3")
]

const PATIENTS: Array[Dictionary] = [
	{
		"name": "ГХАТЬЯР", "tag": "РАЗДУТЫЙ", "form": "tentacle", "skin": Color("#65724e"), "eye": Color("#e5ed91"), "eyes": 1,
		"disease": "ГНИЛЬ ЩУПАЛЕЦ", "symptom": "ТРИ ЩУПАЛЬЦА ПУЛЬСИРУЮТ", "complaint": "ОНО... КАПАЕТ...",
		"method": "potion", "recipe": [3, 0, 2]
	},
	{
		"name": "БАРОН КЛЫК", "tag": "НЕЖНЫЙ", "form": "vampire", "skin": Color("#b5a18a"), "eye": Color("#ee5d60"), "eyes": 2,
		"disease": "ЧЕСНОЧНЫЙ НАСМОРК", "symptom": "ЧИХАЕТ ПРИ ВИДЕ САЛАТА", "complaint": "Я ВАМПИР. ЭТО ИРОНИЯ.",
		"method": "potion", "recipe": [0, 1, 3]
	},
	{
		"name": "САША", "tag": "СКЕЛЕТ", "form": "skeleton", "skin": Color("#d3c8a7"), "eye": Color("#9dcf78"), "eyes": 2,
		"disease": "ХРУСТ ВЕЗДЕ", "symptom": "ХРУСТЯТ ДАЖЕ МЫСЛИ", "complaint": "ХРУЩУ... ВЕЗДЕ...",
		"method": "potion", "recipe": [4, 0, 1]
	},
	{
		"name": "ГРОММИ", "tag": "ГОЛЕМ", "form": "golem", "skin": Color("#71877d"), "eye": Color("#e2b95e"), "eyes": 2,
		"disease": "КАМЕНЬ В ЖЕЛЧИ", "symptom": "ОДИН КАМЕНЬ ЛИШНИЙ", "complaint": "Я ВЕСЬ КАМЕНЬ. НО ЭТОТ — ЛИШНИЙ.",
		"method": "surgery", "recipe": []
	},
	{
		"name": "ЗЁМА", "tag": "ЗОМБИ", "form": "zombie", "skin": Color("#81936b"), "eye": Color("#e9df8c"), "eyes": 2,
		"disease": "ПЛЕСЕНЬ НА МОЗГЕ", "symptom": "ЧЕШЕТСЯ ПОД ЧЕРЕПОМ", "complaint": "МОЗГИ... ЧЕШУТСЯ...",
		"method": "surgery", "recipe": []
	},
	{
		"name": "ДВУГЛАВ", "tag": "ЭТТИН", "form": "twin", "skin": Color("#75855a"), "eye": Color("#d9edaa"), "eyes": 2,
		"disease": "ВТОРАЯ ГОЛОВА БОЛИТ", "symptom": "ГОЛОВЫ НЕ СОШЛИСЬ", "complaint": "НЕ СМОТРИ НА НЕЁ. ЕЙ ХУЖЕ.",
		"method": "surgery", "recipe": []
	},
	{
		"name": "МОРГАНА", "tag": "ПРИЗРАК", "form": "ghost", "skin": Color("#a2c7bb"), "eye": Color("#f2f0c1"), "eyes": 2,
		"disease": "ЭКТОПЛАЗМА В НОСУ", "symptom": "СВЕТИТСЯ НОС", "complaint": "АПЧХИ!.. СНОВА...",
		"method": "grimoire", "recipe": []
	},
	{
		"name": "РАМЗЕС", "tag": "МУМИЯ", "form": "mummy", "skin": Color("#b39a6e"), "eye": Color("#f0d277"), "eyes": 2,
		"disease": "ПРОКЛЯТИЕ ИКОТЫ", "symptom": "ИКНУЛ 3000 РАЗ", "complaint": "ИК... ПРОСТИТЕ... ИК...",
		"method": "grimoire", "recipe": []
	},
	{
		"name": "МИСТЕР ТЕНЬ", "tag": "БЕЗДОМНЫЙ", "form": "shadow", "skin": Color("#30343f"), "eye": Color("#d8e8f0"), "eyes": 2,
		"disease": "ОТСОЕДИНИЛСЯ ОТ ХОЗЯИНА", "symptom": "ТЕНЬ НЕ СОВПАДАЕТ", "complaint": "Я... САМ ПО СЕБЕ... СТРАШНО...",
		"method": "grimoire", "recipe": []
	},
	{
		"name": "ВОЛЬФГАНГ", "tag": "ОБОРОТЕНЬ", "form": "wolf", "skin": Color("#91775d"), "eye": Color("#e7c76e"), "eyes": 2,
		"disease": "ЛУНАТИЗМ В НОВОЛУНИЕ", "symptom": "ПРОСЫПАЕТСЯ НЕ ДОМА", "complaint": "ПРОСЫПАЮСЬ В СОСЕДНЕЙ ДЕРЕВНЕ.",
		"method": "potion", "recipe": [1, 0, 4]
	}
]

static func method_label(method: String) -> String:
	match method:
		"potion":
			return "ЗЕЛЬЁ"
		"surgery":
			return "ХИРУРГИЯ"
		"grimoire":
			return "ГРИМУАР"
	return "НЕИЗВЕСТНО"

static func resource_label(method: String) -> String:
	match method:
		"potion":
			return "ФЛАКОНЫ"
		"surgery":
			return "ИНСТРУМЕНТЫ"
		"grimoire":
			return "РУНЫ"
	return "ЗАПАСЫ"

static func make_shift(rng: RandomNumberGenerator) -> Array[int]:
	var pools: Dictionary = {"potion": [], "surgery": [], "grimoire": []}
	for i in range(PATIENTS.size()):
		var method: String = str(PATIENTS[i]["method"])
		var pool: Array = pools[method]
		pool.append(i)
		pools[method] = pool

	for method in METHODS:
		_shuffle(pools[method], rng)

	var selected: Array[int] = []
	var counts: Dictionary = {"potion": 0, "surgery": 0, "grimoire": 0}
	for method in METHODS:
		var first: Array = pools[method]
		selected.append(int(first.pop_back()))
		pools[method] = first
		counts[method] = 1

	while selected.size() < 5:
		var available: Array[String] = []
		for method in METHODS:
			if int(counts[method]) < 2 and not pools[method].is_empty():
				available.append(method)
		if available.is_empty():
			break
		var method: String = available[rng.randi_range(0, available.size() - 1)]
		var pool: Array = pools[method]
		selected.append(int(pool.pop_back()))
		pools[method] = pool
		counts[method] = int(counts[method]) + 1

	_shuffle(selected, rng)
	return selected

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	var i: int = items.size() - 1
	while i > 0:
		var j: int = rng.randi_range(0, i)
		var temp: Variant = items[i]
		items[i] = items[j]
		items[j] = temp
		i -= 1
