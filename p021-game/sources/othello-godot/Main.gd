extends Control

const BoardViewScript = preload("res://BoardView.gd")

const SIZE := 8
const EMPTY := 0
const BLACK := 1
const WHITE := -1
const DIRS := [
	Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
	Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)
]

var board: Array = []
var turn := BLACK
var human_color := BLACK
var cpu_color := WHITE
var human_first := true
var difficulty := 3
var busy := false
var finished := false
var show_hints := true
var muted := false
var move_count := 0
var last_move := Vector2i(-1, -1)
var qa_mode := false
var record := {"win": 0, "lose": 0, "draw": 0}

var ui_font: Font
var root_margin: MarginContainer
var content_grid: GridContainer
var board_card: PanelContainer
var side_card: PanelContainer
var board_view
var turn_label: Label
var black_label: Label
var white_label: Label
var status_label: Label
var record_label: Label
var sound_button: Button
var hints_button: Button
var starter_buttons := {}
var difficulty_buttons := {}
var result_layer: Control
var result_title: Label
var result_score: Label
var result_sub: Label

var audio_player: AudioStreamPlayer
var tone_place: AudioStreamWAV
var tone_flip: AudioStreamWAV
var tone_error: AudioStreamWAV
var tone_win: AudioStreamWAV

func _ready() -> void:
	_load_font()
	_load_record()
	if OS.get_name() == "Web":
		var value = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa') === '1'", true)
		qa_mode = bool(value)
	_build_ui()
	_setup_audio()
	_start_new_game()
	set_process(true)
	call_deferred("_apply_responsive_layout")
	call_deferred("_update_debug_bridge")

func _process(_delta: float) -> void:
	if OS.get_name() == "Web":
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
			_set_difficulty(3)
		KEY_2:
			_set_difficulty(4)
		KEY_3:
			_set_difficulty(5)
		KEY_S:
			_set_starter(not human_first)
		KEY_M:
			_toggle_hints()
		KEY_R:
			_start_new_game()
		KEY_F:
			if qa_mode:
				_qa_autoplay_finish()
			else:
				return
		_:
			return
	get_viewport().set_input_as_handled()

func _load_font() -> void:
	var loaded = load("res://fonts/NotoSansJP.ttf")
	if loaded is Font:
		ui_font = loaded
	else:
		ui_font = ThemeDB.fallback_font

func _load_record() -> void:
	if not FileAccess.file_exists("user://othello-record.json"):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://othello-record.json"))
	if typeof(parsed) == TYPE_DICTIONARY:
		record = parsed

func _save_record() -> void:
	var file := FileAccess.open("user://othello-record.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(record))

func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 15
	self.theme = theme

	var bg := ColorRect.new()
	bg.color = Color("#041c18")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var glow := ColorRect.new()
	glow.color = Color("#073d33")
	glow.position = Vector2(-120, -100)
	glow.size = Vector2(470, 260)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

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
	top.custom_minimum_size = Vector2(0, 48)
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
	title.text = "OTHELLO"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#f4fffb"))
	title_box.add_child(title)

	var sub := Label.new()
	sub.text = "8x8 / CPU MATCH / GODOT"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color("#77c7b2"))
	title_box.add_child(sub)

	sound_button = _make_button("SOUND ON", "ghost")
	sound_button.custom_minimum_size = Vector2(92, 42)
	sound_button.pressed.connect(_toggle_sound)
	top.add_child(sound_button)

	content_grid = GridContainer.new()
	content_grid.columns = 1
	content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.add_theme_constant_override("h_separation", 10)
	content_grid.add_theme_constant_override("v_separation", 10)
	main.add_child(content_grid)

	board_card = PanelContainer.new()
	board_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_card.add_theme_stylebox_override("panel", _panel_style(Color("#062a24"), Color("#1e6b5b"), 18, 1))
	content_grid.add_child(board_card)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 8)
	board_margin.add_theme_constant_override("margin_right", 8)
	board_margin.add_theme_constant_override("margin_top", 8)
	board_margin.add_theme_constant_override("margin_bottom", 8)
	board_card.add_child(board_margin)

	board_view = BoardViewScript.new()
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.set_font(ui_font)
	board_view.cell_tapped.connect(_on_board_cell_tapped)
	board_margin.add_child(board_view)

	side_card = PanelContainer.new()
	side_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_card.add_theme_stylebox_override("panel", _panel_style(Color("#071f1c"), Color("#1d594d"), 18, 1))
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
	kicker.text = "TACTICAL BOARD / CPU DUEL"
	kicker.add_theme_font_size_override("font_size", 10)
	kicker.add_theme_color_override("font_color", Color("#5eead4"))
	side.add_child(kicker)

	turn_label = Label.new()
	turn_label.text = "YOUR TURN / BLACK"
	turn_label.add_theme_font_size_override("font_size", 17)
	turn_label.add_theme_color_override("font_color", Color("#f8fffd"))
	side.add_child(turn_label)

	var counts := HBoxContainer.new()
	counts.add_theme_constant_override("separation", 6)
	side.add_child(counts)
	black_label = _make_stat_label("BLACK 2")
	white_label = _make_stat_label("WHITE 2")
	counts.add_child(black_label)
	counts.add_child(white_label)

	var starter_title := Label.new()
	starter_title.text = "START COLOR"
	starter_title.add_theme_font_size_override("font_size", 9)
	starter_title.add_theme_color_override("font_color", Color("#6ba99a"))
	side.add_child(starter_title)

	var starter_row := HBoxContainer.new()
	starter_row.add_theme_constant_override("separation", 6)
	side.add_child(starter_row)
	for key in ["human", "cpu"]:
		var label := "YOU FIRST / BLACK" if key == "human" else "CPU FIRST / BLACK"
		var btn := _make_button(label, "segment")
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		if key == "human":
			btn.pressed.connect(func(): _set_starter(true))
		else:
			btn.pressed.connect(func(): _set_starter(false))
		starter_buttons[key] = btn
		starter_row.add_child(btn)

	var diff_title := Label.new()
	diff_title.text = "CPU DEPTH"
	diff_title.add_theme_font_size_override("font_size", 9)
	diff_title.add_theme_color_override("font_color", Color("#6ba99a"))
	side.add_child(diff_title)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 5)
	side.add_child(diff_row)
	for depth in [3, 4, 5]:
		var label := ("EASY " if depth == 3 else ("NORMAL " if depth == 4 else "HARD ")) + str(depth)
		var btn := _make_button(label, "segment")
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		if depth == 3:
			btn.pressed.connect(func(): _set_difficulty(3))
		elif depth == 4:
			btn.pressed.connect(func(): _set_difficulty(4))
		else:
			btn.pressed.connect(func(): _set_difficulty(5))
		difficulty_buttons[depth] = btn
		diff_row.add_child(btn)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	side.add_child(actions)
	var new_btn := _make_button("NEW GAME", "primary")
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.custom_minimum_size = Vector2(0, 40)
	new_btn.pressed.connect(_start_new_game)
	actions.add_child(new_btn)
	hints_button = _make_button("HINTS ON", "secondary")
	hints_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hints_button.custom_minimum_size = Vector2(0, 40)
	hints_button.pressed.connect(_toggle_hints)
	actions.add_child(hints_button)

	status_label = Label.new()
	status_label.text = "光るマスへ石を置こう"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size = Vector2(0, 36)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("#d4efe8"))
	side.add_child(status_label)

	record_label = Label.new()
	record_label.add_theme_font_size_override("font_size", 10)
	record_label.add_theme_color_override("font_color", Color("#789f95"))
	side.add_child(record_label)

	var keys := Label.new()
	keys.text = "KEYS  1/2/3:CPU  S:先後  M:Hint  R:New"
	keys.add_theme_font_size_override("font_size", 9)
	keys.add_theme_color_override("font_color", Color("#557d72"))
	side.add_child(keys)

	_build_result_layer()
	_update_controls()

func _build_result_layer() -> void:
	result_layer = Control.new()
	result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.visible = false
	add_child(result_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.06, 0.05, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(304, 240)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#082d26"), Color("#5eead4"), 22, 2))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	result_title = Label.new()
	result_title.text = "YOU WIN"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 28)
	result_title.add_theme_color_override("font_color", Color("#5eead4"))
	box.add_child(result_title)

	result_score = Label.new()
	result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_score.add_theme_font_size_override("font_size", 18)
	result_score.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(result_score)

	result_sub = Label.new()
	result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_sub.add_theme_font_size_override("font_size", 11)
	result_sub.add_theme_color_override("font_color", Color("#a3c9bf"))
	box.add_child(result_sub)

	var replay := _make_button("REMATCH", "primary")
	replay.custom_minimum_size = Vector2(180, 44)
	replay.pressed.connect(_start_new_game)
	box.add_child(replay)

func _apply_responsive_layout() -> void:
	if content_grid == null:
		return
	var viewport_size := get_viewport_rect().size
	var landscape := viewport_size.x > viewport_size.y * 1.28 and viewport_size.y <= 600
	content_grid.columns = 2 if landscape else 1
	if landscape:
		board_card.custom_minimum_size = Vector2(maxf(390.0, viewport_size.x * 0.56), 0)
		side_card.custom_minimum_size = Vector2(285, 0)
		root_margin.add_theme_constant_override("margin_left", 9)
		root_margin.add_theme_constant_override("margin_right", 9)
		root_margin.add_theme_constant_override("margin_top", 7)
		root_margin.add_theme_constant_override("margin_bottom", 7)
	else:
		board_card.custom_minimum_size = Vector2(0, minf(520.0, maxf(360.0, viewport_size.y * 0.52)))
		side_card.custom_minimum_size = Vector2(0, 248)
		root_margin.add_theme_constant_override("margin_left", 12)
		root_margin.add_theme_constant_override("margin_right", 12)
		root_margin.add_theme_constant_override("margin_top", 10)
		root_margin.add_theme_constant_override("margin_bottom", 10)

func _start_new_game() -> void:
	board = _initial_board()
	human_color = BLACK if human_first else WHITE
	cpu_color = -human_color
	turn = BLACK
	busy = false
	finished = false
	move_count = 0
	last_move = Vector2i(-1, -1)
	if result_layer:
		result_layer.visible = false
	_update_controls()
	_advance_turn()

func _initial_board() -> Array:
	var next: Array = []
	for r in range(SIZE):
		var row: Array = []
		for c in range(SIZE):
			row.append(EMPTY)
		next.append(row)
	next[3][3] = WHITE
	next[3][4] = BLACK
	next[4][3] = BLACK
	next[4][4] = WHITE
	return next

func _on_board_cell_tapped(row: int, col: int) -> void:
	if busy or finished or turn != human_color:
		return
	var move := _find_move(_legal_moves(board, human_color), row, col)
	if move.is_empty():
		status_label.text = "そこには置けません。光る候補を選んでください。"
		_play_tone(tone_error)
		return
	_perform_move(move, human_color)
	turn = cpu_color
	_advance_turn()

func _advance_turn() -> void:
	if _is_game_over(board):
		_finish_game()
		return
	var moves := _legal_moves(board, turn)
	if moves.is_empty():
		var passed := turn
		turn = -turn
		status_label.text = ("あなた" if passed == human_color else "CPU") + " は置ける場所がなくパス"
		moves = _legal_moves(board, turn)
		if moves.is_empty():
			_finish_game()
			return
	_refresh()
	if turn == cpu_color and not finished:
		_cpu_turn_async()
	elif not finished:
		status_label.text = "あなたの手番。光るマスから選んでください。"
		_refresh()

func _cpu_turn_async() -> void:
	if busy or finished or turn != cpu_color:
		return
	busy = true
	status_label.text = "CPUが盤面を読んでいます…"
	_refresh()
	await get_tree().create_timer(0.22).timeout
	if finished or turn != cpu_color:
		busy = false
		return
	var move := _choose_cpu_move(board, cpu_color, difficulty)
	if move.is_empty():
		busy = false
		turn = human_color
		_advance_turn()
		return
	_perform_move(move, cpu_color)
	turn = human_color
	busy = false
	_advance_turn()

func _perform_move(move: Dictionary, player: int) -> void:
	var row := int(move.get("r", -1))
	var col := int(move.get("c", -1))
	if row < 0 or col < 0:
		return
	board[row][col] = player
	var pulse_cells: Array = [Vector2i(col, row)]
	var flips: Array = move.get("flips", [])
	for point in flips:
		var p: Vector2i = point
		board[p.y][p.x] = player
		pulse_cells.append(p)
	last_move = Vector2i(col, row)
	move_count += 1
	board_view.animate_flip(pulse_cells)
	_play_tone(tone_flip if flips.size() >= 3 else tone_place)
	_refresh()

func _find_move(moves: Array, row: int, col: int) -> Dictionary:
	for item in moves:
		var move: Dictionary = item
		if int(move.get("r", -1)) == row and int(move.get("c", -1)) == col:
			return move
	return {}

func _flips(b: Array, row: int, col: int, player: int) -> Array:
	if row < 0 or row >= SIZE or col < 0 or col >= SIZE or int(b[row][col]) != EMPTY:
		return []
	var out: Array = []
	var opponent := -player
	for dir in DIRS:
		var direction: Vector2i = dir
		var r: int = row + direction.y
		var c: int = col + direction.x
		var temp: Array = []
		while _inside(r, c) and int(b[r][c]) == opponent:
			temp.append(Vector2i(c, r))
			r += direction.y
			c += direction.x
		if not temp.is_empty() and _inside(r, c) and int(b[r][c]) == player:
			out.append_array(temp)
	return out

func _legal_moves(b: Array, player: int) -> Array:
	var moves: Array = []
	for r in range(SIZE):
		for c in range(SIZE):
			var flipped := _flips(b, r, c, player)
			if not flipped.is_empty():
				moves.append({"r": r, "c": c, "flips": flipped})
	return moves

func _inside(row: int, col: int) -> bool:
	return row >= 0 and row < SIZE and col >= 0 and col < SIZE

func _clone_board(b: Array) -> Array:
	var out: Array = []
	for row in b:
		var row_array: Array = row
		out.append(row_array.duplicate())
	return out

func _apply_to_clone(b: Array, move: Dictionary, player: int) -> Array:
	var out := _clone_board(b)
	var row := int(move.get("r", 0))
	var col := int(move.get("c", 0))
	out[row][col] = player
	var flips: Array = move.get("flips", [])
	for point in flips:
		var p: Vector2i = point
		out[p.y][p.x] = player
	return out

func _choose_cpu_move(b: Array, player: int, depth: int) -> Dictionary:
	var moves := _legal_moves(b, player)
	if moves.is_empty():
		return {}
	var best_score := -1000000000.0
	var best: Dictionary = moves[0]
	for item in moves:
		var move: Dictionary = item
		var next := _apply_to_clone(b, move, player)
		var score := _minimax(next, -player, maxi(0, depth - 1), -1000000000.0, 1000000000.0, player)
		var r := int(move.get("r", 0))
		var c := int(move.get("c", 0))
		if _is_corner(r, c):
			score += 40.0
		if score > best_score:
			best_score = score
			best = move
	return best

func _minimax(b: Array, player: int, depth: int, alpha_in: float, beta_in: float, max_color: int) -> float:
	if depth <= 0 or _is_game_over(b):
		return _evaluate(b, max_color)
	var moves := _legal_moves(b, player)
	if moves.is_empty():
		return _minimax(b, -player, depth - 1, alpha_in, beta_in, max_color)
	var alpha := alpha_in
	var beta := beta_in
	if player == max_color:
		var best := -1000000000.0
		for item in moves:
			var move: Dictionary = item
			var score := _minimax(_apply_to_clone(b, move, player), -player, depth - 1, alpha, beta, max_color)
			best = maxf(best, score)
			alpha = maxf(alpha, best)
			if beta <= alpha:
				break
		return best
	var best := 1000000000.0
	for item in moves:
		var move: Dictionary = item
		var score := _minimax(_apply_to_clone(b, move, player), -player, depth - 1, alpha, beta, max_color)
		best = minf(best, score)
		beta = minf(beta, best)
		if beta <= alpha:
			break
	return best

func _evaluate(b: Array, max_color: int) -> float:
	var counts := _count_discs(b)
	var mine := int(counts["black"]) if max_color == BLACK else int(counts["white"])
	var theirs := int(counts["white"]) if max_color == BLACK else int(counts["black"])
	var score := float(mine - theirs)
	var mobility := _legal_moves(b, max_color).size() - _legal_moves(b, -max_color).size()
	score += float(mobility) * 2.4
	for corner in [Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 7), Vector2i(7, 7)]:
		var value := int(b[corner.y][corner.x])
		if value == max_color:
			score += 26.0
		elif value == -max_color:
			score -= 26.0
	for i in range(1, 7):
		for point in [Vector2i(i, 0), Vector2i(i, 7), Vector2i(0, i), Vector2i(7, i)]:
			var value := int(b[point.y][point.x])
			if value == max_color:
				score += 1.8
			elif value == -max_color:
				score -= 1.8
	return score

func _is_corner(row: int, col: int) -> bool:
	return (row == 0 or row == 7) and (col == 0 or col == 7)

func _is_game_over(b: Array) -> bool:
	return _legal_moves(b, BLACK).is_empty() and _legal_moves(b, WHITE).is_empty()

func _count_discs(b: Array) -> Dictionary:
	var black := 0
	var white := 0
	for row in b:
		for value in row:
			if int(value) == BLACK:
				black += 1
			elif int(value) == WHITE:
				white += 1
	return {"black": black, "white": white}

func _finish_game() -> void:
	if finished:
		return
	finished = true
	busy = false
	var counts := _count_discs(board)
	var human_count := int(counts["black"]) if human_color == BLACK else int(counts["white"])
	var cpu_count := int(counts["white"]) if human_color == BLACK else int(counts["black"])
	var result := "draw"
	if human_count > cpu_count:
		result = "win"
		record["win"] = int(record.get("win", 0)) + 1
	elif human_count < cpu_count:
		result = "lose"
		record["lose"] = int(record.get("lose", 0)) + 1
	else:
		record["draw"] = int(record.get("draw", 0)) + 1
	_save_record()
	result_title.text = "YOU WIN" if result == "win" else ("CPU WINS" if result == "lose" else "DRAW")
	result_title.add_theme_color_override("font_color", Color("#5eead4") if result == "win" else (Color("#fb7185") if result == "lose" else Color("#facc15")))
	result_score.text = "YOU %d  —  %d CPU" % [human_count, cpu_count]
	result_sub.text = "Depth %d / %s / %d moves" % [difficulty, "BLACK" if human_color == BLACK else "WHITE", move_count]
	result_layer.visible = true
	result_layer.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(result_layer, "modulate", Color.WHITE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	status_label.text = "対局終了。REMATCHですぐ再戦できます。"
	_play_tone(tone_win if result == "win" else tone_flip)
	_refresh()

func _set_starter(next_human_first: bool) -> void:
	human_first = next_human_first
	_start_new_game()

func _set_difficulty(depth: int) -> void:
	difficulty = clampi(depth, 3, 5)
	_update_controls()
	status_label.text = "CPU depthを %d に変更しました。" % difficulty
	_update_debug_bridge()

func _toggle_hints() -> void:
	show_hints = not show_hints
	hints_button.text = "HINTS ON" if show_hints else "HINTS OFF"
	_refresh()

func _refresh() -> void:
	if board_view == null or board.size() != SIZE:
		return
	var moves := _legal_moves(board, turn) if not finished else []
	board_view.set_state(board, moves if turn == human_color else [], show_hints and turn == human_color and not busy, last_move)
	var counts := _count_discs(board)
	black_label.text = "BLACK %d" % int(counts["black"])
	white_label.text = "WHITE %d" % int(counts["white"])
	if not finished:
		if turn == human_color:
			turn_label.text = "YOUR TURN / " + ("BLACK" if human_color == BLACK else "WHITE")
			turn_label.add_theme_color_override("font_color", Color("#f8fffd"))
		else:
			turn_label.text = "CPU TURN / " + ("BLACK" if cpu_color == BLACK else "WHITE")
			turn_label.add_theme_color_override("font_color", Color("#facc15"))
	record_label.text = "RECORD  W %d / L %d / D %d" % [int(record.get("win", 0)), int(record.get("lose", 0)), int(record.get("draw", 0))]
	_update_controls()
	_update_debug_bridge()

func _update_controls() -> void:
	for key in starter_buttons.keys():
		var button: Button = starter_buttons[key]
		button.set_pressed_no_signal((str(key) == "human") == human_first)
	for key in difficulty_buttons.keys():
		var button: Button = difficulty_buttons[key]
		button.set_pressed_no_signal(int(key) == difficulty)
	if hints_button:
		hints_button.text = "HINTS ON" if show_hints else "HINTS OFF"

func _qa_autoplay_finish() -> void:
	if not qa_mode or finished:
		return
	var old_muted := muted
	muted = true
	busy = true
	var guard := 0
	while not _is_game_over(board) and guard < 80:
		var moves := _legal_moves(board, turn)
		if moves.is_empty():
			turn = -turn
		else:
			var move: Dictionary = moves[0]
			_perform_move(move, turn)
			turn = -turn
		guard += 1
	busy = false
	muted = old_muted
	_finish_game()

func _toggle_sound() -> void:
	muted = not muted
	sound_button.text = "SOUND OFF" if muted else "SOUND ON"
	if not muted:
		_play_tone(tone_place)
	_update_debug_bridge()

func _go_home() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href='../../';", true)

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	tone_place = _make_tone(430.0, 0.055, 0.18)
	tone_flip = _make_tone(610.0, 0.075, 0.17)
	tone_error = _make_tone(175.0, 0.11, 0.18)
	tone_win = _make_tone(820.0, 0.22, 0.22)

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
	label.add_theme_color_override("font_color", Color("#d8f5ed"))
	label.add_theme_stylebox_override("normal", _panel_style(Color("#0a3029"), Color("#1d5b4e"), 9, 1))
	return label

func _make_button(text_value: String, kind: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("#f4fffb"))
	var normal_bg := Color("#0c352d")
	var hover_bg := Color("#12483d")
	var pressed_bg := Color("#17604f")
	var border := Color("#286355")
	if kind == "primary":
		normal_bg = Color("#0f766e")
		hover_bg = Color("#0d9488")
		pressed_bg = Color("#115e59")
		border = Color("#5eead4")
	elif kind == "ghost":
		normal_bg = Color("#071f1c")
		hover_bg = Color("#0b332c")
		pressed_bg = Color("#104438")
		border = Color("#28584d")
	elif kind == "segment":
		normal_bg = Color("#0b2d27")
		hover_bg = Color("#104239")
		pressed_bg = Color("#0e7490")
		border = Color("#2a5c51")
	button.add_theme_stylebox_override("normal", _panel_style(normal_bg, border, 10, 1))
	button.add_theme_stylebox_override("hover", _panel_style(hover_bg, border.lightened(0.18), 10, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(pressed_bg, border.lightened(0.28), 10, 2))
	button.add_theme_stylebox_override("focus", _panel_style(normal_bg, Color("#5eead4"), 10, 2))
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
	if OS.get_name() != "Web" or board_view == null or board.size() != SIZE:
		return
	var counts := _count_discs(board)
	var moves := _legal_moves(board, turn) if not finished else []
	var point: Vector2 = board_view.get_first_legal_global()
	var vp := get_viewport_rect().size
	var result := ""
	if finished:
		var human_count := int(counts["black"]) if human_color == BLACK else int(counts["white"])
		var cpu_count := int(counts["white"]) if human_color == BLACK else int(counts["black"])
		result = "win" if human_count > cpu_count else ("lose" if human_count < cpu_count else "draw")
	var payload := {
		"ready": true,
		"engine": "Godot",
		"build": "GAME-057",
		"turn": "black" if turn == BLACK else "white",
		"human": "black" if human_color == BLACK else "white",
		"cpu": "black" if cpu_color == BLACK else "white",
		"difficulty": difficulty,
		"hints": show_hints,
		"busy": busy,
		"finished": finished,
		"result": result,
		"move_count": move_count,
		"legal_count": moves.size(),
		"black": int(counts["black"]),
		"white": int(counts["white"]),
		"viewport_w": vp.x,
		"viewport_h": vp.y,
		"test_cell_x": point.x,
		"test_cell_y": point.y,
		"qa_mode": qa_mode
	}
	JavaScriptBridge.eval("window.__P021_OTHELLO = " + JSON.stringify(payload) + ";", true)
