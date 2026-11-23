extends Node
## Launches the screenshot tour driver on the root so it survives scene changes.

const DRIVER_SCRIPT: GDScript = preload("res://tests/screenshot_tour_driver.gd")


func _ready() -> void:
	var driver: Node = DRIVER_SCRIPT.new()
	driver.name = "ScreenshotTourDriver"
	get_tree().root.add_child.call_deferred(driver)
