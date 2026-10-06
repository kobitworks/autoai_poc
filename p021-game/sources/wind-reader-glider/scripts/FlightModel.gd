class_name WindReaderFlightModel
extends RefCounted

const ALTITUDE_MIN := 0.0
const ALTITUDE_MAX := 100.0
const BOOST_MAX := 100.0
const DURABILITY_MAX := 100.0
const NATURAL_SINK := 1.2
const MAX_CLIMB := 6.5
const BOOST_MULTIPLIER := 1.35
const BOOST_USE_PER_SEC := 25.0
const BOOST_RECOVERY_PER_SEC := 5.0
const COURSE_LIMIT := 1.0
const COURSE_GRACE := 1.5

var position := Vector3(0.0, 55.0, 0.0)
var vertical_speed := 0.0
var depth_speed := 0.0
var boost := 60.0
var durability := 100.0
var base_speed := 18.0
var elapsed := 0.0
var course_out_time := 0.0
var invulnerable_time := 0.0
var failed_reason := ""
var boosting := false

func reset(stage: Dictionary) -> void:
	position = Vector3(0.0, 55.0, 0.0)
	vertical_speed = 0.0
	depth_speed = 0.0
	boost = 60.0
	durability = DURABILITY_MAX
	base_speed = float(stage.get("base_speed", 18.0))
	elapsed = 0.0
	course_out_time = 0.0
	invulnerable_time = 0.0
	failed_reason = ""
	boosting = false

func step(delta: float, steer: Vector2, boost_pressed: bool, wind: Dictionary = {}) -> void:
	if failed_reason != "":
		return
	elapsed += delta
	invulnerable_time = maxf(0.0, invulnerable_time - delta)

	var lift := float(wind.get("lift", 0.0))
	var cross := float(wind.get("cross", 0.0))
	var forward := float(wind.get("forward", 0.0))
	var extra_boost := float(wind.get("boost_recovery", 0.0))

	var steer_climb := clampf(steer.y, -1.0, 1.0)
	var steer_depth := clampf(steer.x, -1.0, 1.0)
	var climb_target := steer_climb * MAX_CLIMB - NATURAL_SINK + lift
	vertical_speed = move_toward(vertical_speed, climb_target, 12.0 * delta)

	var pitch_factor := 1.0 - maxf(steer_climb, 0.0) * 0.12 + maxf(-steer_climb, 0.0) * 0.05
	boosting = boost_pressed and boost >= 5.0
	var forward_speed := base_speed * pitch_factor * (BOOST_MULTIPLIER if boosting else 1.0) + forward

	var depth_target := steer_depth * 0.85 + cross
	depth_speed = move_toward(depth_speed, depth_target, 2.5 * delta)

	position.x += maxf(1.0, forward_speed) * delta
	position.y += vertical_speed * delta
	position.z += depth_speed * delta
	position.y = minf(position.y, ALTITUDE_MAX)

	if boosting:
		boost = maxf(0.0, boost - BOOST_USE_PER_SEC * delta)
	else:
		boost = minf(BOOST_MAX, boost + (BOOST_RECOVERY_PER_SEC + extra_boost) * delta)

	if position.y <= ALTITUDE_MIN:
		position.y = ALTITUDE_MIN
		failed_reason = "高度を失いました"

	if absf(position.z) > COURSE_LIMIT:
		course_out_time += delta
		if course_out_time >= COURSE_GRACE:
			failed_reason = "コースアウト"
	else:
		course_out_time = 0.0

	if durability <= 0.0:
		failed_reason = "耐久が尽きました"

func apply_collision(damage: float) -> bool:
	if invulnerable_time > 0.0 or failed_reason != "":
		return false
	durability = maxf(0.0, durability - maxf(0.0, damage))
	invulnerable_time = 0.8
	if durability <= 0.0:
		failed_reason = "耐久が尽きました"
	return true
