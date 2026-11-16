shader_type canvas_item;
// A painted koi seen through water: it bends as it swims, and the deeper it is the more the water
// blurs, refracts and tints it. Caustic light ripples over its back near the surface.
uniform float amp = 0.035;
uniform float speed = 2.2;
uniform float phase = 0.0;
uniform float depth = 0.0;                 // 0 = just under the surface, 1 = deep
uniform vec3 deep_col : source_color = vec3(0.08, 0.26, 0.30);

vec4 tap(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, uv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) c = vec4(0.0);
	return c;
}

void fragment() {
	vec2 uv = UV;
	float k = uv.y;                                         // 0 head .. 1 tail tip
	uv.x -= sin(TIME * speed + phase - k * 5.0) * amp * k * k;
	// refraction: the water surface bends the picture a little, more when deep
	float rf = 0.002 + 0.006 * depth;
	uv += vec2(sin(uv.y * 34.0 + TIME * 1.7), cos(uv.x * 28.0 + TIME * 1.3)) * rf;
	// depth blur: a small cross of taps that spreads with depth
	float b = 0.004 + 0.016 * depth;
	vec4 c = tap(TEXTURE, uv) * 0.36 + (tap(TEXTURE, uv + vec2(b, 0.0)) + tap(TEXTURE, uv - vec2(b, 0.0)) + tap(TEXTURE, uv + vec2(0.0, b * 0.5)) + tap(TEXTURE, uv - vec2(0.0, b * 0.5))) * 0.16;
	// caustics: bright wavering light net on the body near the surface
	vec2 w = uv * vec2(9.0, 18.0);
	float cs = sin(w.x * 2.1 + TIME * 1.2 + sin(w.y * 1.3 + TIME * 0.8)) * sin(w.y * 1.7 - TIME * 1.0 + sin(w.x * 1.9));
	float caus = smoothstep(0.55, 1.0, cs) * (1.0 - depth) * 0.28;
	vec3 rgb = c.rgb + vec3(0.9, 1.0, 0.9) * caus * c.a;
	// water between us and the fish: tint toward the deep colour, lose contrast
	rgb = mix(rgb, deep_col, depth * 0.78);
	c.a *= 1.0 - depth * 0.55;
	COLOR = vec4(rgb, c.a) * COLOR;
}
