extends RefCounted

# Pure logic for GAME-064 / GAME-G029 Jigsaw.
func shuffled(grid_size: int, seed_value: int) -> Array:
	var count := grid_size * grid_size
	var result: Array = []
	for i in range(count):
		result.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	if is_solved(result) and count > 1:
		var tmp = result[0]
		result[0] = result[1]
		result[1] = tmp
	return result

func is_solved(pieces: Array) -> bool:
	for i in range(pieces.size()):
		if int(pieces[i]) != i:
			return false
	return true

func score(grid_size: int, elapsed_ms: int, moves: int, hints: int) -> int:
	var base := 100000 + grid_size * 12000
	var time_penalty := int(maxi(0, elapsed_ms) / 20)
	var move_penalty := maxi(0, moves) * 130
	var hint_penalty := maxi(0, hints) * 500
	return maxi(1, base - time_penalty - move_penalty - hint_penalty)
