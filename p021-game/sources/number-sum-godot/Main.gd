extends Control

const BoardViewScript = preload("res://BoardView.gd")

var puzzle_sets: Dictionary = {}
var current_puzzle: Dictionary = {}
var current_difficulty := "easy"
var puzzle_cursor := {"easy": 0, "normal": 0, "hard": 0}
var state: Array = []
var active_mode := 1
var hints_used := 0
var start_ms := 0
var won := false
var muted := false
var best_times: Dictionary = {}
var elapsed_cache := -1
var all_fixed_warned := false

var ui_font: Font
var root_margin: MarginContainer
var content_grid: GridContainer
var board_card: PanelContainer
var side_card: PanelContainer
var board
var timer_label: Label
var remaining_label: Label
var best_label: Label
var status_label: Label
var mode_include: Button
var mode_exclude: Button
var sound_button: Button
var difficulty_buttons := {}
var win_layer: Control
var win_time_label: Label
var win_best_label: Label
var win_title_label: Label

var audio_player: AudioStreamPlayer
var tone_select: AudioStreamWAV
var tone_exclude: AudioStreamWAV
var tone_success: AudioStreamWAV
var tone_error: AudioStreamWAV

func _ready() -> void:
	_load_font()
	_load_puzzles()
	_load_save()
	_build_ui()
	_setup_audio()
	_start_puzzle("easy", false)
	set_process(true)
	call_deferred("_apply_responsive_layout")
	call_deferred("_update_debug_bridge")

func _process(_delta: float) -> void:
	if start_ms <= 0 or won:
		return
	var elapsed := _elapsed_seconds()
	if elapsed != elapsed_cache:
		elapsed_cache = elapsed
		_update_stats()
		if elapsed % 2 == 0:
			_update_debug_bridge()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_apply_responsive_layout")
		call_deferred("_update_debug_bridge")

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_start_puzzle("easy", false)
		KEY_2:
			_start_puzzle("normal", false)
		KEY_3:
			_start_puzzle("hard", false)
		KEY_M:
			_set_mode(-1 if active_mode == 1 else 1)
		KEY_R:
			_reset_puzzle()
		KEY_N:
			_start_puzzle(current_difficulty, true)
		KEY_H:
			_use_hint()
		_:
			return
	get_viewport().set_input_as_handled()

func _load_font() -> void:
	var loaded = load("res://fonts/NotoSansJP.ttf")
	if loaded is Font:
		ui_font = loaded
	else:
		ui_font = ThemeDB.fallback_font

func _load_puzzles() -> void:
	var raw := FileAccess.get_file_as_string("res://puzzles.json")
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Number Sum puzzle library could not be parsed")
		puzzle_sets = {}
		return
	puzzle_sets = parsed

func _load_save() -> void:
	if not FileAccess.file_exists("user://number-sum-save.json"):
		best_times = {}
		return
	var raw := FileAccess.get_file_as_string("user://number-sum-save.json")
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		best_times = parsed.get("best_times", {})
	else:
		best_times = {}

func _save_data() -> void:
	var file := FileAccess.open("user://number-sum-save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"best_times": best_times}))

func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 15
	self.theme = theme

	var bg := ColorRect.new()
	bg.color = Color("#071222")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	var glow_a := ColorRect.new()
	glow_a.color = Color("#0a2740")
	glow_a.set_anchors_preset(Control.PRESET_TOP_LEFT)
	glow_a.position = Vector2(-120, -120)
	glow_a.size = Vector2(420, 280)
	glow_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow_a)
	move_child(glow_a, 1)

	root_margin = MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 12)
	root_margin.add_theme_constant_override("margin_right", 12)
	root_margin.add_theme_constant_override("margin_top", 10)
	root_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(root_margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	root_margin.add_child(main)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 46)
	top.add_theme_constant_override("separation", 8)
	main.add_child(top)

	var home := _make_button("HUB", "ghost")
	home.custom_minimum_size = Vector2(58, 42)
	home.pressed.connect(_go_home)
	top.add_child(home)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", -2)
	top.add_child(title_box)

	var title := Label.new()
	title.text = "NUMBER SUM"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f8fbff"))
	title_box.add_child(title)

	var sub := Label.new()
	sub.text = "数字を選び、すべての合計を一致させる"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color("#8da8c9"))
	title_box.add_child(sub)

	sound_button = _make_button("SOUND ON", "ghost")
	sound_button.custom_minimum_size = Vector2(92, 42)
	sound_button.pressed.connect(_toggle_sound)
	top.add_child(sound_button)

	content_grid = GridContainer.new()
	content_grid.columns = 1
	content_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_grid.add_theme_constant_override("h_separation", 10)
	content_grid.add_theme_constant_override("v_separation", 10)
	main.add_child(content_grid)

	board_card = PanelContainer.new()
	board_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_card.add_theme_stylebox_override("panel", _panel_style(Color("#0a1728"), Color("#24415f"), 18, 1))
	content_grid.add_child(board_card)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 8)
	board_margin.add_theme_constant_override("margin_right", 8)
	board_margin.add_theme_constant_override("margin_top", 8)
	board_margin.add_theme_constant_override("margin_bottom", 8)
	board_card.add_child(board_margin)

	board = BoardViewScript.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.set_font(ui_font)
	board.cell_tapped.connect(_on_board_cell_tapped)
	board_margin.add_child(board)

	side_card = PanelContainer.new()
	side_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_card.add_theme_stylebox_override("panel", _panel_style(Color("#0b1b30"), Color("#254766"), 18, 1))
	content_grid.add_child(side_card)

	var side_margin := MarginContainer.new()
	side_margin.add_theme_constant_override("margin_left", 14)
	side_margin.add_theme_constant_override("margin_right", 14)
	side_margin.add_theme_constant_override("margin_top", 12)
	side_margin.add_theme_constant_override("margin_bottom", 12)
	side_card.add_child(side_margin)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side_margin.add_child(side)

	var kicker := Label.new()
	kicker.text = "SUM LOGIC / UNIQUE PUZZLE"
	kicker.add_theme_font_size_override("font_size", 10)
	kicker.add_theme_color_override("font_color", Color("#67e8f9"))
	side.add_child(kicker)

	var how := Label.new()
	how.text = "行・列・色エリアの『現在 / 目標』をすべて一致させます。数字を採用するか、除外するかを判断してください。"
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.add_theme_font_size_override("font_size", 12)
	how.add_theme_color_override("font_color", Color("#c2d2e6"))
	side.add_child(how)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 5)
	side.add_child(diff_row)
	for diff in ["easy", "normal", "hard"]:
		var label: String = str({"easy":"EASY 5x5", "normal":"NORMAL 6x6", "hard":"HARD 7x7"}[diff])
		var btn := _make_button(label, "segment")
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(func(): _start_puzzle(diff, false))
		difficulty_buttons[diff] = btn
		diff_row.add_child(btn)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	side.add_child(stats)
	timer_label = _make_stat_label("TIME 0:00")
	remaining_label = _make_stat_label("LEFT 0")
	best_label = _make_stat_label("BEST --")
	stats.add_child(timer_label)
	stats.add_child(remaining_label)
	stats.add_child(best_label)

	var mode_title := Label.new()
	mode_title.text = "CELL MODE  /  キー M で切替"
	mode_title.add_theme_font_size_override("font_size", 10)
	mode_title.add_theme_color_override("font_color", Color("#7696bb"))
	side.add_child(mode_title)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	side.add_child(mode_row)
	mode_include = _make_button("採用  +", "primary")
	mode_include.toggle_mode = true
	mode_include.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_include.custom_minimum_size = Vector2(0, 42)
	mode_include.pressed.connect(func(): _set_mode(1))
	mode_row.add_child(mode_include)
	mode_exclude = _make_button("除外  x", "danger")
	mode_exclude.toggle_mode = true
	mode_exclude.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_exclude.custom_minimum_size = Vector2(0, 42)
	mode_exclude.pressed.connect(func(): _set_mode(-1))
	mode_row.add_child(mode_exclude)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	side.add_child(action_row)
	var new_btn := _make_button("NEW", "secondary")
	var reset_btn := _make_button("RESET", "secondary")
	var hint_btn := _make_button("HINT", "secondary")
	for btn in [new_btn, reset_btn, hint_btn]:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 40)
		action_row.add_child(btn)
	new_btn.pressed.connect(func(): _start_puzzle(current_difficulty, true))
	reset_btn.pressed.connect(_reset_puzzle)
	hint_btn.pressed.connect(_use_hint)

	status_label = Label.new()
	status_label.text = "数字をタップして始めよう"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("#d7e8fb"))
	status_label.custom_minimum_size = Vector2(0, 34)
	side.add_child(status_label)

	var keys := Label.new()
	keys.text = "KEYS  1/2/3:難易度  R:Reset  N:New  H:Hint"
	keys.add_theme_font_size_override("font_size", 9)
	keys.add_theme_color_override("font_color", Color("#627f9f"))
	side.add_child(keys)

	_build_win_layer()
	_set_mode(1)

func _build_win_layer() -> void:
	win_layer = Control.new()
	win_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.visible = false
	add_child(win_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.09, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	win_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 236)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0b2031"), Color("#4de3c2"), 22, 2))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)

	win_title_label = Label.new()
	win_title_label.text = "CLEAR!"
	win_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_title_label.add_theme_font_size_override("font_size", 28)
	win_title_label.add_theme_color_override("font_color", Color("#5eead4"))
	box.add_child(win_title_label)

	win_time_label = Label.new()
	win_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_time_label.add_theme_font_size_override("font_size", 16)
	win_time_label.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(win_time_label)

	win_best_label = Label.new()
	win_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_best_label.add_theme_font_size_override("font_size", 12)
	win_best_label.add_theme_color_override("font_color", Color("#9db5d2"))
	box.add_child(win_best_label)

	var win_actions := HBoxContainer.new()
	win_actions.add_theme_constant_override("separation", 8)
	box.add_child(win_actions)
	var replay := _make_button("REPLAY", "secondary")
	var next := _make_button("NEXT", "primary")
	replay.custom_minimum_size = Vector2(112, 42)
	next.custom_minimum_size = Vector2(112, 42)
	replay.pressed.connect(_reset_puzzle)
	next.pressed.connect(func(): _start_puzzle(current_difficulty, true))
	win_actions.add_child(replay)
	win_actions.add_child(next)

func _apply_responsive_layout() -> void:
	if content_grid == null:
		return
	var viewport_size := get_viewport_rect().size
	var landscape := viewport_size.x > viewport_size.y * 1.28 and viewport_size.y <= 560
	content_grid.columns = 2 if landscape else 1
	if landscape:
		board_card.custom_minimum_size = Vector2(maxf(390.0, viewport_size.x * 0.56), 0)
		side_card.custom_minimum_size = Vector2(270, 0)
		root_margin.add_theme_constant_override("margin_left", 10)
		root_margin.add_theme_constant_override("margin_right", 10)
		root_margin.add_theme_constant_override("margin_top", 7)
		root_margin.add_theme_constant_override("margin_bottom", 7)
	else:
		board_card.custom_minimum_size = Vector2(0, minf(500.0, maxf(355.0, viewport_size.y * 0.49)))
		side_card.custom_minimum_size = Vector2(0, 236)
		root_margin.add_theme_constant_override("margin_left", 12)
		root_margin.add_theme_constant_override("margin_right", 12)
		root_margin.add_theme_constant_override("margin_top", 10)
		root_margin.add_theme_constant_override("margin_bottom", 10)

func _start_puzzle(difficulty: String, advance: bool) -> void:
	if not puzzle_sets.has(difficulty):
		return
	current_difficulty = difficulty
	var list: Array = puzzle_sets[difficulty]
	if list.is_empty():
		return
	if advance:
		puzzle_cursor[difficulty] = (int(puzzle_cursor[difficulty]) + 1) % list.size()
	var cursor := int(puzzle_cursor[difficulty]) % list.size()
	current_puzzle = list[cursor].duplicate(true)
	var n := int(current_puzzle.get("N", 0))
	state = []
	state.resize(n * n)
	state.fill(0)
	active_mode = 1
	hints_used = 0
	won = false
	all_fixed_warned = false
	start_ms = Time.get_ticks_msec()
	elapsed_cache = -1
	if win_layer:
		win_layer.visible = false
	board.set_puzzle(current_puzzle, state)
	_set_mode(1)
	_update_difficulty_buttons()
	_update_feedback()
	_play_tone(tone_select)
	call_deferred("_update_debug_bridge")

func _reset_puzzle() -> void:
	if current_puzzle.is_empty():
		return
	var n := int(current_puzzle["N"])
	state.resize(n * n)
	state.fill(0)
	hints_used = 0
	won = false
	all_fixed_warned = false
	start_ms = Time.get_ticks_msec()
	elapsed_cache = -1
	if win_layer:
		win_layer.visible = false
	board.set_puzzle(current_puzzle, state)
	status_label.text = "リセットしました。もう一度どうぞ。"
	_play_tone(tone_select)
	_update_stats()
	_update_debug_bridge()

func _on_board_cell_tapped(index: int) -> void:
	if won or index < 0 or index >= state.size():
		return
	if int(state[index]) == active_mode:
		state[index] = 0
	else:
		state[index] = active_mode
	board.refresh(state)
	board.animate_cell(index)
	_play_tone(tone_select if active_mode == 1 else tone_exclude)
	_update_feedback()

func _set_mode(next_mode: int) -> void:
	active_mode = 1 if next_mode >= 0 else -1
	if mode_include:
		mode_include.set_pressed_no_signal(active_mode == 1)
	if mode_exclude:
		mode_exclude.set_pressed_no_signal(active_mode == -1)
	if status_label and not won:
		status_label.text = "採用モード: 数字を合計に入れる" if active_mode == 1 else "除外モード: 数字を合計に入れない"
	_update_debug_bridge()

func _use_hint() -> void:
	if won or current_puzzle.is_empty():
		return
	var solution: Array = current_puzzle.get("solution", [])
	for i in range(state.size()):
		if int(state[i]) == 0:
			state[i] = 1 if int(solution[i]) == 1 else -1
			hints_used += 1
			board.refresh(state)
			board.animate_cell(i)
			status_label.text = "ヒントを1マス反映しました（記録に +5秒）"
			_play_tone(tone_select)
			_update_feedback()
			return
	status_label.text = "未確定マスはありません。合計を見直してみよう。"
	_play_tone(tone_error)

func _update_feedback() -> void:
	var sums := _compute_sums()
	var matched := 0
	var total := 0
	var any_over := false
	var row_targets: Array = current_puzzle.get("row_targets", [])
	var col_targets: Array = current_puzzle.get("col_targets", [])
	var reg_targets: Array = current_puzzle.get("region_targets", [])
	for i in range(row_targets.size()):
		total += 1
		if int(sums["rows"][i]) == int(row_targets[i]):
			matched += 1
		elif int(sums["rows"][i]) > int(row_targets[i]):
			any_over = true
	for i in range(col_targets.size()):
		total += 1
		if int(sums["cols"][i]) == int(col_targets[i]):
			matched += 1
		elif int(sums["cols"][i]) > int(col_targets[i]):
			any_over = true
	for i in range(reg_targets.size()):
		total += 1
		if int(sums["regions"][i]) == int(reg_targets[i]):
			matched += 1
		elif int(sums["regions"][i]) > int(reg_targets[i]):
			any_over = true

	var unknown := _count_state(0)
	if unknown > 0:
		if any_over:
			status_label.text = "合計オーバーあり。赤い目標を見直そう。  MATCH %d/%d" % [matched, total]
		else:
			status_label.text = "順調です。目標一致 %d/%d  /  残り %dマス" % [matched, total, unknown]
	else:
		if matched == total:
			_finish_game()
			return
		if not all_fixed_warned:
			_play_tone(tone_error)
			all_fixed_warned = true
		status_label.text = "全マス確定。でも合計が違います。赤い目標を修正しよう。"
	_update_stats()
	board.queue_redraw()
	_update_debug_bridge()

func _finish_game() -> void:
	if won:
		return
	won = true
	var elapsed := _elapsed_seconds()
	var adjusted := elapsed + hints_used * 5
	var key := current_difficulty
	var prev := int(best_times.get(key, 0))
	var is_best := prev <= 0 or adjusted < prev
	if is_best:
		best_times[key] = adjusted
		_save_data()
	_play_tone(tone_success)
	status_label.text = "CLEAR! 全ての合計が一致しました。"
	win_time_label.text = "TIME  %s   /   HINT %d" % [_format_time(elapsed), hints_used]
	win_best_label.text = ("NEW BEST  %s" % _format_time(adjusted)) if is_best else ("BEST  %s" % _format_time(prev))
	win_title_label.text = "PERFECT SUM"
	win_layer.visible = true
	win_layer.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(win_layer, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_update_stats()
	_update_debug_bridge()

func _compute_sums() -> Dictionary:
	var n := int(current_puzzle.get("N", 0))
	var rows := []
	var cols := []
	var reg_targets: Array = current_puzzle.get("region_targets", [])
	var regions := []
	rows.resize(n)
	cols.resize(n)
	regions.resize(reg_targets.size())
	rows.fill(0)
	cols.fill(0)
	regions.fill(0)
	var numbers: Array = current_puzzle.get("numbers", [])
	var region_ids: Array = current_puzzle.get("regions", [])
	for r in range(n):
		for c in range(n):
			var idx := r * n + c
			if idx < state.size() and int(state[idx]) == 1:
				var value := int(numbers[r][c])
				rows[r] += value
				cols[c] += value
				regions[int(region_ids[r][c])] += value
	return {"rows": rows, "cols": cols, "regions": regions}

func _count_state(value: int) -> int:
	var count := 0
	for item in state:
		if int(item) == value:
			count += 1
	return count

func _update_stats() -> void:
	if timer_label == null:
		return
	var elapsed := _elapsed_seconds()
	timer_label.text = "TIME " + _format_time(elapsed)
	remaining_label.text = "LEFT %d" % _count_state(0)
	var best := int(best_times.get(current_difficulty, 0))
	best_label.text = "BEST --" if best <= 0 else ("BEST " + _format_time(best))

func _update_difficulty_buttons() -> void:
	for key in difficulty_buttons.keys():
		var button: Button = difficulty_buttons[key]
		button.set_pressed_no_signal(str(key) == current_difficulty)

func _elapsed_seconds() -> int:
	if start_ms <= 0:
		return 0
	return maxi(0, int((Time.get_ticks_msec() - start_ms) / 1000))

func _format_time(seconds: int) -> String:
	return "%d:%02d" % [int(seconds / 60), seconds % 60]

func _toggle_sound() -> void:
	muted = not muted
	sound_button.text = "SOUND OFF" if muted else "SOUND ON"
	if not muted:
		_play_tone(tone_select)
	_update_debug_bridge()

func _go_home() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';", true)

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	tone_select = _make_tone(520.0, 0.055, 0.20)
	tone_exclude = _make_tone(315.0, 0.07, 0.18)
	tone_success = _make_tone(760.0, 0.22, 0.24)
	tone_error = _make_tone(170.0, 0.11, 0.20)

func _make_tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	wave.stereo = false
	var frames := int(wave.mix_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(wave.mix_rate)
		var attack := minf(1.0, t / 0.008)
		var release := minf(1.0, (duration - t) / 0.025)
		var envelope := clampf(attack * release, 0.0, 1.0)
		var sample := int(sin(TAU * frequency * t) * 32767.0 * amplitude * envelope)
		if sample < 0:
			sample += 65536
		bytes[i * 2] = sample & 0xff
		bytes[i * 2 + 1] = (sample >> 8) & 0xff
	wave.data = bytes
	return wave

func _play_tone(stream: AudioStreamWAV) -> void:
	if muted or audio_player == null or stream == null:
		return
	audio_player.stream = stream
	audio_player.play()

func _make_stat_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, 34)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#cce2fa"))
	label.add_theme_stylebox_override("normal", _panel_style(Color("#0e2840"), Color("#224965"), 9, 1))
	return label

func _make_button(text_value: String, kind: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#f5f9ff"))
	var normal_bg := Color("#12304b")
	var hover_bg := Color("#194263")
	var pressed_bg := Color("#1f5a78")
	var border := Color("#2a5475")
	if kind == "primary":
		normal_bg = Color("#0f766e")
		hover_bg = Color("#0d9488")
		pressed_bg = Color("#115e59")
		border = Color("#5eead4")
	elif kind == "danger":
		normal_bg = Color("#512235")
		hover_bg = Color("#713047")
		pressed_bg = Color("#3c1828")
		border = Color("#fb7185")
	elif kind == "ghost":
		normal_bg = Color("#0b1b2c")
		hover_bg = Color("#112a43")
		pressed_bg = Color("#173654")
		border = Color("#294863")
	elif kind == "segment":
		normal_bg = Color("#10253a")
		hover_bg = Color("#173652")
		pressed_bg = Color("#0e7490")
		border = Color("#31526d")
	button.add_theme_stylebox_override("normal", _panel_style(normal_bg, border, 10, 1))
	button.add_theme_stylebox_override("hover", _panel_style(hover_bg, border.lightened(0.18), 10, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(pressed_bg, border.lightened(0.28), 10, 2))
	button.add_theme_stylebox_override("focus", _panel_style(normal_bg, Color("#67e8f9"), 10, 2))
	return button

func _panel_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _update_debug_bridge() -> void:
	if OS.get_name() != "Web" or board == null:
		return
	var point: Vector2 = board.get_test_cell_global(0)
	var vp := get_viewport_rect().size
	var payload := {
		"ready": not current_puzzle.is_empty(),
		"engine": "Godot",
		"build": "GAME-056",
		"difficulty": current_difficulty,
		"n": int(current_puzzle.get("N", 0)),
		"mode": "include" if active_mode == 1 else "exclude",
		"selected_count": _count_state(1),
		"excluded_count": _count_state(-1),
		"unknown_count": _count_state(0),
		"hints": hints_used,
		"won": won,
		"muted": muted,
		"elapsed": _elapsed_seconds(),
		"viewport_w": vp.x,
		"viewport_h": vp.y,
		"test_cell_x": point.x,
		"test_cell_y": point.y
	}
	var js := "window.__P021_NUMBER_SUM = " + JSON.stringify(payload) + ";"
	JavaScriptBridge.eval(js, true)
