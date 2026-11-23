extends ColorRect
## Animated neon grid backdrop. Drop the NeonBackground scene into any screen.

const SIZE_UNIFORM: StringName = &"rect_size"


func _ready() -> void:
	resized.connect(_update_shader_size)
	_update_shader_size()


func _update_shader_size() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(SIZE_UNIFORM, size)
