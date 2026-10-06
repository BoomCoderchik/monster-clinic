extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const METHOD_ACTION: Dictionary = {"potion": 2, "surgery": 3, "grimoire": 4}

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_shift_generator()
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	var game: Control = packed.instantiate() as Control
	root.add_child(game)
	await process_frame
	_check(game.pixel_font != null and game.pixel_font_bold != null, "pixel fonts are loaded")

	# Клавиши 1–5, ПРОБЕЛ и M приходят в _gui_input только при фокусе на сцене.
	_check(game.has_focus(), "scene takes focus for keyboard control")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_1
	key_event.physical_keycode = KEY_1
	key_event.pressed = true
	Input.parse_input_event(key_event)
	await process_frame
	_check(game.exam_active, "key 1 starts the examination")

	game.start_shift(7319)
	for patient_number in range(5):
		_check(game.game_state == "playing", "patient %d: shift is active" % (patient_number + 1))
		var patient: Dictionary = game.current_patient
		var method: String = str(patient["method"])
		var stress_before: float = game.patient_stress

		# The book cannot diagnose before the three-point examination.
		game._handle_game_click(game.action_center(1))
		_check(not game.diagnosis_known, "patient %d: diagnosis is locked before exam" % (patient_number + 1))
		game._handle_game_click(game.action_center(0))
		_check(game.exam_active, "patient %d: examination starts" % (patient_number + 1))
		for point in game.hotspot_positions.duplicate():
			game._handle_game_click(point)
		_check(game.examined, "patient %d: three hotspots finish exam" % (patient_number + 1))
		_check(game.patient_stress < stress_before + 5.0, "patient %d: accurate exam is not punished" % (patient_number + 1))
		game._handle_game_click(game.action_center(1))
		_check(game.diagnosis_known, "patient %d: book reveals diagnosis" % (patient_number + 1))

		# One deliberately wrong department confirms the stress feedback, then use the correct one.
		var wrong_method: String = "surgery" if method != "surgery" else "potion"
		var wrong_stress: float = game.patient_stress
		game._handle_game_click(game.action_center(int(METHOD_ACTION[wrong_method])))
		_check(game.patient_stress > wrong_stress, "patient %d: wrong treatment raises stress" % (patient_number + 1))
		game._handle_game_click(game.action_center(int(METHOD_ACTION[method])))
		_check(game.active_minigame == method, "patient %d: correct method opens its minigame" % (patient_number + 1))

		if method == "potion":
			var recipe: Array = patient["recipe"]
			for ingredient in recipe:
				game._handle_game_click(game.ingredient_center(int(ingredient)))
		elif method == "surgery":
			for hit in range(3):
				game.surgery_cursor_x = game.surgery_target_x
				game._handle_game_click(game.surgery_click_position())
		else:
			var frames: int = 0
			while not game.grimoire_ready and frames < 600:
				await process_frame
				frames += 1
			_check(game.grimoire_ready, "patient %d: rune pattern completes" % (patient_number + 1))
			var pattern: Array = game.grimoire_pattern.duplicate()
			for rune in pattern:
				game._handle_game_click(game.rune_center(int(rune)))

		_check(game.patients_cured == patient_number + 1, "patient %d: minigame cures patient" % (patient_number + 1))
		if patient_number < 4:
			var wait_frames: int = 0
			while game.transition_time > 0.0 and wait_frames < 120:
				await process_frame
				wait_frames += 1
			_check(game.current_patient.get("name", "") != patient.get("name", ""), "patient %d: next patient arrives" % (patient_number + 1))

	var final_wait_frames: int = 0
	while game.transition_time > 0.0 and final_wait_frames < 120:
		await process_frame
		final_wait_frames += 1
	_check(game.game_state == "summary", "full five-patient shift reaches summary")
	_check(game.patients_cured == 5, "perfect shift cures all five")
	_check(game.patients_lost == 0, "perfect shift has no escapes")
	_check(game.coins == 75, "perfect shift pays 75 buttons")
	_check(game.resources["potion"] + game.resources["surgery"] + game.resources["grimoire"] == 1, "two of each supply fund five treatments")
	game.queue_free()
	await process_frame
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _test_shift_generator() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for run in range(30):
		var shift: Array[int] = GameData.make_shift(rng)
		_check(shift.size() == 5, "shift %d: exactly five patients" % run)
		var unique: Dictionary = {}
		var counts: Dictionary = {"potion": 0, "surgery": 0, "grimoire": 0}
		for patient_id in shift:
			unique[patient_id] = true
			var method: String = str(GameData.PATIENTS[patient_id]["method"])
			counts[method] = int(counts[method]) + 1
		_check(unique.size() == 5, "shift %d: no duplicate patients" % run)
		_check(int(counts["potion"]) <= 2 and int(counts["surgery"]) <= 2 and int(counts["grimoire"]) <= 2, "shift %d: supplies are balanced" % run)
		_check(int(counts["potion"]) >= 1 and int(counts["surgery"]) >= 1 and int(counts["grimoire"]) >= 1, "shift %d: demonstrates all three treatments" % run)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)
