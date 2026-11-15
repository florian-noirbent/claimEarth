shader_type canvas_item;

// Draws a part texture as a flat silhouette grown outward by `width`. The player rig
// stacks one silhouette per part behind the painted parts to outline the whole body.

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Growth in texture pixels; the part textures keep a transparent margin at least this wide.
uniform float width = 20.0;

const int TAPS = 12;

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	for (int tap = 0; tap < TAPS; tap++) {
		float angle = TAU * float(tap) / float(TAPS);
		vec2 offset = vec2(cos(angle), sin(angle)) * width * TEXTURE_PIXEL_SIZE;
		alpha = max(alpha, texture(TEXTURE, UV + offset).a);
	}
	COLOR = vec4(outline_color.rgb, outline_color.a * smoothstep(0.15, 0.6, alpha));
}
