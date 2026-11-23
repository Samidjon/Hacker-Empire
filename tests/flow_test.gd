extends Node
## Launches the flow test driver. The driver lives on the root so it survives
## the scene changes it triggers.
## Run: godot --headless --path . res://tests/FlowTest.tscn

const DRIVER_SCRIPT: GDScript = preload("res://tests/flow_test_driver.gd")


func _ready() -> void:
	var driver: Node = DRIVER_SCRIPT.new()
	driver.name = "FlowTestDriver"
	get_tree().root.add_child.call_deferred(driver)
