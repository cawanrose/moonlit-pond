shader_type canvas_item;
// Painterly top-down pond water (reference: deep blue-teal, mottled light patches,
// thin concentric ripple lines, tiny glints). Animated so the surface gently shimmers.

uniform vec3 deep : source_color = vec3(0.04, 0.17, 0.27);
uniform vec3 mid : source_color = vec3(0.07, 0.34, 0.40);
uniform vec3 light : source_color = vec3(0.30, 0.60, 0.58);
uniform vec2 screen_size = vec2(360.0, 640.0);
uniform float world_y = 0.0;       // camera scroll so the water moves with the pond

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.03 + vec2(13.1, 7.7); a *= 0.5; }
	return v;
}

void fragment() {
	vec2 px = UV * screen_size;
	vec2 w = vec2(px.x, px.y - world_y);          // world-space position (pixels)
	float t = TIME;
	vec2 q = w / 170.0;
	// domain warp for slow, organic movement
	vec2 warp = vec2(fbm(q + vec2(0.0, t * 0.05)), fbm(q + vec2(5.2, -t * 0.04)));
	float n = fbm(q * 1.3 + warp * 1.6 + vec2(t * 0.02, 0.0));
	// painterly posterize: soft bands of colour like brush patches
	float band = floor(n * 6.0) / 6.0;
	float m = mix(n, band, 0.55);
	vec3 col = mix(deep, mid, smoothstep(0.30, 0.62, m));
	col = mix(col, light, smoothstep(0.66, 0.86, m) * 0.55);
	// small dark flecks / leaf shadows
	float fleck = fbm(w / 38.0 + warp * 2.0);
	col *= 0.88 + 0.12 * smoothstep(0.25, 0.6, fleck);
	// thin concentric ripple rings around a few fixed centres, slowly expanding
	float rings = 0.0;
	for (int k = 0; k < 3; k++) {
		vec2 c = vec2(80.0 + 110.0 * float(k), floor((w.y + 300.0 * float(k)) / 520.0) * 520.0 - 300.0 * float(k) + 200.0);
		float d = length((w - c) * vec2(1.0, 1.0));
		float ph = fract(d / 34.0 - t * 0.18 + float(k) * 0.37);
		float line = smoothstep(0.035, 0.0, abs(ph - 0.5) - 0.0);
		float fade = smoothstep(240.0, 60.0, d) * smoothstep(10.0, 40.0, d);
		float broken = step(0.42, noise(vec2(atan(w.y - c.y, w.x - c.x) * 5.0, d / 34.0)));
		rings += line * fade * broken;
	}
	col = mix(col, light + vec3(0.25), clamp(rings, 0.0, 1.0) * 0.35);
	// glints
	vec2 g = floor(w / 9.0);
	float h = hash(g);
	float tw = 0.5 + 0.5 * sin(t * 2.0 + h * 40.0);
	float glint = step(0.992, h) * tw * smoothstep(0.6, 0.0, length(fract(w / 9.0) - 0.5));
	col += vec3(0.6, 0.8, 0.8) * glint * 0.6;
	COLOR = vec4(col, 1.0);
}
