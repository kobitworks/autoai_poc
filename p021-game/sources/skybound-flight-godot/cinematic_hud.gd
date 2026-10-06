extends Control
class_name SkyboundCinematicHud

var cinematic_time := 0.0
var duration := 10.0
var font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	set_process(true)


func set_cinematic_time(value: float, total: float) -> void:
	cinematic_time = value
	duration = maxf(total, 0.1)
	queue_redraw()


func _process(_delta: float) -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _draw() -> void:
	var s: Vector2 = size
	var unit: float = clampf(minf(s.x / 1920.0, s.y / 1080.0), 0.70, 1.35)
	var margin: float = 28.0 * unit
	var p: float = clampf(cinematic_time / duration, 0.0, 1.0)
	var speed: float = _speed_for_time(cinematic_time)
	var altitude: int = int(round(lerpf(84.0, 326.0, _smooth(clampf((cinematic_time - 1.4) / 5.8, 0.0, 1.0)))))
	var distance: float = lerpf(1.8, 0.72, p)

	# Top-left cinematic mission card.
	var panel: Rect2 = Rect2(margin, margin, 380.0 * unit, 112.0 * unit)
	draw_rect(panel, Color(0.035, 0.075, 0.10, 0.72), true)
	draw_rect(panel, Color(0.88, 0.71, 0.30, 0.26), false, 1.5 * unit)
	_draw_diamond(Vector2(panel.position.x + 31 * unit, panel.position.y + 34 * unit), 13 * unit, Color(0.96, 0.72, 0.20, 1.0))
	draw_string(font, panel.position + Vector2(58, 35) * unit, "SKYBOUND", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * unit), Color(1.0, 0.91, 0.70, 1.0))
	draw_string(font, panel.position + Vector2(58, 64) * unit, "Dawn Launch", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * unit), Color(1, 1, 1, 0.96))
	draw_string(font, panel.position + Vector2(58, 91) * unit, "CINEMATIC MODE  /  AUTO FLIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * unit), Color(0.78, 0.88, 0.91, 0.88))

	# Compass line across the top.
	var center_x: float = s.x * 0.55
	var compass_y: float = margin + 23 * unit
	draw_line(Vector2(center_x - 260 * unit, compass_y), Vector2(center_x + 260 * unit, compass_y), Color(1,1,1,0.32), 1.5 * unit)
	for i in range(11):
		var tx: float = center_x - 250 * unit + float(i) * 50 * unit
		var h: float = 9.0 * unit if i % 5 == 0 else 5.0 * unit
		draw_line(Vector2(tx, compass_y - h), Vector2(tx, compass_y + h), Color(1,1,1,0.46), 1.2 * unit)
	draw_string(font, Vector2(center_x - 260 * unit, compass_y - 13 * unit), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * unit), Color(1,1,1,0.70))
	draw_string(font, Vector2(center_x - 8 * unit, compass_y - 13 * unit), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * unit), Color(1,1,1,0.95))
	draw_string(font, Vector2(center_x + 245 * unit, compass_y - 13 * unit), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * unit), Color(1,1,1,0.70))
	_draw_diamond(Vector2(center_x + (p - 0.35) * 180 * unit, compass_y), 7 * unit, Color(1.0, 0.73, 0.20, 1.0))

	# Waypoint.
	var wp: Vector2 = Vector2(s.x * 0.60, s.y * 0.28)
	_draw_diamond(wp, 13 * unit, Color(1.0, 0.73, 0.20, 1.0))
	var dist_text: String = "%.1f km" % distance
	draw_string(font, wp + Vector2(-30, 38) * unit, dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * unit), Color(1,1,1,0.92))

	# Speed gauge bottom-left.
	var gauge_c: Vector2 = Vector2(margin + 82 * unit, s.y - margin - 80 * unit)
	draw_circle(gauge_c, 71 * unit, Color(0.02, 0.045, 0.055, 0.58))
	draw_arc(gauge_c, 61 * unit, PI * 0.78, PI * 2.22, 48, Color(1,1,1,0.34), 3 * unit, true)
	var speed_ratio: float = clampf(speed / 78.0, 0.0, 1.0)
	draw_arc(gauge_c, 61 * unit, PI * 0.78, lerpf(PI * 0.78, PI * 2.22, speed_ratio), 48, Color(0.30, 0.82, 1.0, 0.95), 7 * unit, true)
	draw_string(font, gauge_c + Vector2(-28, 9) * unit, str(int(round(speed))), HORIZONTAL_ALIGNMENT_LEFT, -1, int(42 * unit), Color(1,1,1,0.98))
	draw_string(font, gauge_c + Vector2(-20, 35) * unit, "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * unit), Color(1,1,1,0.74))

	# Cinematic progress bar bottom center.
	var bar_w: float = minf(520.0 * unit, s.x * 0.38)
	var bar_x: float = s.x * 0.5 - bar_w * 0.5
	var bar_y: float = s.y - margin - 40 * unit
	draw_string(font, Vector2(bar_x, bar_y - 18 * unit), "AUTO FLIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * unit), Color(1.0, 0.91, 0.70, 0.90))
	draw_rect(Rect2(bar_x, bar_y, bar_w, 9 * unit), Color(0.02,0.05,0.06,0.68), true)
	draw_rect(Rect2(bar_x, bar_y, bar_w * p, 9 * unit), Color(0.33,0.82,0.92,0.92), true)
	draw_rect(Rect2(bar_x, bar_y, bar_w, 9 * unit), Color(1,1,1,0.30), false, 1.2 * unit)

	# Altitude scale at right.
	var ax: float = s.x - margin - 36 * unit
	var ay0: float = s.y * 0.34
	var ay1: float = s.y * 0.64
	draw_string(font, Vector2(ax - 18 * unit, ay0 - 22 * unit), "ALT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * unit), Color(1,1,1,0.78))
	draw_line(Vector2(ax, ay0), Vector2(ax, ay1), Color(1,1,1,0.70), 2.0 * unit)
	for i in range(7):
		var yy: float = lerpf(ay0, ay1, float(i) / 6.0)
		draw_line(Vector2(ax - 7 * unit, yy), Vector2(ax + 7 * unit, yy), Color(1,1,1,0.58), 1.5 * unit)
	var alt_ratio: float = clampf((float(altitude) - 84.0) / 242.0, 0.0, 1.0)
	var marker_y: float = lerpf(ay1, ay0, alt_ratio)
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax - 12 * unit, marker_y),
		Vector2(ax - 24 * unit, marker_y - 8 * unit),
		Vector2(ax - 24 * unit, marker_y + 8 * unit)
	]), Color(1.0, 0.82, 0.38, 0.95))
	draw_string(font, Vector2(ax - 16 * unit, marker_y - 15 * unit), str(altitude) + " m", HORIZONTAL_ALIGNMENT_RIGHT, -1, int(17 * unit), Color(1,1,1,0.94))


func _speed_for_time(t: float) -> float:
	if t < 1.8:
		return lerpf(8.0, 22.0, _smooth(t / 1.8))
	if t < 4.8:
		return lerpf(22.0, 72.0, _smooth((t - 1.8) / 3.0))
	if t < 8.8:
		return 69.0 + sin(t * 1.8) * 4.0
	return lerpf(69.0, 58.0, _smooth((t - 8.8) / 1.2))


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0)
	])
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.16))
	var closed := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	draw_polyline(closed, color, 2.0, true)


func _smooth(v: float) -> float:
	var x: float = clampf(v, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
