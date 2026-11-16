shader_type canvas_item;
// v86 giant koi: plain colour handling only, no UV warping (the old warping tore the fins).
// depth tints and fades the koi into the pond; fins are lighter and a touch yellow.
uniform float depth = 0.0;                 // 0 = at the surface, 1 = deep
uniform float fade = 1.0;                  // set from script
uniform float is_fin = 0.0;                // 1 for the pectoral fins
uniform float tail_from = 0.86;            // UV y where the tail fin begins (body only)
uniform vec3 deep_col : source_color = vec3(0.08, 0.26, 0.30);

void fragment() {
	// depth blur: average neighbour texels; only colour is blurred, the shape never moves
	vec2 px = TEXTURE_PIXEL_SIZE * (1.0 + 7.0 * depth);
	vec4 c = texture(TEXTURE, UV) * 0.28;
	c += (texture(TEXTURE, UV + vec2(px.x, 0.0)) + texture(TEXTURE, UV - vec2(px.x, 0.0)) + texture(TEXTURE, UV + vec2(0.0, px.y)) + texture(TEXTURE, UV - vec2(0.0, px.y))) * 0.12;
	c += (texture(TEXTURE, UV + px) + texture(TEXTURE, UV - px) + texture(TEXTURE, UV + vec2(px.x, -px.y)) + texture(TEXTURE, UV + vec2(-px.x, px.y))) * 0.06;
	float tail = (1.0 - is_fin) * smoothstep(tail_from, tail_from + 0.05, UV.y);
	float finm = max(is_fin, tail);
	// fins: more see-through, light yellow cast
	c.a *= 1.0 - 0.42 * finm;
	c.rgb = mix(c.rgb, vec3(1.0, 0.82, 0.34) * (0.55 + 0.6 * dot(c.rgb, vec3(0.33))), 0.3 * finm);
	// water between us and the koi
	c.rgb = mix(c.rgb, deep_col, depth * 0.8);
	c.a *= (1.0 - depth * 0.6) * fade;
	COLOR = c;
}
