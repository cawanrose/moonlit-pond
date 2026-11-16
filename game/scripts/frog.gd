class_name Frog
extends Node2D


signal landed
signal bounced(n: int)

const TEX_IDLE:= preload("res://assets/td_frog_idle.png")
const TEX_JUMP:= TEX_IDLE
const TEX_LAND:= TEX_IDLE


const OFF_IDLE:= Vector2(0, 362 - 374)
const OFF_JUMP:= OFF_IDLE
const OFF_LAND:= OFF_IDLE

const TEX_EXTRA:= preload("res://assets/frog_extra.png")
const EXTRA_CELL:= { "celebrate": 0, "lookup": 1, "sleepy": 2}
const OFF_EXTRA:= Vector2(0, 362 - 600 + 26)
var _extra:= {}
var pose:= "idle"
const BODY_PX:= 500.0
const BODY_W:= 78.0

const JUMP_TIME:= 0.45
const ARC:= 70.0

var pad: LilyPad = null
var uv:= Vector2.ZERO
var jumping:= false
var air_height:= 0.0
var _squash:= 0.0
var charge:= 0.0
var evaporate:= 0.0
var size_k:= 1.0
var spin:= 0.0
var spin_turns:= 0.0
var groove:= 0.0
var _groove_s:= 0.0
var jelly:= 0.0
var jelly_v:= 0.0
const DEW_R:= 20.0
var _breath:= 0.0

var sprite: Sprite2D
var shadow: Node2D


static var SPIN:= 0.0


static func draw_dew(ci: CanvasItem, c: Vector2, r: float, sq: float, alpha: float, t: float, f: Dictionary = {}) -> void:
	var w:= r * (1.0 + 0.16 * sq)
	var h:= r * (1.0 - 0.16 * sq)
	var ln: float = f.get("lobe_n", 0.0)
	var la: float = f.get("lobe_amp", 0.0)
	var lp: float = f.get("lobe_ph", 0.0)
	var ears: float = f.get("ears", 0.0)
	var face: float = f.get("face", 0.0)
	var limbs: float = f.get("limbs", 0.0)
	var water:= Color(0.78, 0.96, 0.92, 0.2 * alpha)
	var rim:= Color(0.95, 1.0, 1.0, 0.5 * alpha)

	ci.draw_set_transform(c, SPIN, Vector2(w, h) / r)

	if limbs > 0.01:
		for sx: float in [-1.0, 1.0]:
			var arm:= Vector2(sx * r * (0.78 + 0.12 * limbs), r * 0.3 + sin(t * 4.0 + sx) * r * 0.05)
			ci.draw_circle(arm, r * 0.26 * limbs, water)
			ci.draw_arc(arm, r * 0.26 * limbs, 0, TAU, 20, rim, 1.0, true)
			var foot:= Vector2(sx * r * 0.42, r * (0.86 + 0.06 * limbs))
			ci.draw_circle(foot, r * 0.27 * limbs, water)
			ci.draw_arc(foot, r * 0.27 * limbs, 0, TAU, 20, rim, 1.0, true)
	if ears > 0.01:
		for sx: float in [-1.0, 1.0]:
			var ec:= Vector2(sx * r * 0.66, -r * (0.6 + 0.16 * ears))
			var er:= r * 0.36 * ears
			ci.draw_circle(ec, er, water)
			ci.draw_circle(ec, er * 0.55, Color(1.0, 0.78, 0.8, 0.35 * alpha * ears))
			ci.draw_arc(ec, er, 0, TAU, 24, rim, 1.2, true)

	var pts:= PackedVector2Array()
	var n:= 48
	for i in n:
		var a:= TAU * i / n
		var rr:= r * (1.0 + la * cos(ln * a + lp) + 0.03 * sin(a * 3.0 + t * 2.0) * la * 4.0)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	if la > 0.02:
		# lobed forms keep a soft glassy outline over the lens
		ci.draw_colored_polygon(pts, Color(0.8, 0.97, 0.93, 0.06 * alpha))
		var loop:= pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, Color(0.95, 1.0, 0.98, 0.26 * alpha), 1.0, true)

	if face > 0.01:
		# jelly-bear face: two glossy dark eyes, a tiny smile and warm blush on the cheeks
		var fa:= alpha * face
		var blink:= 1.0 if fmod(t, 3.7) > 0.12 else 0.15
		for sx: float in [-1.0, 1.0]:
			ci.draw_set_transform(c + (Vector2(sx * r * 0.6, r * 0.16) * Vector2(w, h) / r).rotated(SPIN), SPIN, Vector2(1.25, 0.85) * (w / r))
			ci.draw_circle(Vector2.ZERO, r * 0.13, Color(1.0, 0.36, 0.2, 0.3 * fa))
			ci.draw_circle(Vector2.ZERO, r * 0.09, Color(1.0, 0.36, 0.2, 0.42 * fa))
			ci.draw_set_transform(c + (Vector2(sx * r * 0.36, -r * 0.02) * Vector2(w, h) / r).rotated(SPIN), SPIN, Vector2(1.0, blink) * (w / r))
			ci.draw_circle(Vector2.ZERO, r * 0.115, Color(0.2, 0.08, 0.05, 0.95 * fa))
			ci.draw_circle(Vector2.ZERO, r * 0.075, Color(0.36, 0.16, 0.1, 0.9 * fa))
			ci.draw_circle(Vector2(-r * 0.035, -r * 0.04), r * 0.035, Color(1, 1, 1, 0.95 * fa))
			ci.draw_circle(Vector2(r * 0.03, r * 0.035), r * 0.016, Color(1, 1, 1, 0.6 * fa))
		ci.draw_set_transform(c, SPIN, Vector2(w, h) / r)
		ci.draw_arc(Vector2(0, r * 0.06), r * 0.11, 0.3, PI - 0.3, 12, Color(0.86, 0.3, 0.16, 0.95 * fa), maxf(r * 0.05, 1.2), true)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


var stage:= 0
var form:= { "lobe_n": 3.0, "lobe_amp": 0.0, "lobe_ph": 0.0, "ears": 0.0, "face": 0.0, "limbs": 0.0}
var _form_goal:= { "lobe_amp": 0.0, "ears": 0.0, "face": 0.0, "limbs": 0.0}
var _try_t:= 0.0


func set_stage(st: int) -> void:
	stage = st
	match st:
		0, 4:
			_form_goal = { "lobe_amp": 0.0, "ears": 0.0, "face": 0.0, "limbs": 0.0}
		1:
			_form_goal = { "lobe_amp": 0.0, "ears": 0.0, "face": 0.0, "limbs": 0.0}
		2:
			_form_goal = { "lobe_amp": 0.0, "ears": 0.35, "face": 0.0, "limbs": 0.0}
		3:
			_form_goal = { "lobe_amp": 0.0, "ears": 1.0, "face": 1.0, "limbs": 1.0}
	if st == 3 or st == 4:
		jelly_v += 18.0


func _practice_try() -> void:
	if stage == 1 or stage == 2:
		form.lobe_n = float([3, 4, 5, 6, 2][randi() % 5])
		form.lobe_ph = randf() * TAU
		form.lobe_amp = 0.16 if stage == 1 else 0.26
		_try_t = 0.0
		if stage == 2 and randf() < 0.5:
			form.ears = 0.8


func _update_form(delta: float) -> void:
	_try_t += delta
	form.lobe_amp = move_toward(form.lobe_amp, _form_goal.lobe_amp, delta * (0.35 if _try_t > 0.25 else 0.0))
	form.ears = lerpf(form.ears, _form_goal.ears, clampf(delta * 3.0, 0.0, 1.0))
	form.face = lerpf(form.face, _form_goal.face, clampf(delta * 2.5, 0.0, 1.0))
	form.limbs = lerpf(form.limbs, _form_goal.limbs, clampf(delta * 2.5, 0.0, 1.0))


func beat_bounce() -> void:
	if not jumping:
		jelly_v += 5.0
	_practice_try()


func _draw() -> void:
	var depth:= Main.depth_at(global_position.y)
	var swell:= 0.88 + 0.42 * _groove_s + 0.05 * sin(_breath * 0.5)
	var r:= DEW_R * depth * swell * (1.0 - 0.75 * evaporate) * size_k
	var sq:= clampf(jelly + _squash * 0.4 + charge * 1.3, -1.6, 2.2)
	var shake:= Vector2(sin(_breath * 60.0), 0) * charge * 1.2
	var hop:= maxf(-jelly, 0.0) * 11.0
	var c:= Vector2(0, -air_height - r * 0.85 - hop) + shake
	if lens:
		# the real drop: a lens over whatever lies beneath, squashing and turning with the body
		var shape:= 0
		if float(form.get("limbs", 0.0)) > 0.5:
			shape = 2
		elif float(form.get("ears", 0.0)) > 0.15:
			shape = 1
		place_lens(lens, c, r, sq, 1.0 - evaporate, spin, shape, clampf(float(form.get("limbs", 0.0)), 0.0, 1.0))
	if face_spr:
		var fk:= clampf(float(form.get("face", 0.0)), 0.0, 1.0)
		face_spr.visible = fk > 0.01
		var e:= _face_now()
		face_spr.region_rect = Rect2(clampi(e, 0, 2) * 256, 0, 256, 256)
		face_spr.position = c + Vector2(0, r * 0.04)
		face_spr.rotation = spin
		# the sheet's eyes sit 90px apart; on the dew they should span about 0.74 of its radius
		var fs:= r * 0.74 / 90.0
		face_spr.scale = Vector2(fs * (1.0 + 0.16 * sq), fs * (1.0 - 0.16 * sq))
		face_spr.modulate.a = fk * (1.0 - evaporate)
	SPIN = spin
	var shown:= form
	if lens and lens.has_meta("gloss") and GLOSS_FORMS.size() > 1 and GLOSS_FORMS[0] != null:
		# ears and paws come from the glass picture now, so the drawn circles stay out of the way
		shown = form.duplicate()
		shown["ears"] = 0.0
		shown["limbs"] = 0.0
		shown["lobe_amp"] = 0.0
	if face_spr:
		if shown == form:
			shown = form.duplicate()
		shown["face"] = 0.0
	draw_dew(self, c, r, sq, 1.0 - evaporate, _breath, shown)
	SPIN = 0.0


const LENS_SHADER:= """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float alpha = 1.0;
uniform float spin = 0.0;
uniform float press = 0.0;
uniform float extras = 1.0;
uniform float tint_k = 0.0;
const float QUAD = 1.6;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * QUAD;
	// keep the light fixed in the world while the drop itself turns
	float cs = cos(spin);
	float sn = sin(spin);
	vec2 pw = vec2(p.x * cs - p.y * sn, p.x * sn + p.y * cs);
	vec2 L = normalize(vec2(-0.62, -0.78));
	float d = length(p);
	float t = dot(pw / max(d, 0.001), L);
	vec4 outc = vec4(0.0);
	if (d < 1.0) {
		// a drop sitting on a leaf is a fat little lens: the middle magnifies the veins, the edge bends hard
		float z = sqrt(max(1.0 - d * d, 0.0));
		float k = mix(0.60, 1.0, pow(d, 3.0)) - 0.22 * pow(d, 8.0);
		vec2 dp = p * (k - 1.0);
		mat2 jp = mat2(dFdx(p), dFdy(p));
		mat2 js = mat2(dFdx(SCREEN_UV), dFdy(SCREEN_UV));
		vec2 suv = SCREEN_UV + js * inverse(jp) * dp;
		vec3 col = texture(screen_tex, suv).rgb;
		// inside, the side facing the light is dark and the far side glows with the light the drop has gathered
		float edge = smoothstep(0.25, 1.0, d);
		float dark = edge * smoothstep(-0.15, 1.0, t);
		float glow = edge * smoothstep(0.0, 1.0, -t);
		col *= 1.0 - 0.62 * dark;
		col = col * (1.0 + 0.5 * glow) + vec3(1.0, 1.0, 0.86) * 0.26 * glow * glow;
		col *= 1.04 + 0.1 * z;
		// grown into a bear, the clear water turns to warm orange jelly, deeper toward the thick edge
		// the colour is richest in the thick middle of the drop and thins out to a pale glassy edge
		float core = 1.0 - smoothstep(0.0, 1.0, d);
		vec3 jelly = mix(vec3(1.0, 0.72, 0.42), vec3(1.0, 0.4, 0.06), core);
		col = mix(col, col * 0.3 + jelly * (0.7 + 0.1 * glow - 0.14 * dark), tint_k * (0.42 + 0.53 * core));
		// thin bright meniscus all the way round, strongest away from the light
		float rim = smoothstep(0.93, 0.995, d);
		col = mix(col, vec3(0.93, 1.0, 0.97), extras * rim * (0.18 + 0.4 * smoothstep(-0.2, 1.0, -t)));
		// window highlight: small, hot, slightly stretched, with a faint bloom
		vec2 h = pw - L * 0.46;
		vec2 hr = vec2(h.x * 0.78 - h.y * 0.62, h.x * 0.62 + h.y * 0.78) * vec2(1.0, 1.9);
		float hl = length(hr);
		col += extras * (vec3(1.0, 1.0, 0.97) * smoothstep(0.17, 0.07, hl) * 0.95) + vec3(0.92, 0.98, 1.0) * exp(-hl * hl / 0.1) * 0.2 * (0.4 + 0.6 * extras);
		// a pin-point glint on the far side
		float g2 = length(pw + L * 0.52);
		col += vec3(1.0) * smoothstep(0.05, 0.02, g2) * 0.8 * extras;
		outc = vec4(col, smoothstep(1.0, 0.965, d));
	}
	// on the leaf: a soft shadow thrown away from the light, with a bright caustic crescent inside it
	vec2 sp = pw + L * 0.26;
	float sd = length(sp);
	float sh = (0.46 + 0.14 * press) * smoothstep(1.3 + 0.12 * press, 0.9, sd) * smoothstep(0.86, 1.0, d);
	vec2 cp = pw + L * 0.1;
	float cd = length(cp);
	float ca = (0.35 + 0.65 * extras) * (1.0 + 0.5 * press) * smoothstep(0.11 + 0.05 * press, 0.0, abs(cd - 1.09 - 0.05 * press)) * smoothstep(0.45, 0.98, dot(cp / max(cd, 0.001), -L)) * smoothstep(0.97, 1.02, d);
	vec4 ground = vec4(mix(vec3(0.0, 0.05, 0.04), vec3(1.0, 1.0, 0.82), clamp(ca * 0.9, 0.0, 1.0)), max(sh, ca * 0.75));
	COLOR = vec4(mix(ground.rgb, outc.rgb, outc.a), max(ground.a * (1.0 - outc.a), outc.a) * alpha);
}
"""
var lens: Sprite2D
static var GLOSS_TEX: Texture2D = null
static var GLOSS_FORMS: Array = []
static var _gloss_tried:= false
# radius of the drop inside the 640px overlay picture
const GLOSS_R:= 225.0


# the drop's look lives in one place so the intro and the game share the same material
static func make_lens(parent: CanvasItem) -> Sprite2D:
	var img:= Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var l:= Sprite2D.new()
	l.texture = ImageTexture.create_from_image(img)
	var sh:= Shader.new()
	sh.code = LENS_SHADER
	var mat:= ShaderMaterial.new()
	mat.shader = sh
	l.material = mat
	l.show_behind_parent = true
	parent.add_child(l)
	# painted gloss over the lens: rim, highlight and caustic from the art overlay
	if GLOSS_TEX == null and not _gloss_tried:
		_gloss_tried = true
		var gi:= Image.load_from_file("res://assets/dew_overlay_gpt.png")
		if gi:
			GLOSS_TEX = ImageTexture.create_from_image(gi)
		for nm in ["dew_ears_gpt", "dew_bear_gpt"]:
			var fi:= Image.load_from_file("res://assets/%s.png" % nm)
			GLOSS_FORMS.append(ImageTexture.create_from_image(fi) if fi else null)
	if GLOSS_TEX != null:
		var g:= Sprite2D.new()
		g.texture = GLOSS_TEX
		# the drop is not quite centred in the picture
		g.offset = Vector2(-5.0, 2.5)
		parent.add_child(g)
		l.set_meta("gloss", g)
		mat.set_shader_parameter("extras", 0.0)
	return l


static func place_lens(l: Sprite2D, c: Vector2, r: float, sq: float, alpha: float, turn: float, shape:= 0, tint:= 0.0) -> void:
	var w:= r * (1.0 + 0.16 * sq)
	var h:= r * (1.0 - 0.16 * sq)
	l.position = c
	l.rotation = turn
	l.scale = Vector2(w, h) * 2.0 * 1.6 / 8.0
	var m:= l.material as ShaderMaterial
	m.set_shader_parameter("alpha", alpha)
	m.set_shader_parameter("spin", turn)
	m.set_shader_parameter("tint_k", tint)
	if l.has_meta("gloss"):
		# the light stays put while the drop turns, so the gloss never rotates
		var g: Sprite2D = l.get_meta("gloss")
		# the same glass, in the shape the dew has grown into: round, with ears, or a little bear
		var want: Texture2D = GLOSS_TEX
		var gr:= GLOSS_R
		var goff:= Vector2(-5.0, 2.5)
		if shape == 1 and GLOSS_FORMS.size() > 0 and GLOSS_FORMS[0] != null:
			want = GLOSS_FORMS[0]
			gr = 188.0
			goff = Vector2(2.0, -30.0)
		elif shape == 2 and GLOSS_FORMS.size() > 1 and GLOSS_FORMS[1] != null:
			want = GLOSS_FORMS[1]
			gr = 178.0
			goff = Vector2(0.0, -14.0)
		if g.texture != want:
			g.texture = want
			g.offset = goff
		g.position = c
		g.scale = Vector2(w, h) / gr
		g.modulate = Color(1.0, lerpf(1.0, 0.7, tint), lerpf(1.0, 0.42, tint), alpha)
	# pressed flat on landing: the contact shadow and the pool of light spread for a moment
	m.set_shader_parameter("press", clampf(sq, 0.0, 1.5))


# ---- the face is its own layer, under the gloss, and changes with how the dew feels ----
# sheet cells: 0 smile, 1 delighted, 2 worried
static var FACE_TEX: Texture2D = null
var face_spr: Sprite2D
var mood:= 0
var mood_t:= 0.0


func feel(m: int, seconds: float) -> void:
	mood = m
	mood_t = seconds


func _make_face() -> void:
	if FACE_TEX == null:
		var fi:= Image.load_from_file("res://assets/face_sheet_gpt.png")
		if fi:
			FACE_TEX = ImageTexture.create_from_image(fi)
	if FACE_TEX == null:
		return
	face_spr = Sprite2D.new()
	face_spr.texture = FACE_TEX
	face_spr.region_enabled = true
	face_spr.region_rect = Rect2(0, 0, 256, 256)
	face_spr.offset = Vector2(0, 10)
	add_child(face_spr)


func _face_now() -> int:
	if mood_t > 0.0:
		return mood
	if jumping:
		return 1
	return 0


func _make_lens() -> void:
	_make_face()
	lens = make_lens(self)


func _ready() -> void:
	_make_lens()
	sprite = Sprite2D.new()
	sprite.visible = false
	sprite.texture = TEX_IDLE
	sprite.offset = OFF_IDLE
	add_child(sprite)


func place_on(p: LilyPad, at_uv: Vector2) -> void:
	pad = p
	uv = at_uv
	global_position = p.uv_to_global(uv)


func set_pose(name: String) -> void:
	pose = name
	if name in EXTRA_CELL and false:
		if not _extra.has(name):
			var at:= AtlasTexture.new()
			at.atlas = TEX_EXTRA
			at.region = Rect2(EXTRA_CELL[name] * 724, 0, 724, 724)
			_extra[name] = at
		sprite.texture = _extra[name]
		sprite.offset = OFF_EXTRA
		return
	match name:
		"idle":
			sprite.texture = TEX_IDLE
			sprite.offset = OFF_IDLE
		"jump":
			sprite.texture = TEX_JUMP
			sprite.offset = OFF_JUMP
		"land":
			sprite.texture = TEX_LAND
			sprite.offset = OFF_LAND


func hop_to(target: LilyPad, target_uv: Vector2, water_point:= Vector2.INF, power:= 0.6) -> void:
	jumping = true
	var start_pad:= pad
	var start_uv:= uv
	var start_pt:= global_position
	pad = null
	var goal:= target.uv_to_global(target_uv) if target else water_point
	sprite.flip_h = goal.x < global_position.x - 16
	set_pose("idle")
	var tw:= create_tween()
	tw.tween_property(self, "_squash", 1.0, 0.05)
	await tw.finished
	if start_pad:
		start_pad.takeoff()
	set_pose("jump")
	_squash = -0.6
	jelly = -1.1
	jelly_v = 0.0
	var dur:= JUMP_TIME * lerpf(0.75, 1.2, power)
	var arc:= ARC * lerpf(0.55, 1.35, power)
	var sway:= randf_range(14.0, 30.0) * (1.0 if randf() < 0.5 else -1.0)

	var style: String = ["float", "quick", "bounce", "swoop"][randi() % 4]
	match style:
		"float":
			dur *= 1.22
			arc *= 1.3
		"quick":
			dur *= 0.8
			arc *= 0.72
		"bounce":
			dur *= 1.1
		"swoop":
			sway *= 1.8
			arc *= 1.1
	var t:= 0.0
	while t < dur:
		t += get_process_delta_time()
		var k:= clampf(t / dur, 0.0, 1.0)
		var e:= 0.5 - 0.5 * cos(PI * k)
		var hk:= 4.0 * k * (1.0 - k)
		match style:
			"float":
				hk = pow(sin(PI * k), 0.55)
			"quick":
				e = 1.0 - pow(1.0 - k, 2.2)
				hk = 4.0 * k * (1.0 - k)
			"bounce":
				if k < 0.78:
					var k1:= k / 0.78
					hk = 4.0 * k1 * (1.0 - k1)
					e = 0.92 * (0.5 - 0.5 * cos(PI * k1))
				else:
					var k2:= (k - 0.78) / 0.22
					hk = 0.28 * 4.0 * k2 * (1.0 - k2)
					e = lerpf(0.92, 1.0, k2)
					if k2 < 0.15:
						jelly = 0.6
			"swoop":
				var kk:= pow(k, 0.7)
				hk = 4.0 * kk * (1.0 - kk)
		var a:= start_pad.uv_to_global(start_uv) if start_pad else start_pt
		var b:= target.uv_to_global(target_uv) if target else water_point
		var side:= (b - a).normalized().orthogonal()
		global_position = a.lerp(b, e) + side * sway * sin(PI * e)
		air_height = (arc + absf(b.y - a.y) * 0.12) * hk
		_squash = lerpf(-0.6, 0.0, k)
		if spin_turns != 0.0:
			# somersault: ease in and out so the dew lands upright
			spin = spin_turns * TAU * (0.5 - 0.5 * cos(PI * k))
		await get_tree().process_frame
	air_height = 0.0
	spin = 0.0
	spin_turns = 0.0
	if target:
		place_on(target, target_uv)
	else:
		global_position = water_point
	set_pose("land")
	# squish -> pop back up -> a smaller second bounce -> settle
	_squash = 1.3
	jelly = 0.95
	jelly_v = 0.0
	jumping = false
	landed.emit()
	var tw2:= create_tween()
	tw2.tween_property(self, "_squash", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.11).timeout.connect(func ():
		if not jumping:
			jelly_v -= 30.0
			bounced.emit(1))
	get_tree().create_timer(0.34).timeout.connect(func ():
		if not jumping:
			jelly_v += 10.0
			get_tree().create_timer(0.08).timeout.connect(func ():
				if not jumping:
					jelly_v -= 14.0
					bounced.emit(2)))
	await get_tree().create_timer(0.2).timeout
	if not jumping and target:
		set_pose("idle")


func _process(delta: float) -> void:
	_breath += delta

	# stable spring: fixed small sub-steps, so a long frame (app resume, hitch) can't blow it up
	var left:= minf(delta, 0.25)
	while left > 0.0:
		var h:= minf(left, 1.0 / 120.0)
		jelly_v += (-170.0 * jelly - 6.5 * jelly_v) * h
		jelly += jelly_v * h
		left -= h
	jelly = clampf(jelly, -2.5, 2.5)
	jelly_v = clampf(jelly_v, -240.0, 240.0)
	if is_nan(jelly) or is_nan(jelly_v):
		jelly = 0.0
		jelly_v = 0.0
	mood_t = maxf(mood_t - delta, 0.0)
	_groove_s = lerpf(_groove_s, groove, clampf(delta * 1.5, 0.0, 1.0))
	_update_form(delta)
	if pad != null and not jumping:
		global_position = pad.uv_to_global(uv)
	var depth:= Main.depth_at(global_position.y)
	var s:= BODY_W / BODY_PX * depth
	var breathe:= 0.0 if jumping else sin(_breath * 2.4) * 0.012
	var sq:= _squash + charge * 1.3
	var shake:= Vector2(sin(_breath * 60.0), 0) * charge * 1.2
	sprite.scale = Vector2(s * (1.0 + 0.12 * sq), s * (1.0 - 0.14 * sq + breathe))
	sprite.position = Vector2(0, -air_height) + shake
	queue_redraw()
	if shadow:
		shadow.global_position = global_position
		shadow.set_meta("h", air_height)
		shadow.set_meta("depth", depth)
		shadow.queue_redraw()
