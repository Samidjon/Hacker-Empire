class_name NetworkNodeData
extends RefCounted
## One fictional location on the Network Map (data/network/nodes.json).
## These are places in the game's story, not real hosts.

const DEFAULT_DATA_PATH: String = "res://data/network/nodes.json"

var id: String = ""
var display_name: String = ""
var type: String = ""
var description: String = ""
## Position on the map, 0..1 on both axes.
var map_position: Vector2 = Vector2(0.5, 0.5)
## Player level at which the node becomes known.
var required_level: int = 1
var links: PackedStringArray = []


func is_discovered(player_level: int) -> bool:
	return player_level >= required_level


## Loads every valid node. Links to unknown ids are removed.
static func load_all(path: String = DEFAULT_DATA_PATH) -> Array[NetworkNodeData]:
	var nodes: Array[NetworkNodeData] = []
	var known_ids: Dictionary = {}
	for entry: Dictionary in JsonDataLoader.load_entries(path, "nodes"):
		var node := NetworkNodeData.new()
		node.id = SaveDataReader.get_string(entry, "id")
		if node.id.is_empty() or known_ids.has(node.id):
			push_warning("NetworkNodeData: skipped a node with a missing or duplicate id.")
			continue
		node.display_name = SaveDataReader.get_string(entry, "name", node.id)
		node.type = SaveDataReader.get_string(entry, "type", "unknown")
		node.description = SaveDataReader.get_string(entry, "description")
		node.required_level = maxi(1, SaveDataReader.get_int(entry, "required_level", 1))
		var position_values: Array = SaveDataReader.get_array(entry, "position")
		if position_values.size() == 2:
			node.map_position = Vector2(
				clampf(float(position_values[0]), 0.0, 1.0), clampf(float(position_values[1]), 0.0, 1.0)
			)
		for link: Variant in SaveDataReader.get_array(entry, "links"):
			if link is String:
				node.links.append(link)
		known_ids[node.id] = true
		nodes.append(node)

	for node: NetworkNodeData in nodes:
		var valid_links: PackedStringArray = []
		for link: String in node.links:
			if known_ids.has(link) and link != node.id:
				valid_links.append(link)
			else:
				push_warning("NetworkNodeData: node '%s' links to unknown node '%s'." % [node.id, link])
		node.links = valid_links
	return nodes
