class_name ShadowAlertModel
extends RefCounted

var value := 0.0
var peak := 0.0

func reset() -> void:
	value = 0.0
	peak = 0.0

func update(delta: float, visible: bool, moving: bool, intensity: float = 1.0) -> float:
	if visible:
		var rate := 48.0 if moving else 34.0
		value += rate * maxf(0.2, intensity) * delta
	else:
		value -= 32.0 * delta
	value = clampf(value, 0.0, 100.0)
	peak = maxf(peak, value)
	return value

func state() -> String:
	if value >= 100.0:
		return "SPOTTED"
	if value >= 70.0:
		return "DANGER"
	if value >= 35.0:
		return "SUSPICIOUS"
	return "HIDDEN"

func spotted() -> bool:
	return value >= 100.0
