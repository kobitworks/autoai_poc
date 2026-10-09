extends Control

# GAME-060 / GAME-G013 Water Jug Godot redesign.
const BUILD_ID = "GAME-060"
const DIFFICULTIES = ["easy", "normal", "hard"]
const DIFFICULTY_LABELS = ["EASY", "NORMAL", "HARD"]
const LS_PATH = "user://water-jug-records.json"

class JugBoard:
	extends Control
	var cap_a: int = 3
	var cap_b: int = 5
	var amount_a: float = 0.0
	var amount_b: float = 0.0
	var target: int = 4
	var selected: String = ""

	func set_state(ca: int, cb: int, aa: float, ab: float, goal: int, selected_jug: String) -> void:
		cap_a = max(1, ca)
		cap_b = max(1, cb)
		amount_a = aa
		amount_b = ab
		target = goal
		selected = selected_jug
		queue_redraw()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		var base_y = h - 34.0
		var max_h = clampf(h - 76.0, 105.0, 260.0)
		var jug_w = clampf(w * 0.25, 82.0, 150.0)
		_draw_jug(Vector2(w * 0.29 - jug_w * 0.5, base_y), jug_w, max_h, cap_a, amount_a, "A", selected == "A")
		_draw_jug(Vector2(w * 0.71 - jug_w * 0.5, base_y), jug_w, max_h, cap_b, amount_b, "B", selected == "B")
		var arrow_y = maxf(38.0, base_y - max_h * 0.56)
		draw_line(Vector2(w * 0.45, arrow_y), Vector2(w * 0.55, arrow_y), Color("#67e8f9"), 3.0, true)
		draw_line(Vector2(w * 0.52, arrow_y - 7.0), Vector2(w * 0.55, arrow_y), Color("#67e8f9"), 3.0, true)
		draw_line(Vector2(w * 0.52, arrow_y + 7.0), Vector2(w * 0.55, arrow_y), Color("#67e8f9"), 3.0, true)
		draw_line(Vector2(w * 0.45, arrow_y + 18.0), Vector2(w * 0.55, arrow_y + 18.0), Color("#a78bfa"), 3.0, true)
		draw_line(Vector2(w * 0.48, arrow_y + 11.0), Vector2(w * 0.45, arrow_y + 18.0), Color("#a78bfa"), 3.0, true)
		draw_line(Vector2(w * 0.48, arrow_y + 25.0), Vector2(w * 0.45, arrow_y + 18.0), Color("#a78bfa"), 3.0, true)

	func _draw_jug(pos: Vector2, jug_w: float, max_h: float, cap: int, amount: float, label: String, is_selected: bool) -> void:
		var ratio = float(cap) / float(max(cap_a, cap_b))
		var jug_h = clampf(92.0 + ratio * (max_h - 92.0), 92.0, max_h)
		var top_y = pos.y - jug_h
		var inner = Rect2(pos.x + 8.0, top_y + 10.0, jug_w - 16.0, jug_h - 13.0)
		var fill_ratio = clampf(amount / float(cap), 0.0, 1.0)
		var water_h = inner.size.y * fill_ratio
		if water_h > 0.5:
			draw_rect(Rect2(inner.position.x, inner.end.y - water_h, inner.size.x, water_h), Color("#22d3ee"), true)
			draw_rect(Rect2(inner.position.x, inner.end.y - water_h, inner.size.x, minf(8.0, water_h)), Color("#67e8f9"), true)
		var outline = Color("#f8fafc") if not is_selected else Color("#facc15")
		var thick = 4.0 if is_selected else 3.0
		draw_line(Vector2(pos.x, top_y), Vector2(pos.x, pos.y), outline, thick, true)
		draw_line(Vector2(pos.x + jug_w, top_y), Vector2(pos.x + jug_w, pos.y), outline, thick, true)
		draw_line(Vector2(pos.x, pos.y), Vector2(pos.x + jug_w, pos.y), outline, thick, true)
		draw_line(Vector2(pos.x, top_y), Vector2(pos.x + jug_w * 0.32, top_y), outline, thick, true)
		draw_line(Vector2(pos.x + jug_w * 0.68, top_y), Vector2(pos.x + jug_w, top_y), outline, thick, true)
		if target <= cap:
			var gy = inner.end.y - inner.size.y * (float(target) / float(cap))
			draw_dashed_line(Vector2(pos.x + 5.0, gy), Vector2(pos.x + jug_w - 5.0, gy), Color("#facc15"), 2.0, 5.0)
		var font = ThemeDB.fallback_font
		var caption = "%s  %d/%d" % [label, int(round(amount)), cap]
		draw_string(font, Vector2(pos.x + 5.0, pos.y + 24.0), caption, HORIZONTAL_ALIGNMENT_LEFT, jug_w - 10.0, 18, outline)

var qa_mode := false
var rng := RandomNumberGenerator.new()
var ui_font: Font
var difficulty_index := 0
var cap_a := 3
var cap_b := 5
var target := 4
var amount_a := 0
var amount_b := 0
var optimal := 6
var moves := 0
var phase := "idle"
var selected_jug := ""
var start_ms := 0
var elapsed_ms := 0
var best_records: Dictionary = {}
var sound_on := true
var last_action := "READY"
var root_margin: MarginContainer
var content_grid: GridContainer
var board: JugBoard
var difficulty_button: Button
var sound_button: Button
var objective_label: Label
var move_label: Label
var time_label: Label
var optimal_label: Label
var best_label: Label
var feedback_label: Label
var controls_grid: GridContainer
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var audio_player: AudioStreamPlayer
var tone_action: AudioStreamWAV
var tone_pour: AudioStreamWAV
var tone_clear: AudioStreamWAV

func _ready() -> void:
	_load_font()
	_load_storage()
	if OS.get_name() == "Web":
		qa_mode = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true))
	rng.seed = 60013 if qa_mode else Time.get_unix_time_from_system()
	_build_ui()
	_setup_audio()
	_new_puzzle()
	set_process(true)
	call_deferred("_apply_responsive_layout")
	call_deferred("_update_debug_bridge")

func _process(_delta: float) -> void:
	if phase == "playing":
		elapsed_ms = Time.get_ticks_msec() - start_ms
		time_label.text = "%.1fs" % (float(elapsed_ms) / 1000.0)
	if OS.get_name() == "Web":
		_update_debug_bridge()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_apply_responsive_layout")
		call_deferred("_update_debug_bridge")

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var e := event as InputEventKey
	if not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_D:
			_cycle_difficulty()
		KEY_M:
			_toggle_sound()
		KEY_N, KEY_ENTER:
			_start_game()
		KEY_R:
			_reset_game()
		KEY_1:
			_fill("A")
		KEY_2:
			_empty("A")
		KEY_3:
			_pour("AtoB")
		KEY_7:
			_fill("B")
		KEY_8:
			_empty("B")
		KEY_9:
			_pour("BtoA")
		KEY_A:
			_select_jug("A")
		KEY_B:
			_select_jug("B")
		KEY_SPACE:
			_pour_selected()
		_:
			return
	get_viewport().set_input_as_handled()

func _load_font() -> void:
	var loaded = load("res://fonts/NotoSansJP.ttf")
	ui_font = loaded if loaded is Font else ThemeDB.fallback_font

func _load_storage() -> void:
	if FileAccess.file_exists(LS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			best_records = parsed

func _save_storage() -> void:
	var f = FileAccess.open(LS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(best_records))

func _style(bg: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12.0
	s.content_margin_right = 12.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s

func _make_button(text_value: String, accent := false) -> Button:
	var b = Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(92, 48)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color("#ecfeff"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal_color = Color("#0f2744") if not accent else Color("#155e75")
	b.add_theme_stylebox_override("normal", _style(normal_color, Color("#28577d"), 12))
	b.add_theme_stylebox_override("hover", _style(Color("#164e63"), Color("#67e8f9"), 12))
	b.add_theme_stylebox_override("pressed", _style(Color("#0e7490"), Color("#a5f3fc"), 12))
	return b

func _build_ui() -> void:
	var theme = Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 15
	self.theme = theme

	var bg = ColorRect.new()
	bg.color = Color("#061323")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	root_margin = MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_margin)

	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	root_margin.add_child(page)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	page.add_child(header)
	var title = Label.new()
	title.text = "WATER JUG LAB"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#ecfeff"))
	header.add_child(title)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	difficulty_button = _make_button("EASY", true)
	difficulty_button.pressed.connect(_cycle_difficulty)
	header.add_child(difficulty_button)
	sound_button = _make_button("SOUND ON")
	sound_button.pressed.connect(_toggle_sound)
	header.add_child(sound_button)
	var hub = _make_button("GAME HUB")
	hub.pressed.connect(_go_hub)
	header.add_child(hub)

	objective_label = Label.new()
	objective_label.text = "2つの容器で、指定された水量を作ろう。満たす・空にする・移すだけ。"
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_color_override("font_color", Color("#bae6fd"))
	page.add_child(objective_label)

	content_grid = GridContainer.new()
	content_grid.columns = 1
	content_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_grid.add_theme_constant_override("h_separation", 10)
	content_grid.add_theme_constant_override("v_separation", 10)
	page.add_child(content_grid)

	var arena_panel = PanelContainer.new()
	arena_panel.add_theme_stylebox_override("panel", _style(Color("#0b2038"), Color("#155e75"), 18))
	arena_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.add_child(arena_panel)
	board = JugBoard.new()
	board.custom_minimum_size = Vector2(250, 245)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.gui_input.connect(_on_board_input)
	arena_panel.add_child(board)

	var control_panel = PanelContainer.new()
	control_panel.add_theme_stylebox_override("panel", _style(Color("#0a192d"), Color("#334155"), 18))
	control_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.add_child(control_panel)
	var side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 7)
	control_panel.add_child(side)

	var stats = GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 8)
	side.add_child(stats)
	move_label = _make_stat(stats, "MOVES", "0")
	time_label = _make_stat(stats, "TIME", "0.0s")
	optimal_label = _make_stat(stats, "OPTIMAL", "6")

	feedback_label = Label.new()
	feedback_label.text = "READY — 好きな容器をタップして始められます。"
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("#a5f3fc"))
	feedback_label.add_theme_font_size_override("font_size", 15)
	side.add_child(feedback_label)

	controls_grid = GridContainer.new()
	controls_grid.columns = 3
	controls_grid.add_theme_constant_override("h_separation", 6)
	controls_grid.add_theme_constant_override("v_separation", 6)
	side.add_child(controls_grid)
	var fill_a = _make_button("A 満たす")
	fill_a.pressed.connect(_fill.bind("A"))
	controls_grid.add_child(fill_a)
	var pour_ab = _make_button("A → B", true)
	pour_ab.pressed.connect(_pour.bind("AtoB"))
	controls_grid.add_child(pour_ab)
	var empty_a = _make_button("A 空に")
	empty_a.pressed.connect(_empty.bind("A"))
	controls_grid.add_child(empty_a)
	var fill_b = _make_button("B 満たす")
	fill_b.pressed.connect(_fill.bind("B"))
	controls_grid.add_child(fill_b)
	var pour_ba = _make_button("B → A", true)
	pour_ba.pressed.connect(_pour.bind("BtoA"))
	controls_grid.add_child(pour_ba)
	var empty_b = _make_button("B 空に")
	empty_b.pressed.connect(_empty.bind("B"))
	controls_grid.add_child(empty_b)

	var quick = HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	side.add_child(quick)
	var new_button = _make_button("NEW PUZZLE", true)
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_button.pressed.connect(_new_puzzle)
	quick.add_child(new_button)
	var reset_button = _make_button("RESET")
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_reset_game)
	quick.add_child(reset_button)

	best_label = Label.new()
	best_label.text = "BEST —"
	best_label.add_theme_color_override("font_color", Color("#c4b5fd"))
	best_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(best_label)

	result_panel = PanelContainer.new()
	result_panel.visible = false
	result_panel.add_theme_stylebox_override("panel", _style(Color("#052e2b"), Color("#2dd4bf"), 14))
	side.add_child(result_panel)
	var result_box = VBoxContainer.new()
	result_panel.add_child(result_box)
	result_title = Label.new()
	result_title.text = "CLEAR!"
	result_title.add_theme_font_size_override("font_size", 22)
	result_title.add_theme_color_override("font_color", Color("#5eead4"))
	result_box.add_child(result_title)
	result_detail = Label.new()
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_box.add_child(result_detail)

func _make_stat(parent: GridContainer, title: String, value: String) -> Label:
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t = Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 10)
	t.add_theme_color_override("font_color", Color("#64748b"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var v = Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 19)
	v.add_theme_color_override("font_color", Color("#f8fafc"))
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(v)
	parent.add_child(box)
	return v

func _apply_responsive_layout() -> void:
	if root_margin == null or content_grid == null:
		return
	var s = get_viewport_rect().size
	var landscape = s.x > s.y and s.y < 650
	var margin = 8 if landscape else 12
	for key in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		root_margin.add_theme_constant_override(key, margin)
	content_grid.columns = 2 if landscape or s.x >= 900 else 1
	board.custom_minimum_size = Vector2(250, 225 if landscape else 255)
	controls_grid.columns = 3 if s.x >= 360 else 2
	objective_label.visible = not (landscape and s.y <= 420)

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	tone_action = _make_tone(420.0, 0.06, 0.12)
	tone_pour = _make_tone(610.0, 0.10, 0.13)
	tone_clear = _make_tone(940.0, 0.25, 0.18)

func _make_tone(freq: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var rate = 22050
	var frames = int(float(rate) * duration)
	var data = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var env = 1.0 - (float(i) / maxf(1.0, float(frames)))
		var wave = sin(TAU * freq * float(i) / float(rate))
		var sample = int(clamp(wave * env * amplitude, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream = AudioStreamWAV.new()
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

func _cycle_difficulty() -> void:
	difficulty_index = (difficulty_index + 1) % DIFFICULTIES.size()
	difficulty_button.text = DIFFICULTY_LABELS[difficulty_index]
	_new_puzzle()

func _toggle_sound() -> void:
	sound_on = not sound_on
	sound_button.text = "SOUND ON" if sound_on else "SOUND OFF"
	if sound_on:
		_play(tone_action)
	_update_debug_bridge()

func _new_puzzle() -> void:
	result_panel.visible = false
	phase = "idle"
	moves = 0
	elapsed_ms = 0
	amount_a = 0
	amount_b = 0
	selected_jug = ""
	var diff = DIFFICULTIES[difficulty_index]
	if qa_mode and diff == "easy":
		cap_a = 3
		cap_b = 5
		target = 4
		optimal = 6
	else:
		var p = _generate_puzzle(diff)
		cap_a = int(p["a"])
		cap_b = int(p["b"])
		target = int(p["target"])
		optimal = int(p["optimal"])
	last_action = "NEW %s" % DIFFICULTY_LABELS[difficulty_index]
	feedback_label.text = "目標 %dL — A:%dL / B:%dL。最短 %d手。" % [target, cap_a, cap_b, optimal]
	move_label.text = "0"
	time_label.text = "0.0s"
	optimal_label.text = str(optimal)
	_update_best()
	board.set_state(cap_a, cap_b, 0.0, 0.0, target, selected_jug)
	_update_debug_bridge()

func _generate_puzzle(diff: String) -> Dictionary:
	var a_min = 3
	var a_max = 8
	var b_min = 4
	var b_max = 10
	var min_ok = 3
	var max_ok = 10
	if diff == "normal":
		a_min = 5; a_max = 12; b_min = 6; b_max = 16; min_ok = 4; max_ok = 16
	elif diff == "hard":
		a_min = 8; a_max = 20; b_min = 10; b_max = 28; min_ok = 5; max_ok = 22
	for _i in range(500):
		var ca = rng.randi_range(a_min, a_max)
		var cb = rng.randi_range(b_min, b_max)
		if ca == cb or absi(ca - cb) <= 1:
			continue
		var g = _gcd(ca, cb)
		var candidates: Array[int] = []
		for t in range(g, maxi(ca, cb) + 1, g):
			if t != ca and t != cb:
				candidates.append(t)
		if candidates.is_empty():
			continue
		var goal = candidates[rng.randi_range(0, candidates.size() - 1)]
		var opt = _shortest_steps(ca, cb, goal)
		if opt >= min_ok and opt <= max_ok:
			return {"a": ca, "b": cb, "target": goal, "optimal": opt}
	return {"a": 3, "b": 5, "target": 4, "optimal": 6}

func _gcd(a: int, b: int) -> int:
	var x = a
	var y = b
	while y != 0:
		var t = x % y
		x = y
		y = t
	return absi(x)

func _shortest_steps(ca: int, cb: int, goal: int) -> int:
	var queue: Array[Vector3i] = [Vector3i(0, 0, 0)]
	var seen: Dictionary = {"0,0": true}
	while not queue.is_empty():
		var cur = queue.pop_front()
		if cur.x == goal or cur.y == goal:
			return cur.z
		var nexts: Array[Vector2i] = []
		nexts.append(Vector2i(ca, cur.y))
		nexts.append(Vector2i(cur.x, cb))
		nexts.append(Vector2i(0, cur.y))
		nexts.append(Vector2i(cur.x, 0))
		var moved_ab = mini(cur.x, cb - cur.y)
		nexts.append(Vector2i(cur.x - moved_ab, cur.y + moved_ab))
		var moved_ba = mini(cur.y, ca - cur.x)
		nexts.append(Vector2i(cur.x + moved_ba, cur.y - moved_ba))
		for n in nexts:
			var key = "%d,%d" % [n.x, n.y]
			if seen.has(key):
				continue
			seen[key] = true
			queue.append(Vector3i(n.x, n.y, cur.z + 1))
	return -1

func _start_game() -> void:
	if phase == "playing":
		return
	result_panel.visible = false
	phase = "playing"
	moves = 0
	amount_a = 0
	amount_b = 0
	selected_jug = ""
	start_ms = Time.get_ticks_msec()
	elapsed_ms = 0
	last_action = "START"
	feedback_label.text = "START — まず容器を満たすか、容器をタップして選択。"
	_animate_board()
	_update_stats()
	_play(tone_action)
	_update_debug_bridge()

func _reset_game() -> void:
	result_panel.visible = false
	phase = "playing"
	moves = 0
	amount_a = 0
	amount_b = 0
	selected_jug = ""
	start_ms = Time.get_ticks_msec()
	elapsed_ms = 0
	last_action = "RESET"
	feedback_label.text = "RESET — 同じ問題を最初から。"
	_animate_board()
	_update_stats()
	_play(tone_action)
	_update_debug_bridge()

func _ensure_playing() -> bool:
	if phase == "idle":
		_start_game()
	return phase == "playing"

func _fill(which: String) -> void:
	if not _ensure_playing():
		return
	if which == "A":
		if amount_a == cap_a: return
		amount_a = cap_a
	else:
		if amount_b == cap_b: return
		amount_b = cap_b
	selected_jug = which
	_commit_move("%s を満たした" % which, false)

func _empty(which: String) -> void:
	if not _ensure_playing():
		return
	if which == "A":
		if amount_a == 0: return
		amount_a = 0
	else:
		if amount_b == 0: return
		amount_b = 0
	selected_jug = which
	_commit_move("%s を空にした" % which, false)

func _pour(direction: String) -> void:
	if not _ensure_playing():
		return
	var changed = false
	if direction == "AtoB":
		var moved = mini(amount_a, cap_b - amount_b)
		if moved > 0:
			amount_a -= moved
			amount_b += moved
			selected_jug = "B"
			changed = true
	else:
		var moved = mini(amount_b, cap_a - amount_a)
		if moved > 0:
			amount_b -= moved
			amount_a += moved
			selected_jug = "A"
			changed = true
	if not changed:
		return
	_commit_move("水を %s へ移した" % selected_jug, true)

func _select_jug(which: String) -> void:
	selected_jug = which
	board.set_state(cap_a, cap_b, board.amount_a, board.amount_b, target, selected_jug)
	feedback_label.text = "%s を選択 — SPACEで相手へ注ぐ。" % which
	last_action = "SELECT_" + which
	_play(tone_action)
	_update_debug_bridge()

func _pour_selected() -> void:
	if selected_jug == "A":
		_pour("AtoB")
	elif selected_jug == "B":
		_pour("BtoA")

func _on_board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var e := event as InputEventMouseButton
		_select_jug("A" if e.position.x < board.size.x * 0.5 else "B")
	elif event is InputEventScreenTouch and event.pressed:
		var t := event as InputEventScreenTouch
		_select_jug("A" if t.position.x < board.size.x * 0.5 else "B")

func _commit_move(message: String, is_pour: bool) -> void:
	moves += 1
	last_action = message
	feedback_label.text = "%s — A:%d / B:%d" % [message, amount_a, amount_b]
	_update_stats()
	_animate_board()
	_play(tone_pour if is_pour else tone_action)
	_check_finish()
	_update_debug_bridge()

func _animate_board() -> void:
	if board == null:
		return
	var tween = create_tween().set_parallel(true)
	tween.tween_method(Callable(self, "_anim_a"), board.amount_a, float(amount_a), 0.25)
	tween.tween_method(Callable(self, "_anim_b"), board.amount_b, float(amount_b), 0.25)
	board.cap_a = cap_a
	board.cap_b = cap_b
	board.target = target
	board.selected = selected_jug
	board.queue_redraw()

func _anim_a(v: float) -> void:
	board.amount_a = v
	board.queue_redraw()

func _anim_b(v: float) -> void:
	board.amount_b = v
	board.queue_redraw()

func _update_stats() -> void:
	move_label.text = str(moves)
	optimal_label.text = str(optimal)
	if phase != "playing":
		time_label.text = "%.1fs" % (float(elapsed_ms) / 1000.0)

func _check_finish() -> void:
	if amount_a != target and amount_b != target:
		return
	phase = "result"
	elapsed_ms = Time.get_ticks_msec() - start_ms
	time_label.text = "%.1fs" % (float(elapsed_ms) / 1000.0)
	var delta = moves - optimal
	var rank = "S" if delta <= 0 else ("A" if delta <= 2 else ("B" if delta <= 5 else "C"))
	result_title.text = "CLEAR!  RANK %s" % rank
	result_detail.text = "%d手 / 最短%d手 / %.1fs — 目標%dLを作りました。" % [moves, optimal, float(elapsed_ms) / 1000.0, target]
	result_panel.visible = true
	feedback_label.text = "CLEAR — NEW PUZZLEで次の問題へ。"
	last_action = "CLEAR"
	_record_best()
	_play(tone_clear)
	_update_debug_bridge()

func _record_best() -> void:
	var key = DIFFICULTIES[difficulty_index]
	var cur = {"moves": moves, "time_ms": elapsed_ms, "a": cap_a, "b": cap_b, "target": target}
	var prev = best_records.get(key, null)
	var better = prev == null or moves < int(prev.get("moves", 9999)) or (moves == int(prev.get("moves", 9999)) and elapsed_ms < int(prev.get("time_ms", 99999999)))
	if better:
		best_records[key] = cur
		_save_storage()
	_update_best()

func _update_best() -> void:
	var key = DIFFICULTIES[difficulty_index]
	var rec = best_records.get(key, null)
	if rec == null:
		best_label.text = "BEST — %s はまだ記録なし" % DIFFICULTY_LABELS[difficulty_index]
	else:
		best_label.text = "BEST — %d手 / %.1fs" % [int(rec.get("moves", 0)), float(rec.get("time_ms", 0)) / 1000.0]

func _go_hub() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';", true)

func _update_debug_bridge() -> void:
	if OS.get_name() != "Web":
		return
	var payload = {
		"ready": true,
		"engine": "Godot",
		"build": BUILD_ID,
		"qa_mode": qa_mode,
		"viewport_w": int(get_viewport_rect().size.x),
		"viewport_h": int(get_viewport_rect().size.y),
		"difficulty": DIFFICULTIES[difficulty_index],
		"cap_a": cap_a,
		"cap_b": cap_b,
		"target": target,
		"amount_a": amount_a,
		"amount_b": amount_b,
		"moves": moves,
		"optimal": optimal,
		"phase": phase,
		"sound": sound_on,
		"selected": selected_jug,
		"last_action": last_action,
		"finished": phase == "result"
	}
	JavaScriptBridge.eval("window.__P021_WATER_JUG = %s;" % JSON.stringify(payload), true)
