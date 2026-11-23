class_name HardwareCategory
extends RefCounted
## Hardware slot ids. The computer holds one installed item per category.

const CPU: String = "cpu"
const GPU: String = "gpu"
const RAM: String = "ram"
const SSD: String = "ssd"
const NETWORK: String = "network"
const COOLING: String = "cooling"
const MONITOR: String = "monitor"
const SERVER: String = "server"

const ALL: PackedStringArray = [CPU, GPU, RAM, SSD, NETWORK, COOLING, MONITOR, SERVER]

const DISPLAY_NAMES: Dictionary = {
	CPU: "CPU",
	GPU: "GPU",
	RAM: "RAM",
	SSD: "SSD",
	NETWORK: "Network Adapter",
	COOLING: "Cooling",
	MONITOR: "Monitors",
	SERVER: "Servers",
}


static func is_valid(category: String) -> bool:
	return ALL.has(category)


static func get_display_name(category: String) -> String:
	return DISPLAY_NAMES.get(category, category.capitalize())
