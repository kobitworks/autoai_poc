extends Control
class_name NumberSumBoardView

signal cell_tapped(index: int)

var puzzle: Dictionary = {}
var state: Array = []
var ui_font: Font
var grid_origin := Vector2.ZERO
var cell_size := 0.0
var header_size := 34.0
var pulse_index := -1
var pulse_value := 0.0

var palette := [
	Color("#1d4ed8"), Color("#0f766e"), Color("#7c3aed"), Color("#c2410c"),
	Color("#047857"), Color("#be123c"), Color("#4338ca"), Color("#a16207"),
	Color("#0369a1"), Color("#6d28d9"), Color("#0e7490"), Color("#b45309")
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func set_font(font: Font) -> void:
	ui_font = font
	queue_redraw()

func set_puzzle(data: Dictionary, state_ref: Array) -> void:
	puzzle = data
	state = state_ref
	pulse_index = -1
	pulse_value = 0.0
	queue_redraw()

func refresh(state_ref: Array) -> void:
	state = state_ref
	queue_redraw()

func animate_cell(index: int) -> void:
	pulse_index = index
	pulse_value = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if pulse_value > 0.0:
		pulse_value = maxf(0.0, pulse_value - delta * 4.6)
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if puzzle.is_empty() or cell_size <= 0.0:
		return
	var pos := Vector2(-999.0, -999.0)
	var pressed := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			pos = mouse_event.position
			pressed = true
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			pos = touch_event.position
			pressed = true
	if not pressed:
		return
	var n := int(puzzle.get("N", 0))
	if n <= 0:
		return
	var local := pos - grid_origin
	if local.x < 0.0 or local.y < 0.0:
		return
	var col := int(floor(local.x / cell_size))
	var row := int(floor(local.y / cell_size))
	if row < 0 or row >= n or col < 0 or col >= n:
		return
	cell_tapped.emit(row * n + col)
	accept_event()

func _draw() -> void:
	if puzzle.is_empty() or ui_font == null:
		return
	var n := int(puzzle.get("N", 0))
	if n <= 0:
		return

	header_size = clampf(minf(size.x, size.y) * 0.095, 29.0, 42.0)
	var usable_w := maxf(20.0, size.x - header_size - 10.0)
	var usable_h := maxf(20.0, size.y - header_size - 10.0)
	var board_size: float = floor(minf(usable_w, usable_h))
	cell_size = board_size / float(n)
	grid_origin = Vector2(
		header_size + (usable_w - board_size) * 0.5,
		header_size + (usable_h - board_size) * 0.5
	)

	var sums := _compute_sums()
	var row_cur: Array = sums["rows"]
	var col_cur: Array = sums["cols"]
	var reg_cur: Array = sums["regions"]
	var row_targets: Array = puzzle["row_targets"]
	var col_targets: Array = puzzle["col_targets"]
	var reg_targets: Array = puzzle["region_targets"]
	var numbers: Array = puzzle["numbers"]
	var region_ids: Array = puzzle["regions"]

	var board_rect := Rect2(grid_origin, Vector2(board_size, board_size))
	draw_rect(board_rect.grow(5.0), Color("#07111f"), true)
	draw_rect(board_rect.grow(5.0), Color("#233a56"), false, 2.0)

	var header_font := int(clampf(cell_size * 0.28, 9.0, 15.0))
	var number_font := int(clampf(cell_size * 0.43, 15.0, 26.0))
	var badge_font := int(clampf(cell_size * 0.18, 8.0, 11.0))

	for c in range(n):
		var hrect := Rect2(grid_origin.x + c * cell_size, grid_origin.y - header_size + 3.0, cell_size, header_size - 7.0)
		var hc := _target_color(int(col_cur[c]), int(col_targets[c]))
		draw_rect(hrect, hc.darkened(0.55), true)
		draw_rect(hrect, hc.lightened(0.08), false, 1.0)
		_draw_text_center(hrect, str(col_cur[c]) + "/" + str(col_targets[c]), header_font, hc.lightened(0.55))

	for r in range(n):
		var hrect := Rect2(grid_origin.x - header_size + 3.0, grid_origin.y + r * cell_size, header_size - 7.0, cell_size)
		var hc := _target_color(int(row_cur[r]), int(row_targets[r]))
		draw_rect(hrect, hc.darkened(0.55), true)
		draw_rect(hrect, hc.lightened(0.08), false, 1.0)
		_draw_text_center(hrect, str(row_cur[r]) + "/" + str(row_targets[r]), header_font, hc.lightened(0.55))

	var anchors := {}
	for r in range(n):
		for c in range(n):
			var idx := r * n + c
			var rid := int(region_ids[r][c])
			if not anchors.has(rid):
				anchors[rid] = idx
			var rect := Rect2(
				grid_origin.x + c * cell_size + 1.0,
				grid_origin.y + r * cell_size + 1.0,
				cell_size - 2.0,
				cell_size - 2.0
			)
			var base: Color = palette[rid % palette.size()]
			var fill := Color(base.r, base.g, base.b, 0.18)
			draw_rect(rect, fill, true)
			var value := int(state[idx]) if idx < state.size() else 0
			var center := rect.get_center()
			if value == 1:
				var radius := cell_size * (0.31 + (0.055 * pulse_value if idx == pulse_index else 0.0))
				draw_circle(center, radius, Color("#22d3a7"))
				draw_circle(center, radius, Color("#9fffe8"), false, maxf(1.4, cell_size * 0.035))
			elif value == -1:
				draw_rect(rect.grow(-cell_size * 0.12), Color("#111827"), true)
				var d := cell_size * 0.22
				var cross := Color("#fb7185")
				draw_line(center - Vector2(d, d), center + Vector2(d, d), cross, maxf(2.0, cell_size * 0.05), true)
				draw_line(center + Vector2(d, -d), center + Vector2(-d, d), cross, maxf(2.0, cell_size * 0.05), true)

			var txt_color := Color.WHITE if value == 1 else Color("#e5eefc")
			_draw_text_center(rect, str(numbers[r][c]), number_font, txt_color)

	for r in range(n):
		for c in range(n):
			var rid := int(region_ids[r][c])
			var x := grid_origin.x + c * cell_size
			var y := grid_origin.y + r * cell_size
			var thick := maxf(2.0, cell_size * 0.045)
			var line_color := Color("#9fb8dc")
			if r == 0 or int(region_ids[r - 1][c]) != rid:
				draw_line(Vector2(x, y), Vector2(x + cell_size, y), line_color, thick, true)
			if c == 0 or int(region_ids[r][c - 1]) != rid:
				draw_line(Vector2(x, y), Vector2(x, y + cell_size), line_color, thick, true)
			if r == n - 1 or int(region_ids[r + 1][c]) != rid:
				draw_line(Vector2(x, y + cell_size), Vector2(x + cell_size, y + cell_size), line_color, thick, true)
			if c == n - 1 or int(region_ids[r][c + 1]) != rid:
				draw_line(Vector2(x + cell_size, y), Vector2(x + cell_size, y + cell_size), line_color, thick, true)

	for key in anchors.keys():
		var rid := int(key)
		var idx := int(anchors[key])
		var r := int(idx / n)
		var c := idx % n
		var badge_rect := Rect2(
			grid_origin.x + c * cell_size + cell_size * 0.04,
			grid_origin.y + r * cell_size + cell_size * 0.04,
			cell_size * 0.56,
			cell_size * 0.25
		)
		var ok := int(reg_cur[rid]) == int(reg_targets[rid])
		var over := int(reg_cur[rid]) > int(reg_targets[rid])
		var badge_color := Color("#16a34a") if ok else (Color("#dc2626") if over else Color("#0b1728"))
		draw_rect(badge_rect, badge_color, true)
		draw_rect(badge_rect, Color("#d5e4fa"), false, 1.0)
		_draw_text_center(badge_rect, str(reg_cur[rid]) + "/" + str(reg_targets[rid]), badge_font, Color.WHITE)

	var label_rect := Rect2(grid_origin.x - header_size, grid_origin.y - header_size, header_size - 4.0, header_size - 4.0)
	draw_circle(label_rect.get_center(), minf(label_rect.size.x, label_rect.size.y) * 0.42, Color("#16304c"))
	_draw_text_center(label_rect, "Σ", int(header_font * 1.2), Color("#67e8f9"))

func _compute_sums() -> Dictionary:
	var n := int(puzzle.get("N", 0))
	var row_cur := []
	var col_cur := []
	var reg_targets: Array = puzzle.get("region_targets", [])
	var reg_cur := []
	row_cur.resize(n)
	col_cur.resize(n)
	reg_cur.resize(reg_targets.size())
	row_cur.fill(0)
	col_cur.fill(0)
	reg_cur.fill(0)
	var numbers: Array = puzzle.get("numbers", [])
	var region_ids: Array = puzzle.get("regions", [])
	for r in range(n):
		for c in range(n):
			var idx := r * n + c
			if idx < state.size() and int(state[idx]) == 1:
				var value := int(numbers[r][c])
				row_cur[r] += value
				col_cur[c] += value
				reg_cur[int(region_ids[r][c])] += value
	return {"rows": row_cur, "cols": col_cur, "regions": reg_cur}

func _target_color(current: int, target: int) -> Color:
	if current == target:
		return Color("#22c55e")
	if current > target:
		return Color("#fb7185")
	return Color("#60a5fa")

func _draw_text_center(rect: Rect2, text: String, font_size: int, color: Color) -> void:
	if ui_font == null:
		return
	var y := rect.position.y + rect.size.y * 0.5 + font_size * 0.34
	draw_string(ui_font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)

func get_test_cell_global(index: int = 0) -> Vector2:
	if puzzle.is_empty() or cell_size <= 0.0:
		return global_position
	var n := int(puzzle.get("N", 1))
	var row := int(index / n)
	var col := index % n
	var local := grid_origin + Vector2((col + 0.5) * cell_size, (row + 0.5) * cell_size)
	return global_position + local
