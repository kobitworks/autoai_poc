extends SceneTree

const MainScene = preload("res://Main.tscn")

var failures := 0

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run_move(main, target: String) -> void:
	main._start_move(target)
	check(main.moving, "move starts toward " + target)
	var guard := 0
	while main.moving and guard < 200:
		main._process(0.02)
		guard += 1
	check(not main.moving, "move completes at " + target)
	if main.screen == "playing":
		for i in range(60):
			main._process(0.02)

func _run_stage(main, stage_id: int, route: Array[String]) -> void:
	main._start_game(stage_id)
	check(main.screen == "playing", "stage %d starts through normal game state" % stage_id)
	check(main.current_node == "N1", "stage %d starts at N1" % stage_id)
	for target in route:
		if main.screen != "playing":
			break
		_run_move(main, target)
	check(main.screen == "result", "stage %d reaches result through normal moves" % stage_id)
	check(main.result_clear, "stage %d clears without QA clear shortcut" % stage_id)
	check(main.result_reason == "CLEAR", "stage %d clear reason is normal CLEAR" % stage_id)
	check(main.alert_model.peak < 100.0, "stage %d route avoids SPOTTED" % stage_id)

func _init() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	main.qa_mode = false

	_run_stage(main, 1, ["N2", "N4", "N6", "N8", "N9"])
	check(main.save_manager.is_unlocked(2), "stage 1 clear unlocks stage 2")
	main._pointer_down(main._next_rect().get_center())
	check(main.screen == "playing" and main.selected_stage_id == 2, "NEXT STAGE enters stage 2")

	_run_stage(main, 2, ["N4", "N6", "N9", "N12", "N13"])
	check(main.save_manager.is_unlocked(3), "stage 2 clear unlocks stage 3")
	main._pointer_down(main._next_rect().get_center())
	check(main.screen == "playing" and main.selected_stage_id == 3, "NEXT STAGE enters stage 3")

	_run_stage(main, 3, ["N3", "N6", "N9", "N12", "N14", "N16"])
	check(main.selected_stage_id == 3, "stage 3 remains selected after clear")
	check(main.save_manager.stage_record(1).get("best_time_ms", -1) >= 0, "stage 1 best record saved")
	check(main.save_manager.stage_record(2).get("best_time_ms", -1) >= 0, "stage 2 best record saved")
	check(main.save_manager.stage_record(3).get("best_time_ms", -1) >= 0, "stage 3 best record saved")

	print("GAME-G008 normal-rule three-stage playthrough complete: ", failures, " failure(s)")
	main.queue_free()
	quit(1 if failures > 0 else 0)
