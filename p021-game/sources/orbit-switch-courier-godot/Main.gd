extends Control

# GAME-069 / GAME-G030 Orbit Switch Courier
const BUILD_ID := "GAME-069-20261011"
const CHILD_ID := "GAME-G030"
const PLAY_TIME := 90.0
const CARGO_TIME := 16.0
const SAVE_PATH := "user://orbit-switch-best.txt"
const SWITCH_WINDOW := 0.19
# GAME-076: Larger touch window improves delivery at lower frame rates on tablet displays.
const HUB_WINDOW := 0.23

const ORBIT_SPEEDS := [1.12, -0.94, 0.79]
const SWITCH_ANGLES := [0.35, 2.50, 4.50, 5.72]
const SWITCH_PAIRS := [[0, 1], [1, 2], [0, 1], [1, 2]]
const HUB_ANGLES := [1.48, 3.56, 5.20]
const HUB_NAMES := ["SCARLET / SQUARE", "CYAN / TRIANGLE", "GOLD / CIRCLE"]
const HUB_SHORT := ["SQUARE", "TRIANGLE", "CIRCLE"]
const HUB_COLORS := [Color("#ff6b81"), Color("#42d9ee"), Color("#ffd166")]
const ROUTE_NAMES := ["STARTER", "RUSH", "NIGHT", "ACE"]
# GAME-076 read-only display stress fixture, enabled only by ?qa=1&cue_stress=1.
const QA_LONG_CUE := "配達成功・作業を継続できます / ROUTE NIGHT→ACE / DELIVERY CONFIRMED / NEXT ACTION: 画面のTAP NOW表示と目標HUBを確かめて、安全なタイミングでタップしてください / THIS EXTRA-LONG TEST STATUS MUST STAY INSIDE THE BANNER."

var ui_font: Font
var rng := RandomNumberGenerator.new()
var state := "intro"
var qa_mode := false
var qa_cue_stress := false
var sound_on := true
# Logical Godot units per visible browser CSS pixel; recomputed on resize.
var ui_scale := 1.0

var orbit_index := 1
var orbit_angle := 0.0
var time_left := PLAY_TIME
var cargo_target := 0
var cargo_left := CARGO_TIME
var energy := 3
var deliveries := 0
var streak := 0
var score := 0
var best_score := 0
var action_text := "TAP / SPACE でスタート"
var feedback_text := "交差点で軌道を切替え、荷物と同じ記号のHUBへ届けよう。"
var flash_good := 0.0
var flash_bad := 0.0
var cue_clock := 0.0
var cue_text := ""
var cue_good := true
var result_clock := 0.0
var bridge_clock := 0.0
var elapsed := 0.0
# Beginner timing assistance: forgive the first out-of-window tap before any delivery.
var novice_miss_guard_used := false
var last_action_angle := -99.0
# Ignore a browser-emulated second event for the same physical tap/click.
var last_pointer_down_msec: int = -100000
var trail: Array[Vector2] = []
var sparks: Array[Dictionary] = []

var field_rect := Rect2()
var info_rect := Rect2()
var sound_rect := Rect2()
var hub_rect := Rect2()
var hud_rect := Rect2()
var retry_rect := Rect2()
# GAME-076: read-only rectangles of actually rendered action/guide surfaces for CI.
var action_card_rect := Rect2()
var help_guide_rect := Rect2()

var audio_player: AudioStreamPlayer
var tone_switch: AudioStreamWAV
var tone_delivery: AudioStreamWAV
var tone_error: AudioStreamWAV
var tone_result: AudioStreamWAV

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_load_font()
	_update_ui_scale()
	_setup_audio()
	_load_best()
	if OS.get_name() == "Web":
		qa_mode = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true))
		qa_cue_stress = qa_mode and bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('cue_stress') === '1'", true))
	rng.seed = 69030 if qa_mode else int(Time.get_unix_time_from_system())
	_reset_round(false)
	grab_focus()
	set_process(true)
	queue_redraw()

func _load_font() -> void:
	var loaded: Resource = load("res://fonts/NotoSansJP.ttf")
	ui_font = loaded as Font if loaded is Font else ThemeDB.fallback_font

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	tone_switch = _make_tone(620.0, 0.16, 0.12)
	tone_delivery = _make_chord([660.0, 880.0, 1100.0], 0.24, 0.16)
	tone_error = _make_chord([180.0, 145.0], 0.16, 0.12)
	tone_result = _make_chord([523.25, 659.25, 783.99, 1046.5], 0.42, 0.17)

func _make_tone(freq: float, duration: float, amplitude: float) -> AudioStreamWAV:
	return _make_chord([freq], duration, amplitude)

func _make_chord(freqs: Array, duration: float, amplitude: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := pow(1.0 - float(i) / maxf(1.0, float(frames)), 1.35)
		var wave := 0.0
		for f in freqs:
			wave += sin(TAU * float(f) * t)
		wave /= maxf(1.0, float(freqs.size()))
		var sample := int(clampf(wave * env * amplitude, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

func _play(stream: AudioStreamWAV) -> void:
	if not sound_on or stream == null:
		return
	audio_player.stream = stream
	audio_player.play()

func _load_best() -> void:
	if OS.get_name() == "Web":
		var raw: Variant = JavaScriptBridge.eval("window.localStorage.getItem('p021-g030-best') || '0'", true)
		best_score = maxi(0, int(str(raw)))
	elif FileAccess.file_exists(SAVE_PATH):
		best_score = maxi(0, int(FileAccess.get_file_as_string(SAVE_PATH)))

func _save_best() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.localStorage.setItem('p021-g030-best','%d')" % best_score, true)
	else:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(str(best_score))

func _reset_round(to_intro: bool = true) -> void:
	state = "intro" if to_intro else "intro"
	orbit_index = 1
	orbit_angle = 0.18
	time_left = PLAY_TIME
	cargo_left = CARGO_TIME
	energy = 3
	novice_miss_guard_used = false
	deliveries = 0
	streak = 0
	score = 0
	elapsed = 0.0
	result_clock = 0.0
	flash_good = 0.0
	flash_bad = 0.0
	cue_clock = 0.0
	cue_text = ""
	trail.clear()
	sparks.clear()
	action_text = "TAP / SPACE でスタート"
	feedback_text = "交差点で軌道を切替え、荷物と同じ記号のHUBへ届けよう。"
	cargo_target = 0 if qa_mode else rng.randi_range(0, 2)
	queue_redraw()
	_update_debug_bridge()

func _start_game() -> void:
	state = "playing"
	action_text = "NEXT WINDOW を狙え"
	feedback_text = "TAP / SPACE は1アクション。交差点なら乗換、HUBなら配達。"
	time_left = PLAY_TIME
	cargo_left = CARGO_TIME
	queue_redraw()
	_update_debug_bridge()

func _process(delta: float) -> void:
	elapsed += delta
	bridge_clock += delta
	flash_good = maxf(0.0, flash_good - delta * 2.2)
	flash_bad = maxf(0.0, flash_bad - delta * 2.6)
	cue_clock = maxf(0.0, cue_clock - delta)
	if state == "result":
		result_clock += delta
		_process_sparks(delta)
	elif state == "playing":
		time_left = maxf(0.0, time_left - delta)
		cargo_left = maxf(0.0, cargo_left - delta)
		orbit_angle = wrapf(orbit_angle + float(ORBIT_SPEEDS[orbit_index]) * delta, 0.0, TAU)
		if cargo_left <= 0.0:
			_lose_energy("TIME OUT — 配送期限切れ")
		if time_left <= 0.0 and state == "playing":
			_finish_game("TIME UP")
	_process_sparks(delta)
	if qa_mode and OS.get_name() == "Web":
		_process_qa_command()
	if bridge_clock >= (0.025 if qa_mode else 0.18):
		bridge_clock = 0.0
		_update_debug_bridge()
	queue_redraw()

func _process_sparks(delta: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		var p: Dictionary = sparks[i]
		p["life"] = float(p["life"]) - delta
		p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
		p["vel"] = Vector2(p["vel"]) * 0.97
		sparks[i] = p
		if float(p["life"]) <= 0.0:
			sparks.remove_at(i)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_ui_scale()
		queue_redraw()
		call_deferred("_update_debug_bridge")

func _angle_distance(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))

func _combo_multiplier() -> int:
	if streak >= 5:
		return 3
	if streak >= 3:
		return 2
	return 1

# GAME-075: progression is driven by actual deliveries, not QA commands.
func _mission_tier() -> int:
	if deliveries >= 6:
		return 3
	if deliveries >= 3:
		return 2
	if deliveries >= 1:
		return 1
	return 0

func _mission_name() -> String:
	return str(ROUTE_NAMES[_mission_tier()])

func _cargo_limit() -> float:
	match _mission_tier():
		3: return 10.0
		2: return 12.0
		1: return 14.0
		_: return CARGO_TIME

func _route_color() -> Color:
	match _mission_tier():
		3: return Color("#ffd166")
		2: return Color("#bc91ff")
		1: return Color("#55e3c7")
		_: return Color("#1e5772")

func _visible_cue() -> String:
	# Never touches physics, route, score or player progress.
	return QA_LONG_CUE if qa_cue_stress else cue_text

# GAME-076: preserve result, route and next action in a narrow two-line cue.
# The display summary never changes real physics, progress, or input windows.
func _cue_priority_lines() -> PackedStringArray:
	var original := _visible_cue()
	var chunks := original.split(" / ", false)
	if chunks.size() < 3:
		return PackedStringArray([original, ""])
	var outcome := str(chunks[0]).strip_edges().get_slice("・", 0)
	var route := ""
	var next_action := ""
	for chunk in chunks:
		var phrase := str(chunk).strip_edges()
		if phrase.begins_with("ROUTE "):
			route = phrase.substr(6).strip_edges()
		elif phrase.begins_with("NEXT ACTION:"):
			# Show when TAP NOW lights up, not an unconditional tap instruction.
			next_action = "NEXT · TAP NOW表示で目標HUBへ" if phrase.contains("TAP NOW") else phrase.substr(12).strip_edges()
	var top_line := outcome + (" · ROUTE " + route if not route.is_empty() else "")
	var bottom_line := next_action if not next_action.is_empty() else str(chunks[1]).strip_edges()
	return PackedStringArray([top_line, bottom_line])


func _show_cue(message: String, positive: bool = true) -> void:
	cue_text = message
	cue_good = positive
	cue_clock = 1.65
	queue_redraw()

func _attempt_action() -> void:
	if state == "intro":
		_start_game()
		return
	if state == "result":
		_reset_round()
		return

	var hub_delta := _angle_distance(orbit_angle, float(HUB_ANGLES[orbit_index]))
	if hub_delta <= HUB_WINDOW:
		if orbit_index == cargo_target:
			_deliver()
		else:
			_lose_energy("MISDELIVERY — HUBが違う")
		return

	var best_switch := -1
	var best_delta := 999.0
	for i in range(SWITCH_ANGLES.size()):
		var pair: Array = SWITCH_PAIRS[i]
		if orbit_index != int(pair[0]) and orbit_index != int(pair[1]):
			continue
		var d := _angle_distance(orbit_angle, float(SWITCH_ANGLES[i]))
		if d < best_delta:
			best_delta = d
			best_switch = i
	if best_switch >= 0 and best_delta <= SWITCH_WINDOW:
		_switch_orbit(best_switch)
	else:
		# GAME-076: One first-30-seconds timing hint for a new player.
		# Wrong-HUB taps, valid crossings, score, cargo timer and higher routes are unchanged.
		if not novice_miss_guard_used and deliveries == 0 and PLAY_TIME - time_left <= 30.0:
			novice_miss_guard_used = true
			action_text = "GUIDE · WAIT FOR GREEN"
			feedback_text = "初回ヒント: 緑のTAP NOWが出た時だけタップ"
			_show_cue("FIRST TAP GUIDE · ENERGY SAVED", true)
			_update_debug_bridge()
		else:
			_lose_energy("MISS — 乗換/HUBのタイミング外")

func _switch_orbit(index: int) -> void:
	var pair: Array = SWITCH_PAIRS[index]
	orbit_index = int(pair[1]) if orbit_index == int(pair[0]) else int(pair[0])
	last_action_angle = orbit_angle
	action_text = "TRANSFER!"
	feedback_text = "軌道 %d へ切替成功。配送先 %s を狙え。" % [orbit_index + 1, HUB_SHORT[cargo_target]]
	flash_good = 0.45
	_show_cue("TRANSFER OK · ORBIT %d" % (orbit_index + 1))
	_play(tone_switch)
	_emit_sparks(_player_position(), Color("#7df9ff"), 10)
	_update_debug_bridge()

func _deliver() -> void:
	var multiplier := _combo_multiplier()
	var urgency_bonus := int(round(cargo_left * 2.0))
	var gained := 100 * multiplier + urgency_bonus
	var previous_tier := _mission_tier()
	score += gained
	deliveries += 1
	streak += 1
	var next_multiplier := _combo_multiplier()
	action_text = "+%d  DELIVERY" % gained
	feedback_text = "%sへ配達成功 · STREAK %d · COMBO x%d" % [HUB_SHORT[cargo_target], streak, next_multiplier]
	flash_good = 1.0
	if _mission_tier() > previous_tier:
		_show_cue("NEW ROUTE %d · %s" % [_mission_tier() + 1, _mission_name()])
	else:
		_show_cue("DELIVERY +%d · COMBO x%d" % [gained, next_multiplier])
	_play(tone_delivery)
	_emit_sparks(_player_position(), HUB_COLORS[cargo_target], 22)
	_assign_next_cargo()
	_update_debug_bridge()

func _assign_next_cargo() -> void:
	var previous := cargo_target
	if qa_mode:
		cargo_target = (cargo_target + 1) % 3
	else:
		var choices := [0, 1, 2]
		choices.erase(previous)
		cargo_target = int(choices[rng.randi_range(0, choices.size() - 1)])
	cargo_left = _cargo_limit()

func _lose_energy(reason: String) -> void:
	if state != "playing":
		return
	energy -= 1
	streak = 0
	cargo_left = CARGO_TIME
	action_text = "ENERGY -1"
	feedback_text = reason
	flash_bad = 1.0
	_show_cue("MISS · ENERGY -1", false)
	_play(tone_error)
	_emit_sparks(_player_position(), Color("#ff5577"), 14)
	if energy <= 0:
		_finish_game("ENERGY EMPTY")
	else:
		_assign_next_cargo()
	_update_debug_bridge()

func _finish_game(reason: String) -> void:
	if state == "result":
		return
	state = "result"
	result_clock = 0.0
	if score > best_score:
		best_score = score
		_save_best()
	action_text = "RESULT"
	feedback_text = "%s · %d deliveries · %d pts" % [reason, deliveries, score]
	_play(tone_result)
	_emit_sparks(_field_center(), Color("#ffd166"), 42)
	_update_debug_bridge()

func _emit_sparks(origin: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var a := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(38.0, 150.0)
		sparks.append({
			"pos": origin,
			"vel": Vector2(cos(a), sin(a)) * speed,
			"life": rng.randf_range(0.28, 0.72),
			"color": color
		})

func _field_center() -> Vector2:
	return field_rect.get_center()

func _orbit_radius(index: int) -> float:
	var base := minf(field_rect.size.x, field_rect.size.y) * 0.5
	return base * float([0.42, 0.61, 0.80][index])

func _orbit_position(index: int, angle: float) -> Vector2:
	var center := _field_center()
	var r := _orbit_radius(index)
	var squash := 0.83
	return center + Vector2(cos(angle) * r, sin(angle) * r * squash)

func _player_position() -> Vector2:
	return _orbit_position(orbit_index, orbit_angle)

func _rounded_box(rect: Rect2, bg: Color, border: Color = Color.TRANSPARENT, radius: int = 14, border_width: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border.a > 0.0:
		style.border_color = border
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
	draw_style_box(style, rect)

func _update_ui_scale() -> void:
	ui_scale = 1.0
	if OS.get_name() != "Web":
		return
	# Godot's portrait-sized canvas is often scaled down for phone landscape.
	# Use the displayed canvas CSS height, not devicePixelRatio or logical viewport.
	var css_h: Variant = JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas');return c?c.getBoundingClientRect().height:0;})()", true)
	if typeof(css_h) == TYPE_FLOAT or typeof(css_h) == TYPE_INT:
		if float(css_h) > 40.0:
			ui_scale = clampf(size.y / float(css_h), 0.65, 3.0)

func _ui_px(value: float) -> float:
	return value * ui_scale

func _font_size(base: float) -> int:
	# Ensure HUD/captions remain at least 12 visible CSS pixels.
	return maxi(int(ceil(12.0 * ui_scale)), int(round(base * ui_scale)))


func _draw_label(text_value: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(ui_font, pos, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_fit_label(text_value: String, pos: Vector2, font_size: int, color: Color, available_width: float) -> void:
	var clipped := text_value
	if ui_font.get_string_size(clipped, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
		while clipped.length() > 1 and ui_font.get_string_size(clipped + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
			clipped = clipped.substr(0, clipped.length() - 1)
		clipped += "…"
	_draw_label(clipped, pos, font_size, color)

func _draw_center_text(text_value: String, rect: Rect2, font_size: int, color: Color) -> void:
	var measured := ui_font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var x := rect.position.x + (rect.size.x - measured.x) * 0.5
	var y := rect.position.y + (rect.size.y + ui_font.get_ascent(font_size) - ui_font.get_descent(font_size)) * 0.5
	draw_string(ui_font, Vector2(x, y), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

# Keep important onboarding and action prompts legible without clipping on phone landscape.
func _draw_center_fit_text(text_value: String, rect: Rect2, preferred_size: int, color: Color) -> void:
	var fit_size := preferred_size
	var minimum_size := _font_size(12.0)
	var available_width := maxf(_ui_px(32.0), rect.size.x - _ui_px(12.0))
	while fit_size > minimum_size and ui_font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_size).x > available_width:
		fit_size -= 1
	# A 12 CSS-pixel minimum keeps text readable, but a long translated cue can
	# still overrun a narrow panel. Ellipsize only in that final case.
	var shown := text_value
	if ui_font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_size).x > available_width:
		while shown.length() > 1 and ui_font.get_string_size(shown + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fit_size).x > available_width:
			shown = shown.substr(0, shown.length() - 1)
		shown += "…"
	_draw_center_text(shown, rect, fit_size, color)


func _draw_button(rect: Rect2, label: String, accent: bool = false) -> void:
	_rounded_box(rect, Color("#15314a") if not accent else Color("#14647a"), Color("#335d78") if not accent else Color("#65e7f3"), 11, 1)
	_draw_center_fit_text(label, rect, _font_size(16.0), Color("#f2fbff"))

func _draw() -> void:
	var w := size.x
	var h := size.y
	var phys_w := w / maxf(0.1, ui_scale)
	var phys_h := h / maxf(0.1, ui_scale)
	var compact := phys_h < 520.0
	draw_rect(Rect2(Vector2.ZERO, size), Color("#050914"), true)
	for i in range(18):
		var px := fmod(float(i * 83 + 41), maxf(1.0, w))
		var py := fmod(float(i * 137 + 73), maxf(1.0, h))
		draw_circle(Vector2(px, py), 1.2 + float(i % 3) * 0.5, Color(0.52, 0.82, 1.0, 0.22))
	draw_circle(Vector2(w * 0.16, h * 0.20), minf(w, h) * 0.34, Color(0.10, 0.66, 0.82, 0.055))
	draw_circle(Vector2(w * 0.88, h * 0.78), minf(w, h) * 0.31, Color(0.63, 0.32, 0.88, 0.05))

	var margin := _ui_px(12.0 if compact else 18.0)
	# Reserve the second header row for GAME HUB on portrait/tablet layouts.
	var title_h := _ui_px(56.0 if compact else 112.0)
	# GAME-076: concise first-action cue instead of a small engine/version caption.
	_draw_label("GAME-G030  /  TAP THE GLOW", Vector2(margin, margin + _ui_px(15.0)), _font_size(14.0), Color("#a4f8ff"))
	var heading := "ORBIT COURIER" if phys_w < 520.0 else "ORBIT SWITCH COURIER"
	_draw_label(heading, Vector2(margin, margin + _ui_px(50.0 if compact else 58.0)), _font_size(23.0), Color("#f4fbff"))

	# Physical 116x48 CSS-pixel SOUND button, including narrow phone landscape.
	sound_rect = Rect2(w - margin - _ui_px(116.0), margin + _ui_px(3.0), _ui_px(116.0), _ui_px(48.0))
	_draw_button(sound_rect, "SOUND ON" if sound_on else "SOUND OFF", sound_on)
	hub_rect = Rect2(w - margin - _ui_px(116.0), margin + _ui_px(57.0), _ui_px(116.0), _ui_px(44.0))
	if not compact:
		_draw_button(hub_rect, "GAME HUB")

	var hud_y := margin + title_h + _ui_px(9.0)
	var hud_h := _ui_px(54.0)
	hud_rect = Rect2(margin, hud_y, w - margin * 2.0, hud_h)
	var gap := _ui_px(6.0)
	var stat_w := (w - margin * 2.0 - gap * 3.0) / 4.0
	var stats := [
		["TIME", "%02d" % int(ceil(time_left))],
		["DELIVER", str(deliveries)],
		["SCORE", str(score)],
		["BEST", str(best_score)]
	]
	for i in range(4):
		var r := Rect2(margin + float(i) * (stat_w + gap), hud_y, stat_w, hud_h)
		_rounded_box(r, Color("#0b1727"), Color("#335a73"), 10, 1)
		_draw_label(str(stats[i][0]), r.position + Vector2(_ui_px(8.0), _ui_px(18.0)), _font_size(15.0), Color("#eefaff"))
		_draw_label(str(stats[i][1]), r.position + Vector2(_ui_px(8.0), hud_h - _ui_px(8.0)), _font_size(19.0), Color("#f5fbff"))

	var content_y := hud_y + hud_h + _ui_px(9.0)
	var available_h := h - content_y - margin
	var landscape := w > h * 1.30
	if landscape:
		# Balance the wide information panel and use the lower half for instructions.
		var field_w := minf(w * 0.63, available_h * 1.68)
		field_rect = Rect2(margin, content_y, field_w, available_h)
		info_rect = Rect2(field_rect.end.x + _ui_px(12.0), content_y, w - margin - field_rect.end.x - _ui_px(12.0), available_h)
	else:
		# Small portrait viewports cannot always fit the old fixed 190px field
		# plus 170px info panel beneath the header. Share only the real space.
		var panel_gap := _ui_px(8.0)
		var split_h := maxf(0.0, available_h - panel_gap)
		var info_target_h := clampf(available_h * 0.24, _ui_px(170.0), _ui_px(194.0))
		var info_h := minf(info_target_h, split_h * 0.49)
		var field_h := maxf(0.0, split_h - info_h)
		field_rect = Rect2(margin, content_y, w - margin * 2.0, field_h)
		info_rect = Rect2(margin, field_rect.end.y + panel_gap, w - margin * 2.0, info_h)

	_draw_playfield()
	_draw_info_panel()
	_draw_sparks()

	if state == "intro":
		_draw_intro_overlay()
	elif state == "result":
		_draw_result_overlay()


func _draw_playfield() -> void:
	_rounded_box(field_rect, Color(0.025, 0.065, 0.105, 0.96), _route_color(), 20, 2)
	var center := _field_center()
	var base := minf(field_rect.size.x, field_rect.size.y) * 0.5
	draw_circle(center, base * 0.16, Color(0.09, 0.32, 0.46, 0.5))
	draw_circle(center, base * 0.10, Color(0.14, 0.63, 0.74, 0.30))
	for orbit in range(3):
		var points := PackedVector2Array()
		for s in range(65):
			var a := TAU * float(s) / 64.0
			points.append(_orbit_position(orbit, a))
		var col := Color(0.23, 0.54, 0.68, 0.34 + float(orbit) * 0.05)
		draw_polyline(points, col, 2.0, true)

	for i in range(SWITCH_ANGLES.size()):
		var a := float(SWITCH_ANGLES[i])
		var pair: Array = SWITCH_PAIRS[i]
		var p0 := _orbit_position(int(pair[0]), a)
		var p1 := _orbit_position(int(pair[1]), a)
		var active := orbit_index == int(pair[0]) or orbit_index == int(pair[1])
		var near := active and _angle_distance(orbit_angle, a) <= SWITCH_WINDOW
		draw_line(p0, p1, Color("#7df9ff") if near else Color(0.35, 0.76, 0.85, 0.34), 4.0 if near else 2.0, true)
		draw_circle(p0, 6.0 if near else 4.2, Color("#d8feff") if near else Color("#4c8ca3"))
		draw_circle(p1, 6.0 if near else 4.2, Color("#d8feff") if near else Color("#4c8ca3"))

	for hub in range(3):
		var pos := _orbit_position(hub, float(HUB_ANGLES[hub]))
		var active_hub := cargo_target == hub
		var ring := 19.0 if active_hub else 15.0
		if active_hub:
			var pulse := 0.5 + sin(elapsed * 5.0) * 0.5
			draw_circle(pos, ring + 9.0 + pulse * 4.0, Color(HUB_COLORS[hub], 0.12))
		draw_circle(pos, ring, Color("#091827"))
		draw_arc(pos, ring, 0.0, TAU, 30, HUB_COLORS[hub], 3.0 if active_hub else 2.0, true)
		_draw_hub_symbol(pos, hub, HUB_COLORS[hub])

	var p := _player_position()
	if _near_action_prompt().begins_with("TAP NOW"):
		draw_arc(p, _ui_px(17.0), 0.0, TAU, 40, Color("#72f4d3"), _ui_px(3.0), true)
	trail.push_back(p)
	if trail.size() > 18:
		trail.pop_front()
	for i in range(trail.size()):
		var alpha := float(i + 1) / float(trail.size()) * 0.32
		draw_circle(trail[i], 2.0 + float(i) / float(maxi(1, trail.size())) * 3.0, Color(0.38, 0.92, 1.0, alpha))
	draw_circle(p, 14.0, Color(0.18, 0.93, 1.0, 0.12))
	draw_circle(p, 8.5, Color("#f4fbff"))
	var nose := p + Vector2(cos(orbit_angle + (PI * 0.5 if float(ORBIT_SPEEDS[orbit_index]) > 0 else -PI * 0.5)), sin(orbit_angle + (PI * 0.5 if float(ORBIT_SPEEDS[orbit_index]) > 0 else -PI * 0.5))) * 12.0
	draw_line(p, nose, Color("#47dff1"), 4.0, true)
	if flash_good > 0:
		draw_circle(p, 20.0 + flash_good * 12.0, Color(0.35, 1.0, 0.82, flash_good * 0.22))
	if flash_bad > 0:
		draw_circle(p, 20.0 + flash_bad * 10.0, Color(1.0, 0.28, 0.42, flash_bad * 0.22))

	if (cue_clock > 0.0 or qa_cue_stress) and state == "playing":
		var cue_w := minf(field_rect.size.x - _ui_px(20.0), _ui_px(360.0))
		var cue_r := Rect2(field_rect.position.x + (field_rect.size.x - cue_w) * 0.5, field_rect.position.y + _ui_px(12.0), cue_w, _ui_px(39.0))
		_rounded_box(cue_r, Color("#11463f") if cue_good else Color("#542039"), Color("#72f4d3") if cue_good else Color("#ff91a9"), 10, 1)
		# Split structured long feedback into outcome/route and next safe action.
		# The normal one-line feedback remains unchanged.
		if _visible_cue().contains(" / "):
			var key_lines := _cue_priority_lines()
			var top_cue_r := Rect2(cue_r.position.x, cue_r.position.y + _ui_px(1.0), cue_r.size.x, _ui_px(19.0))
			var bottom_cue_r := Rect2(cue_r.position.x, cue_r.position.y + _ui_px(19.0), cue_r.size.x, _ui_px(19.0))
			_draw_center_fit_text(key_lines[0], top_cue_r, _font_size(15.0), Color("#ffffff"))
			_draw_center_fit_text(key_lines[1], bottom_cue_r, _font_size(14.0), Color("#fff5d9"))
		else:
			_draw_center_fit_text(_visible_cue(), cue_r, _font_size(14.0), Color("#ffffff"))

	# Important live actions remain visible on short phone-landscape screens.
	var prompt := _near_action_prompt()
	if not prompt.is_empty():
		var action_ready := prompt.begins_with("TAP NOW")
		var prompt_rect := Rect2(field_rect.position.x + _ui_px(9.0), field_rect.end.y - _ui_px(45.0), field_rect.size.x - _ui_px(18.0), _ui_px(36.0))
		_rounded_box(prompt_rect, Color("#116750") if action_ready else Color("#153349"), Color("#a8ffe2") if action_ready else Color("#3f839b"), 10, 2 if action_ready else 1)
		_draw_center_fit_text(prompt, prompt_rect, _font_size(17.0 if action_ready else 16.0), Color("#ffffff") if action_ready else Color("#e5f9ff"))

func _draw_hub_symbol(pos: Vector2, hub: int, color: Color) -> void:
	if hub == 0:
		draw_rect(Rect2(pos - Vector2(5, 5), Vector2(10, 10)), color, true)
	elif hub == 1:
		var pts := PackedVector2Array([pos + Vector2(0, -7), pos + Vector2(7, 6), pos + Vector2(-7, 6)])
		draw_colored_polygon(pts, color)
	else:
		draw_circle(pos, 6.0, color)

func _near_action_prompt() -> String:
	if state != "playing":
		return ""
	# GAME-076: Never suggest TAP NOW outside a real, usable scoring window.
	# Hub collision has priority over crossing, so wrong hubs must not invite a TAP.
	var hub_distance := _angle_distance(orbit_angle, float(HUB_ANGLES[orbit_index]))
	if hub_distance <= HUB_WINDOW:
		if orbit_index == cargo_target:
			return "TAP NOW · DELIVER %s" % HUB_SHORT[cargo_target]
		return "OTHER HUB · WAIT TO SWITCH"
	var next_switch_distance := 999.0
	for i in range(SWITCH_ANGLES.size()):
		var pair: Array = SWITCH_PAIRS[i]
		if orbit_index != int(pair[0]) and orbit_index != int(pair[1]):
			continue
		var next_orbit := int(pair[1]) if orbit_index == int(pair[0]) else int(pair[0])
		if absi(next_orbit - cargo_target) >= absi(orbit_index - cargo_target):
			continue
		next_switch_distance = minf(next_switch_distance, _angle_distance(orbit_angle, float(SWITCH_ANGLES[i])))
	if next_switch_distance <= SWITCH_WINDOW:
		return "TAP NOW · TRANSFER"
	if orbit_index == cargo_target and hub_distance <= HUB_WINDOW * 2.4:
		return "GET READY · TARGET HUB"
	if next_switch_distance <= SWITCH_WINDOW * 2.2:
		return "GET READY · CROSSING"
	return "TARGET %s · WAIT FOR GLOW" % HUB_SHORT[cargo_target]


func _draw_info_panel() -> void:
	action_card_rect = Rect2()
	help_guide_rect = Rect2()
	_rounded_box(info_rect, Color("#0a1625"), Color("#2f5b72"), 16, 1)
	var pad := _ui_px(16.0)
	var x := info_rect.position.x + pad
	var y := info_rect.position.y + _ui_px(22.0)
	_draw_fit_label("ROUTE %d · %s  /  CARGO" % [_mission_tier() + 1, _mission_name()], Vector2(x, y), _font_size(16.0), Color("#f5fdff"), info_rect.size.x - pad * 2.0)
	y += _ui_px(24.0)
	# GAME-076: Show the physical remaining seconds FIRST so even a clipped
	# cargo name never hides the deadline. Highlight the final three seconds
	# without obscuring the normal TAP NOW action or altering game timing.
	var cargo_urgent := state == "playing" and cargo_left <= 3.0
	# Keep the destination readable in narrower landscape info columns.
	# HUB_SHORT preserves the target symbol when the full color/shape label would clip.
	var cargo_target_label: String = str(HUB_NAMES[cargo_target])
	if info_rect.size.x < _ui_px(400.0):
		cargo_target_label = HUB_SHORT[cargo_target]
	var cargo_countdown := "%02ds LEFT  ·  %s" % [int(ceil(cargo_left)), cargo_target_label]
	if cargo_urgent:
		# Text and shape reinforce the warning, so urgency is not color-only.
		# Keep remaining seconds first and retain the target hub when space permits.
		cargo_countdown = "%02ds LEFT!  HURRY  ·  %s" % [int(ceil(cargo_left)), cargo_target_label]
		var warning_chip := Rect2(x - _ui_px(6.0), y - _ui_px(18.0), info_rect.size.x - pad * 2.0 + _ui_px(12.0), _ui_px(26.0))
		_rounded_box(warning_chip, Color("#8b2030"), Color("#fff0aa"), 7, 2)
	# GAME-076: Pair the target name with the same square/triangle/circle
	# used on its destination HUB. The icon keeps the target recognizable when
	# a narrow panel shortens the label; no route, input or timer logic changes.
	var target_marker_radius := _ui_px(12.0)
	var target_marker_center := Vector2(info_rect.end.x - pad - target_marker_radius, y - _ui_px(8.0))
	var countdown_text_width := maxf(_ui_px(70.0), info_rect.size.x - pad * 2.0 - _ui_px(33.0))
	_draw_fit_label(cargo_countdown, Vector2(x, y), _font_size(18.0) if cargo_urgent else _font_size(17.0), Color("#ffffff") if cargo_urgent else HUB_COLORS[cargo_target], countdown_text_width)
	draw_circle(target_marker_center, target_marker_radius, Color("#102a3d"))
	draw_arc(target_marker_center, target_marker_radius, 0.0, TAU, 24, HUB_COLORS[cargo_target], _ui_px(2.0), true)
	_draw_hub_symbol(target_marker_center, cargo_target, HUB_COLORS[cargo_target])
	y += _ui_px(20.0)
	var cargo_bar := Rect2(x, y, info_rect.size.x - pad * 2.0, _ui_px(9.0))
	draw_rect(cargo_bar, Color("#68283b") if cargo_urgent else Color("#244a64"), true)
	draw_rect(Rect2(cargo_bar.position, Vector2(cargo_bar.size.x * clampf(cargo_left / _cargo_limit(), 0.0, 1.0), cargo_bar.size.y)), Color("#ff5877") if cargo_urgent else HUB_COLORS[cargo_target], true)
	if cargo_urgent:
		draw_rect(cargo_bar.grow(_ui_px(2.0)), Color("#ff9dab"), false, _ui_px(2.0))
	y += _ui_px(29.0)
	var hearts := ""
	for i in range(3):
		hearts += "◆ " if i < energy else "◇ "
	_draw_label("ENERGY  " + hearts, Vector2(x, y), _font_size(16.0), Color("#ffc4d0"))
	y += _ui_px(25.0)
	# Clip low-priority combo metadata rather than allow overlap with the panel edge.
	_draw_fit_label("STREAK %d  ·  x%d COMBO" % [streak, _combo_multiplier()], Vector2(x, y), _font_size(16.0), Color("#fff0bd"), info_rect.size.x - pad * 2.0)
	y += _ui_px(24.0)
	if info_rect.size.y >= _ui_px(315.0):
		var next_goal := 1 if deliveries < 1 else (3 if deliveries < 3 else (6 if deliveries < 6 else 0))
		var next_route := "RUSH" if deliveries < 1 else ("NIGHT" if deliveries < 3 else ("ACE" if deliveries < 6 else "ACE MASTER"))
		var progress := "NEXT %s · %d more" % [next_route, maxi(0, next_goal - deliveries)] if next_goal > 0 else "ALL ROUTES UNLOCKED"
		_draw_fit_label(progress, Vector2(x, y), _font_size(16.0), Color("#c1ffe9"), info_rect.size.x - pad * 2.0)
		y += _ui_px(23.0)
	# GAME-076: Give the actual next legal action a contrast-safe, unclipped home.
	# Compact portrait layouts retain the single-line fallback rather than drawing outside the card.
	if info_rect.size.y >= _ui_px(158.0):
		var live_action := _near_action_prompt()
		var action_ready := state == "playing" and live_action.begins_with("TAP NOW")
		var action_line := live_action
		if state == "intro":
			action_line = "START → %sを目指そう" % HUB_SHORT[cargo_target]
		elif state == "result":
			action_line = "RETRYで再挑戦"
		# GAME-076: short landscape panels use concise, unambiguous live-action
		# copy to avoid automatic font shrinking under NEXT ACTION. The legal
		# tap window is still computed by _near_action_prompt (unchanged).
		if state == "playing" and info_rect.size.y >= _ui_px(220.0) and info_rect.size.y <= _ui_px(275.0):
			if live_action == "OTHER HUB · WAIT TO SWITCH":
				action_line = "WAIT · WRONG HUB"
			elif live_action == "TAP NOW · TRANSFER":
				action_line = "TAP · SWITCH"
			elif live_action.begins_with("TAP NOW · DELIVER "):
				action_line = live_action.replace("TAP NOW · DELIVER ", "TAP · HUB ")
			elif live_action == "GET READY · TARGET HUB":
				action_line = "READY · TARGET HUB"
			elif live_action == "GET READY · CROSSING":
				action_line = "READY · GREEN"
			elif live_action.begins_with("TARGET "):
				action_line = live_action.replace(" · WAIT FOR GLOW", " · WAIT")
		var card_y := y - _ui_px(13.0)
		# Reserve an 8px gap above the two 30px tutorial chips on 220-239px panels.
		# Without this clearance, the NEXT ACTION card touches the chips at 220-223px.
		var guide_clearance := _ui_px(44.0) if info_rect.size.y >= _ui_px(220.0) and info_rect.size.y < _ui_px(240.0) else _ui_px(11.0)
		var card_h := minf(_ui_px(56.0), info_rect.end.y - card_y - guide_clearance)
		if card_h >= _ui_px(43.0):
			var action_card := Rect2(x, card_y, info_rect.size.x - pad * 2.0, card_h)
			action_card_rect = action_card
			_rounded_box(action_card, Color("#125b4b") if action_ready else Color("#183a51"), Color("#9affdc") if action_ready else Color("#89d7fc"), 11, 3 if action_ready else 2)
			# A short, pulsing green rail makes a genuinely legal TAP window visible
			# without touching orbit, input, score, or the QA state.
			if action_ready:
				var ready_pulse := 0.5 + 0.5 * sin(elapsed * 8.0)
				var ready_rail := Rect2(action_card.position.x + _ui_px(6.0), action_card.position.y + _ui_px(6.0), _ui_px(5.0), card_h - _ui_px(12.0))
				draw_rect(ready_rail, Color(0.60, 1.0, 0.85, 0.55 + 0.45 * ready_pulse), true)
			_draw_label("TAP NOW" if action_ready else "NEXT ACTION", action_card.position + Vector2(_ui_px(14.0 if action_ready else 10.0), _ui_px(16.0)), _font_size(16.0), Color("#ffffff"))
			_draw_center_fit_text(action_line, Rect2(action_card.position.x + _ui_px(5.0), action_card.position.y + _ui_px(18.0), action_card.size.x - _ui_px(10.0), card_h - _ui_px(20.0)), _font_size(18.0 if action_ready else 17.0), Color("#ffffff"))
		else:
			_draw_fit_label(action_line, Vector2(x, y), _font_size(16.0), Color("#ffffff"), info_rect.size.x - pad * 2.0)
	# The tablet-landscape information area is taller: put a readable step guide near
	# the action card instead of leaving the next input unexplained in empty space.
	if info_rect.size.y > _ui_px(470.0):
		_draw_label("HOW TO PLAY", Vector2(x, y + _ui_px(94.0)), _font_size(18.0), Color("#a4f8ff"))
		_draw_fit_label("1  緑でTAP → 乗換", Vector2(x, y + _ui_px(126.0)), _font_size(19.0), Color("#ffffff"), info_rect.size.x - pad * 2.0)
		_draw_fit_label("2  同じ印でTAP → 配達", Vector2(x, y + _ui_px(161.0)), _font_size(19.0), Color("#fff3be"), info_rect.size.x - pad * 2.0)
		_draw_fit_label("3  配達3回→NIGHT / 6回→ACE", Vector2(x, y + _ui_px(196.0)), _font_size(19.0), Color("#b3ffe4"), info_rect.size.x - pad * 2.0)
	# GAME-076: Phone landscape has no room for the large HOW TO PLAY guide.
	# Keep two bright, readable steps below (not inside) the NEXT ACTION card.
	# The <220px portrait panel uses its existing single-line fallback instead.
	if info_rect.size.y >= _ui_px(220.0) and info_rect.size.y <= _ui_px(275.0):
		# Extremely short landscape panels cannot fit two help lines below the
		# next-action card. A single 24px strip leaves a positive visible gap.
		if info_rect.size.y < _ui_px(240.0):
			# Two independent, readable actions replace one crowded sentence.
			# The chips explain the existing real TAP window without altering input.
			var short_help_gap := _ui_px(6.0)
			var short_help_width := (info_rect.size.x - _ui_px(14.0) - short_help_gap) * 0.5
			var switch_chip := Rect2(info_rect.position.x + _ui_px(7.0), info_rect.end.y - _ui_px(36.0), short_help_width, _ui_px(30.0))
			var deliver_chip := Rect2(switch_chip.end.x + short_help_gap, switch_chip.position.y, short_help_width, switch_chip.size.y)
			help_guide_rect = Rect2(switch_chip.position.x, switch_chip.position.y, deliver_chip.end.x - switch_chip.position.x, switch_chip.size.y)
			_rounded_box(switch_chip, Color("#154e45"), Color("#77e9cf"), 9, 1)
			_rounded_box(deliver_chip, Color("#5a4428"), Color("#ffe5a2"), 9, 1)
			_draw_center_fit_text("緑でTAP→乗換", switch_chip, _font_size(18.0), Color("#ffffff"))
			_draw_center_fit_text("同じ印でTAP→配達", deliver_chip, _font_size(18.0), Color("#ffffff"))
		else:
			# Taller phone landscape panels have room for two high-contrast steps.
			var help_band := Rect2(info_rect.position.x + _ui_px(7.0), info_rect.end.y - _ui_px(48.0), info_rect.size.x - _ui_px(14.0), _ui_px(42.0))
			help_guide_rect = help_band
			_rounded_box(help_band, Color("#16364a"), Color("#5ba7c9"), 9, 1)
			_draw_fit_label("1  緑でTAP → 乗換", Vector2(x, info_rect.end.y - _ui_px(32.0)), _font_size(19.0), Color("#ffffff"), info_rect.size.x - pad * 2.0)
			_draw_fit_label("2  同じ印でTAP → 配達", Vector2(x, info_rect.end.y - _ui_px(12.0)), _font_size(19.0), Color("#fff8d9"), info_rect.size.x - pad * 2.0)
	# Tablet landscape: use otherwise empty lower-panel space to show which
	# naturally-earned route tiers are unlocked. This is a display only.
	if info_rect.size.y > _ui_px(525.0):
		var milestones_y := info_rect.end.y - _ui_px(126.0)
		_draw_label("ROUTE MILESTONES", Vector2(x, milestones_y - _ui_px(13.0)), _font_size(18.0), Color("#ffffff"))
		var milestone_gap := _ui_px(6.0)
		var milestone_width := (info_rect.size.x - pad * 2.0 - milestone_gap * 2.0) / 3.0
		for step in range(3):
			var unlocked := _mission_tier() >= step + 1
			var milestone_rect := Rect2(x + float(step) * (milestone_width + milestone_gap), milestones_y, milestone_width, _ui_px(29.0))
			_rounded_box(milestone_rect, Color("#116252") if unlocked else Color("#172e42"), Color("#89ffce") if unlocked else Color("#5186a6"), 8, 1)
			_draw_center_fit_text(str(ROUTE_NAMES[step + 1]), milestone_rect, _font_size(18.0), Color("#ffffff"))
	# Echo successful transfers and missed timing in the otherwise empty lower
	# tablet-landscape panel. The prompt card keeps priority during gameplay.
	if state == "playing" and (cue_clock > 0.0 or qa_cue_stress) and info_rect.size.y > _ui_px(525.0):
		# Keep a clear gap from the route milestone tiles above and help lines below.
		var feedback_rect := Rect2(x, info_rect.end.y - _ui_px(94.0), info_rect.size.x - pad * 2.0, _ui_px(24.0))
		_rounded_box(feedback_rect, Color("#125f4d") if cue_good else Color("#712f4b"), Color("#94f8d9") if cue_good else Color("#ffbbd0"), 8, 1)
		# The tablet side echo carries the short outcome/route summary only.
		var side_cue := _cue_priority_lines()[0] if _visible_cue().contains(" / ") else _visible_cue()
		_draw_center_fit_text(side_cue, feedback_rect, _font_size(18.0), Color("#ffffff"))
	# Medium panels retain the bottom two-step guide. Tall tablet landscape
	# already shows HOW TO PLAY and route milestones, so avoid repeating the
	# same instructions beneath the milestone/feedback row.
	if info_rect.size.y > _ui_px(275.0) and info_rect.size.y <= _ui_px(470.0):
		var guide_band := Rect2(info_rect.position.x + _ui_px(7.0), info_rect.end.y - _ui_px(67.0), info_rect.size.x - _ui_px(14.0), _ui_px(61.0))
		help_guide_rect = guide_band
		_rounded_box(guide_band, Color("#142f43"), Color("#5d9cbd"), 9, 1)
		_draw_fit_label("緑の交差点でTAP → 乗換", Vector2(x, info_rect.end.y - _ui_px(52.0)), _font_size(18.0), Color("#ffffff"), info_rect.size.x - pad * 2.0)
		_draw_fit_label("同じ印のHUBでTAP → 配達", Vector2(x, info_rect.end.y - _ui_px(23.0)), _font_size(18.0), Color("#fff6c9"), info_rect.size.x - pad * 2.0)


func _draw_intro_overlay() -> void:
	draw_rect(field_rect, Color(0.01, 0.025, 0.05, 0.78), true)
	var width := minf(field_rect.size.x - _ui_px(20.0), _ui_px(460.0))
	var height := minf(field_rect.size.y - _ui_px(20.0), _ui_px(240.0))
	var r := Rect2(field_rect.get_center() - Vector2(width, height) * 0.5, Vector2(width, height))
	_rounded_box(r, Color("#0b1a2b"), Color("#46dce9"), 22, 2)
	# GAME-076: On a short phone landscape, fixed step positions could touch
	# the start button. Fit all three steps above the button without clipping.
	var short_panel := height < _ui_px(230.0)
	var title_y := _ui_px(13.0 if short_panel else 18.0)
	var step_y := _ui_px(46.0 if short_panel else 62.0)
	var step_gap := clampf((height - _ui_px(124.0)) * 0.5, _ui_px(23.0), _ui_px(33.0)) if short_panel else _ui_px(34.0)
	var step_h := _ui_px(21.0 if short_panel else 29.0)
	var step_font := _font_size(16.0 if short_panel else 18.0)
	_draw_center_text("ORBIT SWITCH COURIER", Rect2(r.position.x, r.position.y + title_y, width, _ui_px(30.0)), _font_size(20.0 if short_panel else 21.0), Color("#f5fbff"))
	_draw_center_fit_text("1  START → 目標 %s" % HUB_SHORT[cargo_target], Rect2(r.position.x, r.position.y + step_y, width, step_h), step_font, Color("#ffffff"))
	_draw_center_fit_text("2  TAP NOWで画面をタップ", Rect2(r.position.x, r.position.y + step_y + step_gap, width, step_h), step_font, Color("#b6fff0"))
	_draw_center_fit_text("3  同じ印のHUBでタップ→配達", Rect2(r.position.x, r.position.y + step_y + step_gap * 2.0, width, step_h), step_font, Color("#fff3be"))
	var button_height := _ui_px(44.0 if short_panel else 48.0)
	var button_offset := _ui_px(53.0 if short_panel else 59.0)
	var start_rect := Rect2(r.position.x + _ui_px(22.0), r.end.y - button_offset, width - _ui_px(44.0), button_height)
	_rounded_box(start_rect, Color("#14647a"), Color("#8dfbff"), 12, 2)
	_draw_center_text("TAP TO START", start_rect, _font_size(17.0 if short_panel else 18.0), Color.WHITE)


func _draw_result_overlay() -> void:
	draw_rect(field_rect, Color(0.01, 0.02, 0.04, 0.78), true)
	var width := minf(field_rect.size.x - _ui_px(20.0), _ui_px(430.0))
	var height := minf(field_rect.size.y - _ui_px(20.0), _ui_px(224.0))
	var r := Rect2(field_rect.get_center() - Vector2(width, height) * 0.5, Vector2(width, height))
	_rounded_box(r, Color("#0b1a2b"), Color("#ffd166"), 22, 2)
	# GAME-076: Compact layout keeps the deliveries/BEST line clear of RETRY
	# (the previous fixed y=113 and bottom anchored button overlapped).
	var short_panel := height < _ui_px(220.0)
	var heading_y := _ui_px(12.0 if short_panel else 20.0)
	var score_y := _ui_px(41.0 if short_panel else 62.0)
	var detail_y := _ui_px(87.0 if short_panel else 113.0)
	_draw_center_text("DELIVERY RESULT", Rect2(r.position.x, r.position.y + heading_y, width, _ui_px(28.0 if short_panel else 30.0)), _font_size(16.0), Color("#ffd166"))
	_draw_center_text("%d pts" % score, Rect2(r.position.x, r.position.y + score_y, width, _ui_px(40.0 if short_panel else 50.0)), _font_size(30.0 if short_panel else 32.0), Color("#f7fbff"))
	_draw_center_fit_text("%d deliveries  ·  BEST %d" % [deliveries, best_score], Rect2(r.position.x, r.position.y + detail_y, width, _ui_px(24.0 if short_panel else 31.0)), _font_size(14.0 if short_panel else 15.0), Color("#d7f0ff"))
	retry_rect = Rect2(r.position.x + _ui_px(22.0), r.end.y - _ui_px(55.0 if short_panel else 61.0), width - _ui_px(44.0), _ui_px(46.0 if short_panel else 50.0))
	_draw_button(retry_rect, "RETRY  ·  TAP / SPACE", true)

func _draw_sparks() -> void:
	for p in sparks:
		var life := clampf(float(p["life"]), 0.0, 1.0)
		draw_circle(Vector2(p["pos"]), 2.0 + life * 2.5, Color(Color(p["color"]), life * 0.72))

func _pointer_press_allowed() -> bool:
	var now: int = Time.get_ticks_msec()
	if now - last_pointer_down_msec < 120:
		return false
	last_pointer_down_msec = now
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			if not _pointer_press_allowed():
				accept_event()
				return
			if sound_rect.has_point(mouse.position):
				_toggle_sound()
			elif hub_rect.has_point(mouse.position) and size.y > 460.0:
				_go_hub()
			else:
				_attempt_action()
			accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if not _pointer_press_allowed():
				accept_event()
				return
			if sound_rect.has_point(touch.position):
				_toggle_sound()
			elif hub_rect.has_point(touch.position) and size.y > 460.0:
				_go_hub()
			else:
				_attempt_action()
			accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE:
		_attempt_action()
	elif key.keycode == KEY_M:
		_toggle_sound()
	elif key.keycode == KEY_R:
		_reset_round()
	else:
		return
	get_viewport().set_input_as_handled()

func _toggle_sound() -> void:
	sound_on = not sound_on
	if sound_on:
		_play(tone_switch)
	else:
		# Muting also stops an already-playing sample immediately.
		audio_player.stop()
	feedback_text = "SOUND ON" if sound_on else "SOUND OFF"
	_update_debug_bridge()

func _go_hub() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';", true)

func _rect_payload(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _process_qa_command() -> void:
	var raw: Variant = JavaScriptBridge.eval("(function(){var c=window.__P021_ORBIT_COMMAND||null;window.__P021_ORBIT_COMMAND=null;return c?JSON.stringify(c):'';})()", true)
	var text_value := str(raw)
	if text_value.is_empty():
		return
	var parsed: Variant = JSON.parse_string(text_value)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var action := str((parsed as Dictionary).get("action", ""))
	match action:
		"start":
			_start_game()
		"switch_success":
			if state != "playing":
				_start_game()
			var idx := 0
			var pair: Array = SWITCH_PAIRS[idx]
			orbit_index = int(pair[0])
			orbit_angle = float(SWITCH_ANGLES[idx])
			_attempt_action()
		"deliver":
			if state != "playing":
				_start_game()
			orbit_index = cargo_target
			orbit_angle = float(HUB_ANGLES[cargo_target])
			_attempt_action()
		"fail":
			if state != "playing":
				_start_game()
			orbit_angle = 1.0
			_attempt_action()
		"sound":
			_toggle_sound()
		"finish":
			_finish_game("QA COMPLETE")
		"retry":
			_reset_round()
		_:
			pass
	_update_debug_bridge()

func _update_debug_bridge() -> void:
	if OS.get_name() != "Web":
		return
	var payload := {
		"ready": field_rect.size.x > 0.0,
		"build": BUILD_ID,
		"child_id": CHILD_ID,
		"engine": "Godot 4.7.2",
		"state": state,
		"score": score,
		"best": best_score,
		"deliveries": deliveries,
		"energy": energy,
		"novice_guard_used": novice_miss_guard_used,
		"streak": streak,
		"combo": _combo_multiplier(),
		"time_left": time_left,
		"cargo_left": cargo_left,
		"cargo_target": cargo_target,
		"mission_tier": _mission_tier(),
		"mission_name": _mission_name(),
		"cargo_limit": _cargo_limit(),
		"cue_text": cue_text if cue_clock > 0.0 else "",
		"orbit": orbit_index,
		"angle": orbit_angle,
		"sound": sound_on,
		"audio_playing": audio_player.playing,
		"ui_scale": ui_scale,
		"sound_rect": _rect_payload(sound_rect),
		"hub_rect": _rect_payload(hub_rect),
		"hud_rect": _rect_payload(hud_rect),
		"retry_rect": _rect_payload(retry_rect),
		"action_card_rect": _rect_payload(action_card_rect),
		"help_guide_rect": _rect_payload(help_guide_rect),
		"field": _rect_payload(field_rect),
		"info": _rect_payload(info_rect),
		"viewport_w": int(get_viewport_rect().size.x),
		"viewport_h": int(get_viewport_rect().size.y),
		"qa_mode": qa_mode,
		"cue_stress": qa_cue_stress
	}
	JavaScriptBridge.eval("window.__P021_ORBIT = %s;" % JSON.stringify(payload), true)
