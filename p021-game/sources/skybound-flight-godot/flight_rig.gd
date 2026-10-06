extends Node2D
class_name SkyboundFlightRig

var cinematic_time := 0.0


func set_cinematic_time(value: float) -> void:
	cinematic_time = value
	queue_redraw()


func _draw() -> void:
	var flutter := sin(cinematic_time * 7.4) * 11.0 + sin(cinematic_time * 3.1) * 6.0
	var fabric := Color(0.91, 0.82, 0.65, 1.0)
	var fabric_light := Color(1.0, 0.93, 0.76, 1.0)
	var fabric_shadow := Color(0.67, 0.53, 0.37, 1.0)
	var wood := Color(0.35, 0.20, 0.10, 1.0)
	var metal := Color(0.34, 0.36, 0.35, 1.0)
	var metal_light := Color(0.64, 0.67, 0.62, 1.0)
	var red := Color(0.66, 0.17, 0.11, 1.0)

	# Drop shadow under the rig.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-345, 36), Vector2(-95, -28), Vector2(150, -18),
		Vector2(405, 28), Vector2(160, 62), Vector2(-120, 66)
	]), Color(0.03, 0.05, 0.05, 0.16))

	# Left and right canvas wings.
	var left_wing := PackedVector2Array([
		Vector2(-390, -18), Vector2(-156, -108), Vector2(-18, -60),
		Vector2(6, -18), Vector2(-115, 26), Vector2(-314, 34)
	])
	var right_wing := PackedVector2Array([
		Vector2(-4, -52), Vector2(151, -112), Vector2(438, -2),
		Vector2(319, 56), Vector2(120, 24), Vector2(5, -12)
	])
	draw_colored_polygon(left_wing, fabric)
	draw_colored_polygon(right_wing, fabric_light)

	# Red identification markings.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-390, -18), Vector2(-315, -48), Vector2(-257, 18), Vector2(-314, 34)
	]), red)
	draw_colored_polygon(PackedVector2Array([
		Vector2(342, -39), Vector2(438, -2), Vector2(372, 30), Vector2(292, 19)
	]), red)

	# Fabric shading.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-314, 34), Vector2(-115, 26), Vector2(6, -18),
		Vector2(-18, -60), Vector2(-128, -39)
	]), Color(fabric_shadow.r, fabric_shadow.g, fabric_shadow.b, 0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -12), Vector2(120, 24), Vector2(319, 56),
		Vector2(372, 30), Vector2(218, 10)
	]), Color(fabric_shadow.r, fabric_shadow.g, fabric_shadow.b, 0.18))

	# Wing seams and ribs.
	for i in range(6):
		var t := float(i + 1) / 7.0
		var lx := lerp(-365.0, -24.0, t)
		var ly := lerp(-16.0, -50.0, t)
		draw_line(Vector2(lx, ly), Vector2(lerp(-304.0, -8.0, t), lerp(29.0, -16.0, t)), Color(0.34, 0.26, 0.18, 0.28), 2.0)
	for i in range(7):
		var t := float(i + 1) / 8.0
		var rx := lerp(9.0, 420.0, t)
		draw_line(Vector2(rx, lerp(-50.0, -3.0, t)), Vector2(lerp(13.0, 319.0, t), lerp(-12.0, 54.0, t)), Color(0.34, 0.26, 0.18, 0.24), 2.0)

	# Main wooden spars.
	draw_line(Vector2(-376, -9), Vector2(421, 6), wood, 12.0, true)
	draw_line(Vector2(-154, -93), Vector2(318, 47), wood, 10.0, true)
	draw_line(Vector2(-106, 31), Vector2(151, -98), wood, 8.0, true)

	# Metallic brackets on the spars.
	var joints := [
		Vector2(-158, -5), Vector2(-46, -3), Vector2(62, -1),
		Vector2(170, 1), Vector2(284, 3), Vector2(4, -25)
	]
	for p in joints:
		draw_circle(p, 11.0, metal)
		draw_circle(p, 5.0, metal_light)
		draw_circle(p, 2.0, Color(0.12, 0.12, 0.11, 1.0))

	# Suspension frame and control bar.
	draw_line(Vector2(-104, 28), Vector2(18, 88), metal, 8.0, true)
	draw_line(Vector2(164, 17), Vector2(18, 88), metal, 8.0, true)
	draw_line(Vector2(-22, -33), Vector2(18, 88), metal, 7.0, true)
	draw_line(Vector2(-31, 68), Vector2(123, 61), Color(0.21, 0.16, 0.12, 1.0), 8.0, true)

	# Tension cables.
	var cable := Color(0.20, 0.18, 0.15, 0.72)
	draw_line(Vector2(-357, -15), Vector2(18, 88), cable, 2.0, true)
	draw_line(Vector2(416, 2), Vector2(18, 88), cable, 2.0, true)
	draw_line(Vector2(-147, -95), Vector2(18, 88), cable, 2.0, true)
	draw_line(Vector2(149, -102), Vector2(18, 88), cable, 2.0, true)

	# Backpack behind the heroine.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40, -105), Vector2(4, -125), Vector2(35, -101),
		Vector2(28, -54), Vector2(-20, -55), Vector2(-49, -76)
	]), Color(0.27, 0.23, 0.16, 1.0))
	draw_circle(Vector2(22, -69), 12, Color(0.44, 0.31, 0.17, 1.0))
	draw_line(Vector2(-20, -92), Vector2(27, -94), Color(0.58, 0.42, 0.23, 0.9), 4.0)

	# Hero legs and boots.
	draw_line(Vector2(2, -47), Vector2(-26, 22), Color(0.23, 0.28, 0.29, 1.0), 20.0, true)
	draw_line(Vector2(24, -44), Vector2(58, 14), Color(0.23, 0.28, 0.29, 1.0), 20.0, true)
	draw_line(Vector2(-28, 22), Vector2(-52, 38), Color(0.24, 0.15, 0.09, 1.0), 18.0, true)
	draw_line(Vector2(58, 14), Vector2(77, 26), Color(0.24, 0.15, 0.09, 1.0), 18.0, true)

	# Torso: cream shirt and darker vest.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -120), Vector2(38, -127), Vector2(70, -83),
		Vector2(42, -38), Vector2(-15, -43), Vector2(-42, -82)
	]), Color(0.91, 0.86, 0.73, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, -116), Vector2(25, -121), Vector2(49, -79),
		Vector2(34, -48), Vector2(-10, -51), Vector2(-27, -83)
	]), Color(0.25, 0.31, 0.29, 1.0))
	draw_line(Vector2(-10, -112), Vector2(36, -49), Color(0.55, 0.36, 0.18, 1.0), 6.0, true)
	draw_line(Vector2(26, -119), Vector2(-2, -48), Color(0.55, 0.36, 0.18, 1.0), 6.0, true)

	# Arms reaching toward the controls.
	var skin := Color(0.88, 0.66, 0.48, 1.0)
	draw_line(Vector2(42, -102), Vector2(86, -53), skin, 15.0, true)
	draw_line(Vector2(-22, -103), Vector2(-37, -61), skin, 15.0, true)
	draw_line(Vector2(86, -53), Vector2(120, -29), Color(0.19, 0.18, 0.16, 1.0), 14.0, true)
	draw_line(Vector2(-37, -61), Vector2(-20, -34), Color(0.19, 0.18, 0.16, 1.0), 14.0, true)

	# Head, hair, face, goggles.
	draw_circle(Vector2(15, -153), 30, skin)
	draw_circle(Vector2(7, -163), 31, Color(0.24, 0.13, 0.08, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -171), Vector2(10, -190), Vector2(39, -174),
		Vector2(44, -151), Vector2(30, -160), Vector2(14, -145),
		Vector2(-2, -151)
	]), Color(0.29, 0.15, 0.08, 1.0))
	for i in range(7):
		var x := -18.0 - i * 8.0
		var y := -161.0 + sin(cinematic_time * 5.0 + i) * 4.0 + i * 2.0
		draw_line(Vector2(-4, -163), Vector2(x, y), Color(0.27, 0.14, 0.07, 0.95), 7.0, true)
	draw_circle(Vector2(18, -151), 3.2, Color(0.08, 0.08, 0.07, 1.0))
	draw_line(Vector2(28, -143), Vector2(36, -145), Color(0.37, 0.17, 0.10, 0.8), 2.0, true)
	draw_arc(Vector2(4, -179), 14, PI + 0.15, TAU - 0.15, 18, Color(0.62, 0.42, 0.13, 1.0), 6.0, true)
	draw_circle(Vector2(-2, -179), 8.5, Color(0.19, 0.29, 0.35, 1.0))
	draw_circle(Vector2(12, -181), 8.5, Color(0.19, 0.29, 0.35, 1.0))
	draw_circle(Vector2(-4, -182), 3.2, Color(0.82, 0.92, 0.94, 0.75))
	draw_circle(Vector2(10, -184), 3.2, Color(0.82, 0.92, 0.94, 0.75))

	# Red scarf, wide enough to read clearly at game scale.
	var scarf := PackedVector2Array([
		Vector2(-8, -133), Vector2(-30, -135),
		Vector2(-82, -149 + flutter * 0.18),
		Vector2(-140, -143 - flutter * 0.28),
		Vector2(-207, -166 + flutter),
		Vector2(-191, -139 + flutter * 0.52),
		Vector2(-132, -119 - flutter * 0.08),
		Vector2(-76, -124 + flutter * 0.18),
		Vector2(-25, -119)
	])
	draw_colored_polygon(scarf, red)
	draw_line(Vector2(-30, -130), Vector2(-190, -151 + flutter * 0.75), Color(0.88, 0.29, 0.18, 0.42), 3.0, true)

	# Small wind ribbons and highlights sell motion.
	for i in range(4):
		var y := -112.0 + i * 21.0
		draw_line(Vector2(-285 - i * 18, y), Vector2(-224 - i * 12, y - 5), Color(1.0, 0.95, 0.78, 0.20), 2.0, true)
