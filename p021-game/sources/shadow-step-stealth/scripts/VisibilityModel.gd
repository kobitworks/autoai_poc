class_name ShadowVisibilityModel
extends RefCounted

static func _segment_hits_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return a.distance_to(center) <= radius
	var t := clampf((center - a).dot(ab) / denom, 0.0, 1.0)
	var nearest := a + ab * t
	return nearest.distance_to(center) <= radius

static func in_cone(origin: Vector2, angle_rad: float, half_fov_rad: float, max_range: float, point: Vector2) -> bool:
	var delta := point - origin
	if delta.length() > max_range or delta.length_squared() <= 0.0001:
		return false
	var angle_delta := absf(wrapf(delta.angle() - angle_rad, -PI, PI))
	return angle_delta <= half_fov_rad

static func is_visible(origin: Vector2, angle_rad: float, half_fov_rad: float, max_range: float, point: Vector2, occluders: Array) -> bool:
	if not in_cone(origin, angle_rad, half_fov_rad, max_range, point):
		return false
	for raw in occluders:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var occluder: Dictionary = raw as Dictionary
		var center: Vector2 = occluder.get("center", Vector2.ZERO)
		var radius := float(occluder.get("radius", 0.0))
		if point.distance_to(center) <= radius * 1.15:
			continue
		if _segment_hits_circle(origin, point, center, radius):
			return false
	return true
