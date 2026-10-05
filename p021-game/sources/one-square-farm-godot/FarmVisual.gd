extends Control

const ATLAS_PATH := "res://assets/kenney/tiny_farm.png"
const TILE := 16
const COLS := 12
const GRASS := [106, 107, 94, 119]
const DIRT := [0, 12, 24, 36]
const TREES := [64, 65, 66, 67, 68]
const BUSHES := [27, 39, 15, 3]
const CROP_A := [4, 5, 6, 7, 8]
const CROP_B := [16, 17, 18, 19, 20]
const FENCE := 69
const FENCE_GATE := 71
const WELL := 112
const BARN := 48

var atlas: Texture2D
var crop: Dictionary = {}
var weather_key := "sun"
var soil := 70
var day_progress := 1.0
var clock := 0.0
var water_fx := 0.0
var harvest_fx := 0.0
var plant_fx := 0.0
var soil_fx := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(ATLAS_PATH):
		atlas = load(ATLAS_PATH) as Texture2D
	set_process(true)

func set_farm_state(crop_state: Dictionary, weather: String, soil_value: int, progress: float) -> void:
	crop = crop_state.duplicate(true)
	weather_key = weather
	soil = soil_value
	day_progress = progress
	queue_redraw()

func splash_water() -> void:
	water_fx = 1.8

func harvest_burst() -> void:
	harvest_fx = 1.3

func plant_pop() -> void:
	plant_fx = 0.8

func soil_burst() -> void:
	soil_fx = 0.8

func _process(delta: float) -> void:
	clock += delta
	water_fx = maxf(0.0, water_fx - delta)
	harvest_fx = maxf(0.0, harvest_fx - delta)
	plant_fx = maxf(0.0, plant_fx - delta)
	soil_fx = maxf(0.0, soil_fx - delta)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 20.0 or h < 20.0:
		return
	if atlas == null:
		_draw_fallback(w, h)
		return
	_draw_pixel_scene(w, h)
	_draw_weather_overlay(w, h)
	_draw_crop(w, h)
	_draw_effects(w, h)

func _src(tile_id: int) -> Rect2:
	var x := (tile_id % COLS) * TILE
	var y := (tile_id / COLS) * TILE
	return Rect2(x, y, TILE, TILE)

func _tile(tile_id: int, pos: Vector2, scale_value: float = 3.0) -> void:
	draw_texture_rect_region(atlas, Rect2(pos, Vector2(TILE, TILE) * scale_value), _src(tile_id))

func _draw_pixel_scene(w: float, h: float) -> void:
	# A complete little farm scene built from Kenney Tiny Farm CC0 tiles.
	var scale_value := 3.0
	var step := TILE * scale_value
	var cols := int(ceil(w / step))
	var rows := int(ceil(h / step))

	for y in range(rows):
		for x in range(cols):
			var grass_id: int = GRASS[(x * 3 + y * 5) % GRASS.size()]
			_tile(grass_id, Vector2(x * step, y * step), scale_value)

	# Central one-square field: a strong visual focal point.
	var field := Rect2(w * 0.27, h * 0.42, w * 0.46, h * 0.42)
	for y in range(int(field.size.y / step) + 1):
		for x in range(int(field.size.x / step) + 1):
			var p := field.position + Vector2(x * step, y * step)
			if p.x < field.end.x and p.y < field.end.y:
				_tile(DIRT[(x + y) % DIRT.size()], p, scale_value)

	# Fence, gate and landmark props give the screen a real farm silhouette.
	var fence_y := field.position.y - step * 0.74
	var fence_cols := int(field.size.x / step) + 1
	for x in range(fence_cols):
		var id := FENCE_GATE if x == fence_cols / 2 else FENCE
		_tile(id, Vector2(field.position.x + x * step, fence_y), scale_value)

	_tile(BARN, Vector2(w * 0.08, h * 0.18), 4.4)
	_tile(WELL, Vector2(w * 0.76, h * 0.30), 3.4)

	for i in range(5):
		_tile(TREES[i % TREES.size()], Vector2(10 + i * 55, 40 + (i % 2) * 18), 3.3)
	for i in range(4):
		_tile(BUSHES[i % BUSHES.size()], Vector2(w - 190 + i * 42, h - 70 - (i % 2) * 14), 2.8)

	# Soft vignette keeps the HUD readable while retaining the pixel scene.
	draw_rect(Rect2(0, 0, w, 72), Color(0.04, 0.10, 0.06, 0.24), true)
	draw_rect(Rect2(0, h - 34, w, 34), Color(0.04, 0.10, 0.06, 0.18), true)

func _draw_weather_overlay(w: float, h: float) -> void:
	var sun_x := w * (0.18 + 0.64 * (1.0 - day_progress))
	var sun_y := 70.0 - sin((1.0 - day_progress) * PI) * 18.0
	if weather_key == "sun":
		draw_circle(Vector2(sun_x, sun_y), 24.0, Color(1.0, 0.82, 0.26, 0.92))
		draw_circle(Vector2(sun_x - 7, sun_y - 6), 4.0, Color(1.0, 0.95, 0.64, 0.8))
	elif weather_key == "cloud":
		draw_rect(Rect2(0, 0, w, h), Color(0.55, 0.65, 0.70, 0.16), true)
		_cloud(Vector2(w * 0.28, 72), 0.9)
		_cloud(Vector2(w * 0.72, 92), 0.72)
	elif weather_key == "rain":
		draw_rect(Rect2(0, 0, w, h), Color(0.20, 0.32, 0.42, 0.24), true)
		_cloud(Vector2(w * 0.30, 66), 0.9)
		_cloud(Vector2(w * 0.72, 88), 0.74)
		for i in range(24):
			var x := fmod(float(i * 61) + clock * 120.0, w + 30.0) - 15.0
			var y := 92.0 + fmod(float(i * 41) + clock * 178.0, h - 95.0)
			draw_line(Vector2(x, y), Vector2(x - 5, y + 13), Color(0.42, 0.72, 0.95, 0.82), 2.4)

func _cloud(center: Vector2, scale_value: float) -> void:
	var c := Color(0.97, 0.99, 1.0, 0.86)
	draw_circle(center + Vector2(-26, 5) * scale_value, 19.0 * scale_value, c)
	draw_circle(center + Vector2(0, -7) * scale_value, 27.0 * scale_value, c)
	draw_circle(center + Vector2(29, 6) * scale_value, 19.0 * scale_value, c)
	draw_rect(Rect2(center + Vector2(-39, 2) * scale_value, Vector2(78, 24) * scale_value), c)

func _draw_crop(w: float, h: float) -> void:
	if crop.is_empty():
		# Empty field marker.
		draw_circle(Vector2(w * 0.5, h * 0.66), 30.0, Color(1.0, 0.96, 0.72, 0.18))
		draw_arc(Vector2(w * 0.5, h * 0.66), 30.0, 0, TAU, 32, Color(1.0, 0.95, 0.72, 0.66), 2.0)
		return

	var key: String = crop.get("key", "radish")
	var growth := maxf(0.0, float(crop.get("growth", 0.0)))
	var max_days := 3.0
	if key == "lettuce":
		max_days = 4.0
	elif key == "tomato":
		max_days = 5.0
	var ratio := clampf(growth / max_days, 0.0, 1.0)
	var stage := mini(4, int(floor(ratio * 4.999)))
	var crop_id: int = CROP_A[stage] if key != "lettuce" else CROP_B[stage]
	var center := Vector2(w * 0.5, h * 0.67)
	var pop := 1.0 + (sin((1.0 - plant_fx / 0.8) * PI) * 0.18 if plant_fx > 0.0 else 0.0)

	# A compact cluster feels like one cultivated plot while still reading as "1マス".
	for offset in [Vector2(-50, 10), Vector2(0, -6), Vector2(50, 10), Vector2(-25, 45), Vector2(25, 45)]:
		_tile(crop_id, center + offset - Vector2(28, 28), 3.5 * pop)

	if key == "tomato" and ratio > 0.62:
		for offset in [Vector2(-22, -8), Vector2(20, 10), Vector2(0, 32)]:
			draw_circle(center + offset, 8.0, Color(0.91, 0.18, 0.12, 0.96))
			draw_circle(center + offset + Vector2(-2.5, -3), 2.0, Color(1.0, 0.66, 0.52, 0.9))

	var health := clampf(float(crop.get("health", 100)) / 100.0, 0.0, 1.0)
	if health < 0.65:
		draw_rect(Rect2(center.x - 92, center.y + 72, 184, 8), Color(0.12, 0.12, 0.12, 0.5), true)
		draw_rect(Rect2(center.x - 92, center.y + 72, 184 * health, 8), Color(0.95, 0.62, 0.20, 0.95), true)

func _draw_effects(w: float, h: float) -> void:
	var center := Vector2(w * 0.5, h * 0.67)
	if water_fx > 0.0:
		var p := 1.0 - water_fx / 1.8
		var origin := Vector2(w * 0.79, h * 0.30)
		for i in range(18):
			var phase := fmod(p * 1.7 + float(i) / 18.0, 1.0)
			var pos := origin.lerp(center, phase)
			pos.y -= sin(phase * PI) * 22.0
			draw_circle(pos, 3.5 + 1.4 * sin(phase * PI), Color(0.25, 0.69, 0.96, 0.92))
		for j in range(7):
			var a := float(j) / 7.0 * PI
			var splash := center + Vector2(cos(a) * (12.0 + p * 20.0), -sin(a) * (7.0 + p * 15.0))
			draw_circle(splash, 3.5, Color(0.38, 0.75, 1.0, 0.86))

	if harvest_fx > 0.0:
		var p2 := 1.0 - harvest_fx / 1.3
		for i in range(12):
			var a2 := float(i) / 12.0 * TAU
			var radius := 30.0 + p2 * 110.0
			var pos2 := center + Vector2(cos(a2), sin(a2)) * radius + Vector2(0, -p2 * 48.0)
			draw_circle(pos2, 8.5 * (1.0 - p2 * 0.25), Color(1.0, 0.78, 0.18, 1.0 - p2))

	if soil_fx > 0.0:
		var p3 := 1.0 - soil_fx / 0.8
		for i in range(9):
			var a3 := float(i) / 9.0 * TAU
			var pos3 := center + Vector2(cos(a3), sin(a3)) * (18.0 + p3 * 54.0)
			draw_circle(pos3, 4.5, Color(0.46, 0.27, 0.14, 0.8 * (1.0 - p3)))

func _draw_fallback(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color("#8bc76e"))
	draw_rect(Rect2(w * 0.27, h * 0.42, w * 0.46, h * 0.42), Color("#765037"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 36), "Tiny Farm asset loading...", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
