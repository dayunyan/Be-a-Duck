shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // 描边颜色
uniform float line_thickness : hint_range(0, 10) = 1.0; // 描边厚度
uniform bool is_enabled = false; // 开关

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	if (is_enabled) {
		vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;

		float outline = texture(TEXTURE, UV + vec2(-size.x, 0)).a;
		outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
		outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
		outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;

		outline = min(outline, 1.0);

		vec4 final_color = mix(color, line_color, outline - color.a);
		COLOR = final_color;
	} else {
		COLOR = color;
	}
}