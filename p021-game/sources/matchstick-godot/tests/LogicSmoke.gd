extends SceneTree

const Logic = preload("res://MatchstickLogic.gd")

func _init() -> void:
	var logic = Logic.new()
	logic.set_seed(62015)
	for level in ["easy", "normal", "hard"]:
		for _i in range(24):
			var puzzle: Dictionary = logic.generate_puzzle(level)
			var before: Array = puzzle["digit_masks"]
			var broken := logic.equation_from(puzzle["chars"], before)
			if broken == "" or logic.is_equation_valid(broken):
				push_error("Generated puzzle must start invalid: " + broken)
				quit(1)
				return
			var solution: Dictionary = puzzle["solution"]
			var solved := logic.apply_move_copy(before, int(solution["from_pos"]), int(solution["to_pos"]), int(solution["seg"]))
			if not logic.one_match_only(before, solved):
				push_error("Solution must move exactly one match.")
				quit(1)
				return
			var solved_text := logic.equation_from(puzzle["chars"], solved)
			if not logic.is_equation_valid(solved_text):
				push_error("Solution did not create a valid equation: " + solved_text)
				quit(1)
				return
	print("GAME-062 MatchstickLogic smoke tests passed.")
	quit(0)
