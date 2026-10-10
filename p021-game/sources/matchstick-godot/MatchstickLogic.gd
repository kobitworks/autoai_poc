class_name MatchstickLogic
extends RefCounted

const RULE_ID := "one_match_only"
const DIGIT_TO_MASK := {
	0: 63,
	1: 6,
	2: 91,
	3: 79,
	4: 102,
	5: 109,
	6: 125,
	7: 7,
	8: 127,
	9: 111,
}
const MASK_TO_DIGIT := {
	63: 0,
	6: 1,
	91: 2,
	79: 3,
	102: 4,
	109: 5,
	125: 6,
	7: 7,
	127: 8,
	111: 9,
}

var rng := RandomNumberGenerator.new()

func set_seed(value: int) -> void:
	rng.seed = value

func digit_mask(digit: int) -> int:
	return int(DIGIT_TO_MASK.get(digit, 0))

func digit_from_mask(value: int) -> int:
	return int(MASK_TO_DIGIT.get(value, -1))

func is_valid_digit_mask(value: int) -> bool:
	return MASK_TO_DIGIT.has(value)

func on_segments(value: int) -> Array:
	var result: Array = []
	for seg in range(7):
		if value & (1 << seg):
			result.append(seg)
	return result

func can_remove(value: int, seg: int) -> bool:
	if (value & (1 << seg)) == 0:
		return false
	return is_valid_digit_mask(value & ~(1 << seg))

func can_add(value: int, seg: int) -> bool:
	if value & (1 << seg):
		return false
	return is_valid_digit_mask(value | (1 << seg))

func eval_expr(a: int, op: String, b: int) -> int:
	match op:
		"+":
			return a + b
		"-":
			return a - b
		"×":
			return a * b
		_:
			return 2147483647

func is_equation_valid(text: String) -> bool:
	var eq := text.split("=")
	if eq.size() != 2:
		return false
	var lhs: String = eq[0]
	var rhs: String = eq[1]
	if not rhs.is_valid_int():
		return false
	for op in ["+", "-", "×"]:
		var pos := lhs.find(op)
		if pos <= 0:
			continue
		var left := lhs.substr(0, pos)
		var right := lhs.substr(pos + op.length())
		if not left.is_valid_int() or not right.is_valid_int():
			return false
		return eval_expr(int(left), op, int(right)) == int(rhs)
	return false

func equation_from(chars: Array, masks: Array) -> String:
	var out := ""
	for i in range(chars.size()):
		var ch := String(chars[i])
		if i < masks.size() and int(masks[i]) >= 0 and "0123456789".contains(ch):
			var digit := digit_from_mask(int(masks[i]))
			if digit < 0:
				return ""
			out += str(digit)
		else:
			out += ch
	return out

func apply_move_copy(masks: Array, from_pos: int, to_pos: int, seg: int) -> Array:
	var next := masks.duplicate()
	if from_pos < 0 or from_pos >= next.size() or to_pos < 0 or to_pos >= next.size():
		return next
	var from_mask := int(next[from_pos])
	var to_mask := int(next[to_pos])
	if not can_remove(from_mask, seg) or not can_add(to_mask, seg):
		return next
	next[from_pos] = from_mask & ~(1 << seg)
	next[to_pos] = to_mask | (1 << seg)
	return next

func one_match_only(before: Array, after: Array) -> bool:
	if before.size() != after.size():
		return false
	var removed_count := 0
	var added_count := 0
	var removed_seg := -1
	var added_seg := -2
	for i in range(before.size()):
		var a := int(before[i])
		var b := int(after[i])
		if a < 0 or b < 0:
			continue
		for seg in range(7):
			var bit := 1 << seg
			if (a & bit) and not (b & bit):
				removed_count += 1
				removed_seg = seg
			elif not (a & bit) and (b & bit):
				added_count += 1
				added_seg = seg
	return removed_count == 1 and added_count == 1 and removed_seg == added_seg

func _pick(values: Array):
	return values[rng.randi_range(0, values.size() - 1)]

func _chars_and_masks(text: String) -> Dictionary:
	var chars: Array = []
	var masks: Array = []
	var digit_positions: Array = []
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		chars.append(ch)
		if "0123456789".contains(ch):
			masks.append(digit_mask(int(ch)))
			digit_positions.append(i)
		else:
			masks.append(-1)
	return {"chars": chars, "masks": masks, "digit_positions": digit_positions}

func generate_puzzle(level: String) -> Dictionary:
	var ops: Array = ["+", "-"] if level != "hard" else ["+", "-", "×"]
	var max_value := 9 if level == "easy" else 99
	for _tries in range(2000):
		var op := String(_pick(ops))
		var a := rng.randi_range(0, max_value)
		var b := rng.randi_range(0, max_value)
		if op == "-" and a < b:
			var swap := a
			a = b
			b = swap
		var c := eval_expr(a, op, b)
		if c < 0 or c > 99:
			continue
		if level == "easy" and (a > 9 or b > 9 or c > 9):
			continue
		var valid := "%d%s%d=%d" % [a, op, b, c]
		var data := _chars_and_masks(valid)
		var chars: Array = data["chars"]
		var masks: Array = data["masks"]
		var positions: Array = data["digit_positions"]
		if positions.size() < 2:
			continue
		for _inner in range(240):
			var from_pos := int(_pick(positions))
			var to_pos := int(_pick(positions))
			if from_pos == to_pos:
				continue
			var from_mask := int(masks[from_pos])
			var to_mask := int(masks[to_pos])
			var on: Array = on_segments(from_mask)
			if on.is_empty():
				continue
			var seg := int(_pick(on))
			var new_from := from_mask & ~(1 << seg)
			if not is_valid_digit_mask(new_from):
				continue
			if to_mask & (1 << seg):
				continue
			var new_to := to_mask | (1 << seg)
			if not is_valid_digit_mask(new_to):
				continue
			var broken_chars := chars.duplicate()
			var broken_masks := masks.duplicate()
			broken_chars[from_pos] = str(digit_from_mask(new_from))
			broken_chars[to_pos] = str(digit_from_mask(new_to))
			broken_masks[from_pos] = new_from
			broken_masks[to_pos] = new_to
			var broken := equation_from(broken_chars, broken_masks)
			if broken == "" or is_equation_valid(broken):
				continue
			return {
				"level": level,
				"valid": valid,
				"chars": broken_chars,
				"digit_masks": broken_masks,
				"solution": {"from_pos": to_pos, "to_pos": from_pos, "seg": seg},
			}
	return _fallback(level)

func _fallback(level: String) -> Dictionary:
	var chars: Array = ["8", "+", "8", "=", "0"]
	var masks: Array = [127, -1, 127, -1, 63]
	return {
		"level": level,
		"valid": "0+8=8",
		"chars": chars,
		"digit_masks": masks,
		"solution": {"from_pos": 0, "to_pos": 4, "seg": 6},
	}
