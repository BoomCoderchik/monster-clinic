extends Control

signal minigame_ready

const GameData = preload("res://scripts/game_data.gd")
const SfxScript = preload("res://scripts/sfx.gd")

const VIEW_W: float = 640.0
const VIEW_H: float = 275.0
const ROOM_H: float = 137.0
const ACTION_X: float = 258.0
const ACTION_Y: float = 158.0
const ACTION_W: float = 129.0
const ACTION_H: float = 19.0
const ACTION_STEP: float = 21.0
const PATIENT_CARD: Rect2 = Rect2(5.0, 146.0, 84.0, 121.0)
const COMPLAINT_CARD: Rect2 = Rect2(93.0, 146.0, 86.0, 121.0)
const BOOK_CARD: Rect2 = Rect2(183.0, 146.0, 66.0, 121.0)
const SURGERY_TRACK: Rect2 = Rect2(177.0, 83.0, 286.0, 16.0)
const FONT_REGULAR_PATH: String = "res://assets/DejaVuSansMono.ttf"
const FONT_BOLD_PATH: String = "res://assets/DejaVuSansMono-Bold.ttf"

const C_VOID: Color = Color("#090f10")
const C_WALL: Color = Color("#172321")
const C_WALL_LIGHT: Color = Color("#22302a")
const C_WOOD: Color = Color("#352821")
const C_WOOD_LIGHT: Color = Color("#594131")
const C_PANEL: Color = Color("#1b2424")
const C_PANEL_HI: Color = Color("#32413a")
const C_FRAME: Color = Color("#75604a")
const C_PAPER: Color = Color("#ddcfaa")
const C_PAPER_SHADE: Color = Color("#c2b18b")
const C_INK: Color = Color("#252a25")
const C_TEXT: Color = Color("#e4d9b7")
const C_MUTED: Color = Color("#9a9b7d")
const C_GOLD: Color = Color("#d4ad59")
const C_GREEN: Color = Color("#88aa66")
const C_RED: Color = Color("#b9554f")
const C_BLUE: Color = Color("#73a8ae")

const ACTION_LABELS: Array[String] = ["1  ОСМОТР", "2  КНИГА", "3  ЗЕЛЬЕ", "4  ХИРУРГИЯ", "5  ГРИМУАР"]

var rng := RandomNumberGenerator.new()
var pixel_font: Font
var pixel_font_bold: Font
var sfx: Node

var game_state: String = "playing"
var shift_number: int = 0
var shift_order: Array[int] = []
var resolved_count: int = 0
var patients_cured: int = 0
var patients_lost: int = 0
var coins: int = 0
var resources: Dictionary = {}
var current_patient: Dictionary = {}
var patient_stress: float = 0.0
var stress_rate: float = 0.28
var log_lines: Array[String] = []
var toast_text: String = ""
var toast_time: float = 0.0
var sound_enabled: bool = true

var examined: bool = false
var diagnosis_known: bool = false
var exam_active: bool = false
var exam_timer: float = 0.0
var hotspot_positions: Array[Vector2] = []
var found_hotspots: Array[bool] = []

var active_minigame: String = ""
var potion_step: int = 0
var potion_recipe: Array = []
var surgery_cursor_x: float = 30.0
var surgery_direction: float = 1.0
var surgery_target_x: float = 142.0
var surgery_target_width: float = 56.0
var surgery_hits: int = 0
var grimoire_pattern: Array[int] = []
var grimoire_clock: float = 0.0
var grimoire_ready: bool = false
var grimoire_input_index: int = 0

var transition_time: float = 0.0
var ambient_time: float = 0.0
var shake_time: float = 0.0
var shake_strength: float = 0.0
var mouse_position: Vector2 = Vector2(-100.0, -100.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(VIEW_W, VIEW_H)
	pixel_font = _load_pixel_font(FONT_REGULAR_PATH)
	pixel_font_bold = _load_pixel_font(FONT_BOLD_PATH)
	if pixel_font is FontFile:
		(pixel_font as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_NONE
		(pixel_font as FontFile).hinting = TextServer.HINTING_NONE
	if pixel_font_bold is FontFile:
		(pixel_font_bold as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_NONE
		(pixel_font_bold as FontFile).hinting = TextServer.HINTING_NONE
	sfx = SfxScript.new()
	add_child(sfx)
	_start_shift(false, -1)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _load_pixel_font(path: String) -> Font:
	# В редакторе и обычном экспорте шрифт приходит как импортированный ресурс.
	# В шаблонной сборке без редактора .ttf не проходит через ResourceLoader,
	# поэтому пробуем загрузить динамический шрифт напрямую.
	var font: Font = null
	if ResourceLoader.exists(path):
		font = load(path) as Font
	if font == null:
		var dynamic_font := FontFile.new()
		if dynamic_font.load_dynamic_font(path) == OK:
			font = dynamic_font
	return font

func _process(delta: float) -> void:
	ambient_time += delta
	if toast_time > 0.0:
		toast_time = maxf(0.0, toast_time - delta)
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)
		shake_strength = maxf(0.0, shake_strength - delta * 10.0)

	if transition_time > 0.0:
		transition_time -= delta
		if transition_time <= 0.0:
			transition_time = 0.0
			_advance_patient()
	elif game_state == "playing":
		patient_stress = minf(100.0, patient_stress + stress_rate * delta)
		if exam_active:
			exam_timer -= delta
			if exam_timer <= 0.0:
				exam_active = false
				_add_stress(7.0, "Осмотр затянулся. Точки ушли.")
		if active_minigame == "surgery":
			_update_surgery(delta)
		elif active_minigame == "grimoire" and not grimoire_ready:
			grimoire_clock += delta
			if grimoire_clock >= float(grimoire_pattern.size()) * 0.48 + 0.3:
				grimoire_ready = true
				_toast("Повтори руны. Не зови их по именам.", 1.4)
				minigame_ready.emit()
		if patient_stress >= 100.0 and game_state == "playing":
			_lose_patient()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_position = (event as InputEventMouseMotion).position
		queue_redraw()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			mouse_position = mouse_event.position
			_handle_game_click(mouse_event.position)
			accept_event()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_1: _press_action(0)
				KEY_2: _press_action(1)
				KEY_3: _press_action(2)
				KEY_4: _press_action(3)
				KEY_5: _press_action(4)
				KEY_SPACE:
					if active_minigame == "surgery":
						_surgery_strike()
				KEY_M:
					sound_enabled = not sound_enabled
					if sfx != null:
						sfx.set_muted(not sound_enabled)
					_toast("Звук: " + ("ВКЛ" if sound_enabled else "ВЫКЛ"), 1.0)
			accept_event()

func _start_shift(increment_number: bool, seed_value: int) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	if increment_number:
		shift_number += 1
	else:
		shift_number = 1
	shift_order = GameData.make_shift(rng)
	resolved_count = 0
	patients_cured = 0
	patients_lost = 0
	coins = 0
	resources = {"potion": 2, "surgery": 2, "grimoire": 2}
	game_state = "playing"
	active_minigame = ""
	transition_time = 0.0
	log_lines.clear()
	_log_event("Смена %02d. Осмотр → книга → лечение." % shift_number)
	_begin_patient()

func start_shift(seed_value: int = -1) -> void:
	_start_shift(true, seed_value)

func _begin_patient() -> void:
	if resolved_count >= shift_order.size():
		game_state = "summary"
		active_minigame = ""
		_log_event("Смена закрыта. Бумаги не спрашивай.")
		return
	game_state = "playing"
	current_patient = GameData.PATIENTS[shift_order[resolved_count]]
	patient_stress = float(rng.randi_range(12, 18))
	examined = false
	diagnosis_known = false
	exam_active = false
	exam_timer = 0.0
	hotspot_positions = [Vector2(418.0, 72.0), Vector2(434.0, 83.0), Vector2(449.0, 94.0)]
	found_hotspots = [false, false, false]
	active_minigame = ""
	potion_step = 0
	potion_recipe.clear()
	grimoire_ready = false
	grimoire_input_index = 0
	_log_event("%s: «%s»" % [str(current_patient["name"]), str(current_patient["complaint"])])
	_toast("Осмотри 3 точки → Книга → верный метод.", 2.4)
	queue_redraw()

func _advance_patient() -> void:
	if resolved_count >= shift_order.size():
		game_state = "summary"
		active_minigame = ""
		_log_event("Смена закрыта. Итог: %d/5." % patients_cured)
		if sfx != null:
			sfx.play_fx("success")
	else:
		_begin_patient()

func _handle_game_click(position: Vector2) -> void:
	if transition_time > 0.0:
		return
	if game_state == "summary":
		if action_rect(4).has_point(position):
			start_shift()
		return
	if game_state != "playing":
		return

	if active_minigame == "potion":
		for i in range(GameData.INGREDIENTS.size()):
			if ingredient_rect(i).has_point(position):
				_choose_ingredient(i)
				return
		return
	if active_minigame == "surgery":
		if Rect2(167.0, 70.0, 306.0, 43.0).has_point(position):
			_surgery_strike()
		return
	if active_minigame == "grimoire":
		if not grimoire_ready:
			return
		for i in range(4):
			if rune_rect(i).has_point(position):
				_choose_rune(i)
				return
		return

	if position.y >= ROOM_H:
		for i in range(ACTION_LABELS.size()):
			if action_rect(i).has_point(position):
				_press_action(i)
				return
		if BOOK_CARD.has_point(position):
			_consult_book()
		return
	if exam_active:
		_click_exam_spot(position)

func _press_action(index: int) -> void:
	if game_state == "summary":
		if index == 4:
			start_shift()
		return
	if game_state != "playing" or transition_time > 0.0 or active_minigame != "":
		return
	match index:
		0: _begin_exam()
		1: _consult_book()
		2: _start_treatment("potion")
		3: _start_treatment("surgery")
		4: _start_treatment("grimoire")

func _begin_exam() -> void:
	if examined:
		_toast("Осмотр готов. Пятна всё ещё подозрительные.")
		return
	if exam_active:
		_toast("Три метки. Не тыкай в мебель.")
		return
	exam_active = true
	exam_timer = 20.0
	found_hotspots = [false, false, false]
	_log_event("Осмотр: найди три мерцающие точки.")
	_toast("Кликни по всем трём меткам на пациенте.", 2.0)
	if sfx != null:
		sfx.play_fx("inspect")

func _click_exam_spot(position: Vector2) -> void:
	for i in range(hotspot_positions.size()):
		if not found_hotspots[i] and position.distance_to(hotspot_positions[i]) <= 10.0:
			found_hotspots[i] = true
			if sfx != null:
				sfx.play_fx("click")
			if _all_hotspots_found():
				exam_active = false
				examined = true
				patient_stress = maxf(0.0, patient_stress - 5.0)
				_log_event("Осмотр готов. Теперь спроси книгу.")
				_toast("Осмотр готов. Книга ждёт.", 1.7)
			queue_redraw()
			return
	_add_stress(4.0, "Мимо. У пациента не там болит.")

func _all_hotspots_found() -> bool:
	for found in found_hotspots:
		if not found:
			return false
	return true

func _consult_book() -> void:
	if not examined:
		_toast("Книга без осмотра ставит диагноз: «нет».")
		return
	diagnosis_known = true
	var disease: String = str(current_patient.get("disease", "НЕИЗВЕСТНО"))
	var method: String = str(current_patient.get("method", ""))
	_log_event("Книга: %s → %s." % [disease, GameData.method_label(method)])
	_toast("Диагноз: " + disease + ".", 2.0)
	if sfx != null:
		sfx.play_fx("rune")
	queue_redraw()

func _start_treatment(method: String) -> void:
	if not examined:
		_toast("Сначала осмотр. Мы не гадаем по щупальцам.")
		return
	if not diagnosis_known:
		_toast("Спроси Книгу. Она старше интернов.")
		return
	if method != str(current_patient.get("method", "")):
		_add_stress(12.0, "Не тот метод. Пациент: «Ясно...»")
		return
	if int(resources.get(method, 0)) <= 0:
		_toast("Запасов нет. Надо было не лечить всех подряд.")
		return
	active_minigame = method
	if method == "potion":
		potion_recipe = current_patient.get("recipe", []).duplicate()
		potion_step = 0
		_log_event("Зелье: повтори рецепт по порядку.")
		_toast("Смешай ингредиенты в нужной последовательности.", 1.7)
	elif method == "surgery":
		surgery_hits = 0
		surgery_cursor_x = 12.0
		surgery_direction = 1.0
		surgery_target_x = rng.randf_range(82.0, SURGERY_TRACK.size.x - 48.0)
		surgery_target_width = 58.0
		_log_event("Хирургия: три точных движения.")
		_toast("Клик / ПРОБЕЛ — когда шкала в зелёном.", 1.8)
	else:
		active_minigame = "grimoire"
		grimoire_pattern.clear()
		for i in range(4):
			grimoire_pattern.append(rng.randi_range(0, 3))
		grimoire_clock = 0.0
		grimoire_ready = false
		grimoire_input_index = 0
		_log_event("Гримуар: запомни четыре руны.")
		_toast("Смотри, запоминай. Книга не повторяет.", 1.7)
	if sfx != null:
		sfx.play_fx("click")
	queue_redraw()

func _choose_ingredient(index: int) -> void:
	if potion_step >= potion_recipe.size():
		return
	if index == int(potion_recipe[potion_step]):
		potion_step += 1
		if sfx != null:
			sfx.play_fx("potion")
		if potion_step >= potion_recipe.size():
			_complete_patient()
	else:
		potion_step = 0
		_add_stress(6.0, "Зелье вспенилось. Рецепт — сначала.")
		if game_state == "playing":
			_toast("Пшшш. Рецепт снова с первого шага.")
	queue_redraw()

func _update_surgery(delta: float) -> void:
	surgery_cursor_x += surgery_direction * 168.0 * delta
	if surgery_cursor_x >= SURGERY_TRACK.size.x - 3.0:
		surgery_cursor_x = SURGERY_TRACK.size.x - 3.0
		surgery_direction = -1.0
	elif surgery_cursor_x <= 3.0:
		surgery_cursor_x = 3.0
		surgery_direction = 1.0

func _surgery_strike() -> void:
	if active_minigame != "surgery":
		return
	if absf(surgery_cursor_x - surgery_target_x) <= surgery_target_width * 0.5:
		surgery_hits += 1
		if sfx != null:
			sfx.play_fx("surgery")
		_toast("Точно. Ещё %d." % (3 - surgery_hits), 0.8)
		surgery_target_width = maxf(23.0, surgery_target_width - 9.0)
		surgery_target_x = clampf(surgery_target_x + rng.randf_range(-46.0, 46.0), 36.0, SURGERY_TRACK.size.x - 36.0)
		if surgery_hits >= 3:
			_complete_patient()
	else:
		_add_stress(5.0, "Скальпель дрогнул. Пациент заметил.")
	queue_redraw()

func _choose_rune(index: int) -> void:
	if not grimoire_ready or active_minigame != "grimoire":
		return
	if index == grimoire_pattern[grimoire_input_index]:
		grimoire_input_index += 1
		if sfx != null:
			sfx.play_fx("rune")
		if grimoire_input_index >= grimoire_pattern.size():
			_complete_patient()
	else:
		_add_stress(7.0, "Руна не та. Гримуар обиделся.")
		if game_state == "playing":
			grimoire_ready = false
			grimoire_clock = 0.0
			grimoire_input_index = 0
			_toast("Запоминай снова. Это не алфавит.", 1.4)
	queue_redraw()

func _complete_patient() -> void:
	if game_state != "playing" or transition_time > 0.0:
		return
	var method: String = str(current_patient.get("method", "potion"))
	active_minigame = ""
	exam_active = false
	resources[method] = max(0, int(resources.get(method, 0)) - 1)
	patients_cured += 1
	coins += 15
	resolved_count += 1
	patient_stress = maxf(0.0, patient_stress - 16.0)
	transition_time = 0.55
	_log_event("Вылечен! Оплата: 15 пуговиц.")
	_toast("Вылечен. Он даже не укусил.", 1.5)
	shake_time = 0.20
	shake_strength = 2.0
	if sfx != null:
		sfx.play_fx("success")
	queue_redraw()

func _add_stress(amount: float, message: String) -> void:
	patient_stress = minf(100.0, patient_stress + amount)
	_log_event(message)
	_toast(message, 1.5)
	shake_time = 0.15
	shake_strength = 1.4
	if sfx != null:
		sfx.play_fx("mistake")
	if patient_stress >= 100.0 and game_state == "playing":
		_lose_patient()

func _lose_patient() -> void:
	if game_state != "playing" or transition_time > 0.0:
		return
	active_minigame = ""
	exam_active = false
	patient_stress = 100.0
	patients_lost += 1
	resolved_count += 1
	transition_time = 0.65
	_log_event("Сбежал. Поставил себе диагноз в сети.")
	_toast("Пациент ушёл. Интернет победил.", 1.5)
	if sfx != null:
		sfx.play_fx("leave")
	queue_redraw()

func _log_event(message: String) -> void:
	log_lines.append(message)
	while log_lines.size() > 7:
		log_lines.pop_front()
	queue_redraw()

func _toast(message: String, duration: float = 1.4) -> void:
	toast_text = message
	toast_time = duration
	queue_redraw()

func action_rect(index: int) -> Rect2:
	return Rect2(ACTION_X, ACTION_Y + float(index) * ACTION_STEP, ACTION_W, ACTION_H)

func action_center(index: int) -> Vector2:
	var rect: Rect2 = action_rect(index)
	return rect.position + rect.size * 0.5

func ingredient_rect(index: int) -> Rect2:
	return Rect2(184.0 + float(index) * 55.0, 91.0, 50.0, 23.0)

func ingredient_center(index: int) -> Vector2:
	var rect: Rect2 = ingredient_rect(index)
	return rect.position + rect.size * 0.5

func rune_rect(index: int) -> Rect2:
	return Rect2(250.0 + float(index % 2) * 68.0, 58.0 + float(int(index / 2)) * 29.0, 48.0, 22.0)

func rune_center(index: int) -> Vector2:
	var rect: Rect2 = rune_rect(index)
	return rect.position + rect.size * 0.5

func surgery_click_position() -> Vector2:
	return Vector2(SURGERY_TRACK.position.x + surgery_target_x, SURGERY_TRACK.position.y + SURGERY_TRACK.size.y * 0.5)

func _draw() -> void:
	var shake_x: float = 0.0
	if shake_time > 0.0:
		shake_x = sin(ambient_time * 61.0) * shake_strength
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), C_VOID, true)
	draw_set_transform(Vector2(shake_x, 0.0), 0.0, Vector2.ONE)
	_draw_room()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud()
	if active_minigame != "":
		_draw_minigame()
	if game_state == "summary":
		_draw_summary()
	elif toast_time > 0.0 and active_minigame == "":
		_draw_toast()

func _draw_room() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, ROOM_H), C_WALL, true)
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 9.0), C_VOID, true)
	for x in range(13, 640, 39):
		draw_line(Vector2(float(x), 10.0), Vector2(float(x + 7), 98.0), C_WALL_LIGHT.darkened(0.45), 1.0)
	for y in range(25, 97, 23):
		for x in range(4, 635, 57):
			draw_line(Vector2(float(x), float(y)), Vector2(float(x + 17), float(y)), Color("#202c27"), 1.0)
	_draw_window(35.0, 18.0, 72.0, 82.0, 0)
	_draw_window(126.0, 18.0, 72.0, 82.0, 1)

	# Тёмная деревянная обшивка и пол.
	draw_rect(Rect2(0.0, 101.0, VIEW_W, 36.0), C_WOOD, true)
	for x in range(0, 640, 35):
		draw_rect(Rect2(float(x), 103.0, 1.0, 34.0), C_WOOD_LIGHT.darkened(0.5), true)
		draw_line(Vector2(float(x + 4), 116.0), Vector2(float(x + 28), 116.0), Color("#49372c"), 1.0)
		draw_rect(Rect2(float(x + 5), 128.0, 2.0, 2.0), C_GOLD.darkened(0.45), true)
	draw_rect(Rect2(0.0, 134.0, VIEW_W, 3.0), C_FRAME, true)

	# Пыль в тёплом луче лампы.
	draw_colored_polygon(PackedVector2Array([Vector2(480.0, 18.0), Vector2(540.0, 18.0), Vector2(475.0, 118.0), Vector2(367.0, 118.0)]), Color(0.83, 0.69, 0.37, 0.075))
	for i in range(10):
		var mote_x: float = 385.0 + float((i * 31 + int(ambient_time * 9.0)) % 125)
		var mote_y: float = 31.0 + float((i * 17 + int(ambient_time * 13.0)) % 76)
		draw_rect(Rect2(mote_x, mote_y, 1.0, 1.0), Color(0.94, 0.79, 0.47, 0.45), true)

	# Ширма, врачебный стул и тумба с пузырьками.
	draw_rect(Rect2(363.0, 46.0, 12.0, 70.0), Color("#28302d"), true)
	draw_rect(Rect2(373.0, 43.0, 4.0, 73.0), C_FRAME, true)
	draw_rect(Rect2(389.0, 44.0, 86.0, 66.0), Color("#26302d"), true)
	draw_rect(Rect2(389.0, 44.0, 86.0, 5.0), C_FRAME, true)
	draw_rect(Rect2(391.0, 50.0, 7.0, 63.0), Color("#566057"), true)
	draw_rect(Rect2(466.0, 50.0, 7.0, 63.0), Color("#566057"), true)
	draw_rect(Rect2(383.0, 102.0, 94.0, 8.0), Color("#544435"), true)
	draw_rect(Rect2(391.0, 110.0, 5.0, 24.0), Color("#47382d"), true)
	draw_rect(Rect2(467.0, 110.0, 5.0, 24.0), Color("#47382d"), true)

	# Лампа и медовая лужа света.
	draw_rect(Rect2(514.0, 0.0, 4.0, 24.0), C_FRAME, true)
	draw_colored_polygon(PackedVector2Array([Vector2(505.0, 22.0), Vector2(530.0, 22.0), Vector2(537.0, 30.0), Vector2(498.0, 30.0)]), Color("#64533a"))
	draw_rect(Rect2(502.0, 26.0, 31.0, 3.0), Color("#e3cb81"), true)
	draw_rect(Rect2(501.0, 29.0, 33.0, 1.0), C_GOLD, true)

	# Дверь и аптечная полка справа.
	draw_rect(Rect2(573.0, 16.0, 59.0, 119.0), Color("#111a19"), true)
	draw_rect(Rect2(579.0, 22.0, 47.0, 113.0), Color("#202a27"), true)
	draw_rect(Rect2(584.0, 28.0, 37.0, 97.0), Color("#16211f"), true)
	draw_rect(Rect2(614.0, 82.0, 3.0, 3.0), C_GOLD, true)
	draw_rect(Rect2(506.0, 87.0, 56.0, 4.0), C_WOOD_LIGHT, true)
	for i in range(4):
		var bx: float = 511.0 + float(i) * 11.0
		draw_rect(Rect2(bx, 74.0, 7.0, 13.0), Color("#47664e"), true)
		draw_rect(Rect2(bx + 2.0, 70.0, 3.0, 5.0), C_PAPER_SHADE, true)
		draw_rect(Rect2(bx + 1.0, 79.0, 5.0, 2.0), Color("#a8bd82"), true)

	# Пациент и его приветствие.
	_draw_monster(Vector2(431.0, 82.0), 1.0, current_patient)
	_draw_speech_bubble()
	if exam_active:
		for i in range(hotspot_positions.size()):
			if not found_hotspots[i]:
				_draw_hotspot(hotspot_positions[i], i)
			else:
				var p: Vector2 = hotspot_positions[i]
				draw_rect(Rect2(p.x - 2.0, p.y - 2.0, 5.0, 5.0), C_GREEN, true)

	draw_rect(Rect2(7.0, 7.0, 132.0, 12.0), Color("#111a18"), true)
	_text(Vector2(12.0, 16.0), "КАБИНЕТ №13", 8, C_GOLD, true)
	draw_line(Vector2(0.0, ROOM_H - 1.0), Vector2(VIEW_W, ROOM_H - 1.0), C_GOLD.darkened(0.35), 1.0)

func _draw_window(x: float, y: float, w: float, h: float, variant: int) -> void:
	var outer := PackedVector2Array([
		Vector2(x, y + h), Vector2(x, y + 18.0), Vector2(x + 7.0, y + 7.0),
		Vector2(x + w * 0.5, y), Vector2(x + w - 7.0, y + 7.0), Vector2(x + w, y + 18.0), Vector2(x + w, y + h)
	])
	draw_colored_polygon(outer, Color("#54443e"))
	var inner := PackedVector2Array([
		Vector2(x + 4.0, y + h - 4.0), Vector2(x + 4.0, y + 18.0), Vector2(x + 11.0, y + 10.0),
		Vector2(x + w * 0.5, y + 4.0), Vector2(x + w - 11.0, y + 10.0), Vector2(x + w - 4.0, y + 18.0), Vector2(x + w - 4.0, y + h - 4.0)
	])
	draw_colored_polygon(inner, Color("#344c4d"))
	draw_rect(Rect2(x + 7.0, y + 25.0, w - 14.0, h - 34.0), Color("#294244"), true)
	# Дождь и чужой силуэт снаружи.
	for i in range(12):
		var rx: float = x + 10.0 + float((i * 13 + int(ambient_time * 27.0)) % int(w - 20.0))
		var ry: float = y + 20.0 + float((i * 19 + int(ambient_time * 52.0)) % int(h - 28.0))
		draw_line(Vector2(rx, ry), Vector2(rx - 2.0, ry + 5.0), Color("#7fa2a1"), 1.0)
	if variant == 0:
		draw_rect(Rect2(x + 20.0, y + 56.0, 8.0, 24.0), Color("#263335"), true)
		draw_rect(Rect2(x + 18.0, y + 50.0, 12.0, 12.0), Color("#202d2f"), true)
		draw_rect(Rect2(x + 20.0, y + 54.0, 2.0, 2.0), C_GREEN, true)
		draw_rect(Rect2(x + 26.0, y + 54.0, 2.0, 2.0), C_GREEN, true)
	else:
		draw_rect(Rect2(x + 43.0, y + 55.0, 8.0, 23.0), Color("#273436"), true)
		draw_rect(Rect2(x + 38.0, y + 49.0, 18.0, 10.0), Color("#202d2f"), true)
		draw_rect(Rect2(x + 41.0, y + 52.0, 2.0, 2.0), C_GOLD, true)
		draw_rect(Rect2(x + 50.0, y + 52.0, 2.0, 2.0), C_GOLD, true)
	# Деревянные переплёты.
	draw_rect(Rect2(x + w * 0.5 - 2.0, y + 14.0, 4.0, h - 18.0), C_FRAME, true)
	draw_rect(Rect2(x + 6.0, y + 52.0, w - 12.0, 3.0), C_FRAME, true)
	draw_rect(Rect2(x - 4.0, y + h - 1.0, w + 8.0, 4.0), C_WOOD_LIGHT, true)
	if fposmod(ambient_time + float(variant) * 3.2, 10.5) < 0.13:
		draw_line(Vector2(x + w * 0.58, y + 17.0), Vector2(x + w * 0.42, y + 40.0), Color("#d6d889"), 2.0)
		draw_line(Vector2(x + w * 0.42, y + 40.0), Vector2(x + w * 0.55, y + 48.0), Color("#d6d889"), 1.0)

func _draw_speech_bubble() -> void:
	var bubble := Rect2(255.0, 14.0, 207.0, 31.0)
	draw_rect(Rect2(bubble.position + Vector2(2.0, 2.0), bubble.size), Color("#090d0d"), true)
	draw_rect(bubble, C_PAPER_SHADE, true)
	draw_rect(Rect2(bubble.position + Vector2(1.0, 1.0), bubble.size - Vector2(2.0, 2.0)), C_PAPER, true)
	draw_colored_polygon(PackedVector2Array([Vector2(426.0, 44.0), Vector2(439.0, 44.0), Vector2(436.0, 51.0)]), C_PAPER)
	var complaint: String = str(current_patient.get("complaint", "МНЕ НУЖЕН ВРАЧ."))
	_draw_wrapped(complaint, Rect2(262.0, 17.0, 192.0, 25.0), 7, C_INK, 2)

func _draw_monster(center: Vector2, scale: float, patient: Dictionary) -> void:
	if patient.is_empty():
		return
	var form: String = str(patient.get("form", "tentacle"))
	var skin: Color = patient.get("skin", Color("#65724e"))
	var shade: Color = skin.darkened(0.32)
	var highlight: Color = skin.lightened(0.22)
	var eye: Color = patient.get("eye", C_GOLD)
	# Тень и ноги.
	_mrect(center, scale, -22.0, 20.0, 44.0, 5.0, Color("#101615"))
	_mrect(center, scale, -12.0, 11.0, 8.0, 15.0, shade)
	_mrect(center, scale, 4.0, 11.0, 8.0, 15.0, shade)
	_mrect(center, scale, -17.0, -4.0, 34.0, 24.0, skin)
	_mrect(center, scale, -14.0, -21.0, 28.0, 21.0, shade)
	_mrect(center, scale, -12.0, -19.0, 24.0, 16.0, skin)
	_mrect(center, scale, -13.0, -4.0, 26.0, 3.0, highlight.darkened(0.1))
	_mrect(center, scale, -21.0, -1.0, 6.0, 17.0, shade)
	_mrect(center, scale, 15.0, -1.0, 6.0, 17.0, shade)

	match form:
		"tentacle":
			_mline(center, scale, -16.0, 4.0, -27.0, 13.0, shade, 4.0)
			_mline(center, scale, -27.0, 13.0, -33.0, 8.0, highlight, 3.0)
			_mline(center, scale, 16.0, 3.0, 27.0, 12.0, shade, 4.0)
			_mline(center, scale, 27.0, 12.0, 34.0, 7.0, highlight, 3.0)
			_mline(center, scale, -10.0, 13.0, -18.0, 22.0, shade, 3.0)
			_mline(center, scale, -18.0, 22.0, -24.0, 18.0, highlight, 2.0)
			_mline(center, scale, 10.0, 13.0, 19.0, 22.0, shade, 3.0)
			_mline(center, scale, 19.0, 22.0, 26.0, 18.0, highlight, 2.0)
			_mrect(center, scale, -2.0, -14.0, 5.0, 5.0, eye)
		"vampire":
			draw_colored_polygon(PackedVector2Array([
				Vector2(center.x - 15.0 * scale, center.y - 1.0 * scale), Vector2(center.x + 15.0 * scale, center.y - 1.0 * scale),
				Vector2(center.x + 23.0 * scale, center.y + 22.0 * scale), Vector2(center.x + 8.0 * scale, center.y + 17.0 * scale),
				Vector2(center.x, center.y + 25.0 * scale), Vector2(center.x - 8.0 * scale, center.y + 17.0 * scale), Vector2(center.x - 23.0 * scale, center.y + 22.0 * scale)
			]), Color("#563c4a"))
			_mrect(center, scale, -17.0, -24.0, 7.0, 9.0, shade)
			_mrect(center, scale, 10.0, -24.0, 7.0, 9.0, shade)
			_mrect(center, scale, -5.0, -2.0, 3.0, 6.0, C_PAPER)
			_mrect(center, scale, 3.0, -2.0, 3.0, 6.0, C_PAPER)
		"skeleton":
			_mrect(center, scale, -15.0, -22.0, 30.0, 21.0, Color("#cfc4a2"))
			_mrect(center, scale, -10.0, -16.0, 5.0, 5.0, Color("#1c2422"))
			_mrect(center, scale, 5.0, -16.0, 5.0, 5.0, Color("#1c2422"))
			_mrect(center, scale, -2.0, -11.0, 4.0, 6.0, Color("#6f6758"))
			for rib in range(3):
				_mline(center, scale, -9.0, 1.0 + float(rib) * 5.0, 9.0, 1.0 + float(rib) * 5.0, Color("#d9cfad"), 2.0)
			_mline(center, scale, -16.0, 1.0, -24.0, 8.0, Color("#cfc4a2"), 3.0)
			_mline(center, scale, 16.0, 1.0, 24.0, 8.0, Color("#cfc4a2"), 3.0)
		"golem":
			_mrect(center, scale, -20.0, -22.0, 40.0, 18.0, shade)
			_mrect(center, scale, -14.0, -18.0, 28.0, 12.0, skin)
			_mrect(center, scale, -17.0, 3.0, 12.0, 12.0, highlight.darkened(0.18))
			_mrect(center, scale, 5.0, 1.0, 13.0, 13.0, shade)
			_mrect(center, scale, -24.0, -4.0, 8.0, 12.0, shade)
			_mrect(center, scale, 18.0, -7.0, 8.0, 13.0, highlight.darkened(0.2))
			_mrect(center, scale, -10.0, -14.0, 5.0, 4.0, eye)
			_mrect(center, scale, 5.0, -14.0, 5.0, 4.0, eye)
		"zombie":
			_mrect(center, scale, -19.0, -5.0, 12.0, 8.0, highlight.darkened(0.12))
			_mrect(center, scale, 15.0, -5.0, 10.0, 20.0, shade)
			_mrect(center, scale, 4.0, -22.0, 8.0, 5.0, Color("#d1bb8d"))
			_mrect(center, scale, -8.0, -14.0, 5.0, 4.0, eye)
			_mrect(center, scale, 5.0, -14.0, 5.0, 4.0, eye)
		"twin":
			_mrect(center, scale, -20.0, -27.0, 19.0, 18.0, shade)
			_mrect(center, scale, 2.0, -27.0, 19.0, 18.0, highlight.darkened(0.1))
			_mrect(center, scale, -15.0, -21.0, 4.0, 4.0, eye)
			_mrect(center, scale, 7.0, -21.0, 4.0, 4.0, eye)
			_mline(center, scale, -18.0, -29.0, -22.0, -35.0, skin, 3.0)
			_mline(center, scale, 17.0, -29.0, 22.0, -34.0, skin, 3.0)
		"ghost":
			_mrect(center, scale, -18.0, -22.0, 36.0, 42.0, Color(0.52, 0.72, 0.68, 0.82))
			draw_colored_polygon(PackedVector2Array([
				Vector2(center.x - 18.0 * scale, center.y + 14.0 * scale), Vector2(center.x - 8.0 * scale, center.y + 23.0 * scale),
				Vector2(center.x, center.y + 15.0 * scale), Vector2(center.x + 10.0 * scale, center.y + 24.0 * scale),
				Vector2(center.x + 18.0 * scale, center.y + 13.0 * scale)
			]), Color(0.52, 0.72, 0.68, 0.82))
		"mummy":
			for stripe in range(4):
				_mline(center, scale, -13.0, -14.0 + float(stripe) * 5.0, 13.0, -11.0 + float(stripe) * 5.0, Color("#e0c990"), 2.0)
			for stripe in range(3):
				_mline(center, scale, -14.0, 3.0 + float(stripe) * 5.0, 13.0, 5.0 + float(stripe) * 5.0, Color("#e0c990"), 2.0)
		"shadow":
			_mrect(center, scale, -19.0, -24.0, 38.0, 51.0, Color("#232531"))
			_mrect(center, scale, -15.0, -18.0, 30.0, 15.0, Color("#30323e"))
			_mline(center, scale, -15.0, 16.0, -23.0, 24.0, Color("#232531"), 4.0)
			_mline(center, scale, 15.0, 16.0, 23.0, 23.0, Color("#232531"), 4.0)
		"wolf":
			_mline(center, scale, -13.0, -20.0, -17.0, -31.0, shade, 6.0)
			_mline(center, scale, 13.0, -20.0, 18.0, -31.0, shade, 6.0)
			_mrect(center, scale, -6.0, -7.0, 14.0, 7.0, shade)
			_mrect(center, scale, -12.0, -15.0, 5.0, 4.0, eye)
			_mrect(center, scale, 7.0, -15.0, 5.0, 4.0, eye)

	if form != "skeleton" and form != "twin" and form != "golem" and form != "zombie" and form != "wolf" and form != "tentacle":
		var eye_count: int = int(patient.get("eyes", 2))
		if eye_count == 1:
			_mrect(center, scale, -2.0, -14.0, 5.0, 5.0, eye)
		else:
			_mrect(center, scale, -10.0, -14.0, 5.0, 4.0, eye)
			_mrect(center, scale, 5.0, -14.0, 5.0, 4.0, eye)
		_mline(center, scale, -5.0, -5.0, 5.0, -5.0, shade, 1.0)
	if form == "tentacle":
		_mrect(center, scale, -6.0, -6.0, 2.0, 2.0, C_PAPER)
	if form == "vampire":
		_mrect(center, scale, -6.0, -10.0, 3.0, 3.0, eye)
		_mrect(center, scale, 4.0, -10.0, 3.0, 3.0, eye)

func _mrect(center: Vector2, scale: float, x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(center.x + x * scale, center.y + y * scale, maxf(1.0, w * scale), maxf(1.0, h * scale)), color, true)

func _mline(center: Vector2, scale: float, x1: float, y1: float, x2: float, y2: float, color: Color, width: float) -> void:
	draw_line(Vector2(center.x + x1 * scale, center.y + y1 * scale), Vector2(center.x + x2 * scale, center.y + y2 * scale), color, maxf(1.0, width * scale), false)

func _draw_hotspot(point: Vector2, index: int) -> void:
	var pulse: float = 1.0 + fposmod(ambient_time * 4.0 + float(index) * 0.6, 1.0) * 2.0
	draw_rect(Rect2(point.x - pulse, point.y - pulse, pulse * 2.0 + 1.0, pulse * 2.0 + 1.0), Color(0.78, 0.95, 0.55, 0.20), true)
	draw_rect(Rect2(point.x - 3.0, point.y - 3.0, 7.0, 7.0), C_GREEN.lightened(0.2), false, 1.0)
	draw_rect(Rect2(point.x - 1.0, point.y - 1.0, 3.0, 3.0), C_GOLD, true)
	draw_line(Vector2(point.x - 5.0, point.y), Vector2(point.x + 5.0, point.y), C_TEXT.darkened(0.2), 1.0)
	draw_line(Vector2(point.x, point.y - 5.0), Vector2(point.x, point.y + 5.0), C_TEXT.darkened(0.2), 1.0)

func _draw_hud() -> void:
	draw_rect(Rect2(0.0, ROOM_H, VIEW_W, VIEW_H - ROOM_H), C_PANEL, true)
	draw_rect(Rect2(0.0, ROOM_H, VIEW_W, 2.0), C_GOLD.darkened(0.48), true)
	_draw_panel(PATIENT_CARD, C_PAPER, C_FRAME)
	_draw_panel(COMPLAINT_CARD, C_PAPER, C_FRAME)
	_draw_panel(BOOK_CARD, C_WOOD, C_GOLD.darkened(0.25))
	_draw_patient_card()
	_draw_complaint_card()
	_draw_book_card()

	_draw_panel(Rect2(255.0, 141.0, 135.0, 14.0), C_WOOD, C_GOLD.darkened(0.2))
	_center_text(Rect2(256.0, 141.0, 133.0, 14.0), "ДЕЙСТВИЯ", 8, C_GOLD, true)
	for i in range(ACTION_LABELS.size()):
		var enabled: bool = _is_action_available(i)
		_draw_button(action_rect(i), ACTION_LABELS[i], enabled)
	if game_state == "summary":
		_draw_button(action_rect(4), "ЕЩЁ СМЕНУ", true, true)

	_draw_status_panels()

func _draw_patient_card() -> void:
	if current_patient.is_empty():
		return
	var portrait := Rect2(10.0, 152.0, 74.0, 49.0)
	draw_rect(portrait, Color("#26302b"), true)
	draw_rect(Rect2(portrait.position + Vector2(1.0, 1.0), portrait.size - Vector2(2.0, 2.0)), Color("#35413a"), true)
	_draw_monster(Vector2(47.0, 178.0), 0.62, current_patient)
	draw_line(Vector2(10.0, 204.0), Vector2(84.0, 204.0), C_FRAME, 1.0)
	_text(Vector2(11.0, 216.0), str(current_patient.get("name", "МОНСТР")), 7, C_INK, true)
	_text(Vector2(11.0, 226.0), str(current_patient.get("tag", "")), 7, C_INK)
	_text(Vector2(11.0, 242.0), "СМЕНА %d" % shift_number, 6, C_MUTED, true)
	for i in range(5):
		var x: float = 12.0 + float(i) * 13.0
		var resolved: bool = i < resolved_count
		var cured: bool = resolved and i < patients_cured
		var pip_color: Color = C_GREEN if cured else (C_RED if resolved else Color("#a69a7a"))
		draw_rect(Rect2(x, 250.0, 9.0, 7.0), pip_color if resolved else C_PAPER_SHADE, true)
		draw_rect(Rect2(x, 250.0, 9.0, 7.0), C_FRAME.darkened(0.1), false, 1.0)

func _draw_complaint_card() -> void:
	_text(Vector2(99.0, 159.0), "ЖАЛОБА", 8, C_INK, true)
	draw_line(Vector2(98.0, 163.0), Vector2(174.0, 163.0), C_FRAME, 1.0)
	var display_text: String = str(current_patient.get("complaint", ""))
	var header: String = "ЖАЛОБА"
	if examined:
		display_text = str(current_patient.get("symptom", ""))
		header = "СИМПТОМ"
	if diagnosis_known:
		display_text = str(current_patient.get("disease", ""))
		header = "ДИАГНОЗ"
	_text(Vector2(99.0, 174.0), header, 6, C_MUTED, true)
	_draw_wrapped(display_text, Rect2(99.0, 177.0, 74.0, 68.0), 7, C_INK, 6)
	if diagnosis_known:
		var method: String = str(current_patient.get("method", ""))
		_text(Vector2(99.0, 257.0), "→ " + GameData.method_label(method), 6, Color("#536449"), true)
	else:
		_text(Vector2(99.0, 257.0), "СЛУШАЙ ВНИМАТЕЛЬНО", 5, C_MUTED)

func _draw_book_card() -> void:
	# Корешок, обложка и латунный уголок.
	draw_rect(Rect2(190.0, 159.0, 50.0, 65.0), Color("#20191b"), true)
	draw_rect(Rect2(194.0, 155.0, 45.0, 66.0), Color("#49343b"), true)
	draw_rect(Rect2(197.0, 158.0, 38.0, 59.0), Color("#563e42"), true)
	draw_rect(Rect2(195.0, 158.0, 4.0, 60.0), C_GOLD.darkened(0.28), true)
	draw_line(Vector2(202.0, 163.0), Vector2(231.0, 163.0), Color("#80635a"), 1.0)
	draw_line(Vector2(202.0, 212.0), Vector2(231.0, 212.0), Color("#80635a"), 1.0)
	if diagnosis_known:
		draw_rect(Rect2(204.0, 169.0, 24.0, 3.0), C_GOLD, true)
		draw_rect(Rect2(204.0, 177.0, 19.0, 2.0), C_PAPER_SHADE, true)
		draw_rect(Rect2(204.0, 183.0, 24.0, 2.0), C_PAPER_SHADE, true)
		_center_text(Rect2(199.0, 188.0, 34.0, 18.0), "№13", 8, C_GOLD, true)
	else:
		_center_text(Rect2(199.0, 172.0, 34.0, 28.0), "КНИГА", 7, C_PAPER, true)
		_center_text(Rect2(199.0, 190.0, 34.0, 25.0), "???", 9, C_GOLD, true)
	draw_rect(Rect2(229.0, 154.0, 9.0, 7.0), C_GOLD, true)
	draw_rect(Rect2(230.0, 215.0, 8.0, 6.0), C_GOLD.darkened(0.2), true)
	_center_text(Rect2(185.0, 227.0, 62.0, 16.0), "КНИГА", 7, C_PAPER, true)
	_center_text(Rect2(185.0, 240.0, 62.0, 18.0), "ПАТОЛОГИЙ", 6, C_PAPER_SHADE)
	_center_text(Rect2(185.0, 254.0, 62.0, 10.0), "КЛИК", 5, C_MUTED)

func _draw_status_panels() -> void:
	_draw_panel(Rect2(394.0, 144.0, 241.0, 31.0), C_PANEL_HI, C_FRAME)
	_text(Vector2(402.0, 156.0), "СТРЕСС", 7, C_TEXT, true)
	_text(Vector2(402.0, 167.0), "%02d%%" % int(round(patient_stress)), 7, C_TEXT)
	var bar := Rect2(445.0, 151.0, 179.0, 15.0)
	draw_rect(bar, Color("#111718"), true)
	draw_rect(Rect2(bar.position + Vector2(2.0, 2.0), bar.size - Vector2(4.0, 4.0)), Color("#3b2b2e"), true)
	var fill_width: float = (bar.size.x - 4.0) * clampf(patient_stress / 100.0, 0.0, 1.0)
	var stress_color: Color = C_GREEN if patient_stress < 55.0 else (C_GOLD if patient_stress < 80.0 else C_RED)
	if fill_width > 0.0:
		draw_rect(Rect2(bar.position.x + 2.0, bar.position.y + 2.0, fill_width, bar.size.y - 4.0), stress_color, true)
	for i in range(5):
		var tick_x: float = bar.position.x + 2.0 + float(i) * 35.0
		draw_rect(Rect2(tick_x, bar.position.y + 4.0, 1.0, 7.0), Color("#25292a"), true)

	_draw_panel(Rect2(394.0, 179.0, 241.0, 27.0), C_PANEL_HI, C_FRAME)
	_text(Vector2(402.0, 196.0), "ЗАПАСЫ", 7, C_TEXT, true)
	_draw_resource(467.0, 184.0, "З", "potion", Color("#8bac67"))
	_draw_resource(523.0, 184.0, "И", "surgery", Color("#c7b49a"))
	_draw_resource(580.0, 184.0, "Р", "grimoire", Color("#b08cae"))

	_draw_panel(Rect2(394.0, 210.0, 241.0, 57.0), Color("#151b1d"), C_FRAME)
	_text(Vector2(402.0, 221.0), "ЖУРНАЛ", 7, C_GOLD, true)
	_text(Vector2(576.0, 221.0), "M  ЗВУК", 6, C_MUTED)
	draw_line(Vector2(400.0, 224.0), Vector2(629.0, 224.0), C_FRAME.darkened(0.18), 1.0)
	var start: int = maxi(0, log_lines.size() - 4)
	var visible_index: int = 0
	for i in range(start, log_lines.size()):
		var line: String = log_lines[i]
		if line.length() > 49:
			line = line.substr(0, 46) + "..."
		_text(Vector2(401.0, 235.0 + float(visible_index) * 9.0), line, 6, C_MUTED if visible_index < 3 else C_TEXT)
		visible_index += 1
	_text(Vector2(402.0, 264.0), "ЛЕЧЕНИЯ %d/5  ·  %d ПУГОВИЦ" % [patients_cured, coins], 6, C_GREEN)

func _draw_resource(x: float, y: float, icon: String, method: String, color: Color) -> void:
	draw_rect(Rect2(x, y, 15.0, 15.0), Color("#182021"), true)
	draw_rect(Rect2(x + 2.0, y + 2.0, 11.0, 11.0), color.darkened(0.18), true)
	if method == "potion":
		draw_rect(Rect2(x + 5.0, y + 3.0, 5.0, 2.0), C_PAPER_SHADE, true)
		draw_rect(Rect2(x + 4.0, y + 5.0, 7.0, 6.0), color, true)
	elif method == "surgery":
		draw_line(Vector2(x + 4.0, y + 11.0), Vector2(x + 11.0, y + 4.0), C_PAPER, 2.0)
		draw_rect(Rect2(x + 3.0, y + 10.0, 4.0, 3.0), C_GOLD, true)
	else:
		draw_line(Vector2(x + 4.0, y + 4.0), Vector2(x + 11.0, y + 11.0), C_PAPER, 1.0)
		draw_line(Vector2(x + 11.0, y + 4.0), Vector2(x + 4.0, y + 11.0), C_PAPER, 1.0)
	_text(Vector2(x + 20.0, y + 11.0), "%s %d" % [icon, int(resources.get(method, 0))], 7, C_TEXT)

func _is_action_available(index: int) -> bool:
	if game_state != "playing" or active_minigame != "" or transition_time > 0.0:
		return false
	if index == 0:
		return not examined
	if index == 1:
		return examined
	return diagnosis_known

func _draw_button(rect: Rect2, label: String, enabled: bool, force_highlight: bool = false) -> void:
	var hovered: bool = rect.has_point(mouse_position) and enabled
	var outer: Color = C_FRAME if enabled else Color("#4c4940")
	var fill: Color = Color("#344d43") if enabled else Color("#252c29")
	if hovered or force_highlight:
		fill = Color("#526c55")
		outer = C_GOLD
	draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0, rect.size.x, rect.size.y), Color("#0d1111"), true)
	draw_rect(rect, outer, true)
	draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, 2.0)), fill, true)
	draw_line(Vector2(rect.position.x + 4.0, rect.position.y + 2.0), Vector2(rect.position.x + rect.size.x - 4.0, rect.position.y + 2.0), Color("#71806c") if enabled else Color("#393e39"), 1.0)
	var text_color: Color = C_TEXT if enabled else Color("#7c7a68")
	_center_text(rect, label, 7, text_color, enabled)
	if hovered:
		draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0, 2.0, rect.size.y - 4.0), C_GOLD, true)

func _draw_panel(rect: Rect2, fill: Color, border: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size), C_VOID, true)
	draw_rect(rect, border, true)
	draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, 2.0)), fill, true)
	draw_rect(Rect2(rect.position.x + 3.0, rect.position.y + 3.0, 2.0, 2.0), C_GOLD.darkened(0.48), true)

func _draw_minigame() -> void:
	if active_minigame == "potion":
		_draw_panel(Rect2(174.0, 21.0, 292.0, 110.0), Color("#202525"), C_GOLD.darkened(0.16))
		_center_text(Rect2(181.0, 25.0, 278.0, 15.0), "АЛХИМИЯ · РЕЦЕПТ", 8, C_GOLD, true)
		_text(Vector2(194.0, 48.0), "ПО ПОРЯДКУ", 6, C_MUTED)
		for i in range(potion_recipe.size()):
			var box := Rect2(255.0 + float(i) * 42.0, 35.0, 30.0, 25.0)
			draw_rect(box, C_FRAME if i == potion_step else Color("#4a4740"), true)
			draw_rect(Rect2(box.position + Vector2(1.0, 1.0), box.size - Vector2(2.0, 2.0)), Color("#1a2020"), true)
			var ingredient_index: int = int(potion_recipe[i])
			_draw_ingredient_icon(Vector2(box.position.x + 15.0, box.position.y + 12.0), ingredient_index, 1.0)
			_text(Vector2(box.position.x + 10.0, box.position.y + 22.0), str(i + 1), 5, C_TEXT)
			if i < potion_recipe.size() - 1:
				_center_text(Rect2(box.position.x + 30.0, 37.0, 12.0, 20.0), "›", 9, C_GOLD, true)
		for i in range(GameData.INGREDIENTS.size()):
			var rect: Rect2 = ingredient_rect(i)
			_draw_button(rect, GameData.INGREDIENTS[i], true, rect.has_point(mouse_position))
			_draw_ingredient_icon(Vector2(rect.position.x + 8.0, rect.position.y + 11.0), i, 0.58)
		_text(Vector2(184.0, 125.0), "ШАГ %d / %d" % [mini(potion_step + 1, potion_recipe.size()), potion_recipe.size()], 6, C_TEXT)
	elif active_minigame == "surgery":
		_draw_panel(Rect2(158.0, 28.0, 324.0, 91.0), Color("#202525"), C_GOLD.darkened(0.16))
		_center_text(Rect2(165.0, 33.0, 310.0, 15.0), "ХИРУРГИЯ · НЕ ДЫШИ", 8, C_GOLD, true)
		_center_text(Rect2(166.0, 49.0, 308.0, 13.0), "ПОПАДАНИЯ  %d / 3" % surgery_hits, 7, C_TEXT)
		draw_rect(SURGERY_TRACK, Color("#101617"), true)
		draw_rect(Rect2(SURGERY_TRACK.position.x + 2.0, SURGERY_TRACK.position.y + 2.0, SURGERY_TRACK.size.x - 4.0, SURGERY_TRACK.size.y - 4.0), Color("#36403b"), true)
		var zone_x: float = SURGERY_TRACK.position.x + surgery_target_x - surgery_target_width * 0.5
		draw_rect(Rect2(zone_x, SURGERY_TRACK.position.y + 2.0, surgery_target_width, SURGERY_TRACK.size.y - 4.0), Color("#89a968"), true)
		draw_rect(Rect2(SURGERY_TRACK.position.x + surgery_cursor_x - 2.0, SURGERY_TRACK.position.y - 5.0, 4.0, SURGERY_TRACK.size.y + 10.0), C_GOLD, true)
		_center_text(Rect2(164.0, 102.0, 312.0, 13.0), "КЛИК / ПРОБЕЛ — В ЗЕЛЁНОЙ ЗОНЕ", 6, C_MUTED)
	elif active_minigame == "grimoire":
		_draw_panel(Rect2(190.0, 20.0, 260.0, 110.0), Color("#202025"), Color("#836688"))
		_center_text(Rect2(196.0, 24.0, 248.0, 15.0), "ГРИМУАР · ЗАПОМНИ", 8, C_GOLD, true)
		var flash_index: int = -1
		if not grimoire_ready and grimoire_pattern.size() > 0:
			var phase: float = fposmod(grimoire_clock, 0.48)
			flash_index = int(grimoire_clock / 0.48)
			if phase > 0.30:
				flash_index = -1
		for i in range(4):
			var rect: Rect2 = rune_rect(i)
			var lit: bool = i == flash_index
			var border: Color = C_GOLD if lit else Color("#655a66")
			draw_rect(rect, border, true)
			draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, 2.0)), Color("#24242a") if not lit else Color("#65503b"), true)
			_draw_rune(i, rect.position + rect.size * 0.5, C_GOLD if lit else Color("#a79eb0"))
		if grimoire_ready:
			_center_text(Rect2(195.0, 112.0, 250.0, 12.0), "ПОВТОРИ  %d / 4" % grimoire_input_index, 6, C_TEXT)
		else:
			_center_text(Rect2(195.0, 112.0, 250.0, 12.0), "СЛЕДИ ЗА СВЕЧЕНИЕМ", 6, C_MUTED)

func _draw_ingredient_icon(center: Vector2, index: int, scale: float) -> void:
	var color: Color = GameData.INGREDIENT_COLORS[index]
	match index:
		0:
			draw_rect(Rect2(center.x - 4.0 * scale, center.y - 5.0 * scale, 8.0 * scale, 10.0 * scale), color, true)
			draw_rect(Rect2(center.x - 2.0 * scale, center.y - 7.0 * scale, 4.0 * scale, 3.0 * scale), C_PAPER_SHADE, true)
		1:
			draw_rect(Rect2(center.x - 4.0 * scale, center.y - 3.0 * scale, 8.0 * scale, 7.0 * scale), color, true)
			draw_rect(Rect2(center.x - 2.0 * scale, center.y - 5.0 * scale, 4.0 * scale, 3.0 * scale), color.lightened(0.2), true)
		2:
			draw_rect(Rect2(center.x - 5.0 * scale, center.y - 4.0 * scale, 10.0 * scale, 8.0 * scale), color, true)
			draw_rect(Rect2(center.x - 2.0 * scale, center.y - 2.0 * scale, 4.0 * scale, 4.0 * scale), Color("#4b4136"), true)
		3:
			draw_rect(Rect2(center.x - 5.0 * scale, center.y - 3.0 * scale, 10.0 * scale, 7.0 * scale), color, true)
			draw_rect(Rect2(center.x - 3.0 * scale, center.y - 5.0 * scale, 5.0 * scale, 2.0 * scale), color.lightened(0.2), true)
		4:
			draw_rect(Rect2(center.x - 5.0 * scale, center.y - 5.0 * scale, 10.0 * scale, 10.0 * scale), color, true)
			draw_line(Vector2(center.x - 4.0 * scale, center.y + 3.0 * scale), Vector2(center.x + 4.0 * scale, center.y - 3.0 * scale), Color("#746f61"), maxf(1.0, scale))

func _draw_rune(index: int, center: Vector2, color: Color) -> void:
	match index:
		0:
			draw_line(center + Vector2(0.0, -7.0), center + Vector2(-6.0, 0.0), color, 2.0)
			draw_line(center + Vector2(-6.0, 0.0), center + Vector2(0.0, 7.0), color, 2.0)
			draw_line(center + Vector2(0.0, 7.0), center + Vector2(6.0, 0.0), color, 2.0)
			draw_line(center + Vector2(6.0, 0.0), center + Vector2(0.0, -7.0), color, 2.0)
		1:
			draw_line(center + Vector2(-6.0, -6.0), center + Vector2(0.0, -1.0), color, 2.0)
			draw_line(center + Vector2(0.0, -1.0), center + Vector2(-4.0, 6.0), color, 2.0)
			draw_line(center + Vector2(0.0, -1.0), center + Vector2(6.0, -6.0), color, 2.0)
		2:
			draw_rect(Rect2(center.x - 5.0, center.y - 5.0, 10.0, 10.0), color, false, 2.0)
			draw_rect(Rect2(center.x - 1.0, center.y - 1.0, 3.0, 3.0), color, true)
		3:
			draw_line(center + Vector2(-6.0, -6.0), center + Vector2(0.0, 6.0), color, 2.0)
			draw_line(center + Vector2(0.0, 6.0), center + Vector2(6.0, -6.0), color, 2.0)
			draw_line(center + Vector2(-4.0, 0.0), center + Vector2(4.0, 0.0), color, 2.0)

func _draw_summary() -> void:
	_draw_panel(Rect2(185.0, 20.0, 270.0, 112.0), Color("#222825"), C_GOLD)
	_center_text(Rect2(192.0, 26.0, 256.0, 17.0), "ИТОГ НОЧНОЙ СМЕНЫ", 9, C_GOLD, true)
	draw_line(Vector2(198.0, 46.0), Vector2(442.0, 46.0), C_FRAME, 1.0)
	_center_text(Rect2(194.0, 51.0, 252.0, 15.0), "ВЫЛЕЧЕНО  %d / 5" % patients_cured, 9, C_TEXT, true)
	_center_text(Rect2(194.0, 67.0, 252.0, 14.0), "СБЕЖАЛО  %d" % patients_lost, 7, C_MUTED)
	_center_text(Rect2(194.0, 82.0, 252.0, 15.0), _shift_rank(), 8, C_GREEN, true)
	_center_text(Rect2(194.0, 101.0, 252.0, 17.0), "ПОЛУЧЕНО  %d ПУГОВИЦ" % coins, 7, C_GOLD)
	_center_text(Rect2(194.0, 119.0, 252.0, 10.0), "БУХГАЛТЕР-ПРИЗРАК УЖЕ ЖДЁТ", 5, C_MUTED)

func _shift_rank() -> String:
	if patients_cured >= 5:
		return "СТАРШИЙ ВЕДЬМОВРАЧ"
	if patients_cured >= 4:
		return "НОЧНОЙ ТЕРАПЕВТ"
	if patients_cured >= 3:
		return "СТАЖЁР ПО УЖАСАМ"
	return "ВЫГОВОР ОТ ПРИЗРАКА"

func _draw_toast() -> void:
	var rect := Rect2(205.0, 113.0, 270.0, 18.0)
	draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size), Color("#080e0e"), true)
	draw_rect(rect, C_FRAME, true)
	draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, 2.0)), Color("#182120"), true)
	_center_text(rect, toast_text, 7, C_TEXT, true)

func _wrap_text(text: String, max_chars: int, max_lines: int) -> PackedStringArray:
	var result := PackedStringArray()
	var line: String = ""
	var words: PackedStringArray = text.split(" ", false)
	for word in words:
		if line.is_empty():
			line = word
		elif line.length() + word.length() + 1 <= max_chars:
			line += " " + word
		else:
			result.append(line)
			line = word
	if not line.is_empty():
		result.append(line)
	if result.size() > max_lines:
		while result.size() > max_lines:
			result.remove_at(result.size() - 1)
		if result.size() > 0 and result[result.size() - 1].length() > 2:
			result[result.size() - 1] = result[result.size() - 1].substr(0, result[result.size() - 1].length() - 1) + "…"
	return result

func _draw_wrapped(text: String, rect: Rect2, font_size: int, color: Color, max_lines: int) -> void:
	var max_chars: int = maxi(1, int(rect.size.x / (float(font_size) * 0.62)))
	var lines: PackedStringArray = _wrap_text(text, max_chars, max_lines)
	for i in range(lines.size()):
		_text(Vector2(rect.position.x, rect.position.y + float(font_size + 2) + float(i) * float(font_size + 2)), lines[i], font_size, color)

func _text(position: Vector2, value: String, font_size: int = 8, color: Color = C_TEXT, bold: bool = false) -> void:
	var font: Font = pixel_font_bold if bold and pixel_font_bold != null else pixel_font
	if font == null:
		font = get_theme_default_font()
	if font != null:
		draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _center_text(rect: Rect2, value: String, font_size: int, color: Color, bold: bool = false) -> void:
	var estimated_width: float = float(value.length()) * float(font_size) * 0.60
	var x: float = rect.position.x + (rect.size.x - estimated_width) * 0.5
	var baseline: float = rect.position.y + (rect.size.y + float(font_size) * 0.55) * 0.5
	_text(Vector2(x, baseline), value, font_size, color, bold)
