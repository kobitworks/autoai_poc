extends Control
class_name OthelloBoardView

signal cell_tapped(row: int, col: int)

const SIZE := 8
const EMPTY := 0
const BLACK := 1
const WHITE := -1

var board: Array = []
var legal_moves: Array = []
var show_hints := true
var ui_font: Font
var board_origin := Vector2.ZERO
var cell_size := 0.0
var last_move := Vector2i(-1, -1)
var pulse_cells: Array = []
var pulse := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func set_font(font: Font) -> void:
	ui_font = font
	queue_redraw()

func set_state(board_ref: Array, legal_ref: Array, hints: bool, last: Vector2i = Vector2i(-1, -1)) -> void:
	board = board_ref
	legal_moves = legal_ref
	show_hints = hints
	last_move = last
	queue_redraw()

func animate_flip(cells: Array) -> void:
	pulse_cells = cells.duplicate()
	pulse = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse = maxf(0.0, pulse - delta * 4.2)
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if cell_size <= 0.0:
		return
	var pos := Vector2(-999, -999)
	var pressed := false
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			pos = e.position
			pressed = true
	elif event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			pos = e.position
			pressed = true
	if not pressed:
		return
	var local := pos - board_origin
	if local.x < 0.0 or local.y < 0.0:
		return
	var col := int(floor(local.x / cell_size))
	var row := int(floor(local.y / cell_size))
	if row < 0 or row >= SIZE or col < 0 or col >= SIZE:
		return
	cell_tapped.emit(row, col)
	accept_event()

func _draw() -> void:
	if board.size() != SIZE:
		return
	var margin := clampf(minf(size.x, size.y) * 0.035, 8.0, 18.0)
	var usable := maxf(80.0, minf(size.x, size.y) - margin * 2.0)
	var board_size: float = floor(usable)
	cell_size = board_size / float(SIZE)
	board_origin = Vector2((size.x - board_size) * 0.5, (size.y - board_size) * 0.5)

	var outer := Rect2(board_origin - Vector2(7, 7), Vector2(board_size + 14, board_size + 14))
	draw_rect(outer, Color("#052d26"), true)
	draw_rect(outer, Color("#5eead4"), false, 2.0)

	for r in range(SIZE):
		for c in range(SIZE):
			var rect := Rect2(board_origin.x + c * cell_size, board_origin.y + r * cell_size, cell_size, cell_size)
			var checker := ((r + c) % 2) == 0
			var fill := Color("#0d7a5f") if checker else Color("#0b6a54")
			draw_rect(rect, fill, true)
			draw_rect(rect, Color(0.05, 0.16, 0.13, 0.72), false, maxf(1.0, cell_size * 0.018))
			if last_move == Vector2i(c, r):
				draw_rect(rect.grow(-cell_size * 0.055), Color("#facc15"), false, maxf(2.0, cell_size * 0.045))
			var value := int(board[r][c])
			if value != EMPTY:
				_draw_disc(rect, value, _is_pulsing(r, c))
			elif show_hints and _is_legal(r, c):
				var center := rect.get_center()
				var radius := cell_size * 0.105
				draw_circle(center, radius, Color(0.55, 1.0, 0.87, 0.58))
				draw_circle(center, radius + 2.0, Color(0.75, 1.0, 0.94, 0.35), false, maxf(1.0, cell_size * 0.02))

	for i in range(SIZE + 1):
		var p := i * cell_size
		var line_color := Color(0.02, 0.12, 0.10, 0.75)
		draw_line(Vector2(board_origin.x + p, board_origin.y), Vector2(board_origin.x + p, board_origin.y + board_size), line_color, maxf(1.0, cell_size * 0.02))
		draw_line(Vector2(board_origin.x, board_origin.y + p), Vector2(board_origin.x + board_size, board_origin.y + p), line_color, maxf(1.0, cell_size * 0.02))

func _draw_disc(rect: Rect2, value: int, pulsing: bool) -> void:
	var center := rect.get_center()
	var radius := cell_size * (0.355 + (0.035 * pulse if pulsing else 0.0))
	draw_circle(center + Vector2(0, cell_size * 0.055), radius, Color(0, 0, 0, 0.24))
	if value == BLACK:
		draw_circle(center, radius, Color("#0a1012"))
		draw_circle(center - Vector2(radius * 0.18, radius * 0.18), radius * 0.72, Color("#1f2b2d"))
		draw_arc(center, radius * 0.76, 3.6, 5.7, 20, Color("#5b6f71"), maxf(1.0, cell_size * 0.024), true)
	else:
		draw_circle(center, radius, Color("#e7f2ef"))
		draw_circle(center - Vector2(radius * 0.18, radius * 0.18), radius * 0.72, Color("#ffffff"))
		draw_arc(center, radius * 0.82, 0.2, 2.5, 20, Color("#afc8c2"), maxf(1.0, cell_size * 0.022), true)

func _is_legal(row: int, col: int) -> bool:
	for move in legal_moves:
		if int(move.get("r", -1)) == row and int(move.get("c", -1)) == col:
			return true
	return false

func _is_pulsing(row: int, col: int) -> bool:
	if pulse <= 0.0:
		return false
	for item in pulse_cells:
		var p: Vector2i = item
		if p == Vector2i(col, row):
			return true
	return false

func get_first_legal_global() -> Vector2:
	if legal_moves.is_empty() or cell_size <= 0.0:
		return global_position + size * 0.5
	var move: Dictionary = legal_moves[0]
	var row := int(move.get("r", 0))
	var col := int(move.get("c", 0))
	return global_position + board_origin + Vector2((col + 0.5) * cell_size, (row + 0.5) * cell_size)
