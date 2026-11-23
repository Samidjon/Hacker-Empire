shader_type canvas_item;
// Slowly scrolling neon grid with a soft vignette. Used by NeonBackground.

uniform vec4 base_color : source_color = vec4(0.031, 0.043, 0.078, 1.0);
uniform vec4 grid_color : source_color = vec4(0.0, 0.898, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.659, 0.333, 0.969, 1.0);
uniform float grid_size = 64.0;
uniform float scroll_speed = 10.0;
uniform float grid_intensity : hint_range(0.0, 1.0) = 0.14;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.12;
// Set from script so grid cells stay square at any size.
uniform vec2 rect_size = vec2(1920.0, 1080.0);

void fragment() {
	vec2 pixel = UV * rect_size;
	pixel.y += TIME * scroll_speed;

	vec2 cell = abs(fract(pixel / grid_size) - 0.5);
	float line = smoothstep(0.47, 0.5, max(cell.x, cell.y));

	float pulse = 0.6 + 0.4 * sin(TIME * 0.7 + UV.y * 5.0);
	float vignette = smoothstep(0.95, 0.25, distance(UV, vec2(0.5)));

	vec3 color = base_color.rgb;
	color += grid_color.rgb * line * grid_intensity * pulse;
	color += glow_color.rgb * glow_intensity * (1.0 - UV.y) * vignette;
	color *= mix(0.55, 1.0, vignette);

	COLOR = vec4(color, 1.0);
}
