extends Node2D

const DURATION := 10.0
const FlightRig = preload("res://flight_rig.gd")
const CinematicHud = preload("res://cinematic_hud.gd")

var elapsed := 0.0
var rig: Node2D
var camera: Camera2D
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var hud: Control


func _ready() -> void:
	_build_rig()
	_build_camera()
	_build_hud()
	_build_fade()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		elapsed = fmod(elapsed, DURATION)

	_update_rig(elapsed)
	_update_camera(elapsed)
	_update_fade(elapsed)
	hud.set_cinematic_time(elapsed, DURATION)
	queue_redraw()


func _build_rig() -> void:
	rig = FlightRig.new()
	rig.z_index = 50
	add_child(rig)
	rig.position = Vector2(560, 700)
	rig.scale = Vector2.ONE * 0.86


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	camera.zoom = Vector2.ONE
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	hud = CinematicHud.new()
	layer.add_child(hud)


func _build_fade() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.position = Vector2.ZERO
	fade_rect.size = get_viewport_rect().size
	fade_rect.color = Color(0.025, 0.055, 0.072, 1.0)
	fade_layer.add_child(fade_rect)


func _update_rig(t: float) -> void:
	var pos := Vector2(560, 700)
	var rot := -0.025
	var scale_value := 0.86

	if t < 1.8:
		var u := _smooth(t / 1.8)
		pos = Vector2(560 + u * 22.0, 700 - u * 5.0)
		rot = -0.025 + sin(t * 2.8) * 0.008
	elif t < 4.8:
		var u := _smooth((t - 1.8) / 3.0)
		pos = Vector2(
			582 + 790.0 * u,
			695 - 305.0 * u - sin(u * PI) * 72.0
		)
		rot = lerp(-0.03, -0.14, u) + sin(t * 2.2) * 0.012
		scale_value = lerp(0.86, 0.93, u)
	elif t < 8.8:
		var u := _smooth((t - 4.8) / 4.0)
		pos = Vector2(
			1372 + 1180.0 * u,
			390 - 80.0 * u + sin(t * 1.65) * 16.0
		)
		rot = -0.09 + sin(t * 1.4) * 0.025
		scale_value = lerp(0.93, 0.88, u)
	else:
		var u := _smooth((t - 8.8) / 1.2)
		pos = Vector2(
			2552 + 360.0 * u,
			310 - 76.0 * u
		)
		rot = lerp(-0.07, -0.025, u)
		scale_value = lerp(0.88, 0.70, u)

	rig.position = pos
	rig.rotation = rot
	rig.scale = Vector2.ONE * scale_value
	rig.set_cinematic_time(t)


func _update_camera(t: float) -> void:
	var target := Vector2(960, 540)
	var zoom_value := 1.0

	if t < 1.8:
		var u := _smooth(t / 1.8)
		target = Vector2(960 + u * 18.0, 540 - u * 12.0)
		zoom_value = lerp(1.02, 1.07, u)
	elif t < 4.8:
		var u := _smooth((t - 1.8) / 3.0)
		target = Vector2(978 + 410.0 * u, 528 - 112.0 * u)
		zoom_value = lerp(1.07, 1.02, u)
	elif t < 8.8:
		var u := _smooth((t - 4.8) / 4.0)
		target = rig.position + Vector2(260 + 100.0 * u, 145 + 35.0 * u)
		zoom_value = lerp(1.02, 0.90, u)
	else:
		var u := _smooth((t - 8.8) / 1.2)
		target = rig.position + Vector2(390 + 100.0 * u, 200 + 55.0 * u)
		zoom_value = lerp(0.90, 0.76, u)

	# Tiny handheld-style movement to avoid a sterile slide.
	target += Vector2(sin(t * 3.2) * 2.0, cos(t * 4.1) * 1.5)
	camera.position = target
	camera.zoom = Vector2.ONE * zoom_value


func _update_fade(t: float) -> void:
	fade_rect.size = get_viewport_rect().size
	var alpha := 0.0
	if t < 0.65:
		alpha = 1.0 - _smooth(t / 0.65)
	elif t > 9.25:
		alpha = _smooth((t - 9.25) / 0.75)
	fade_rect.color = Color(0.025, 0.055, 0.072, alpha)


func _draw() -> void:
	_draw_sky()
	_draw_sun_and_haze()
	_draw_far_mountains()
	_draw_high_cloud_banks()
	_draw_distant_ruins()
	_draw_giant_tree()
	_draw_mid_cliffs_and_water()
	_draw_ruin_city()
	_draw_near_clouds()
	_draw_launch_cliff()
	_draw_takeoff_dust()
	_draw_wind_streaks()
	_draw_birds()


func _draw_sky() -> void:
	var top := Color(0.20, 0.48, 0.74, 1.0)
	var mid := Color(0.50, 0.72, 0.87, 1.0)
	var horizon := Color(0.97, 0.72, 0.42, 1.0)
	for i in range(60):
		var p := float(i) / 59.0
		var col: Color
		if p < 0.62:
			col = top.lerp(mid, p / 0.62)
		else:
			col = mid.lerp(horizon, (p - 0.62) / 0.38)
		var y := -900.0 + p * 2700.0
		draw_rect(Rect2(-1900, y, 7900, 48), col, true)

	# Thin painterly cloud strokes high in the sky.
	for i in range(22):
		var x := -200.0 + i * 235.0
		var y := 96.0 + float((i * 57) % 190)
		var w := 80.0 + float((i * 31) % 150)
		draw_line(Vector2(x, y), Vector2(x + w, y - 18), Color(1.0, 0.86, 0.68, 0.18), 11.0, true)
		draw_line(Vector2(x + 26, y - 12), Vector2(x + w * 0.72, y - 28), Color(1.0, 0.95, 0.86, 0.22), 6.0, true)


func _draw_sun_and_haze() -> void:
	var sun := Vector2(2780, 245)
	for i in range(10, 0, -1):
		var r := 52.0 + i * 38.0
		draw_circle(sun, r, Color(1.0, 0.78, 0.35, 0.010 + i * 0.006))
	draw_circle(sun, 34.0, Color(1.0, 0.96, 0.72, 1.0))
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var a := sun + Vector2(cos(angle), sin(angle)) * 74.0
		var b := sun + Vector2(cos(angle), sin(angle)) * 190.0
		draw_line(a, b, Color(1.0, 0.83, 0.48, 0.12), 7.0, true)

	# Warm haze near the horizon.
	for i in range(8):
		draw_rect(Rect2(-1000, 410 + i * 34, 6500, 34), Color(1.0, 0.75, 0.47, 0.020 + i * 0.008), true)


func _draw_far_mountains() -> void:
	_draw_ridge(520, 115, 240, 0.55, Color(0.33, 0.46, 0.55, 0.48), 0.0)
	_draw_ridge(590, 155, 205, 0.77, Color(0.25, 0.39, 0.45, 0.63), 140.0)
	_draw_ridge(665, 190, 170, 1.05, Color(0.20, 0.33, 0.35, 0.77), 280.0)


func _draw_ridge(base_y: float, height: float, step: float, jagged: float, color: Color, offset: float) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(-1300, 1600))
	var x := -1100.0
	var i := 0
	while x < 5200:
		var local_h: float = height * (0.55 + 0.45 * absf(sin(float(i) * 1.73 + offset * 0.001)))
		var y: float = base_y - local_h * (0.55 + 0.45 * absf(sin(float(i) * jagged)))
		pts.append(Vector2(x, y))
		x += step
		i += 1
	pts.append(Vector2(5400, 1600))
	draw_colored_polygon(pts, color)


func _draw_high_cloud_banks() -> void:
	var specs := [
		Vector4(80, 530, 1.4, 0.24), Vector4(520, 475, 1.1, 0.22),
		Vector4(920, 540, 1.7, 0.30), Vector4(1420, 490, 1.0, 0.22),
		Vector4(1880, 535, 1.5, 0.27), Vector4(2320, 470, 1.1, 0.20),
		Vector4(2780, 525, 1.65, 0.28), Vector4(3260, 485, 1.2, 0.22),
		Vector4(3720, 540, 1.5, 0.25), Vector4(4200, 500, 1.3, 0.22)
	]
	for i in range(specs.size()):
		var q: Vector4 = specs[i]
		var drift := elapsed * (6.0 + (i % 3) * 2.0)
		_draw_cloud(Vector2(q.x - drift, q.y + sin(elapsed * 0.35 + i) * 5.0), q.z, q.w)


func _draw_distant_ruins() -> void:
	_draw_ruin_cluster(Vector2(830, 535), 0.48, Color(0.26, 0.33, 0.32, 0.58))
	_draw_ruin_cluster(Vector2(1620, 500), 0.56, Color(0.23, 0.31, 0.30, 0.64))
	_draw_ruin_cluster(Vector2(2310, 520), 0.52, Color(0.22, 0.29, 0.28, 0.60))
	_draw_ruin_cluster(Vector2(3140, 510), 0.46, Color(0.22, 0.29, 0.28, 0.56))
	_draw_ruin_cluster(Vector2(3900, 545), 0.42, Color(0.22, 0.29, 0.28, 0.50))


func _draw_giant_tree() -> void:
	var base := Vector2(3520, 500)
	var trunk := PackedVector2Array([
		base + Vector2(-56, 35), base + Vector2(-18, -88), base + Vector2(-8, -205),
		base + Vector2(10, -212), base + Vector2(28, -88), base + Vector2(72, 35)
	])
	draw_colored_polygon(trunk, Color(0.23, 0.31, 0.27, 0.78))
	for i in range(5):
		var off := float(i - 2) * 25.0
		draw_line(base + Vector2(off, 15), base + Vector2(off * 0.35, -195), Color(0.45, 0.50, 0.38, 0.22), 6.0)
	var canopy_color := Color(0.16, 0.33, 0.25, 0.76)
	for i in range(15):
		var ang := TAU * float(i) / 15.0
		var radius := 72.0 + float((i * 23) % 48)
		var pos := base + Vector2(cos(ang) * 155.0, -220 + sin(ang) * 48.0)
		draw_circle(pos, radius, canopy_color)
	draw_circle(base + Vector2(0, -225), 150, canopy_color)
	for i in range(8):
		var x := base.x - 115 + i * 33
		draw_line(Vector2(x, base.y - 188), Vector2(x - 8 + sin(i) * 16, base.y - 116 + i % 3 * 10), Color(0.30, 0.36, 0.27, 0.38), 3.0)


func _draw_mid_cliffs_and_water() -> void:
	# Main winding river.
	var river := PackedVector2Array([
		Vector2(1250, 880), Vector2(1580, 730), Vector2(1930, 720),
		Vector2(2270, 800), Vector2(2630, 745), Vector2(3000, 690),
		Vector2(3390, 750), Vector2(3830, 830), Vector2(4210, 960),
		Vector2(4490, 1170), Vector2(4490, 1450), Vector2(2140, 1450),
		Vector2(1740, 1120)
	])
	draw_colored_polygon(river, Color(0.24, 0.60, 0.68, 0.90))
	for i in range(9):
		var y := 760.0 + i * 62.0
		draw_line(Vector2(1700 + i * 90, y), Vector2(2640 + i * 130, y + 120), Color(0.94, 0.90, 0.63, 0.12), 5.0, true)

	_draw_plateau(Vector2(960, 690), 450, 280, 1.0, true)
	_draw_plateau(Vector2(1540, 650), 520, 300, 0.95, true)
	_draw_plateau(Vector2(2200, 680), 500, 310, 0.92, true)
	_draw_plateau(Vector2(2850, 640), 590, 350, 0.98, true)
	_draw_plateau(Vector2(3580, 690), 520, 330, 0.90, false)

	# Waterfalls.
	_draw_waterfall(Vector2(1190, 770), 32, 205)
	_draw_waterfall(Vector2(1815, 735), 44, 250)
	_draw_waterfall(Vector2(2440, 780), 36, 210)
	_draw_waterfall(Vector2(3090, 740), 50, 285)
	_draw_waterfall(Vector2(3740, 790), 34, 210)


func _draw_plateau(origin: Vector2, width: float, depth: float, scale_value: float, has_ruins: bool) -> void:
	var top_color := Color(0.22, 0.39, 0.28, 0.96)
	var rock := Color(0.31, 0.34, 0.30, 0.96)
	var rock_dark := Color(0.20, 0.25, 0.23, 0.96)
	var top := PackedVector2Array([
		origin + Vector2(-width * 0.5, 0),
		origin + Vector2(-width * 0.30, -70 * scale_value),
		origin + Vector2(width * 0.08, -96 * scale_value),
		origin + Vector2(width * 0.48, -44 * scale_value),
		origin + Vector2(width * 0.5, 18)
	])
	var face := PackedVector2Array([
		top[0], top[4], origin + Vector2(width * 0.36, depth),
		origin + Vector2(-width * 0.35, depth * 0.94)
	])
	draw_colored_polygon(face, rock)
	draw_colored_polygon(top, top_color)
	for i in range(11):
		var x := origin.x - width * 0.38 + i * width * 0.075
		var y0 := origin.y + 18 + float((i * 19) % 38)
		var len: float = depth * (0.45 + 0.45 * absf(sin(float(i) * 1.5)))
		draw_line(Vector2(x, y0), Vector2(x - 10, y0 + len), Color(rock_dark.r, rock_dark.g, rock_dark.b, 0.35), 6.0)
	for i in range(18):
		var xg := origin.x - width * 0.44 + i * width * 0.05
		var hg := 18.0 + float((i * 17) % 28)
		draw_line(Vector2(xg, origin.y - 12), Vector2(xg + sin(i) * 8, origin.y - hg), Color(0.35, 0.49, 0.26, 0.72), 3.0)
	if has_ruins:
		_draw_ruin_cluster(origin + Vector2(-width * 0.10, -86 * scale_value), 0.72 * scale_value, Color(0.32, 0.34, 0.29, 0.92))


func _draw_waterfall(origin: Vector2, width: float, height: float) -> void:
	draw_rect(Rect2(origin.x - width * 0.5, origin.y, width, height), Color(0.83, 0.93, 0.90, 0.56), true)
	for i in range(5):
		var x := origin.x - width * 0.42 + i * width * 0.21
		draw_line(Vector2(x, origin.y + 4), Vector2(x + sin(i) * 4, origin.y + height), Color(1.0, 1.0, 0.95, 0.38), 3.0)
	draw_circle(origin + Vector2(0, height + 8), width * 0.88, Color(0.90, 0.96, 0.93, 0.17))


func _draw_ruin_city() -> void:
	_draw_ruin_cluster(Vector2(1510, 685), 0.90, Color(0.30, 0.32, 0.27, 0.96))
	_draw_ruin_cluster(Vector2(2140, 700), 0.83, Color(0.29, 0.31, 0.27, 0.94))
	_draw_ruin_cluster(Vector2(2920, 680), 0.95, Color(0.29, 0.31, 0.27, 0.96))

	# Long aqueduct bridge.
	var base_y := 790.0
	var start_x := 2470.0
	for i in range(8):
		var x := start_x + i * 78.0
		draw_line(Vector2(x, base_y - 34), Vector2(x, base_y + 92), Color(0.30, 0.31, 0.27, 0.84), 12.0)
		draw_arc(Vector2(x + 39, base_y + 6), 36, PI, TAU, 24, Color(0.30, 0.31, 0.27, 0.84), 10.0, true)
	draw_line(Vector2(start_x - 8, base_y - 38), Vector2(start_x + 8 * 78.0, base_y - 38), Color(0.35, 0.35, 0.29, 0.92), 13.0)


func _draw_ruin_cluster(origin: Vector2, scale_value: float, color: Color) -> void:
	var towers := [
		Vector4(-94, 0, 34, 154),
		Vector4(-39, 10, 26, 112),
		Vector4(16, -7, 38, 184),
		Vector4(78, 12, 30, 128)
	]
	for raw_tower in towers:
		var t: Vector4 = raw_tower
		var x: float = origin.x + t.x * scale_value
		var bottom: float = origin.y + t.y * scale_value
		var w: float = t.z * scale_value
		var h: float = t.w * scale_value
		draw_rect(Rect2(x - w * 0.5, bottom - h, w, h), color, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.62, bottom - h),
			Vector2(x, bottom - h - 22 * scale_value),
			Vector2(x + w * 0.62, bottom - h)
		]), color)
		for k in range(3):
			var wy: float = bottom - h * (0.25 + float(k) * 0.23)
			draw_rect(Rect2(x - 3 * scale_value, wy - 7 * scale_value, 6 * scale_value, 14 * scale_value), Color(0.05, 0.10, 0.10, 0.42), true)

	# Broken arches.
	for i in range(3):
		var cx := origin.x - 65 * scale_value + i * 66 * scale_value
		var cy := origin.y + 12 * scale_value
		var radius := 26 * scale_value
		draw_arc(Vector2(cx, cy), radius, PI, TAU, 18, color, 8 * scale_value, true)
		draw_line(Vector2(cx - radius, cy), Vector2(cx - radius, cy + 42 * scale_value), color, 8 * scale_value)
		draw_line(Vector2(cx + radius, cy), Vector2(cx + radius, cy + 42 * scale_value), color, 8 * scale_value)


func _draw_near_clouds() -> void:
	var specs := [
		Vector4(280, 780, 1.4, 0.38), Vector4(780, 860, 1.0, 0.33),
		Vector4(1320, 820, 1.2, 0.31), Vector4(1910, 900, 1.5, 0.36),
		Vector4(2520, 850, 1.1, 0.29), Vector4(3190, 930, 1.5, 0.34),
		Vector4(3860, 860, 1.3, 0.31)
	]
	for i in range(specs.size()):
		var q: Vector4 = specs[i]
		var drift := elapsed * (18.0 + (i % 3) * 4.0)
		_draw_cloud(Vector2(q.x - drift, q.y + sin(elapsed * 0.52 + i) * 8.0), q.z, q.w)


func _draw_cloud(pos: Vector2, scale_value: float, alpha: float) -> void:
	var warm := Color(1.0, 0.94, 0.82, alpha)
	var white := Color(1.0, 1.0, 0.96, alpha * 0.72)
	var cool := Color(0.75, 0.87, 0.90, alpha * 0.48)
	draw_circle(pos + Vector2(-62, 12) * scale_value, 54 * scale_value, cool)
	draw_circle(pos + Vector2(-18, -8) * scale_value, 71 * scale_value, warm)
	draw_circle(pos + Vector2(48, 7) * scale_value, 62 * scale_value, white)
	draw_circle(pos + Vector2(13, 35) * scale_value, 82 * scale_value, white)


func _draw_launch_cliff() -> void:
	var rock := Color(0.28, 0.29, 0.24, 1.0)
	var rock_dark := Color(0.16, 0.20, 0.18, 1.0)
	var cliff := PackedVector2Array([
		Vector2(-1100, 650), Vector2(110, 610), Vector2(430, 618),
		Vector2(635, 670), Vector2(700, 780), Vector2(530, 1220),
		Vector2(260, 1510), Vector2(-1100, 1510)
	])
	draw_colored_polygon(cliff, rock)
	for i in range(18):
		var x := -40.0 + i * 42.0
		var y := 650.0 + float((i * 29) % 120)
		draw_line(Vector2(x, y), Vector2(x - 30, y + 210 + (i % 4) * 35), Color(rock_dark.r, rock_dark.g, rock_dark.b, 0.45), 7.0)

	var grass := PackedVector2Array([
		Vector2(-1100, 610), Vector2(100, 585), Vector2(450, 596),
		Vector2(635, 650), Vector2(525, 652), Vector2(160, 624), Vector2(-1100, 646)
	])
	draw_colored_polygon(grass, Color(0.31, 0.46, 0.25, 1.0))
	for i in range(60):
		var xg := -70.0 + i * 15.0
		var base_y := 610.0 + sin(i * 0.61) * 9.0
		var h := 14.0 + float((i * 13) % 29)
		draw_line(Vector2(xg, base_y), Vector2(xg + sin(i) * 8, base_y - h), Color(0.46, 0.61, 0.30, 0.86), 2.5)

	# Tiny wildflowers.
	for i in range(20):
		var p := Vector2(-15 + i * 29, 585 + float((i * 17) % 27))
		draw_circle(p, 3.2, Color(1.0, 0.98, 0.88, 0.92))
		draw_circle(p + Vector2(3, 2), 2.6, Color(1.0, 0.82, 0.28, 0.92))


func _draw_takeoff_dust() -> void:
	if elapsed < 1.65 or elapsed > 4.1:
		return
	for i in range(28):
		var born := 1.65 + i * 0.065
		var age := elapsed - born
		if age < 0.0 or age > 1.55:
			continue
		var dir := 1.0 if i % 2 == 0 else -1.0
		var p := Vector2(
			575 - age * (95.0 + (i % 7) * 12.0) + dir * (i % 4) * 8.0,
			674 - age * (30.0 + (i % 5) * 12.0)
		)
		var r := 6.0 + age * (13.0 + (i % 3) * 4.0)
		var a := (1.0 - age / 1.55) * 0.20
		draw_circle(p, r, Color(0.83, 0.72, 0.51, a))

	for i in range(18):
		var born2 := 1.82 + i * 0.08
		var age2 := elapsed - born2
		if age2 < 0.0 or age2 > 1.2:
			continue
		var px := 580 - age2 * (150 + (i % 4) * 30) - i * 3
		var py := 650 - age2 * (65 + (i % 5) * 9)
		draw_line(Vector2(px, py), Vector2(px - 7, py + 9), Color(0.30, 0.42, 0.20, 0.55 * (1.0 - age2 / 1.2)), 3.0, true)


func _draw_wind_streaks() -> void:
	if elapsed < 1.7:
		return
	for i in range(22):
		var x := wrapf(250.0 + i * 238.0 - elapsed * (180.0 + (i % 4) * 35.0), -400.0, 5000.0)
		var y := 180.0 + float((i * 91) % 700)
		var length := 70.0 + float((i * 37) % 125)
		var alpha := 0.055 + float(i % 4) * 0.025
		draw_line(Vector2(x, y), Vector2(x + length, y - 5), Color(1.0, 0.97, 0.83, alpha), 2.0, true)


func _draw_birds() -> void:
	for i in range(9):
		var x := 1900.0 + i * 150.0 - elapsed * 18.0
		var y := 410.0 + sin(i * 1.8 + elapsed * 0.7) * 46.0
		var s := 8.0 + (i % 3) * 2.0
		var col := Color(0.10, 0.16, 0.17, 0.40)
		draw_line(Vector2(x - s, y), Vector2(x, y - s * 0.40), col, 2.0, true)
		draw_line(Vector2(x, y - s * 0.40), Vector2(x + s, y), col, 2.0, true)


func _smooth(value: float) -> float:
	var v: float = clampf(value, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)
