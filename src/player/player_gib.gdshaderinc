// Shared by the painted and the silhouette shader of a loose body part, so both melt,
// swell, and dissolve along the same shapes. Plain texture samples and hash noise only.

// Part size about stretch_pivot, in the sprite's own axes.
uniform vec2 stretch = vec2(1.0);
// Center of the part in sprite pixels, the point it swells around.
uniform vec2 stretch_pivot = vec2(0.0);
// Share of the part eaten away, from 0 to 1.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_edge_width : hint_range(0.0, 0.5) = 0.12;
// 0 eats in noise patches, 1 from the world top of the part down.
uniform float dissolve_top_down : hint_range(0.0, 1.0) = 0.0;
// How far the part runs down in drips, as a share of its texture.
uniform float melt : hint_range(0.0, 1.0) = 0.0;
// World up in the texture's UV space; the owner updates it as the part turns.
uniform vec2 up_uv = vec2(0.0, -1.0);
// Texture pixels per noise cell.
uniform float noise_cell = 26.0;
// Per-part offset so parts do not share one pattern.
uniform float seed = 0.0;
// Slow drift of the patterns, advanced by the owner.
uniform float phase = 0.0;

float gib_hash(vec2 point) {
	point = fract(point * vec2(127.1, 311.7));
	point += dot(point, point + 34.53);
	return fract(point.x * point.y);
}

float gib_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float top = mix(gib_hash(cell), gib_hash(cell + vec2(1.0, 0.0)), blend.x);
	float bottom = mix(gib_hash(cell + vec2(0.0, 1.0)), gib_hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(top, bottom, blend.y);
}

vec2 gib_vertex(vec2 vertex) {
	return stretch_pivot + (vertex - stretch_pivot) * stretch;
}

// Texture coordinate of a pixel once the part has run down in uneven drips.
vec2 gib_uv(vec2 uv, vec2 pixel_size) {
	if (melt <= 0.0) {
		return uv;
	}
	vec2 across = vec2(-up_uv.y, up_uv.x);
	float lane = dot(uv / pixel_size, across) / noise_cell * 2.3;
	float drip = 0.25 + 0.75 * gib_noise(vec2(lane + seed, 3.7));
	return uv + up_uv * melt * drip;
}

// Position of a pixel in the dissolve order: low values go first.
float gib_dissolve_field(vec2 uv, vec2 pixel_size) {
	float patches = gib_noise(uv / pixel_size / noise_cell + vec2(seed, phase));
	float height = clamp(0.5 - dot(uv - vec2(0.5), up_uv), 0.0, 1.0);
	return mix(patches, mix(height, patches, 0.25), dissolve_top_down);
}

// 1 where the part still exists, 0 where it is eaten away.
float gib_dissolve_mask(float field) {
	float cut = dissolve * (1.0 + dissolve_edge_width) - dissolve_edge_width;
	return smoothstep(cut, cut + 0.03, field);
}

// 1 on the rim that is about to go, 0 inside the part.
float gib_dissolve_rim(float field) {
	float cut = dissolve * (1.0 + dissolve_edge_width);
	return (1.0 - smoothstep(cut - 0.03, cut, field)) * step(0.001, dissolve);
}
