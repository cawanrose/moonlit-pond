class_name Intro
extends CanvasLayer
## v0.93 opening — "달빛 연못으로 떨어지는 이슬" (about 10 s, one continuous shot)
## Art direction: pond_style_ref (top-down lily pads, deep green water, red koi).
##
##  0.0 - 2.0  dark; a moonbeam finds the tip of a lotus leaf hanging over the pond
##  2.0 - 3.2  a dew bead swells on the tip, the leaf bends under it
##  3.2 - 7.0  it lets go (the leaf springs back); the camera follows it down,
##             dark foreground leaves slide past, the deep water and the pads open up
##  7.0 - 8.5  splash in the channel: ripples, droplets, pads breathe outward,
##             the small red fish scatter, then a pad (Moon_Floor_02) rises under the dew
##  8.5 - 10   warm light on the dew, title + "moonshot2026", tap to start
##
## Art: res://assets/intro/*.png (GPT layers, loaded raw like the other *_gpt
## pictures). If one is missing that layer falls back to shapes drawn in code.
## Game resources: small red fish = Koi, water surface = water.gdshader, ripples = Ripple,
## dew = Frog lens + dew_overlay_gpt gloss (same as in play).
## Tap = skip to the title; tap again = start.

signal started

const DRIP_T:= 3.2
const LAND_T:= 7.0
const RISE:= Vector2(7.6, 8.4)
const GLOW_T:= 8.5
const TITLE_T:= 9.0
const FORM:= Vector2(2.0, 3.2)

# design space: 360 wide; the mid layer (pond surface) is the reference layer
const CAM0:= Vector2(180, 210)
const Z0:= 0.9
const TIP:= Vector2(182, 150)
const LAND:= Vector2(180, 860)
const CAM_END_Y:= 845.0

const PAR_FAR:= Vector2(0.35, 0.3)   # [camera follow, zoom follow]
const PAR_NEAR:= Vector2(1.7, 2.8)
const PAR_MOTE:= Vector2(1.25, 1.5)

const DIR:= "res://assets/intro/"
const R_FAR:= Rect2(-153, -190, 666, 1000)
const R_MID:= Rect2(-90, 470, 540, 810)
const R_NEAR:= Rect2(-50, -140, 460, 690)
# GPT cut-out of the two front leaves (gpt_near_leaves_cutout, sides extended by 150 px):
# placed so that at ~4.5 s it matches the approved reference frame exactly
const R_NEAR2:= Rect2(-14.5, 245.8, 399.6, 538.7)
const LEAF_SIZE:= 240.0          # drip leaf width; height follows the picture (1254 x 1757)
const LEAF_TIP_UV:= Vector2(0.497, 0.789)  # tip of intro_drip_leaf.png at (624, 1386)

const C_BG:= Color("06130f")
const C_DEEP:= Color("0d2a22")
const C_WATER:= Color("174a3a")
const C_PAD:= Color("6fbf3f")
const C_NEAR:= Color("061009")
const MOON:= Color(0.78, 0.95, 0.88)
const WARM:= Color(1.0, 0.84, 0.5)

var root: Control
var far_ci: Control
var mid_ci: Control
var fx_ci: Control
var beam_ci: Control
var dew_ci: Control
var glow_ci: Control
var near_ci: Control
var vig: ColorRect
var logo: Control
var prompt: Label
var fade: ColorRect

var t_far: Texture2D
var t_mid: Texture2D
var t_near: Texture2D
var t_near_lower: Texture2D
var t_leaf: Texture2D
var t_floor: Texture2D
var lily: Texture2D
var _dummy_pads:= []
# game resources: small red fish (Koi), water surface (water.gdshader), ripples (Ripple), dew lens (Frog)
const WATER_PAL:= [Color(0.05, 0.22, 0.15), Color(0.09, 0.33, 0.22), Color(0.28, 0.54, 0.36)]
const SHOWN:= {"lobe_n": 3.0, "lobe_amp": 0.0, "lobe_ph": 0.0, "ears": 0.0, "face": 0.0, "limbs": 0.0}
const CHANNEL:= [Vector2(240, 628), Vector2(150, 734), Vector2(184, 860), Vector2(177, 945), Vector2(110, 1050)]
var water_node: Node2D
var _water_mat: ShaderMaterial
var fish_node: Node2D
var ripple_node: Node2D
var lens: Sprite2D
var fish:= []
var _fish_next:= []
var _orbiting:= []    # 0 free, 1 gathering, 2 orbiting
const RING_R:= 40.0
var _rng:= RandomNumberGenerator.new()
var _winds:= []
var _motes:= []

var _t:= 0.0
var cam:= CAM0
var zoom:= Z0
static var quick:= false
var _leaving:= false
var _main: Node
var _events:= [[DRIP_T, "drip"], [LAND_T, "land"], [RISE.x, "rise"], [GLOW_T, "glow"]]
var _fired:= {}
# ending: hand over to the game screen
const LEAVE_MOVE:= 1.5     # camera glide
const LEAVE_FADE:= Vector2(0.45, 1.7)   # intro world crossfades out over this window
const LEAVE_END:= 2.0
var _lt:= 0.0
var _cam_from:= Vector2.ZERO
var _cam_to:= Vector2.ZERO
var _zoom_from:= 1.0
var _zoom_to:= 1.0
var _fade_ui: Array = []


func setup(main: Node) -> void:
	_main = main


func _serif(spacing: int) -> FontVariation:
	var f:= FontVariation.new()
	var path:= "res://fonts/NanumMyeongjo.woff2"
	if ResourceLoader.exists(path):
		f.base_font = load(path)
	else:
		var sf:= SystemFont.new()
		sf.font_names = PackedStringArray(["NanumMyeongjo", "Noto Serif CJK KR", "serif"])
		f.base_font = sf
	f.spacing_glyph = spacing
	return f


static func _raw(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var im:= Image.load_from_file(path)
	if im == null or im.is_empty():
		return null
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)


func _layer(draw_fn: Callable, additive:= false) -> Control:
	var c:= Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	c.draw.connect(draw_fn.bind(c))
	if additive:
		var m:= CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		c.material = m
	root.add_child(c)
	return c


func _ready() -> void:
	layer = 10
	t_far = _raw(DIR + "intro_far.png")
	t_mid = _raw(DIR + "intro_mid.png")
	t_near = _raw(DIR + "intro_near.png")
	# lower copy (the leaves that brush past during the fall): same art with its top and
	# bottom edges faded, so it never shows a straight cut across the screen
	t_near_lower = _raw(DIR + "intro_near_lower.png")
	if t_near_lower == null:
		t_near_lower = t_near
	t_leaf = _raw(DIR + "intro_drip_leaf.png")
	t_floor = _raw("res://assets/Moon_Floor_02.png")
	lily = load("res://assets/td_lily_pad.png")
	_build()

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_input)
	add_child(root)

	var bg:= ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	far_ci = _layer(_draw_far)
	_make_water()
	_make_fish()
	mid_ci = _layer(_draw_mid)
	mid_ci.material = _edge_feather(0.07)
	fx_ci = _layer(_draw_fx)
	ripple_node = Node2D.new()
	root.add_child(ripple_node)
	beam_ci = _layer(_draw_beam, true)
	dew_ci = _layer(_draw_dew)
	lens = Frog.make_lens(dew_ci)
	glow_ci = _layer(_draw_glow, true)
	near_ci = _layer(_draw_near)
	near_ci.material = _edge_feather(0.05)

	vig = ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh:= Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.85;
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.1;
	COLOR = vec4(0.01, 0.04, 0.025, smoothstep(0.22, 0.72, length(p)) * strength * COLOR.a);
}"""
	var vm:= ShaderMaterial.new()
	vm.shader = sh
	vig.material = vm
	root.add_child(vig)

	logo = TitleCard.new()
	logo.sub_text = "노래에 맞춰 잎을 건너는 이슬"
	logo.modulate.a = 0.0
	root.add_child(logo)

	prompt = Label.new()
	prompt.text = "화면을 눌러 시작"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_override("font", _serif(3))
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.98, 0.93))
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.modulate.a = 0.0
	root.add_child(prompt)

	var credit:= Label.new()
	credit.text = "moonshot2026"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_override("font", _serif(3))
	credit.add_theme_font_size_override("font_size", 11)
	credit.add_theme_color_override("font_color", Color(1.0, 1.0, 0.95, 0.6))
	credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credit.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -24
	credit.offset_bottom = -6
	root.add_child(credit)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 1.2)

	if quick:
		quick = false
		_skip_to(TITLE_T + 1.2)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_camera()


# v106: the layer pictures are finite rectangles; when the camera pulls back for the hand-off
# to the game (and the pad layer is turning) their straight edges showed as cut lines.
# Fade every picture out softly at its own borders so an edge never reads as a cut.
static func _edge_feather(m: float) -> ShaderMaterial:
	var sh:= Shader.new()
	sh.code = """shader_type canvas_item;
uniform float m = 0.07;
void fragment() {
	vec2 e = min(UV, 1.0 - UV);
	COLOR.a *= smoothstep(0.0, m, e.x) * smoothstep(0.0, m, e.y);
}"""
	var mat:= ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("m", m)
	return mat


func _build() -> void:
	var rng:= RandomNumberGenerator.new()
	rng.seed = 9301
	# dummy pads (only drawn when intro_mid.png is missing): fill the frame,
	# leave a winding channel through LAND
	var y:= R_MID.position.y
	while y < R_MID.end.y:
		var x:= R_MID.position.x
		while x < R_MID.end.x:
			var p:= Vector2(x + rng.randf_range(-14, 14), y + rng.randf_range(-14, 14))
			var cx:= LAND.x + sin((p.y - LAND.y) / 120.0) * 40.0
			if absf(p.x - cx) > 62.0:
				_dummy_pads.append(Vector4(p.x, p.y, rng.randf_range(58, 92), rng.randf() * TAU))
			x += rng.randf_range(52, 70)
		y += rng.randf_range(48, 62)
	# moon motes
	for i in 34:
		_motes.append(Vector4(rng.randf_range(-40, 400), rng.randf_range(-100, 1100), rng.randf_range(0.6, 1.8), rng.randf() * TAU))


# ---------------------------------------------------------------- time / camera

static func _sm(a: float, b: float, t: float) -> float:
	return smoothstep(a, b, t)


func _leaf_angle() -> float:
	# sways; dips while the bead grows, springs back when it lets go
	var sway:= sin(_t * 1.1) * 0.035 + sin(_t * 2.3 + 1.0) * 0.012
	var bend:= 0.09 * _sm(FORM.x, DRIP_T, _t)
	if _t >= DRIP_T:
		var a:= _t - DRIP_T
		bend = 0.09 * exp(-a * 3.0) * cos(a * 9.0)
	return sway + bend


func _leaf_xf() -> Transform2D:
	# pivot at the top centre of the leaf picture, tip hangs at TIP when angle = 0
	var pivot:= TIP - Vector2(0, _leaf_h() * LEAF_TIP_UV.y)
	return Transform2D(_leaf_angle(), pivot)


func _tip_world() -> Vector2:
	return _leaf_xf() * Vector2(0, _leaf_h() * LEAF_TIP_UV.y)


func _leaf_h() -> float:
	if t_leaf:
		return LEAF_SIZE * float(t_leaf.get_height()) / float(t_leaf.get_width())
	return LEAF_SIZE


func _dew_world() -> Vector2:
	if _t < DRIP_T:
		return _tip_world() + Vector2(0, 4.0 + 6.0 * _sm(FORM.x, DRIP_T, _t))
	if _t < LAND_T:
		var s:= (_t - DRIP_T) / (LAND_T - DRIP_T)
		var f:= s * s * (3.0 - 2.0 * s)
		var start:= TIP + Vector2(0, 10)
		var drift:= sin(s * PI) * 10.0
		return Vector2(lerpf(start.x, LAND.x, f) + drift, lerpf(start.y, LAND.y, f))
	var bob:= sin((_t - LAND_T) * 5.0) * 2.0 * exp(-(_t - LAND_T) * 1.5)
	return LAND + Vector2(0, bob - 5.0 * _sm(RISE.x, RISE.y, _t))


func _update_camera() -> void:
	var d:= _dew_world()
	var cy:= CAM0.y
	if _t >= DRIP_T:
		cy = clampf(d.y + 40.0, CAM0.y, CAM_END_Y)
	var sway:= Vector2(sin(_t * 0.5) * 4.0, cos(_t * 0.37) * 2.0) * (1.0 - _sm(7.5, 9.5, _t))
	cam = Vector2(CAM0.x, cy) + sway
	zoom = Z0 + 0.05 * _sm(0.0, 4.0, _t) + 0.5 * _sm(4.0, 8.5, _t) + 0.15 * _sm(8.5, 10.5, _t)
	if _leaving:
		# match cut: glide so our dew sits exactly where (and as big as) the game's dew is
		var k:= _sm(0.15, LEAVE_MOVE, _lt)
		cam = _cam_from.lerp(_cam_to, k)
		zoom = lerpf(_zoom_from, _zoom_to, k)


func _xf(par: Vector2, z0: float) -> Transform2D:
	var vs:= root.get_viewport_rect().size
	var u:= vs.x / 360.0
	var cl:= CAM0 + (cam - CAM0) * par.x
	var s:= (z0 + (zoom - Z0) * par.y) * u
	return Transform2D(0.0, Vector2(s, s), 0.0, vs * 0.5 - cl * s)


func _xf_mid() -> Transform2D:
	return _xf(Vector2.ONE, Z0)


func _layout() -> void:
	var vs:= root.get_viewport_rect().size
	logo.size = Vector2(vs.x, 200)
	logo.position = Vector2(0, vs.y * 0.1)
	prompt.size = Vector2(vs.x, 30)
	prompt.position = Vector2(0, vs.y * 0.87)


func _process(delta: float) -> void:
	_t += delta
	if _leaving:
		_lt += delta
	for ev: Array in _events:
		if _t >= ev[0] and not _fired.has(ev[1]):
			_fired[ev[1]] = true
			_cue(ev[1])
	_update_camera()
	var lift:= _sm(2.0, 6.5, _t)
	far_ci.modulate = Color.WHITE.lerp(Color(0.15, 0.15, 0.15), 1.0 - lift)
	var ml:= Color.WHITE.lerp(Color(0.3, 0.3, 0.3), 1.0 - _sm(2.5, 6.0, _t))
	var xm:= _xf_mid()
	for n: Node2D in [water_node, fish_node, ripple_node]:
		n.transform = xm
	water_node.modulate = Color(ml.r, ml.g, ml.b, 0.62)
	fish_node.modulate = ml
	mid_ci.modulate = ml
	_steer_fish()
	for wv: Array in _winds:
		if _t >= wv[0] and not wv[2]:
			wv[2] = true
			_ripple(wv[1], 0.32, 1)
	(vig.material as ShaderMaterial).set_shader_parameter("strength", lerpf(0.92, 0.6, _sm(7.0, 9.5, _t)))
	if _t >= TITLE_T and not _leaving:
		logo.modulate.a = minf(logo.modulate.a + delta * 0.9, 1.0)
		prompt.modulate.a = clampf(_t - TITLE_T - 1.0, 0.0, 1.0) * (0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 2.0)))
	for c: Control in [far_ci, mid_ci, fx_ci, beam_ci, dew_ci, glow_ci, near_ci]:
		c.queue_redraw()
	if _leaving:
		_leave_step()


func _cue(name: String) -> void:
	if _main != null:
		_cue_sound(name)
	_cue_fx(name)


func _cue_sound(name: String) -> void:
	match name:
		"drip":
			_main._play("plop", 1.8, -14.0)
		"land":
			_main._play("plop", 1.0, -4.0)
			_main._haptic("land")
		"rise":
			_main._play("sparkle", 0.8, -14.0)
		"glow":
			_main._play("sparkle", 1.0, -8.0)


func _cue_fx(name: String) -> void:
	match name:
		"land":
			_ripple(LAND, 1.1, 3)       # same as the game's landing ripple
			_scatter_fish()
		"rise":
			_ripple(LAND + Vector2(0, 4), 0.6, 2)


func _skip_to(t: float) -> void:
	_t = maxf(_t, t)
	for ev: Array in _events:
		if _t >= ev[0]:
			_fired[ev[1]] = true
	for wv: Array in _winds:
		if _t >= wv[0]:
			wv[2] = true


# ---------------------------------------------------------------- game resources

func _make_water() -> void:
	# the game's own pond surface (water.gdshader, green palette) laid over the deep water
	water_node = Node2D.new()
	root.add_child(water_node)
	var path:= "res://scripts/water.gdshader"
	if not ResourceLoader.exists(path):
		return
	var wr:= ColorRect.new()
	wr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wr.position = Vector2(-220, -500)
	wr.size = Vector2(800, 2000)
	var wm:= ShaderMaterial.new()
	var wsh:= Shader.new()
	var code: String = (load(path) as Shader).code
	code = code.replace("shader_type canvas_item;", "shader_type canvas_item;\nuniform float intro_fade = 1.0;")
	code = code.replace("COLOR = vec4(col, 1.0);", "COLOR = vec4(col, intro_fade);")
	wsh.code = code
	wm.shader = wsh
	_water_mat = wm
	wm.set_shader_parameter("deep", WATER_PAL[0])
	wm.set_shader_parameter("mid", WATER_PAL[1])
	wm.set_shader_parameter("light", WATER_PAL[2])
	wm.set_shader_parameter("screen_size", wr.size)
	wr.material = wm
	water_node.add_child(wr)


func _make_fish() -> void:
	# the game's small red fish (Koi, patch 0), swimming the channel
	fish_node = Node2D.new()
	root.add_child(fish_node)
	_rng.seed = 2026
	for i in 4:
		var k:= Koi.new()
		k.setup(_channel_point(), 9300 + i)
		k.patch = 0
		k.length = _rng.randf_range(24.0, 30.0)
		k.speed = _rng.randf_range(50.0, 65.0)
		fish_node.add_child(k)
		fish.append(k)
		_fish_next.append(_rng.randf_range(0.0, 1.5))
		_orbiting.append(0)
	for k in 6:  # little wind ripples on the open water before the drop
		_winds.append([3.6 + k * 0.55, _channel_point(), false])


func _channel_point() -> Vector2:
	var y:= _rng.randf_range(CHANNEL[0].y, CHANNEL[CHANNEL.size() - 1].y)
	var x:= CHANNEL[0].x
	for i in CHANNEL.size() - 1:
		var a: Vector2 = CHANNEL[i]
		var b: Vector2 = CHANNEL[i + 1]
		if y >= a.y and y <= b.y:
			x = lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return Vector2(x + _rng.randf_range(-34.0, 34.0), y)


func _steer_fish() -> void:
	for i in fish.size():
		var k: Node2D = fish[i]
		if not is_instance_valid(k) or _t < _fish_next[i]:
			continue
		if _t < LAND_T:
			k.dash(_channel_point(), _rng.randf_range(1.6, 2.6))
			_fish_next[i] = _t + _rng.randf_range(1.4, 2.4)
		elif _orbiting[i] == 0:
			# first gather evenly spaced on the ring, all at the same speed...
			_orbiting[i] = 1
			k.speed = 60.0
			k.dash(LAND + Vector2.from_angle(i * TAU / fish.size() - PI * 0.5) * RING_R, 0.7)
			_fish_next[i] = LAND_T + 1.5
		elif _orbiting[i] == 1:
			# ...then the fish's own orbit (the same call the game uses to circle the dew's pad).
			# One call only; the fish handles its own position, heading and tail from here.
			_orbiting[i] = 2
			k.orbit(LAND, RING_R, 99999.0)
			k.orbit_dir = 1.0          # all the same way round, so they read as one ring


func _scatter_fish() -> void:
	# a short startle away from the splash (the game's flee() sends them off-screen, too far for the intro)
	for i in fish.size():
		var k: Node2D = fish[i]
		if not is_instance_valid(k):
			continue
		var away: Vector2 = k.position - LAND
		if away.length() < 1.0:
			away = Vector2.from_angle(i * TAU / fish.size())
		k.dash(LAND + away.normalized() * 95.0, 0.5)
		k.speed = 70.0
		_fish_next[i] = LAND_T + 0.7 + i * 0.12


func _ripple(pos: Vector2, size: float, rings: int) -> void:
	var r:= Ripple.new()
	r.position = pos
	r.size = size
	r.rings = rings
	ripple_node.add_child(r)


func _splash() -> float:
	# 0 before the landing, eases to 1 (pads breathe outward and stay out)
	var a:= _t - LAND_T
	return 0.0 if a < 0.0 else 1.0 - exp(-a * 3.5)


# ---------------------------------------------------------------- drawing

func _draw_far(ci: Control) -> void:
	var xf:= _xf(PAR_FAR, 1.0)
	# slow drift of the deep water
	var drift:= Vector2(sin(_t * 0.21) * 6.0, cos(_t * 0.17) * 5.0)
	ci.draw_set_transform_matrix(xf * Transform2D(0.0, drift))
	if t_far:
		ci.draw_texture_rect(t_far, R_FAR, false)
	else:
		ci.draw_rect(R_FAR, C_DEEP)
		for i in 7:
			var p:= Vector2(20 + i * 55, 180 + (i % 3) * 140)
			ci.draw_circle(p, 46.0, C_DEEP.darkened(0.35))
	# moving moonlight caustics on the deep water
	ci.draw_set_transform_matrix(xf)
	for i in 9:
		var ph:= _t * (0.25 + i * 0.03) + i * 1.7
		var p:= Vector2(180 + sin(ph) * 150.0 + cos(ph * 0.7 + i) * 40.0, 120 + i * 60.0 + cos(ph * 0.8) * 30.0)
		var r:= 30.0 + 18.0 * sin(ph * 1.3)
		ci.draw_circle(p, r, Color(MOON, 0.035))


func _pad_turn() -> float:
	# the pads around the dew start a slow turn when it lands (eases in, then keeps turning)
	var a:= _t - LAND_T
	if a <= 0.0:
		return 0.0
	const SPIN_V:= 0.11      # rad/s once up to speed
	const RAMP:= 1.2
	if a < RAMP:
		return SPIN_V * a * a / (2.0 * RAMP)
	return SPIN_V * (a - RAMP * 0.5)


func _draw_mid(ci: Control) -> void:
	var xf:= _xf_mid()
	# pads breathe slowly; after the splash they ease outward from LAND
	var breathe:= 1.0 + sin(_t * 0.8) * 0.006 + 0.045 * _splash()
	var bob:= Vector2(sin(_t * 0.6) * 1.5, cos(_t * 0.5) * 1.5)
	var turn:= _pad_turn()
	var m:= Transform2D(turn, bob + LAND) * Transform2D(0.0, Vector2(breathe, breathe), 0.0, Vector2.ZERO) * Transform2D(0.0, -LAND)
	ci.draw_set_transform_matrix(xf * m)
	if t_mid:
		ci.draw_texture_rect(t_mid, R_MID, false)
	else:
		for p: Vector4 in _dummy_pads:
			var pm:= Transform2D(p.w + sin(_t * 0.4 + p.x) * 0.03, Vector2.ONE * p.z / 840.0, 0.0, Vector2(p.x, p.y))
			ci.draw_set_transform_matrix(xf * m * pm)
			ci.draw_texture(lily, Vector2(-512, -512), Color(0.85, 1.0, 0.75))
	# the drip leaf hangs in the mid layer so its tip lines up with the dew
	ci.draw_set_transform_matrix(xf * _leaf_xf())
	var rect:= Rect2(-LEAF_SIZE * LEAF_TIP_UV.x, 0.0, LEAF_SIZE, _leaf_h())
	if t_leaf:
		ci.draw_texture_rect(t_leaf, rect, false)
	else:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-90, 0), Vector2(90, 0), Vector2(30, LEAF_SIZE * 0.6),
			Vector2(0, LEAF_SIZE * LEAF_TIP_UV.y), Vector2(-30, LEAF_SIZE * 0.6)]), C_PAD.darkened(0.45))


func _draw_fx(ci: Control) -> void:
	var xf:= _xf_mid()
	var a:= _t - LAND_T
	# moon reflection on the channel
	ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(1, 0.45), 0.0, LAND + Vector2(14, -40)))
	var shim:= 0.5 + 0.5 * sin(_t * 1.7)
	ci.draw_circle(Vector2.ZERO, 22.0, Color(MOON, 0.08 + 0.04 * shim))
	ci.draw_circle(Vector2(sin(_t) * 3.0, 0), 11.0, Color(MOON, 0.12 + 0.05 * shim))
	if a < 0.0:
		return
	# droplets
	if a < 0.7:
		ci.draw_set_transform_matrix(xf)
		for k in 7:
			var dir:= Vector2.from_angle(-PI * 0.5 + (k - 3) * 0.45)
			var p:= LAND + dir * (a * 70.0) + Vector2(0, a * a * 160.0)
			ci.draw_circle(p, 2.2 * (1.0 - a / 0.7) + 0.6, Color(0.9, 1.0, 0.96, 0.85 * (1.0 - a / 0.7)))
	# the pad that rises under the dew
	var rk:= _sm(RISE.x, RISE.y, _t)
	if rk > 0.0:
		ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(1, 0.8), 0.0, LAND + Vector2(0, 4)))
		var sz:= 62.0 * (0.45 + 0.55 * rk)
		var pt:= t_floor if t_floor else lily
		var pm:= Transform2D(0.35 + (1.0 - rk) * 0.6 + _pad_turn() * 1.6, Vector2.ONE * sz / float(pt.get_width()), 0.0, LAND + Vector2(0, 4))
		ci.draw_set_transform_matrix(xf * pm)
		ci.draw_texture(pt, -Vector2(pt.get_size()) * 0.5, Color(1, 1, 1, rk))
	ci.draw_set_transform_matrix(xf)


func _draw_beam(ci: Control) -> void:
	var xf:= _xf_mid()
	ci.draw_set_transform_matrix(xf)
	var ia:= _sm(0.3, 1.8, _t) * (1.0 - _sm(4.5, 6.5, _t))
	var ib:= _sm(3.8, 6.2, _t)
	var tip:= _tip_world()
	_ray(ci, Vector2(380, -330), 60.0, tip + Vector2(6, 30), 110.0, 0.15 * ia)
	_ray(ci, Vector2(420, -330), 30.0, tip + Vector2(40, 60), 60.0, 0.07 * ia)
	_ray(ci, Vector2(540, 120), 90.0, LAND + Vector2(0, 10), 220.0, 0.10 * ib)
	_ray(ci, Vector2(580, 180), 40.0, LAND + Vector2(60, 0), 110.0, 0.06 * ib)
	if ia > 0.0:
		_soft_glow(ci, tip, 46.0, MOON, 0.08 * ia)
	if ib > 0.0:
		ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(1, 0.7), 0.0, LAND))
		_soft_glow(ci, Vector2.ZERO, 110.0, MOON, 0.07 * ib)
	# floating moon motes, between the pond and the camera
	ci.draw_set_transform_matrix(_xf(PAR_MOTE, 1.0))
	var mk:= _sm(0.8, 2.5, _t)
	for m: Vector4 in _motes:
		var p:= Vector2(m.x + sin(_t * 0.6 + m.w) * 8.0, m.y - fmod(_t * 6.0 * m.z, 60.0))
		var tw:= 0.5 + 0.5 * sin(_t * 2.0 * m.z + m.w)
		ci.draw_circle(p, 1.0 + m.z * 0.6, Color(MOON, 0.25 * tw * mk))


func _ray(ci: CanvasItem, a: Vector2, wa: float, b: Vector2, wb: float, alpha: float) -> void:
	# soft god ray: bell-shaped across its width, faded at both ends, with slow drifting streaks
	if alpha <= 0.001:
		return
	alpha *= 0.85 + 0.15 * sin(_t * 1.3 + a.x)
	wa *= 1.6
	wb *= 1.6
	var n:= (b - a).normalized().orthogonal()
	var end:= b + (b - a).normalized() * wb * 0.35
	const SL:= 18     # slices across
	const SG:= 8      # segments along
	for i in SL:
		var u0:= float(i) / SL
		var u1:= float(i + 1) / SL
		var um:= (u0 + u1) * 0.5
		var bell:= pow(sin(um * PI), 2.2)
		var streak:= 0.65 + 0.35 * sin(um * 23.0 + a.x * 0.1 + _t * 0.35) * sin(um * 9.0 - _t * 0.22 + 1.3)
		var k:= alpha * bell * streak
		if k <= 0.0005:
			continue
		for j in SG:
			var s0:= float(j) / SG
			var s1:= float(j + 1) / SG
			var p0:= a.lerp(end, s0)
			var p1:= a.lerp(end, s1)
			var w0:= lerpf(wa, wb, s0)
			var w1:= lerpf(wa, wb, s1)
			var e0:= _ray_env(s0) * k
			var e1:= _ray_env(s1) * k
			ci.draw_polygon(PackedVector2Array([p0 + n * w0 * (u0 - 0.5), p0 + n * w0 * (u1 - 0.5),
				p1 + n * w1 * (u1 - 0.5), p1 + n * w1 * (u0 - 0.5)]),
				PackedColorArray([Color(MOON, e0), Color(MOON, e0), Color(MOON, e1), Color(MOON, e1)]))


static func _ray_env(s: float) -> float:
	# fades in from the source, holds, and dissolves past the target
	return smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.7, 1.0, s)) * (1.1 - 0.5 * s)


func _soft_glow(ci: CanvasItem, p: Vector2, r: float, col: Color, alpha: float) -> void:
	# many thin layers so the halo has no visible rings
	const STEPS:= 24
	for k in STEPS:
		var f:= 1.0 - float(k) / STEPS
		ci.draw_circle(p, r * f, Color(col, alpha * 2.2 / STEPS))


func _draw_dew(ci: Control) -> void:
	# the game's dew: glass lens over what lies beneath + dew_overlay_gpt gloss + drawn rim (Frog)
	var vis:= _t >= FORM.x
	if lens:
		lens.visible = vis
		if lens.has_meta("gloss"):
			(lens.get_meta("gloss") as Node2D).visible = vis
	if not vis:
		return
	var xf:= _xf_mid()
	var s:= xf.get_scale().x
	var form:= _sm(FORM.x, FORM.x + 1.0, _t)
	var r:= 11.0 * s * (0.25 + 0.75 * form) * (1.0 + 0.4 * _sm(RISE.y, GLOW_T + 1.0, _t))
	var sq:= 0.0
	if _t < DRIP_T:
		sq = -1.4 * _sm(2.6, DRIP_T, _t) + sin(_t * 9.0) * 0.25 * form
	elif _t < LAND_T:
		sq = -0.9 * (1.0 - _sm(DRIP_T, DRIP_T + 0.6, _t)) - 0.5
	else:
		var a:= _t - LAND_T
		sq = 2.2 * exp(-a * 5.0) * cos(a * 18.0)
	# faint trail while falling
	if _t > DRIP_T and _t < LAND_T:
		for k in 5:
			var tb:= _t - (k + 1) * 0.05
			var saved:= _t
			_t = maxf(tb, DRIP_T)
			var p:= xf * _dew_world()
			_t = saved
			ci.draw_circle(p, r * (0.5 - k * 0.08), Color(MOON, 0.18 - k * 0.03))
	var c:= xf * _dew_world()
	if lens:
		Frog.place_lens(lens, c, r, sq, dew_ci.modulate.a, 0.0)
	Frog.draw_dew(ci, c, r, sq, 1.0, _t, SHOWN)


func _draw_glow(ci: Control) -> void:
	var xf:= _xf_mid()
	var s:= xf.get_scale().x
	var p:= xf * _dew_world()
	var g:= _sm(2.3, 2.9, _t) * (1.0 - _sm(DRIP_T, DRIP_T + 0.5, _t))
	if g > 0.0:
		var q:= p + Vector2(-4, -6) * s
		var L:= 9.0 * s * (0.8 + 0.2 * sin(_t * 7.0))
		ci.draw_line(q - Vector2(L, 0), q + Vector2(L, 0), Color(1, 1, 0.95, 0.8 * g), 1.4, true)
		ci.draw_line(q - Vector2(0, L), q + Vector2(0, L), Color(1, 1, 0.95, 0.8 * g), 1.4, true)
		_soft_glow(ci, p, 30.0 * s, MOON, 0.12 * g)
	# soft moon halo so the falling bead reads against the dark water
	var fk:= _sm(DRIP_T - 0.2, DRIP_T + 0.3, _t) * (1.0 - _sm(LAND_T + 0.2, LAND_T + 1.0, _t))
	if fk > 0.0:
		_soft_glow(ci, p, 22.0 * s, MOON, 0.12 * fk)
	var w:= _sm(GLOW_T, GLOW_T + 0.8, _t)
	if w > 0.0:
		var pulse:= 1.0 + 0.06 * sin(_t * 2.0)
		_soft_glow(ci, p, 75.0 * s * pulse, WARM, 0.2 * w)


func _draw_near(ci: Control) -> void:
	var xf:= _xf(PAR_NEAR, 1.0)
	# near leaves sway around the top of the frame
	var sw:= sin(_t * 0.7) * 0.02
	for i in 2:
		var r: Rect2 = R_NEAR if i == 0 else R_NEAR2
		var piv:= Vector2(r.get_center().x, r.position.y)
		var m:= Transform2D(0.0, piv) * Transform2D(sw * (1.0 if i == 0 else -0.5), Vector2.ZERO) * Transform2D(0.0, -piv)
		ci.draw_set_transform_matrix(xf * m)
		if t_near:
			if i == 0:
				ci.draw_texture_rect(t_near, r, false)
			else:  # the two front leaves that the dew falls past
				ci.draw_texture_rect(t_near_lower, r, false)
		else:
			var y0:= r.position.y
			for k in 5:
				var lx:= r.position.x + (k * 113) % int(r.size.x)
				if lx > 60.0 and lx < 300.0 and i == 0:
					continue
				ci.draw_circle(Vector2(lx, y0 + 80 + (k % 2) * 140), 70.0, C_NEAR)
			ci.draw_rect(Rect2(r.position.x, y0, 40, r.size.y), C_NEAR)
			ci.draw_rect(Rect2(r.end.x - 40, y0, 40, r.size.y), C_NEAR)


# ---------------------------------------------------------------- input / exit

func _on_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _t < TITLE_T:
			_skip_to(TITLE_T)
			return
		begin()


func begin() -> void:
	if _leaving:
		return
	if _t < TITLE_T:
		_skip_to(TITLE_T + 1.0)
		_update_camera()
	_leaving = true
	_lt = 0.0
	if _main:
		_main._play("jump", 1.2, -4.0)
	# where the game's dew is drawn (Frog draws it r*0.85 above its origin) and how big
	var target:= Vector2(180, 456) * (root.get_viewport_rect().size.x / 360.0)
	var game_r:= 17.6
	if _main and "frog" in _main and is_instance_valid(_main.frog):
		var fr: Node2D = _main.frog
		game_r = Frog.DEW_R * Main.depth_at(fr.global_position.y) * 0.88 * fr.size_k
		target = fr.get_global_transform_with_canvas().origin + Vector2(0, -game_r * 0.85)
	var u:= root.get_viewport_rect().size.x / 360.0
	var vs:= root.get_viewport_rect().size
	var dew:= _dew_world()
	_cam_from = cam
	_zoom_from = zoom
	_zoom_to = game_r / (11.0 * 1.4 * u)   # our dew is 11 * 1.4 world units once grown
	_cam_to = dew - (target - vs * 0.5) / (_zoom_to * u)
	# the game's UI fades in under us instead of popping on at the end
	if _main:
		for nm in ["ui", "title_box"]:
			if nm in _main and _main.get(nm) is CanvasItem:
				var c: CanvasItem = _main.get(nm)
				if nm == "title_box" and "ever_jumped" in _main and _main.ever_jumped:
					continue
				c.modulate.a = 0.0
				c.visible = true
				_fade_ui.append(c)
	var tw:= create_tween()
	tw.set_parallel(true)
	tw.tween_property(logo, "modulate:a", 0.0, 0.45)
	tw.tween_property(prompt, "modulate:a", 0.0, 0.25)


func _leave_step() -> void:
	var w:= 1.0 - _sm(LEAVE_FADE.x, LEAVE_FADE.y, _lt)
	for c in root.get_children():
		if c == dew_ci or c == logo or c == prompt:
			continue
		(c as CanvasItem).modulate.a = w * (0.62 if c == water_node else 1.0)
	if _water_mat:
		_water_mat.set_shader_parameter("intro_fade", w)
	# our dew sits on top of the game's dew, then lets it take over
	dew_ci.modulate.a = 1.0 - _sm(LEAVE_FADE.y - 0.1, LEAVE_END, _lt)
	glow_ci.modulate.a = w
	for c: CanvasItem in _fade_ui:
		if is_instance_valid(c):
			c.modulate.a = _sm(LEAVE_FADE.x + 0.4, LEAVE_END, _lt)
	if _lt >= LEAVE_END:
		set_process(false)
		for c: CanvasItem in _fade_ui:
			if is_instance_valid(c):
				c.modulate.a = 1.0
		started.emit()
		queue_free()
