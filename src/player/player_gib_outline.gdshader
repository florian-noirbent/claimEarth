shader_type canvas_item;

// The dark silhouette behind one body part during a death sequence. It grows the part's
// shape like player_outline.gdshader and melts, swells, and dissolves with the part.

#include "res://src/player/player_gib.gdshaderinc"

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Growth in texture pixels; the part textures keep a transparent margin at least this wide.
uniform float width = 20.0;

const int TAPS = 12;

void vertex() {
	VERTEX = gib_vertex(VERTEX);
}

void fragment() {
	vec2 uv = gib_uv(UV, TEXTURE_PIXEL_SIZE);
	float alpha = texture(TEXTURE, uv).a;
	for (int tap = 0; tap < TAPS; tap++) {
		float angle = TAU * float(tap) / float(TAPS);
		vec2 offset = vec2(cos(angle), sin(angle)) * width * TEXTURE_PIXEL_SIZE;
		alpha = max(alpha, texture(TEXTURE, uv + offset).a);
	}
	float mask = gib_dissolve_mask(gib_dissolve_field(UV, TEXTURE_PIXEL_SIZE));
	COLOR = vec4(outline_color.rgb, outline_color.a * smoothstep(0.15, 0.6, alpha) * mask);
}
