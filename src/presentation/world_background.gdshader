shader_type canvas_item;

uniform float level_zero_y = 0.0;
uniform float left_edge = -512.0;
uniform float right_edge = 512.0;
uniform float grass_band_top = -64.0;
uniform float grass_band_bottom = 0.0;
uniform float cave_saturation = 0.45;
uniform float cave_brightness = 0.62;
uniform float cave_contrast = 0.78;
uniform vec4 cave_tint : source_color = vec4(0.42, 0.55, 0.62, 1.0);
uniform float cave_tint_strength = 0.28;
uniform float depth_darkening = 0.28;
uniform float depth_darkening_distance = 3200.0;
uniform float side_vignette_strength = 0.22;
uniform float side_vignette_inner = 0.42;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec4 source = COLOR;
	if (local_position.y < level_zero_y || (local_position.y >= grass_band_top && local_position.y <= grass_band_bottom)) {
		COLOR = source;
	} else {
		float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		vec3 graded = mix(vec3(luma), source.rgb, cave_saturation);
		graded = ((graded - vec3(0.5)) * cave_contrast + vec3(0.5)) * cave_brightness;
		graded = mix(graded, graded * cave_tint.rgb, cave_tint_strength);

		float depth_factor = clamp((local_position.y - level_zero_y) / max(depth_darkening_distance, 1.0), 0.0, 1.0);
		graded *= 1.0 - depth_darkening * depth_factor;

		float width = max(right_edge - left_edge, 1.0);
		float horizontal = clamp((local_position.x - left_edge) / width, 0.0, 1.0);
		float edge_distance = abs(horizontal * 2.0 - 1.0);
		float vignette = smoothstep(side_vignette_inner, 1.0, edge_distance) * side_vignette_strength;
		graded *= 1.0 - vignette;

		COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), source.a);
	}
}
