extends Node2D

const DURATION := 10.0
const HERO_TEXTURE: Texture2D = preload("res://assets/heroine.svg")

var elapsed := 0.0
var hero_group: Node2D
var heroine: Sprite2D
var scarf: Line2D
var camera: Camera2D
var fade_rect: ColorRect


func _ready() -> void:
	_build_hero()
	_build_camera()
	_build_fade()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		elapsed = fmod(elapsed, DURATION)

	_update_hero(elapsed)
	_update_camera(elapsed)
	_update_fade(elapsed)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		elapsed = 0.0
	elif event is InputEventMouseButton and event.pressed:
		elapsed = 0.0
	elif event is InputEventScreenTouch and event.pressed:
		elapsed = 0.0


func _build_hero() -> void:
	hero_group = Node2D.new()
	hero_group.z_index = 20
	add_child(hero_group)

	scarf = Line2D.new()
	scarf.width = 20.0
	scarf.default_color = Color(0.61, 0.20, 0.13, 1.0)
	scarf.antialiased = true
	scarf.points = PackedVector2Array([
		Vector2(-4, -90),
		Vector2(-48, -104),
		Vector2(-104, -96),
		Vector2(-162, -120)
	])
	hero_group.add_child(scarf)

	var wing_shadow := Polygon2D.new()
	wing_shadow.polygon = PackedVector2Array([
		Vector2(-250, 18),
		Vector2(-78, -48),
		Vector2(18, -22),
		Vector2(116, -54),
		Vector2(252, 8),
		Vector2(126, 36),
		Vector2(18, 24),
		Vector2(-116, 42)
	])
	wing_shadow.color = Color(0.23, 0.20, 0.17, 0.28)
	wing_shadow.position = Vector2(6, 10)
	hero_group.add_child(wing_shadow)

	var wing := Polygon2D.new()
	wing.polygon = PackedVector2Array([
		Vector2(-250, 0),
		Vector2(-78, -66),
		Vector2(18, -40),
		Vector2(116, -72),
		Vector2(252, -10),
		Vector2(126, 22),
		Vector2(18, 10),
		Vector2(-116, 28)
	])
	wing.color = Color(0.91, 0.82, 0.65, 1.0)
	hero_group.add_child(wing)

	var wing_edge := Line2D.new()
	wing_edge.width = 5.0
	wing_edge.default_color = Color(0.26, 0.22, 0.18, 0.92)
	wing_edge.antialiased = true
	wing_edge.points = PackedVector2Array([
		Vector2(-250, 0),
		Vector2(-78, -66),
		Vector2(18, -40),
		Vector2(116, -72),
		Vector2(252, -10),
		Vector2(126, 22),
		Vector2(18, 10),
		Vector2(-116, 28),
		Vector2(-250, 0)
	])
	hero_group.add_child(wing_edge)

	var frame := Line2D.new()
	frame.width = 6.0
	frame.default_color = Color(0.23, 0.20, 0.17, 1.0)
	frame.antialiased = true
	frame.points = PackedVector2Array([
		Vector2(-154, -18),
		Vector2(146, 7),
		Vector2(28, 70),
		Vector2(-22, -32),
		Vector2(92, -35),
		Vector2(28, 70)
	])
	hero_group.add_child(frame)

	var nose := Polygon2D.new()
	nose.polygon = PackedVector2Array([
		Vector2(218, -17),
		Vector2(276, -4),
		Vector2(220, 10)
	])
	nose.color = Color(0.66, 0.29, 0.18, 1.0)
	hero_group.add_child(nose)

	heroine = Sprite2D.new()
	heroine.texture = HERO_TEXTURE
	heroine.position = Vector2(-2, -76)
	heroine.rotation = deg_to_rad(23.0)
	heroine.scale = Vector2(0.34, 0.34)
	heroine.modulate = Color(0.18, 0.24, 0.23, 1.0)
	hero_group.add_child(heroine)

	hero_group.position = Vector2(520, 700)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	camera.zoom = Vector2.ONE
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	fade_rect = ColorRect.new()
	layer.add_child(fade_rect)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0.02, 0.045, 0.055, 1.0)


func _update_hero(t: float) -> void:
	var pos := Vector2(520, 700)
	var rot := -0.035
	var scale_value := 0.95

	if t < 2.0:
		var u := _smooth(t / 2.0)
		pos = Vector2(520 + sin(t * 3.2) * 2.5, 700 - u * 4.0)
		rot = -0.035 + sin(t * 2.7) * 0.009
	elif t < 5.2:
		var u := _smooth((t - 2.0) / 3.2)
		pos = Vector2(
			520 + 820.0 * u,
			700 - 390.0 * u - 72.0 * sin(u * PI)
		)
		rot = lerp(-0.045, -0.16, u) + sin(t * 2.6) * 0.012
		scale_value = lerp(0.95, 1.0, u)
	elif t < 8.6:
		var u := _smooth((t - 5.2) / 3.4)
		pos = Vector2(
			1340 + 430.0 * u,
			310 - 58.0 * u + sin(t * 2.15) * 12.0
		)
		rot = -0.12 + sin(t * 1.45) * 0.028
	else:
		var u := _smooth((t - 8.6) / 1.4)
		pos = Vector2(
			1770 + 250.0 * u,
			252 - 90.0 * u
		)
		rot = lerp(-0.10, -0.055, u)
		scale_value = lerp(1.0, 0.72, u)

	hero_group.position = pos
	hero_group.rotation = rot
	hero_group.scale = Vector2.ONE * scale_value

	var flutter := sin(t * 8.5) * 10.0 + sin(t * 3.8) * 5.0
	scarf.points = PackedVector2Array([
		Vector2(-4, -90),
		Vector2(-48, -104 + flutter * 0.15),
		Vector2(-104, -96 - flutter * 0.35),
		Vector2(-166, -120 + flutter)
	])


func _update_camera(t: float) -> void:
	var target := Vector2(960, 540)
	var zoom_value := 1.0

	if t < 2.0:
		var u := _smooth(t / 2.0)
		target = Vector2(940 + 20.0 * u, 540 - 14.0 * u)
		zoom_value = lerp(1.03, 1.10, u)
	elif t < 5.2:
		var u := _smooth((t - 2.0) / 3.2)
		target = Vector2(960 + 360.0 * u, 526 - 150.0 * u)
		zoom_value = lerp(1.10, 1.05, u)
	elif t < 8.6:
		var u := _smooth((t - 5.2) / 3.4)
		target = hero_group.position + Vector2(210 + 80.0 * u, 105 + 40.0 * u)
		zoom_value = lerp(1.05, 0.88, u)
	else:
		var u := _smooth((t - 8.6) / 1.4)
		target = hero_group.position + Vector2(300 + 150.0 * u, 150 + 60.0 * u)
		zoom_value = lerp(0.88, 0.68, u)

	target += Vector2(sin(t * 3.7) * 2.3, cos(t * 4.2) * 1.7)
	camera.position = target
	camera.zoom = Vector2.ONE * zoom_value


func _update_fade(t: float) -> void:
	var alpha := 0.0
	if t < 0.7:
		alpha = 1.0 - _smooth(t / 0.7)
	elif t > 9.1:
		alpha = _smooth((t - 9.1) / 0.9)
	fade_rect.color = Color(0.02, 0.045, 0.055, alpha)


func _draw() -> void:
	_draw_sky()
	_draw_sun()
	_draw_mountains(620, 78, 0.018, Color(0.30, 0.43, 0.45, 0.55), elapsed * 5.0)
	_draw_mountains(715, 112, 0.026, Color(0.20, 0.34, 0.34, 0.78), elapsed * 11.0)
	_draw_valley()
	_draw_mountains(835, 146, 0.038, Color(0.13, 0.25, 0.22, 0.96), elapsed * 18.0)
	_draw_ruins()
	_draw_cloud_field()
	_draw_cliff()
	_draw_dust()
	_draw_wind()
	_draw_birds()


func _draw_sky() -> void:
	var top := Color(0.20, 0.43, 0.62, 1.0)
	var middle := Color(0.55, 0.71, 0.72, 1.0)
	var bottom := Color(0.89, 0.65, 0.40, 1.0)
	for i in range(44):
		var p := float(i) / 43.0
		var col := top.lerp(middle, p / 0.60) if p < 0.60 else middle.lerp(bottom, (p - 0.60) / 0.40)
		var y := -700.0 + p * 2500.0
		draw_rect(Rect2(-1200, y, 5200, 62), col, true)


func _draw_sun() -> void:
	var sun := Vector2(1510, 220)
	for i in range(7, 0, -1):
		var r := 44.0 + float(i) * 34.0
		draw_circle(sun, r, Color(1.0, 0.78, 0.39, 0.018 * float(i)))
	draw_circle(sun, 31.0, Color(1.0, 0.94, 0.69, 0.98))


func _draw_mountains(base_y: float, amp: float, freq: float, color: Color, phase: float) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(-1200, 1600))
	for i in range(48):
		var x := -1000.0 + float(i) * 115.0
		var y := (
			base_y
			+ sin((x + phase) * freq * 0.12) * amp
			+ sin((x + phase * 0.55) * freq * 0.31) * amp * 0.34
		)
		points.append(Vector2(x, y))
	points.append(Vector2(4400, 1600))
	draw_colored_polygon(points, color)


func _draw_valley() -> void:
	var water := PackedVector2Array([
		Vector2(920, 735),
		Vector2(1190, 665),
		Vector2(1510, 700),
		Vector2(1880, 820),
		Vector2(2470, 1110),
		Vector2(3100, 1360),
		Vector2(3100, 1600),
		Vector2(1560, 1600),
		Vector2(1190, 1140)
	])
	draw_colored_polygon(water, Color(0.28, 0.59, 0.63, 0.74))

	for i in range(8):
		var y := 760.0 + float(i) * 72.0
		draw_line(
			Vector2(1160 + i * 54.0, y),
			Vector2(1770 + i * 115.0, y + 160.0),
			Color(0.81, 0.92, 0.84, 0.12),
			3.0
		)


func _draw_ruins() -> void:
	var ruin_color := Color(0.16, 0.27, 0.27, 0.70)
	var glow := Color(0.80, 0.71, 0.50, 0.18)
	var bases := [
		Vector2(1080, 615),
		Vector2(1230, 600),
		Vector2(1390, 640),
		Vector2(1590, 625),
		Vector2(1810, 700)
	]
	for i in range(bases.size()):
		var p: Vector2 = bases[i]
		var h := 70.0 + float((i * 37) % 85)
		draw_rect(Rect2(p.x, p.y - h, 22, h), ruin_color, true)
		draw_rect(Rect2(p.x + 35, p.y - h * 0.72, 15, h * 0.72), ruin_color, true)
		draw_line(Vector2(p.x - 12, p.y), Vector2(p.x + 70, p.y), glow, 3.0)

	for i in range(5):
		var x := 1460.0 + i * 112.0
		draw_arc(Vector2(x, 765), 46, PI, TAU, 20, ruin_color, 8.0, true)
		draw_line(Vector2(x - 46, 765), Vector2(x - 46, 820), ruin_color, 8.0)
		draw_line(Vector2(x + 46, 765), Vector2(x + 46, 820), ruin_color, 8.0)


func _draw_cloud_field() -> void:
	var specs := [
		Vector4(180, 340, 1.35, 0.24),
		Vector4(520, 500, 1.05, 0.19),
		Vector4(880, 390, 0.76, 0.16),
		Vector4(1190, 505, 1.42, 0.25),
		Vector4(1580, 410, 0.95, 0.17),
		Vector4(1910, 560, 1.60, 0.26),
		Vector4(2240, 355, 0.78, 0.15),
		Vector4(2600, 620, 1.24, 0.19),
		Vector4(2940, 460, 1.48, 0.22)
	]
	for i in range(specs.size()):
		var q: Vector4 = specs[i]
		var drift := elapsed * (18.0 + i * 2.5)
		var x := wrapf(q.x - drift, -360.0, 3150.0)
		_draw_cloud(Vector2(x, q.y + sin(elapsed * 0.35 + i) * 7.0), q.z, q.w)


func _draw_cloud(pos: Vector2, size_scale: float, alpha: float) -> void:
	var cloud_color := Color(1.0, 0.96, 0.84, alpha)
	var soft_color := Color(1.0, 1.0, 1.0, alpha * 0.50)
	draw_circle(pos + Vector2(-64, 12) * size_scale, 55 * size_scale, soft_color)
	draw_circle(pos + Vector2(0, 0) * size_scale, 83 * size_scale, cloud_color)
	draw_circle(pos + Vector2(72, 18) * size_scale, 59 * size_scale, soft_color)
	draw_circle(pos + Vector2(18, 38) * size_scale, 92 * size_scale, Color(1.0, 0.98, 0.91, alpha * 0.72))


func _draw_cliff() -> void:
	var cliff := PackedVector2Array([
		Vector2(-900, 650),
		Vector2(170, 628),
		Vector2(510, 640),
		Vector2(620, 680),
		Vector2(700, 790),
		Vector2(560, 1160),
		Vector2(280, 1450),
		Vector2(-900, 1500)
	])
	draw_colored_polygon(cliff, Color(0.18, 0.25, 0.19, 1.0))

	var top_grass := PackedVector2Array([
		Vector2(-900, 620),
		Vector2(200, 602),
		Vector2(540, 620),
		Vector2(620, 665),
		Vector2(510, 652),
		Vector2(160, 632),
		Vector2(-900, 654)
	])
	draw_colored_polygon(top_grass, Color(0.34, 0.43, 0.27, 1.0))

	for i in range(34):
		var x := -100.0 + i * 20.0
		var h := 12.0 + float((i * 17) % 25)
		draw_line(
			Vector2(x, 630 + sin(i * 0.7) * 5.0),
			Vector2(x + sin(i) * 8.0, 630 - h),
			Color(0.54, 0.62, 0.34, 0.72),
			3.0
		)


func _draw_dust() -> void:
	if elapsed < 1.8 or elapsed > 4.4:
		return
	for i in range(16):
		var born := 1.85 + float(i) * 0.10
		var age := elapsed - born
		if age < 0.0 or age > 1.5:
			continue
		var p := Vector2(
			520 - age * (85 + i * 5.0) - (i % 3) * 18.0,
			675 - age * (30 + (i % 4) * 10.0)
		)
		var radius := 7.0 + age * 18.0
		var alpha := (1.0 - age / 1.5) * 0.19
		draw_circle(p, radius, Color(0.86, 0.76, 0.58, alpha))


func _draw_wind() -> void:
	if elapsed < 2.0:
		return
	for i in range(18):
		var x := wrapf(260.0 + i * 177.0 - elapsed * (120.0 + (i % 4) * 34.0), -300.0, 3100.0)
		var y := 190.0 + float((i * 83) % 680)
		var length := 65.0 + float((i * 29) % 120)
		var alpha := 0.08 + float(i % 4) * 0.025
		draw_line(
			Vector2(x, y),
			Vector2(x + length, y - 4.0),
			Color(1.0, 0.97, 0.83, alpha),
			2.0
		)


func _draw_birds() -> void:
	for i in range(5):
		var x := 1310.0 + i * 96.0 - elapsed * 14.0
		var y := 360.0 + sin(i * 1.7 + elapsed * 0.55) * 28.0
		var s := 8.0 + i * 1.8
		var col := Color(0.12, 0.20, 0.21, 0.44)
		draw_line(Vector2(x - s, y), Vector2(x, y - s * 0.42), col, 2.0)
		draw_line(Vector2(x, y - s * 0.42), Vector2(x + s, y), col, 2.0)


func _smooth(value: float) -> float:
	var v := clamp(value, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)
