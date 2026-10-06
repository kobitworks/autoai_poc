class_name ShadowCoverGraph
extends RefCounted

var _nodes: Dictionary = {}
var _edge_times: Dictionary = {}

func configure(node_items: Array, edge_items: Array) -> void:
	_nodes.clear()
	_edge_times.clear()
	for item in node_items:
		var data: Dictionary = (item as Dictionary).duplicate(true)
		data["neighbors"] = []
		_nodes[str(data.get("id", ""))] = data
	for edge_item in edge_items:
		var edge: Dictionary = edge_item as Dictionary
		var a := str(edge.get("from", ""))
		var b := str(edge.get("to", ""))
		var travel := maxf(0.1, float(edge.get("time", 0.6)))
		if not _nodes.has(a) or not _nodes.has(b):
			continue
		(_nodes[a]["neighbors"] as Array).append(b)
		(_nodes[b]["neighbors"] as Array).append(a)
		_edge_times[_key(a, b)] = travel
		_edge_times[_key(b, a)] = travel

func _key(a: String, b: String) -> String:
	return a + "|" + b

func has_node(id: String) -> bool:
	return _nodes.has(id)

func node(id: String) -> Dictionary:
	if not _nodes.has(id):
		return {}
	return (_nodes[id] as Dictionary).duplicate(true)

func neighbors(id: String) -> Array:
	if not _nodes.has(id):
		return []
	return (_nodes[id].get("neighbors", []) as Array).duplicate()

func can_move(from_id: String, to_id: String) -> bool:
	return _edge_times.has(_key(from_id, to_id))

func edge_time(from_id: String, to_id: String) -> float:
	return float(_edge_times.get(_key(from_id, to_id), 0.6))
