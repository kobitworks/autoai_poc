class_name ShadowAudioManager
extends Node

var player: AudioStreamPlayer
var level := 0.7

func _ensure_player() -> void:
	if player != null:
		return
	player = AudioStreamPlayer.new()
	add_child(player)

func set_level(linear: float) -> void:
	level = clampf(linear, 0.0, 1.0)
	_ensure_player()
	player.volume_db = -80.0 if level <= 0.001 else linear_to_db(level)

func play_sfx(kind: String) -> void:
	if level <= 0.001:
		return
	_ensure_player()
	var frequency := float({
		"ui": 520.0,
		"move": 360.0,
		"safe": 620.0,
		"info": 880.0,
		"danger": 220.0,
		"spotted": 140.0,
		"clear": 740.0,
		"fail": 170.0
	}.get(kind, 440.0))
	var duration := 0.08
	if kind == "clear":
		duration = 0.18
	elif kind == "spotted" or kind == "fail":
		duration = 0.15
	player.stream = _tone(frequency, duration)
	player.play()

func _tone(frequency: float, duration: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := maxi(1, int(float(mix_rate) * duration))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var envelope := 1.0 - float(i) / float(frames)
		var sample := int(sin(TAU * frequency * float(i) / float(mix_rate)) * 9000.0 * envelope)
		bytes.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = bytes
	return wav
