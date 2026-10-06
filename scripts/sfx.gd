extends Node

const SAMPLE_RATE: int = 22050

var _players: Array[AudioStreamPlayer] = []
var _samples: Dictionary = {}
var _next_player: int = 0
var _muted: bool = false

func _ready() -> void:
	for i in range(5):
		var player := AudioStreamPlayer.new()
		player.volume_db = -13.0
		add_child(player)
		_players.append(player)
	_samples["click"] = _make_tone(580.0, 0.045, 1)
	_samples["inspect"] = _make_tone(390.0, 0.095, 0)
	_samples["mistake"] = _make_tone(155.0, 0.13, 1)
	_samples["potion"] = _make_tone(510.0, 0.11, 0)
	_samples["surgery"] = _make_tone(245.0, 0.08, 1)
	_samples["rune"] = _make_tone(760.0, 0.16, 0)
	_samples["success"] = _make_tone(900.0, 0.28, 0)
	_samples["leave"] = _make_tone(120.0, 0.22, 1)

func set_muted(value: bool) -> void:
	_muted = value
	if _muted:
		for player in _players:
			player.stop()

func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null
	_samples.clear()

func play_fx(effect: String) -> void:
	if _muted or _players.is_empty() or not _samples.has(effect):
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _samples[effect] as AudioStream
	player.pitch_scale = randf_range(0.96, 1.04)
	player.play()

func _make_tone(frequency: float, duration: float, shape: int) -> AudioStreamWAV:
	var frame_count: int = int(float(SAMPLE_RATE) * duration)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for i in range(frame_count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var phase: float = TAU * frequency * t
		var wave: float = sin(phase)
		if shape == 1:
			wave = 1.0 if sin(phase) >= 0.0 else -1.0
		var attack: float = clampf(float(i) / maxf(1.0, float(SAMPLE_RATE) * 0.008), 0.0, 1.0)
		var release: float = clampf(float(frame_count - i) / maxf(1.0, float(SAMPLE_RATE) * 0.055), 0.0, 1.0)
		var sample_value: int = int(clampf(wave * attack * release * 6800.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, sample_value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
