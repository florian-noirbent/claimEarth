shader_type canvas_item;

// Paints one body part during a death sequence: hit flash, tint, scorching with glowing
// embers, a noise dissolve with a bright rim, melting drips, and swelling. With every
// uniform at rest it draws the part exactly like a plain sprite.

#include "res://src/player/player_gib.gdshaderinc"

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint : hint_range(0.0, 1.0) = 0.0;
uniform vec4 scorch_color : source_color = vec4(0.06, 0.045, 0.04, 1.0);
uniform float scorch : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ember_color : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform float ember : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_edge_color : source_color = vec4(1.0, 0.6, 0.15, 1.0);

varying vec4 part_modulate;

void vertex() {
	VERTEX = gib_vertex(VERTEX);
	part_modulate = COLOR;
}

void fragment() {
	vec2 uv = gib_uv(UV, TEXTURE_PIXEL_SIZE);
	vec4 painted = texture(TEXTURE, uv);
	vec3 color = painted.rgb * part_modulate.rgb;
	float brightness = dot(color, vec3(0.299, 0.587, 0.114));

	color = mix(color, tint_color.rgb * (0.35 + 0.9 * brightness), tint);
	// Scorching darkens in patches first, so the part chars unevenly.
	float soot = gib_noise(uv / TEXTURE_PIXEL_SIZE / noise_cell * 1.7 + vec2(seed * 3.1, 9.2));
	float burnt = smoothstep(soot * 0.6, soot * 0.6 + 0.4, scorch);
	color = mix(color, scorch_color.rgb * (0.7 + 0.6 * brightness), burnt);
	float specks = gib_noise(uv / TEXTURE_PIXEL_SIZE / noise_cell * 1.5 + vec2(seed, phase * 2.0));
	color += ember_color.rgb * ember * smoothstep(0.6, 0.75, specks);

	float field = gib_dissolve_field(UV, TEXTURE_PIXEL_SIZE);
	color = mix(color, dissolve_edge_color.rgb, gib_dissolve_rim(field));
	color = mix(color, flash_color.rgb, flash);
	COLOR = vec4(color, painted.a * part_modulate.a * gib_dissolve_mask(field));
}
