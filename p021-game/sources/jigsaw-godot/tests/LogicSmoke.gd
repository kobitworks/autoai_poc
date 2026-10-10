extends SceneTree

const Logic = preload("res://JigsawLogic.gd")

func _init() -> void:
	var logic = Logic.new()
	for grid in range(3, 8):
		var puzzle = logic.shuffled(grid, 64000 + grid)
		assert(puzzle.size() == grid * grid)
		assert(not logic.is_solved(puzzle))
		var seen := {}
		for value in puzzle:
			seen[int(value)] = true
		assert(seen.size() == grid * grid)
	var solved: Array = []
	for i in range(9):
		solved.append(i)
	assert(logic.is_solved(solved))
	var fast_score := logic.score(3, 1500, 8, 0)
	var slow_score := logic.score(3, 12000, 22, 2)
	assert(fast_score > slow_score)
	assert(logic.score(7, 1500, 8, 0) > 0)
	print("GAME-064 Jigsaw logic smoke: PASS")
	quit(0)
