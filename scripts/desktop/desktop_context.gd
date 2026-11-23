class_name DesktopContext
extends RefCounted
## What the desktop offers to the applications running on it.
##
## Applications never reference the desktop directly. An app that needs
## these services implements
##   setup_app(context: DesktopContext, definition: AppDefinition)
## and the desktop calls it right after the app is added to its window.

signal open_app_requested(app_id: String)
signal close_app_requested(app_id: String)

var filesystem: VirtualFileSystem
var app_definitions: Array[AppDefinition] = []


func request_open_app(app_id: String) -> void:
	open_app_requested.emit(app_id)


func request_close_app(app_id: String) -> void:
	close_app_requested.emit(app_id)


func find_definition(app_id: String) -> AppDefinition:
	for definition: AppDefinition in app_definitions:
		if definition.id == app_id:
			return definition
	return null
