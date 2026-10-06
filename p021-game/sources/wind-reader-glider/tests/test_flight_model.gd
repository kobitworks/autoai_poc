extends SceneTree

func _initialize() -> void:
	var Flight = load("res://scripts/FlightModel.gd")
	var Stage = load("res://scripts/StageDefinition.gd")
	var model = Flight.new()
	var stage = Stage.stage_1()
	model.reset(stage)

	if absf(model.position.y - 55.0) > 0.001:
		_fail("initial altitude")
		return

	for i in range(60):
		model.step(1.0 / 60.0, Vector2(0.0, 1.0), false, {"lift": 3.8, "boost_recovery": 18.0})
	if model.position.y <= 55.0:
		_fail("updraft/climb did not increase altitude")
		return
	if model.boost < 60.0 or model.boost > 100.0:
		_fail("boost recovery clamp")
		return

	model.boost = 6.0
	for i in range(60):
		model.step(1.0 / 60.0, Vector2.ZERO, true, {})
	if model.boost < 0.0:
		_fail("boost below zero")
		return

	model.reset(stage)
	model.position.z = 1.2
	for i in range(100):
		model.step(1.0 / 60.0, Vector2.ZERO, false, {})
	if model.failed_reason != "コースアウト":
		_fail("course grace failure")
		return

	model.reset(stage)
	if not model.apply_collision(20.0):
		_fail("first collision")
		return
	if model.apply_collision(20.0):
		_fail("invulnerability")
		return
	if absf(model.durability - 80.0) > 0.001:
		_fail("collision damage")
		return

	print("GAME-G007 FlightModel smoke PASS")
	quit(0)

func _fail(label: String) -> void:
	push_error("GAME-G007 FlightModel smoke FAIL: " + label)
	quit(1)
