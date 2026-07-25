shader_type canvas_item;

uniform float line_thickness: hint_range(0.0, 0.5) = 0.02;
uniform float line_opacity: hint_range(0.0, 0.3) = 0.06;
uniform float scroll_speed: hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float line = step(line_thickness, fract(UV.y * SCREEN_PIXEL_SIZE.y * 2.0 + TIME * scroll_speed));
	color.rgb = mix(color.rgb, vec3(0.0), line_opacity * (1.0 - line));
	COLOR = color;
}
