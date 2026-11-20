class_name Main
extends Node2D


const DESIGN_W:= 360.0
# build identity (APK protection guide §3): stays in every copy of the game, readable only from the compiled code
const BUILD_NO:= 116
const BUILD_VER:= "1.16"
const BUILD_DATE:= "2026-11-19"
const MAKER_ID:= "moonshot2026"
const BUILD_FP:= "mp-e1af284cb6ee4fa6"      # per-build fingerprint, recorded in the build log
const SIGN_SHA256:= "7C:CE:CB:6A:DE:E3:C3:F7"   # first bytes of the release signing certificate (2026 key)
const LANDINGS_PER_ROUND:= 5
const SCROLL_TIME:= 0.6


const PATTERNS:= [
	{ "name": "지그재그", "pads": [[95, 0, 150], [252, -165, 145], [108, -330, 142], [255, -495, 145], [105, -660, 140], [240, -825, 150], [120, -985, 120], [270, -1120, 110]]},
	{ "name": "넓은 호", "pads": [[175, 0, 150], [275, -150, 140], [270, -320, 145], [170, -475, 140], [80, -625, 140], [110, -795, 150], [240, -950, 120], [140, -1090, 110]]},
	{ "name": "징검다리", "pads": [[90, 0, 128], [195, -132, 118], [285, -258, 115], [195, -392, 118], [92, -515, 115], [180, -650, 128], [280, -780, 110], [150, -905, 105]]},
]

const SND:= {
	"jump": preload("res://audio/jump.wav"),
	"edge": preload("res://audio/edge.wav"),
	"nudge": preload("res://audio/nudge.wav"),
	"bloom": preload("res://audio/bloom.wav"),
	"sparkle": preload("res://audio/sparkle.wav"),
	"ambient": preload("res://audio/ambient.wav"),
	"bgm": preload("res://audio/bgm_summer_sky_pond.mp3"),
	"croak": preload("res://audio/croak.wav"),
	"aim": preload("res://audio/aim.wav"),
	"plop": preload("res://audio/plop.wav"),
	"p0": preload("res://audio/perfect_0.wav"),
	"p1": preload("res://audio/perfect_1.wav"),
	"p2": preload("res://audio/perfect_2.wav"),
	"p3": preload("res://audio/perfect_3.wav"),
	"p4": preload("res://audio/perfect_4.wav"),
	"p5": preload("res://audio/perfect_5.wav"),
}

const BGS:= [
	preload("res://assets/pond_background.png"),
	preload("res://assets/pond_bg_halfmoon.png"),
	preload("res://assets/pond_bg_crescent.png"),
]
const UI_SHEET:= preload("res://assets/ui_icons.png")

static var home_y:= 470.0
static var top_y:= 70.0


static func depth_at(y: float) -> float:

	var t:= (y - top_y) / maxf(home_y - top_y, 1.0)
	return clampf(lerpf(0.84, 1.0, t), 0.8, 1.05)


var vs:= Vector2(360, 640)
var x_off:= 0.0
var pattern_index:= 0
var round_no:= 1
var step:= 0
var landings:= 0
var taps:= 0
var last_tap:= Vector2.INF
var opened_upto:= 0
var pad_size:= 96.0
var _quip_used: Dictionary = {}
var centers:= 0
var combo:= 0
var results: Array = []
var locked:= false
var bloomed:= false
var ever_jumped:= false
var idle_time:= 0.0
var scroll:= 0.0

var bg: Sprite2D
var credit: Label
var water_sv: SubViewport
var water_rect: ColorRect
var layer: Node2D
var ripples: Node2D
var pads: Array = []
var frog: Frog
var frog_shadow: Node2D
var hint: Node2D
var lotus: Lotus
var flies: Fireflies
var ui: CanvasLayer
var hud: Control
var title_box: Control
var result_box: Control
var result_title: Label
var result_sub: Label
var again_btn: Button
var pond_label: Label
var fade: ColorRect
var ambient: AudioStreamPlayer
var bgm: AudioStreamPlayer
var sound_btn: TextureButton
var sound_on:= true
var stars_node: Node2D
var celebrate_t:= 0.0

const STREAK_GOAL:= 4
var streak:= 0
var escapes:= 0
var run_time:= 0.0
var light_idx:= -2.2
var light_on:= false
var best:= 0
var light: LightChaser = null
static var beat_pulse:= 0.0
var song_t:= 0.0
var _last_beat:= -1
var score:= 0
var rhythm_combo:= 0
var best_combo:= 0
var turtles:= 0
var koi_met:= 0   # v114: hidden koi found this walk
const TURTLE_EVERY:= 16
var big_turtle: Turtle
var path_heading:= 0.0
var in_intro:= true
var intro: Intro
var result_img: TextureRect
const TYPO:= "res://assets/typo_set.png"
const BUTTON:= "res://assets/ui_button.png"
var _typo_tex: Texture2D = null
var font: Font = preload("res://fonts/NanumMyeongjoBold.woff2")
var _hint_t:= 0.0
var _rng:= RandomNumberGenerator.new()


var autoplay:= false
var showcase:= false   # recording aid: the autoplayer also goes looking for the hidden koi
var _show_t:= 0.0
var shots_dir:= ""
var quit_after_rounds:= 0
var auto_landings:= 18   # test/recording only: --landings=N
var _auto_wait:= 0.0
var _bloom_count_this_round:= 0
var _log_prefix:= "[TEST] "


func _ready() -> void:
	_rng.randomize()
	_parse_args()
	_load_best()
	if FLOW_MODE:
		_load_book()
	if TARGET_MODE:
		var timg:= Image.load_from_file("res://assets/Moon_Floor_02.png")
		if timg:
			TARGET_TEX = ImageTexture.create_from_image(timg)
		var fimg:= Image.load_from_file("res://assets/deco_flowers.png")
		if fimg:
			LilyPad.FLOWER_TEX = ImageTexture.create_from_image(fimg)
	_build_scene()
	_build_ui()
	frog.bounced.connect(_on_dew_bounce)
	get_viewport().size_changed.connect(_layout)
	_start_round(true)
	intro = Intro.new()
	intro.setup(self)
	title_box.visible = false
	ui.visible = false
	intro.started.connect(func ():
		in_intro = false
		ui.visible = true
		title_box.visible = not ever_jumped
		if dew_name == "" and not autoplay:
			get_tree().create_timer(1.2).timeout.connect(_ask_dew_name))
	add_child(intro)
	ambient = AudioStreamPlayer.new()
	ambient.stream = SND.ambient
	ambient.volume_db = -34.0   # v107: pond plinks well under the music (v106 -27, v105 -15)
	ambient.finished.connect(ambient.play)
	add_child(ambient)
	ambient.play()
	bgm = AudioStreamPlayer.new()
	bgm.stream = SND.bgm
	var bgm_bytes:= FileAccess.get_file_as_bytes("res://audio/bgm_new.mp3")
	if bgm_bytes.size() > 1000:
		var new_song:= AudioStreamMP3.new()
		new_song.data = bgm_bytes
		bgm.stream = new_song
	bgm.volume_db = 0.0   # v109: music up 4dB (was -4)
	bgm.finished.connect(func ():
		bgm.play()
		song_t = 0.0)
	add_child(bgm)
	bgm.play()
	song_t = 0.0


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
		if a == "--showcase":
			showcase = true
		elif a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--landings="):
			auto_landings = int(a.substr(11))
		elif a.begins_with("--rounds="):
			quit_after_rounds = int(a.substr(9))


func _build_scene() -> void:
	bg = Sprite2D.new()
	bg.texture = preload("res://assets/pond_background.png")
	bg.z_index = -20
	add_child(bg)

	layer = Node2D.new()
	layer.y_sort_enabled = true
	add_child(layer)
	ripples = Node2D.new()
	ripples.z_index = -1
	layer.add_child(ripples)
	touch_fx = Node2D.new()
	touch_fx.z_index = -1
	touch_fx.draw.connect(_draw_touch_fx)
	layer.add_child(touch_fx)
	lane_fx = Node2D.new()
	lane_fx.z_index = 3
	lane_fx.draw.connect(_draw_lane_edges)
	layer.add_child(lane_fx)
	hint = Node2D.new()
	hint.z_index = 3
	hint.draw.connect(_draw_hint)
	layer.add_child(hint)
	var dusk:= CanvasModulate.new()
	dusk.color = Color(0.9, 0.95, 1.0)
	add_child(dusk)
	stars_node = Node2D.new()
	stars_node.z_index = 4
	stars_node.draw.connect(_draw_stars)
	var smat:= CanvasItemMaterial.new()
	smat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	stars_node.material = smat
	layer.add_child(stars_node)
	frog_shadow = Node2D.new()
	frog_shadow.set_script(preload("res://scripts/frog_shadow.gd"))
	frog_shadow.z_index = 4 if TARGET_MODE else 1
	layer.add_child(frog_shadow)
	frog = Frog.new()
	frog.z_index = 5 if TARGET_MODE else 2
	frog.shadow = frog_shadow
	layer.add_child(frog)
	# v116: a little name tag floats above the dew
	name_tag = Node2D.new()
	name_tag.z_index = 20
	layer.add_child(name_tag)
	name_tag.draw.connect(_draw_name_tag)

	lotus = Lotus.new()
	lotus.z_index = 4
	add_child(lotus)
	flies = Fireflies.new()
	flies.z_index = 5
	add_child(flies)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root:= Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	root.add_child(hud)

	pond_label = _label("", 12, Color(0.85, 0.9, 1.0, 0.7))
	pond_label.position = Vector2(16, 14)
	pond_label.size = Vector2(150, 20)
	root.add_child(pond_label)

	sound_btn = TextureButton.new()
	sound_btn.ignore_texture_size = true
	sound_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	sound_btn.custom_minimum_size = Vector2(40, 40)
	sound_btn.size = Vector2(40, 40)
	sound_btn.pressed.connect(_toggle_sound)
	root.add_child(sound_btn)

	credit = Label.new()
	credit.text = "%s  ·  v%s (%d)  ·  %s" % [MAKER_ID, BUILD_VER, BUILD_NO, BUILD_DATE.replace("-", ".")]
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cf:= FontVariation.new()
	cf.base_font = preload("res://fonts/NanumMyeongjo.woff2")
	cf.spacing_glyph = 2
	credit.add_theme_font_override("font", cf)
	credit.add_theme_font_size_override("font_size", 12)   # v112: maker mark 10% larger (was 11)
	credit.add_theme_color_override("font_color", Color(1.0, 1.0, 0.95, 0.55))
	credit.add_theme_color_override("font_shadow_color", Color(0, 0.05, 0.04, 0.5))
	credit.add_theme_constant_override("shadow_offset_y", 1)
	credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(credit)
	_update_sound_icon()
	if FLOW_MODE:
		_build_book_ui(root)

	title_box = VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override("separation", 6)
	var t1:= TextureRect.new()
	t1.texture = preload("res://assets/title_logo.png")
	t1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t1.custom_minimum_size = Vector2(0, 118)
	t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t2: Control = _label("길을 막은 연잎을 톡 두드려 물길을 열어 주세요", 15, Color(0.88, 0.95, 1.0, 0.9))
	if typo_atlas(1):
		t2 = typo_node(1, "", 15, Color.WHITE)
	title_box.add_child(t2)
	t1.queue_free()
	root.add_child(title_box)

	result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 8)
	result_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_title = _label("", 26, Color(1.0, 0.93, 0.8))
	result_sub = _label("", 14, Color(0.9, 0.95, 1.0, 0.9))
	result_box.add_child(result_title)
	result_img = TextureRect.new()
	result_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_img.custom_minimum_size = Vector2(0, 64)
	result_img.visible = false
	result_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_box.add_child(result_img)
	result_box.add_child(result_sub)
	var spacer:= Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	result_box.add_child(spacer)
	again_btn = Button.new()
	again_btn.text = "한 번 더"
	again_btn.custom_minimum_size = Vector2(170, 54)
	again_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again_btn.add_theme_font_override("font", font)
	again_btn.add_theme_font_size_override("font_size", 20)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb:= StyleBoxFlat.new()
		sb.bg_color = Color(0.93, 0.55, 0.66, 0.95) if st != "pressed" else Color(0.8, 0.42, 0.55, 1.0)
		if st == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(27)
		sb.shadow_color = Color(0, 0, 0, 0.25)
		sb.shadow_size = 6 if st != "focus" else 0
		again_btn.add_theme_stylebox_override(st, sb)
	again_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	again_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	again_btn.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.95))
	again_btn.pressed.connect(_on_again)
	if ResourceLoader.exists(BUTTON):
		var btex: Texture2D = load(BUTTON)
		for st in ["normal", "hover", "pressed", "focus"]:
			var at:= AtlasTexture.new()
			at.atlas = btex
			at.region = Rect2(640 if st == "pressed" else 0, 0, 640, 200)
			var sbt: StyleBox = StyleBoxEmpty.new()
			if st != "focus":
				var sx:= StyleBoxTexture.new()
				sx.texture = at
				sbt = sx
			again_btn.add_theme_stylebox_override(st, sbt)
		again_btn.custom_minimum_size = Vector2(200, 62)
		var lab:= typo_atlas(4)
		if lab:
			again_btn.text = ""
			var tr:= TextureRect.new()
			tr.texture = lab
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.offset_top = 6
			tr.offset_bottom = -10
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			again_btn.add_child(tr)
	result_box.add_child(again_btn)
	result_box.visible = false
	root.add_child(result_box)

	fade = ColorRect.new()
	fade.color = Color(0.02, 0.04, 0.1, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)


func typo_atlas(row: int) -> AtlasTexture:
	if _typo_tex == null:
		if not ResourceLoader.exists(TYPO):
			return null
		_typo_tex = load(TYPO)
	var at:= AtlasTexture.new()
	at.atlas = _typo_tex
	at.region = Rect2(0, row * 256, 1024, 256)
	return at


func typo_node(row: int, fallback: String, size: int, col: Color) -> Control:
	var at:= typo_atlas(row)
	if at == null:
		return _label(fallback, size, col)
	var tr:= TextureRect.new()
	tr.texture = at
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.custom_minimum_size = Vector2(0, size * 2.2)
	return tr


func _label(text: String, size: int, col: Color) -> Label:
	var l:= Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.15, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _layout() -> void:
	vs = get_viewport_rect().size
	x_off = (vs.x - DESIGN_W) * 0.5
	home_y = vs.y - 170.0
	top_y = 70.0
	if water_sv:
		var ws:= Vector2i(int(ceil(vs.x * 0.5)), int(ceil(vs.y * 0.5)))
		if water_sv.size != ws:
			water_sv.size = ws
			water_rect.size = Vector2(ws)
	var tex_size:= bg.texture.get_size()
	var cover:= maxf(vs.x / tex_size.x, vs.y / tex_size.y) * 1.04
	bg.scale = Vector2(cover, cover)
	_update_bg()
	layer.position.x = x_off
	if pads.size() > step:
		layer.position.y = home_y - (pads[step] as LilyPad).position.y
	flies.area = Rect2(10, 90, vs.x - 20, vs.y - 160)
	# v77: the button stack sits at the bottom right, same order as before
	sound_btn.position = Vector2(vs.x - 50, vs.y - 190)
	if book_btn:
		book_btn.position = Vector2(vs.x - 56, vs.y - 142)
	if restart_btn:
		restart_btn.position = Vector2(vs.x - 62, vs.y - 102)
	if vib_btn:
		vib_btn.position = Vector2(vs.x - 62, vs.y - 66)
	if photo_btn:
		photo_btn.position = Vector2(vs.x - 56, vs.y - 238)
	if video_btn:
		video_btn.position = Vector2(vs.x - 56, vs.y - 280)
	if name_btn:
		name_btn.position = Vector2(vs.x * 0.5 - 110, 110)
	if credit:
		credit.size = Vector2(vs.x, 18)
		credit.position = Vector2(0, vs.y - 22)
	title_box.size = Vector2(vs.x, 150)
	title_box.position = Vector2(0, vs.y * 0.17)
	result_box.size = Vector2(vs.x, 160)
	result_box.position = Vector2(0, vs.y * 0.26)
	hud.queue_redraw()


func _update_bg() -> void:
	var tex_size:= bg.texture.get_size() * bg.scale
	var margin:= (tex_size.y - vs.y) * 0.5
	bg.position = Vector2(vs.x * 0.5, vs.y * 0.5 + clampf(scroll * 0.03, -margin, margin))


func _start_round(first: bool) -> void:
	_path_phase = _rng.randf() * TAU
	for p in pads:
		if is_instance_valid(p):
			p.queue_free()
	pads.clear()
	path_heading = 0.0
	pad_size = 96.0
	var p0:= LilyPad.new()
	p0.setup(96.0, _rng.randf() * TAU)
	p0.position = Vector2(180, 0)
	layer.add_child(p0)
	pads.append(p0)
	for k in 8:
		_add_pad(false)
	_build_pond()
	step = 0
	falls = 0
	skips = 0
	stars_caught = 0
	charging = false
	pressing = false
	power = 0.0
	landings = 0
	centers = 0
	combo = 0
	streak = 0
	escapes = 0
	score = 0
	rhythm_combo = 0
	taps = 0
	fed = 0
	_quip_used.clear()
	if frog: frog.set_stage(0)
	turtles = 0
	run_time = 0.0
	light_idx = -2.2
	light_on = false
	results.clear()
	bloomed = false
	locked = false
	idle_time = 0.0
	scroll = 0.0
	lotus.visible = false
	_apply_water(0)
	result_box.visible = false
	pond_label.text = ""
	_layout()
	frog.evaporate = 0.0
	frog.set_pose("idle")
	stars.clear()
	frog.place_on(pads[0], Vector2(0.0, 0.0))
	(pads[1] as LilyPad).set_target(true)
	var p0pos: Vector2 = (pads[0] as LilyPad).position
	_open_corridor(p0pos + Vector2(0, 460), p0pos, 0.0, false)
	_line_channel(p0pos + Vector2(0, 460), p0pos, false)
	if FLOW_MODE:
		_flow_reset()
	else:
		_open_path(0, false)
	title_box.visible = first
	title_box.modulate.a = 1.0
	hud.queue_redraw()
	_log("run_start run=%d" % round_no)


func _add_pad(animate_crowd: bool) -> void:
	var last: LilyPad = pads[pads.size() - 1]

	path_heading += _rng.randf_range(-1.0, 1.0)
	path_heading = clampf(path_heading, -1.35, 1.35)
	if PUSH_MODE:
		# a gentle, regular meander like the reference river
		path_heading = 0.5 * sin(pads.size() * 0.95 + _path_phase)
	var dist:= _rng.randf_range(140.0, 168.0) if not TARGET_MODE else (_rng.randf_range(150.0, 165.0) if PUSH_MODE else _rng.randf_range(130.0, 290.0))
	var dir:= Vector2(sin(path_heading), -cos(path_heading))
	var nxt:= last.position + dir * dist
	if nxt.x < 72.0 or nxt.x > 288.0:
		path_heading = -path_heading * 0.8
		dir = Vector2(sin(path_heading), -cos(path_heading))
		nxt = last.position + dir * dist
	var x:= clampf(nxt.x, 72.0, 288.0)
	var y:= minf(nxt.y, last.position.y - 55.0)
	var p:= LilyPad.new()
	var shrink:= clampf(float(pads.size()) * 0.35, 0.0, 22.0)
	pad_size = _rng.randf_range(64.0, 80.0) if _rng.randf() < 0.5 else _rng.randf_range(98.0, 124.0)
	if TARGET_MODE:
		pad_size = _rng.randf_range(101.0, 121.0)
	p.setup(pad_size - shrink * 0.3, _rng.randf() * TAU)
	p.position = Vector2(x, y)
	p.reveal = 0.0
	if TARGET_MODE:
		p.custom_tex = TARGET_TEX
	layer.add_child(p)
	pads.append(p)
	_spawn_crowd(last.position.y + 40.0, y - 40.0)
	_spawn_blockers(pads.size() - 1)


func _spawn_blockers(i: int) -> void:
	if FLOW_MODE or i < 2 or i >= pads.size():
		return
	var a: Vector2 = (pads[i - 1] as LilyPad).position
	var b: Vector2 = (pads[i] as LilyPad).position
	var spots:= [b + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-10, 10)), a.lerp(b, 0.55) + Vector2(_rng.randf_range(-20, 20), 0)]
	if _rng.randf() < 0.6:
		spots.append(a.lerp(b, 0.8) + Vector2(_rng.randf_range(-45, 45), 0))
	for at in spots:
		var c:= LilyPad.new()
		c.setup(_rng.randf_range(96.0, 128.0), _rng.randf() * TAU)
		c.decor = true
		c.position = at
		layer.add_child(c)
		_maybe_flower(c)
		crowd.append({ "node": c, "home": at})


func _on_again() -> void:
	if not bloomed:
		return
	bloomed = false
	locked = true
	result_box.visible = false
	var tw:= create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	await tw.finished
	round_no += 1
	_start_round(false)
	var tw2:= create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.4)


const TAP_BOOST:= 0.12
const BPM:= 99.38
const BEAT:= 60.0 / BPM
const HOLD_RATE:= 0.62 / BEAT
const FIRE_DELAY:= 0.32
const MAX_POWER:= 1.6
const CENTER_P:= 0.62
const HOP_MIN:= 26.0
const HOP_MAX_RATIO:= 1.0 / CENTER_P
var charging:= false
var pressing:= false
var power:= 0.0
var since_release:= 0.0
var charge_t:= 0.0
var _tick_t:= 0.0
var falls:= 0
var skips:= 0
var stars_caught:= 0
var stars: Array = []


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_finger_move(event.position, event.velocity)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			last_tap = event.position
			_finger = event.position - layer.global_position
			_finger_vel = Vector2.ZERO
			_stroke_n = 0
			handle_tap()
		else:
			_finger_up()
		get_viewport().set_input_as_handled()


func can_act() -> bool:
	return not (in_intro or locked or bloomed or frog.jumping)


func begin_charge() -> void:
	if not can_act():
		_log("press_ignored locked=%s" % locked)
		return
	if frog.pose == "sleepy":
		frog.set_pose("idle")
	charging = true
	pressing = true
	power = 0.0
	idle_time = 0.0
	_play("aim", 0.9, -14.0)


func charge_power() -> float:
	return power


func release_charge() -> void:
	if not charging:
		return
	charging = false
	pressing = false
	frog.charge = 0.0
	var pw:= power
	power = 0.0
	_judge_rhythm()
	handle_release(pw)


func landing_point(pw: float) -> Vector2:
	var from:= frog.global_position
	var c1:= (pads[step + 1] as LilyPad).uv_to_global(Vector2.ZERO)
	var d1:= (c1 - from).length()
	var d:= pw * d1 / CENTER_P
	if d <= d1 or step + 2 >= pads.size():
		return from + (c1 - from).normalized() * d
	var c2:= (pads[step + 2] as LilyPad).uv_to_global(Vector2.ZERO)
	return c1 + (c2 - c1).normalized() * (d - d1)


func landing_kind(pt: Vector2) -> String:
	if step + 2 < pads.size():
		var far: LilyPad = pads[step + 2]
		if far.reveal > 0.5 and far.norm_dist(pt) <= 1.15:
			return "skip_center" if far.is_center(pt) else "skip_edge"
	var target: LilyPad = pads[step + 1]
	if target.norm_dist(pt) <= 1.15:
		return "center" if target.is_center(pt) else "edge"
	if (pads[step] as LilyPad).norm_dist(pt) <= 0.9:
		return "stay"
	return "water"


func handle_tap() -> void:
	if in_intro or bloomed:
		return
	if frog.pose == "sleepy":
		frog.set_pose("idle")
	idle_time = 0.0
	_stroke_hit.clear()
	_judge_rhythm()
	taps += 1
	_candy_tap()
	# v90: touching the koi never swallows the tap: the pads still get pushed as usual
	if not _tap_koi(last_tap - layer.global_position):
		_reveal_check(last_tap - layer.global_position)
	if title_box.visible:
		var tw:= create_tween()
		tw.tween_property(title_box, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func (): title_box.visible = false)
	if _shoo_giant(last_tap):
		pass
	elif TARGET_MODE and _press_target(last_tap):
		pass
	elif FLOW_MODE:
		_flow_tap(last_tap)
	elif not _grab_at(last_tap):
		_touch_leaf(last_tap)
	_maybe_quip()
	last_tap = Vector2.INF


const CLEAR_HALF:= 50.0

# ================= v0.31 FLOW MODE =================
# Lily pads drift down toward the dew. Tapping in front of the dew parts the water;
# fast taps open a longer lane (with a little randomness). Stop tapping and, if the lane
# is long enough, a lily pad rises at its end and the dew hops there.
# Red fish rush to where you tap; leave them alone and they sip the dew smaller.
const FLOW_MODE:= true
# v0.34: the game shows the next leaf; press it (it dips), release to land once the way is clear
const TARGET_MODE:= true
# v0.46: the route is fixed (a river pattern). Push the pads near the dew upward; they stay put.
# When the way to the next spot is clear the leaf rises and the dew crosses by itself.
const PUSH_MODE:= true
# v0.47 = the planning doc: tap -> ripple spreads pads; pads drift back over 15 s (a tap while
# returning sends them further out); red fish 1 -> +1 every 10 s, they rock the dew's pad;
# 20 s on one pad -> the pad sinks and the dew is gone.
const SPEC:= true
const RETURN_T:= 15.0
const STAY_LIMIT:= 20.0
const FISH_EVERY_S:= 10.0
const FISH_MAX:= 12
var _stay_t:= 0.0
var _fish_t:= 0.0
var _shake_t:= 0.0
var _stay_hints:= 0
var _sinking:= false
var _emerge_t:= 0.0
var _path_phase:= 0.0
const LANE_HALF:= 34.0
var TARGET_TEX: Texture2D = null
var _target_pressed:= false
var _blocked_hints:= 0
var _emerging:= false
var _lane_clear:= false
var _lane_latched:= false
var _clear_wait:= 0.0
var _wake_pulse:= 0.0
var _water_hints:= 0
# v0.39: fish that join as you travel, and a temporary restart button for testing
const FISH_EVERY:= 3
var followers: Array = []
var _fish_pop:= 0.0
var restart_btn: Button
var photo_btn: Button
var name_btn: Button
var dew_name:= ""          # v115: the player names their dew on the first walk
var _name_panel: Control
var _photo_busy:= false
var video_btn: Button       # v116: a five-second clip
var name_tag: Node2D
var _tag_t:= 0.0
var _tag_a:= 1.0
var _rec:= {}
var _share_btn: Button
var vib_btn: Button
var vib_level:= 2  # 0 off, 1 weak, 2 mid, 3 strong
var _hap_last:= -1000.0
var _hap_busy:= false
var _scatter_retap:= false
const VIB_NAMES:= ["끄기", "약", "중", "강"]
const VIB_MULT:= [0.0, 0.6, 1.0, 1.3]
const HAPTICS:= {
	"tap": [[22, 0.45, 0]],
	"flower": [[30, 0.7, 0]],
	"flower_all": [[70, 1.0, 70], [110, 1.0, 0]],
	"retap": [[22, 0.5, 80], [22, 0.5, 0]],
	"rise": [[10, 0.2, 70], [15, 0.35, 70], [20, 0.5, 0]],
	"land": [[35, 0.7, 100], [18, 0.4, 0]],
	"big_land": [[55, 1.0, 100], [25, 0.55, 0]],
	"fish": [[8, 0.12, 0]],
	"warn": [[20, 0.4, 300], [20, 0.4, 0]],
	"sink": [[80, 0.5, 0]],
	"giant": [[50, 0.35, 0]],
	"reward": [[8, 0.3, 80], [8, 0.3, 80], [8, 0.3, 0]],
}


func _haptic(name: String) -> void:
	if vib_level <= 0 or not HAPTICS.has(name):
		return
	if not name in ["tap", "retap", "flower", "flower_all"]:
		# the phone only answers the player's own touch
		return
	var now:= Time.get_ticks_msec() / 1000.0
	var must:= name in ["land", "big_land", "sink"]
	if now - _hap_last < 0.08 and not must:
		return
	if _hap_busy and name in ["tap", "fish"]:
		return
	_hap_last = now
	_hap_busy = true
	var mult: float = VIB_MULT[vib_level]
	for pulse in HAPTICS[name]:
		var ms: int = int(pulse[0])
		var amp: float = minf(float(pulse[1]) * mult, 1.0)
		Input.vibrate_handheld(ms, amp)
		var gap: int = int(pulse[2])
		if gap > 0 and is_inside_tree():
			await get_tree().create_timer((ms + gap) / 1000.0).timeout
	_hap_busy = false
	_hap_last = Time.get_ticks_msec() / 1000.0


func _cycle_vib() -> void:
	vib_level = (vib_level + 1) % 4
	vib_btn.text = "진동 " + VIB_NAMES[vib_level]
	_save_book()
	_haptic("tap")
var _hint_phase:= -1
var _hint_done:= false
var _hint_counts:= [0, 0, 0]
const PHASE_HINTS:= ["길을 막은 연잎을 톡 두드려 물길을 열어요", "물 위를 톡 두드려 보세요", "떠오른 연잎을 눌렀다 떼 보세요"]


var tutorial_done:= false
var tut_pos:= Vector2.INF   # where the ring pulses (layer space), INF = none
var _tut_t:= 0.0


func _update_tutorial() -> void:
	tut_pos = Vector2.INF
	if tutorial_done or in_intro or frog.jumping or locked or bloomed or autoplay:
		return
	var t:= _target()
	if t == null:
		return
	if step >= 2:
		tutorial_done = true
		_save_book()
		_log("tutorial_done")
		return
	if t.reveal < 0.6 or t.submerged > 0.3:
		var bl:= _blockers(step)
		if bl.size() > 0:
			var best: LilyPad = bl[0]
			for nd in bl:
				if (nd as LilyPad).position.distance_to(t.position) < best.position.distance_to(t.position):
					best = nd
			tut_pos = best.position
		else:
			tut_pos = t.position
	else:
		tut_pos = t.position


func _draw_tutorial() -> void:
	if tut_pos == Vector2.INF:
		return
	var p:= tut_pos   # touch_fx draws in layer space
	var k:= fmod(_tut_t, 1.6) / 1.6
	touch_fx.draw_circle(p, 10.0, Color(1.0, 0.98, 0.86, 0.55))
	touch_fx.draw_arc(p, 14.0 + 34.0 * k, 0, TAU, 48, Color(1.0, 0.97, 0.8, 0.7 * (1.0 - k)), 2.0, true)
	var k2:= fmod(_tut_t + 0.8, 1.6) / 1.6
	touch_fx.draw_arc(p, 14.0 + 34.0 * k2, 0, TAU, 48, Color(1.0, 0.97, 0.8, 0.5 * (1.0 - k2)), 1.4, true)


func _update_phase_hint() -> void:
	if frog.jumping or locked or bloomed or in_intro:
		return
	var t:= _target()
	if t == null:
		return
	var ph:= 2
	if t.reveal < 0.6 or t.submerged > 0.3:
		ph = 0
	if ph != _hint_phase:
		_hint_phase = ph
		_hint_done = false
	if _hint_done or _hint_counts[ph] >= 2 or _idle_tap < (0.6 if not tutorial_done else 2.5) or (PUSH_MODE and ph != 0):
		return
	_hint_done = true
	_hint_counts[ph] += 1
	_show_quip(PHASE_HINTS[ph])
var _dance_t:= 0.0
const FLOW_DRIFT:= 17.0
const OPEN_MIN:= 90.0
const OPEN_MAX:= 380.0
const OPEN_HALF:= 44.0
const DEW_MIN:= 0.42
const DEW_REST:= 0.62   # v114: smallest the dew gets in healing mode
const DEW_MAX:= 1.4
var open_len:= 0.0
var open_dir:= Vector2.UP
var _open_shown:= 0.0
var _last_tap_t:= -10.0
var _idle_tap:= 9.0
var _committed:= false
var _flow_time:= 0.0
var dew_size:= 1.0
var _nibble_fx:= 0.0
var _nibble_warned:= false
var _dew_gone_flag:= false
var _tap_marks: Array = []
var _ready_ping:= false


func _flow_reset_hints() -> void:
	_hint_phase = -1
	_hint_done = false
	_hint_counts = [0, 0, 0]


func _flow_reset() -> void:
	_flow_reset_hints()
	_stay_t = 0.0
	_fish_t = 0.0
	_stay_hints = 0
	_sinking = false
	followers.clear()
	_fish_pop = 0.0
	var hr: int = Time.get_datetime_dict_from_system().hour
	if hr < 4:
		get_tree().create_timer(3.0).timeout.connect(_unlock.bind("night"))
	_clean_steps = 0
	_sipped_since_land = false
	_treasure_cd = 12.0
	open_len = 0.0
	_open_shown = 0.0
	open_dir = Vector2.UP
	_committed = false
	_idle_tap = 0.0
	dew_size = 1.0
	_nibble_warned = false
	_dew_gone_flag = false
	_ready_ping = false
	_tap_marks.clear()
	seg_open.clear()
	if pads.size() > 1:
		(pads[1] as LilyPad).reveal = 0.0
		(pads[1] as LilyPad).set_target(false)
	for i in range(2, pads.size()):
		(pads[i] as LilyPad).reveal = 0.0
	if TARGET_MODE:
		for pp in pads:
			(pp as LilyPad).custom_tex = TARGET_TEX
		(pads[0] as LilyPad).z_index = 3
		_raise_target()
	frog.size_k = 1.0
	for f in small_fish:
		if is_instance_valid(f):
			(f as Koi).kind = ""
			(f as Koi).blue = false
			(f as Koi).yellow = false


func _flow_origin() -> Vector2:
	return (pads[step] as LilyPad).position


func _flow_tap(screen_pt: Vector2) -> void:
	if screen_pt == Vector2.INF:
		return
	var local:= screen_pt - layer.global_position
	var origin:= _flow_origin()
	var rel:= local - origin
	_idle_tap = 0.0
	if SPEC and _pick_flower(local):
		return
	_tap_marks.append({ "p": local, "t": 0.0})
	if _tap_marks.size() > 8:
		_tap_marks.pop_front()
	if not SPEC:
		# red fish rush to the finger
		for f in small_fish + followers:
			if is_instance_valid(f):
				var k:= f as Koi
				k.dash(local + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(10.0, 40.0), 1.3)
				k.orbit_r = 22.0 + _rng.randf() * 26.0
	_spawn_ripple(local, 1.0, 2)
	if SPEC:
		_spec_scatter(local, 169.0)
	elif PUSH_MODE:
		_push_tap(local)
	else:
		_scatter_ring(local, 130.0)
	dew_size = minf(dew_size + 0.012, DEW_MAX)
	_on_tap_book(screen_pt)
	if _try_treasure(local):
		return
	if TARGET_MODE:
		if not PUSH_MODE and not (locked or frog.jumping or bloomed) and _on_open_water(local):
			_try_place_target(local)
		var tempo_t:= clampf((0.5 - (_flow_time - _last_tap_t)) / 0.36, 0.0, 1.0)
		_last_tap_t = _flow_time
		var beat_t:= _beat_distance(song_t) <= 0.12
		_play("nudge", _rng.randf_range(0.95, 1.15), -10.0)
		if beat_t:
			pass
		_spawn_drops(screen_pt, 1 + (1 if tempo_t > 0.6 else 0) + (1 if beat_t else 0))
		return
	var can_open:= not (locked or frog.jumping or _committed or bloomed)
	if not can_open:
		return
	if rel.y > -10.0 or rel.length() > 430.0:
		# behind / beside the dew: fish come, but the lane does not grow
		_play("plop", 1.6, -16.0)
		return
	var now:= _flow_time
	var gap:= now - _last_tap_t
	_last_tap_t = now
	var tempo:= clampf((0.5 - gap) / 0.36, 0.0, 1.0)
	var gain:= (18.0 + 40.0 * tempo) * _rng.randf_range(0.6, 1.4)
	var on_beat:= _beat_distance(song_t) <= 0.12
	if on_beat:
		gain *= 1.3
	# steer: the lane leans toward where you tap
	var want:= rel.normalized()
	var ang:= clampf(Vector2.UP.angle_to(want), -0.8, 0.8)
	var tip_x:= origin.x + sin(ang) * maxf(open_len, 160.0)
	if tip_x < 70.0 or tip_x > 290.0:
		ang *= 0.4
	open_dir = open_dir.slerp(Vector2.UP.rotated(ang), 0.45 if open_len < 40.0 else 0.18).normalized()
	open_len = minf(open_len + gain, OPEN_MAX)
	var pitch:= 0.85 + 0.5 * (open_len / OPEN_MAX) + _rng.randf_range(-0.03, 0.03)
	_play("nudge", pitch, -9.0)
	if tempo > 0.75:
		flies.burst(screen_pt, 3, false)
	if on_beat:
		pass
	_spawn_drops(screen_pt, 1 + (1 if tempo > 0.6 else 0) + (1 if on_beat else 0))
	if open_len >= OPEN_MIN and not _ready_ping:
		_ready_ping = true
		_play("sparkle", 1.4, -12.0)
	if open_len >= OPEN_MAX:
		_flow_commit()


func _update_flow(delta: float) -> void:
	_flow_time += delta
	_tut_t += delta
	_update_drops(delta)
	_update_treasure(delta)
	for m in _tap_marks:
		m.t += delta
	while not _tap_marks.is_empty() and _tap_marks[0].t > 0.3:
		_tap_marks.pop_front()
	if in_intro or bloomed or pads.size() <= step + 1:
		return
	if not (_committed or frog.jumping or locked):
		_idle_tap += delta
	var origin:= _flow_origin()
	var top:= -layer.position.y
	var bottom:= top + vs.y
	var dew_pad: LilyPad = pads[step]
	var nxt: LilyPad = pads[step + 1]
	var nrm:= Vector2(-open_dir.y, open_dir.x)
	var lane:= _open_shown
	# lane breathes toward the opened length
	_open_shown = lerpf(_open_shown, open_len, clampf(delta * 10.0, 0.0, 1.0))
	_dance_t = maxf(_dance_t - delta, 0.0)
	if PUSH_MODE and not frog.jumping and not locked and not bloomed:
		if not _emerging and nxt.reveal > 0.7 and _target_blockers().is_empty():
			_emerge_target()
			_emerge_t = 0.0
		elif _emerging:
			_emerge_t += delta
			if _emerge_t > 0.85 and nxt.submerged < 0.1:
				_release_target()
	if TARGET_MODE:
		var was:= _lane_clear
		_lane_clear = false
		if _lane_clear:
			_clear_wait += delta
			_wake_pulse -= delta
			if _wake_pulse <= 0.0:
				# the sleeping leaf stirs under the water
				_wake_pulse = 1.3
				_spawn_ripple(nxt.position, 0.7, 1)
		elif was:
			_clear_wait = 0.0
		_update_phase_hint()
		_update_tutorial()
	if not _committed and not TARGET_MODE:
		if _idle_tap > 0.45 and open_len >= OPEN_MIN and not locked and not frog.jumping:
			_flow_commit()
		elif _idle_tap > 0.35:
			open_len = maxf(open_len - 85.0 * delta, 0.0)
			if open_len < OPEN_MIN:
				_ready_ping = false
	# ---- leaves drift down, part around pads, keep out of the lane ----
	var drop: Array = []
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or nd.held or nd.rest == Vector2.INF:
			continue
		var r:= nd.rx()
		var rp:= nd.rest
		if SPEC and not c.has("out"):
			c.out = c.home
			c.rt = 99.0
		if SPEC and (nd.get_instance_id() + Engine.get_process_frames()) % 6 == 0:
			# pads along both banks are anchored and keep the river's outline; only the middle stays loose
			nd.fixed_bank = absf((c.home as Vector2).x - _path_x_at((c.home as Vector2).y)) > BANK_FREE
		if rp.y > top - 260.0 and rp.y < bottom + 120.0 and not nd.fixed_bank:
			var dv:= Vector2(0.0, FLOW_DRIFT * delta)
			if SPEC:
				# loose pads ride the stream: they follow the river's bends on their way down
				dv.x = _path_x_at(rp.y + dv.y) - _path_x_at(rp.y)
			rp += dv
			if TARGET_MODE:
				c.home += dv
			if SPEC:
				c.out += dv
		if SPEC:
			if float(c.rt) < RETURN_T:
				c.rt = float(c.rt) + delta
				var q:= clampf(float(c.rt) / RETURN_T, 0.0, 1.0)
				rp = (c.out as Vector2).lerp(c.home, q * q * (3.0 - 2.0 * q))
			else:
				rp = c.home
				c.out = c.home
		if rp.y > bottom + r + 60.0:
			if crowd.size() - drop.size() > (115 if TARGET_MODE else 90):
				drop.append(c)
				continue
			# recycle to the top of the screen
			rp = Vector2(_rng.randf_range(-30.0, 390.0), top - r - _rng.randf_range(20.0, 140.0))
			if SPEC:
				# keep the balance: loose pads come back into the stream, bank pads onto a bank
				var cx:= _path_x_at(rp.y)
				if nd.fixed_bank:
					var side:= 1.0 if _rng.randf() < 0.5 else -1.0
					if cx + side * (BANK_FREE + 20.0) < -30.0 or cx + side * (BANK_FREE + 20.0) > 430.0:
						side = -side
					rp.x = clampf(cx + side * _rng.randf_range(BANK_FREE + 20.0, BANK_FREE + 200.0), -40.0, 440.0)
				else:
					rp.x = cx + _rng.randf_range(-BANK_FREE + 20.0, BANK_FREE - 20.0)
			nd.position = rp
			nd.vel = Vector2.ZERO
			nd.lit = 0.0
			nd.treasure = false
			_maybe_flower(nd)
			c.hidden = false
			c.home = rp
			if SPEC:
				c.out = rp
				c.rt = 99.0
		var base_rp:= rp
		if SPEC and not open_segs.is_empty() and (nd.get_instance_id() + Engine.get_process_frames()) % 3 == 0:
			# the river the dew has travelled stays open: pads whose resting place is in it move out for good
			var hm0: Vector2 = c.home
			var hc0:= _channel_clear(hm0, r, nd.bank)
			if hc0.distance_to(hm0) > 1.0:
				rp += hc0 - hm0
		if TARGET_MODE and not PUSH_MODE and (nd.get_instance_id() + Engine.get_process_frames()) % 3 == 0:
			var hm: Vector2 = c.home
			if not open_segs.is_empty():
				var hc:= _channel_clear(hm, r, nd.bank)
				if hc.distance_to(hm) > 1.0:
					c.home = hc
					hm = hc
			# scattered pads drift slowly back to fill the pond again
			rp = rp.lerp(hm, clampf(delta * 3.0 * 0.45, 0.0, 1.0))
		# flow around the dew's pad (and the next pad once it is up)
		for pd: LilyPad in [dew_pad, nxt]:
			if pd == nxt and (nxt.reveal < 0.5 or nxt.submerged > 0.5):
				continue
			var dv:= rp - pd.position
			var lim:= pd.rx() + r * 0.85
			if TARGET_MODE and pd == nxt:
				lim = pd.rx() + r * 1.05
			if dv.length() < lim:
				var sx:= signf(dv.x) if absf(dv.x) > 2.0 else (1.0 if nd.get_instance_id() % 2 == 0 else -1.0)
				var kk:= clampf(delta * (10.0 if TARGET_MODE else 6.0), 0.0, 1.0)
				if TARGET_MODE:
					rp += dv.normalized() * (lim - dv.length()) * kk + Vector2(sx * 14.0 * delta, 0.0)
				else:
					rp.x += sx * (lim - dv.length()) * kk + sx * 8.0 * delta
		# once the leaf has risen, keep the way to it open
		if TARGET_MODE and (_lane_latched or (_emerging and nxt.submerged <= 0.5)):
			var rel2:= rp - origin
			var ab2:= (nxt.position - origin)
			var L2:= ab2.length()
			if L2 > 1.0:
				var dir2:= ab2 / L2
				var n2:= Vector2(-dir2.y, dir2.x)
				var t2:= rel2.dot(dir2)
				var lat2:= rel2.dot(n2)
				var need2:= LANE_HALF + r * 0.55
				if t2 > 0.0 and t2 < L2 and absf(lat2) < need2:
					var sd:= signf(lat2) if absf(lat2) > 1.0 else (1.0 if nd.get_instance_id() % 2 == 0 else -1.0)
					rp += n2 * sd * (need2 - absf(lat2)) * clampf(delta * 6.0, 0.0, 1.0)
		# the opened lane
		if lane > 6.0:
			var rel:= rp - origin
			var t:= rel.dot(open_dir)
			var lat:= rel.dot(nrm)
			var need:= OPEN_HALF + r * 0.55
			if t > -10.0 and t < lane + r * 0.35 and absf(lat) < need:
				var side:= signf(lat) if absf(lat) > 1.0 else (1.0 if nd.get_instance_id() % 2 == 0 else -1.0)
				var k:= clampf(delta * 9.0, 0.0, 1.0)
				rp += nrm * side * (need - absf(lat)) * k
				if absf(lat) < need * 0.6 and nd.hit_t <= 0.0:
					nd.vel += nrm * side * 60.0
					nd.hit_t = 0.2
		if SPEC:
			# lasting nudges (river, flowing round pads, kept-open lane) move the whole return path
			var adj:= rp - base_rp
			if adj.length() > 0.001:
				c.home += adj
				c.out += adj
		nd.rest = rp
	for c in drop:
		crowd.erase(c)
		(c.node as Node).queue_free()
	# ---- red fish: rush the finger, or sip the dew when left alone ----
	var dew_local:= frog.global_position - layer.global_position
	var nibblers:= 0
	_update_followers(delta, dew_local, top, bottom)
	_update_descender(delta)
	for f in small_fish:
		if not is_instance_valid(f):
			continue
		var kf:= f as Koi
		var off_screen:= kf.position.y < top - 40.0 or kf.position.y > bottom + 40.0 or kf.position.x < -40.0 or kf.position.x > vs.x + 40.0
		if off_screen and kf.position.distance_to(dew_local) > 260.0:
			var sx:= -30.0 if _rng.randf() < 0.5 else vs.x + 30.0
			kf.position = Vector2(sx, clampf(dew_local.y + _rng.randf_range(-120.0, 80.0), top + 40.0, bottom - 40.0))
		if not SPEC and _idle_tap > 1.3 and not frog.jumping and _dance_t <= 0.0 and step >= 2 and not (_descender != null and is_instance_valid(_descender) and _descender.blocking):
			var to:= dew_local - kf.position
			if to.length() > 26.0:
				kf.position += to.normalized() * 95.0 * delta
	var giant_here:= _descender != null and is_instance_valid(_descender) and _descender.blocking
	if SPEC:
		_update_spec(delta, dew_local, top, bottom)
	if not SPEC and _idle_tap > 1.3 and not frog.jumping and not _dew_gone_flag and _dance_t <= 0.0 and step >= 2 and not giant_here:
		for f in small_fish:
			if not is_instance_valid(f):
				continue
			var k:= f as Koi
			if k.mode != "orbit" or k.orbit_c.distance_to(dew_local) > 4.0 or k.orbit_node != null:
				k.orbit(dew_local, 15.0 + _rng.randf() * 8.0, 9999.0)
				k.orbit_node = null
				k.boost_t = 1.2
			k.orbit_c = dew_local
			if k.position.distance_to(dew_local) < 48.0:
				nibblers += 1
	if nibblers > 0:
		_sipped_since_land = true
		dew_size = maxf(dew_size - 0.011 * mini(nibblers, 5) * delta, DEW_REST)   # v114: gentle, never to nothing
		_nibble_fx -= delta
		if _nibble_fx <= 0.0:
			_nibble_fx = _rng.randf_range(0.35, 0.6)
			frog.jelly_v += _rng.randf_range(-3.0, 3.0)
			_spawn_ripple(dew_local + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-6, 6)), 0.35, 1)
			_play("plop", _rng.randf_range(1.0, 1.15), -24.0)   # v114: soft drip, not a high pop
		if dew_size < 0.68 and not _nibble_warned:
			_nibble_warned = true
			_show_quip("물고기들이 이슬과 놀고 싶나 봐요")
	if dew_size > 0.8:
		_nibble_warned = false
	dew_size = clampf(dew_size, 0.0, DEW_MAX)
	frog.size_k = lerpf(frog.size_k, dew_size, clampf(delta * 5.0, 0.0, 1.0))
	# v114 healing mode: the dew never disappears; it just stays small until it moves again


# a tap's ripple pushes every leaf inside it outward, strongest at the centre
func _scatter_ring(at: Vector2, radius: float) -> void:
	var weak:= 1.0
	if _descender and is_instance_valid(_descender) and _descender.blocking and at.distance_to(_descender.position) < _giant_body_r() * 1.6:
		weak = 0.5
	radius *= weak
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or nd.held or nd.rest == Vector2.INF:
			continue
		var d:= nd.position - at
		var reach:= radius + nd.rx() * 0.5
		if d.length() >= reach:
			continue
		var dir:= d.normalized() if d.length() > 1.0 else Vector2.from_angle(_rng.randf() * TAU)
		var k:= 1.0 - d.length() / reach
		nd.rest += dir * (36.0 + 70.0 * k) * weak
		nd.vel += dir * (140.0 + 260.0 * k) * weak
		nd.hit_t = maxf(nd.hit_t, 0.35)
		nd.tilt_axis = dir.angle() + PI * 0.5
		nd._tilt_wob = maxf(nd._tilt_wob, 0.6 * k)


# ================= v0.33: moon drops, treasure leaves, pond book =================
var drops:= 0
var drops_total:= 0
var far_jumps:= 0
var giant_seen:= 0
var corner_taps:= 0
var _clean_steps:= 0
var _sipped_since_land:= false
var unlocked: Dictionary = {}
var _drops: Array = []
var drops_fx: Node2D
var drops_label: Label
var _drops_pop:= 0.0
var _treasure_cd:= 12.0
var book_btn: Button
var book_panel: Control
var book_list: VBoxContainer
const BOOK:= [
	{ "id": "red", "name": "빨간 송사리", "hint": "처음부터 연못에 살아요", "fish": "red"},
	{ "id": "blue", "name": "파란 송사리", "hint": "빨간 물고기 8마리와 함께하기", "fish": "blue"},
	{ "id": "yellow", "name": "노랑 송사리", "hint": "한 번에 멀리 뛰기 5번", "fish": "yellow"},
	{ "id": "white", "name": "하얀 송사리", "hint": "박자에 맞춰 20번 연속 두드리기", "fish": "white"},
	{ "id": "orange", "name": "주황 송사리", "hint": "보물 연잎 5번 열기", "fish": "orange"},
	{ "id": "stripe", "name": "줄무늬 송사리", "hint": "달빛 방울 500개 모으기", "fish": "stripe"},
	{ "id": "night", "name": "밤 반딧불", "hint": "자정부터 새벽 4시 사이에 연못 들르기", "fish": ""},
	{ "id": "corner", "name": "수줍은 올챙이", "hint": "…화면 왼쪽 위 구석을 자꾸 두드리면?", "fish": ""},
	{ "id": "far", "name": "달빛 연꽃", "hint": "한 판에 연잎 25칸 건너기", "fish": ""},
]


func _spawn_drops(screen_pt: Vector2, n: int) -> void:
	for i in n:
		_drops.append({
			"p": screen_pt + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-8, 8)),
			"v": Vector2(_rng.randf_range(-70, 70), _rng.randf_range(-170, -110)),
			"t": -0.05 * i,
			"r": _rng.randf_range(1.6, 2.3),   # v81: half size
		})


func _draw_fish_count() -> void:
	var c:= Vector2(30, 152)
	var s:= 1.0 + 0.3 * _fish_pop
	var col:= Color(0.95, 0.25, 0.12, 0.95)
	# a little koi icon
	var body:= PackedVector2Array()
	for k in 12:
		var a:= TAU * k / 12.0
		body.append(c + Vector2(cos(a) * 9.0, sin(a) * 4.2) * s)
	drops_fx.draw_colored_polygon(body, col)
	drops_fx.draw_colored_polygon(PackedVector2Array([c + Vector2(7, 0) * s, c + Vector2(14, -5) * s, c + Vector2(14, 5) * s]), col)
	drops_fx.draw_circle(c + Vector2(-5, -1) * s, 1.1 * s, Color(1, 1, 1, 0.9))
	# blossoms gathered so far: little dots that fill up
	for q in FLOWER_GOAL:
		var fc:= Vector2(26.0 + 13.0 * q, 174.0)
		if q < _flower_count:
			drops_fx.draw_circle(fc, 4.6, Color(1.0, 0.45, 0.36, 0.95))
			drops_fx.draw_circle(fc, 1.6, Color(1.0, 0.92, 0.7, 0.95))
		else:
			drops_fx.draw_arc(fc, 4.2, 0, TAU, 20, Color(1.0, 0.95, 0.9, 0.35), 1.2, true)
	if drops_fx.has_meta("fish_label") == false:
		var fl:= _label("0", 15, Color(1.0, 0.93, 0.88, 0.95))
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		fl.size = Vector2(90, 22)
		fl.position = Vector2(48, 141)
		fl.pivot_offset = Vector2(0, 11)
		drops_label.get_parent().add_child(fl)
		drops_fx.set_meta("fish_label", fl)
	var lab: Label = drops_fx.get_meta("fish_label")
	lab.text = "× %d" % (small_fish.size() if SPEC else followers.size())
	lab.scale = Vector2.ONE * (1.0 + 0.2 * _fish_pop)


func _collect_fish() -> void:
	var f:= Koi.new()
	f.z_index = -1 if TARGET_MODE else 1
	var dew_local:= frog.global_position - layer.global_position
	var from_side:= -40.0 if _rng.randf() < 0.5 else vs.x + 40.0
	f.setup(Vector2(from_side, dew_local.y + _rng.randf_range(-60.0, 60.0)), _rng.randi())
	f.patch = 0
	f.length = _rng.randf_range(28.0, 36.0)
	f.speed = _rng.randf_range(60.0, 75.0)
	# mostly red, now and then one of the colours found in the book
	var extra: Array = []
	for b in BOOK:
		if b.fish != "" and b.id != "red" and unlocked.get(b.id, false):
			extra.append(b.fish)
	if not extra.is_empty() and _rng.randf() < 0.3:
		var kd: String = extra[_rng.randi() % extra.size()]
		pass  # small fish stay red (art direction)
	layer.add_child(f)
	kois.append(f)
	followers.append(f)
	f.dash(dew_local + Vector2.from_angle(_rng.randf() * TAU) * 60.0, 1.5)
	_fish_pop = 1.0
	_banner("물고기 친구가 함께해요 · %d마리" % followers.size(), Color(1.0, 0.88, 0.82))
	_play("sparkle", 1.3, -12.0)
	_log("fish_joined n=%d" % followers.size())


func _update_followers(delta: float, dew_local: Vector2, top: float, bottom: float) -> void:
	_fish_pop = maxf(_fish_pop - delta * 2.5, 0.0)
	var i:= 0
	for f in followers:
		if not is_instance_valid(f):
			continue
		var k:= f as Koi
		var off_screen:= k.position.y < top - 40.0 or k.position.y > bottom + 40.0 or k.position.x < -40.0 or k.position.x > vs.x + 40.0
		if off_screen and k.position.distance_to(dew_local) > 260.0:
			k.position = Vector2(-30.0 if i % 2 == 0 else vs.x + 30.0, clampf(dew_local.y + 40.0, top + 40.0, bottom - 40.0))
		if _dance_t <= 0.0 and (k.mode == "wander" or (k.mode == "orbit" and k.mode_t > 1000.0)):
			if k.mode != "orbit":
				k.orbit(dew_local, 62.0 + 10.0 * (i % 4), 99999.0)
			k.orbit_c = dew_local
			# swim straight back to the dew when far away
			var to:= dew_local - k.position
			if to.length() > 105.0:
				k.position += to.normalized() * 120.0 * delta
		i += 1


func _drops_target() -> Vector2:
	return Vector2(30, 122)


func _update_drops(delta: float) -> void:
	_drops_pop = maxf(_drops_pop - delta * 3.0, 0.0)
	if _drops.is_empty():
		if drops_fx:
			drops_fx.queue_redraw()
		return
	var keep: Array = []
	var tgt:= _drops_target()
	for d in _drops:
		d.t += delta
		if d.t < 0.0:
			keep.append(d)
			continue
		if d.t < 0.45:
			d.v = (d.v as Vector2) * (1.0 - 2.2 * delta)
			d.p += d.v * delta
		else:
			var to: Vector2 = tgt - d.p
			var sp: float = 260.0 + 900.0 * (float(d.t) - 0.45)
			if to.length() < sp * delta + 6.0:
				drops += 1
				drops_total += 1
				_drops_pop = 1.0
				if drops % 4 == 0:
					_play("sparkle", _rng.randf_range(1.7, 1.9), -22.0)
				continue
			d.p += to.normalized() * sp * delta
		keep.append(d)
	_drops = keep
	if drops_label:
		drops_label.text = str(drops)
		drops_label.scale = Vector2.ONE * (1.0 + 0.18 * _drops_pop)
	if drops_fx:
		drops_fx.queue_redraw()
	if drops_total >= 500:
		_unlock("stripe")


func _draw_drops() -> void:
	_draw_fish_count()
	var tgt:= _drops_target()
	# counter icon
	var ir:= 7.0 + 2.0 * _drops_pop
	drops_fx.draw_circle(tgt, ir + 5.0, Color(1.0, 0.95, 0.75, 0.12 + 0.2 * _drops_pop))
	drops_fx.draw_circle(tgt, ir, Color(1.0, 0.97, 0.85, 0.9))
	drops_fx.draw_circle(tgt + Vector2(-2, -2), ir * 0.35, Color(1, 1, 1, 0.9))
	for d in _drops:
		if d.t < 0.0:
			continue
		var p: Vector2 = d.p
		var r: float = d.r
		drops_fx.draw_circle(p, r * 2.4, Color(1.0, 0.95, 0.7, 0.12))
		drops_fx.draw_circle(p, r, Color(1.0, 0.98, 0.86, 0.95))
		drops_fx.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.95))


# ---- treasure leaf: a golden pad drifts down now and then ----
func _update_treasure(delta: float) -> void:
	if in_intro or bloomed:
		return
	_treasure_cd -= delta
	if _treasure_cd > 0.0:
		return
	_treasure_cd = _rng.randf_range(16.0, 26.0)
	var top:= -layer.position.y
	var cands: Array = []
	for c in crowd:
		var nd: LilyPad = c.node
		if is_instance_valid(nd) and not nd.treasure and nd.position.y > top + 60.0 and nd.position.y < top + vs.y * 0.45 and nd.position.x > 40.0 and nd.position.x < 320.0:
			cands.append(nd)
	if cands.is_empty():
		_treasure_cd = 3.0
		return
	var pick: LilyPad = cands[_rng.randi() % cands.size()]
	pick.treasure = true
	_play("sparkle", 1.2, -14.0)
	_log("treasure_leaf")


func _try_treasure(local: Vector2) -> bool:
	for c in crowd:
		var nd: LilyPad = c.node
		if is_instance_valid(nd) and nd.treasure and nd.position.distance_to(local) < nd.rx() * 1.1:
			nd.treasure = false
			nd.cleared_glow = 1.0
			var sp:= nd.position + layer.global_position
			_spawn_drops(sp, 15)
			flies.burst(sp, 16, true)
			_spawn_ripple(nd.position, 1.3, 3)
			_play("bloom", 1.4, -8.0)
			_float_text("보물 연잎!", sp + Vector2(0, -34), Color(1.0, 0.94, 0.7))
			_haptic("reward")
			giant_seen += 1
			_check_book()
			_log("treasure_taken")
			return true
	return false


# ---- pond book ----
func _on_tap_book(screen_pt: Vector2) -> void:
	if screen_pt.x < vs.x * 0.2 and screen_pt.y < vs.y * 0.13:
		corner_taps += 1
		if corner_taps >= 40:
			_unlock("corner")


func _check_book() -> void:
	if (SPEC and small_fish.size() >= 8) or (not SPEC and _clean_steps >= 8):
		_unlock("blue")
	if far_jumps >= 5:
		_unlock("yellow")
	if best_combo >= 20:
		_unlock("white")
	if giant_seen >= 5:
		_unlock("orange")
	if step >= 25:
		_unlock("far")
	_save_book()


func _unlock(id: String) -> void:
	if unlocked.get(id, false):
		return
	unlocked[id] = true
	var e: Dictionary = {}
	for b in BOOK:
		if b.id == id:
			e = b
	_save_book()
	_log("unlock %s" % id)
	if e.is_empty():
		return
	_banner("새 친구가 왔어요 · %s" % e.name, Color(1.0, 0.95, 0.8))
	_haptic("reward")
	_play("bloom", 1.2, -10.0)
	flies.burst(frog.global_position + Vector2(0, -40), 14, true)
	if e.fish != "":
		_add_book_fish(e.fish, frog.position + Vector2(_rng.randf_range(-60, 60), 40))
	if book_btn:
		var tw:= create_tween()
		tw.tween_property(book_btn, "scale", Vector2(1.25, 1.25), 0.15)
		tw.tween_property(book_btn, "scale", Vector2.ONE, 0.3)
	_refresh_book()


func _add_book_fish(kind: String, at: Vector2) -> void:
	var f:= Koi.new()
	f.z_index = -1 if TARGET_MODE else 1
	f.setup(at, _rng.randi())
	f.patch = 0
	f.length = _rng.randf_range(30.0, 36.0)
	f.speed = _rng.randf_range(55.0, 72.0)
	f.blue = false
	f.yellow = false
	f.kind = ""  # small fish stay red (art direction)
	layer.add_child(f)
	kois.append(f)
	small_fish.append(f)


func _book_extra_fish() -> void:
	for b in BOOK:
		if b.fish != "" and b.id != "red" and unlocked.get(b.id, false):
			_add_book_fish(b.fish, (pads[0] as LilyPad).position + Vector2(_rng.randf_range(-80, 80), _rng.randf_range(-40, 60)))


func _save_book() -> void:
	var cf:= ConfigFile.new()
	cf.load("user://moonlit_pond.cfg")
	cf.set_value("score", "best", best)
	cf.set_value("book", "unlocked", unlocked.keys())
	cf.set_value("book", "drops_total", drops_total)
	cf.set_value("book", "drops", drops)
	cf.set_value("book", "far_jumps", far_jumps)
	cf.set_value("book", "giant_seen", giant_seen)
	cf.set_value("book", "corner_taps", corner_taps)
	cf.set_value("book", "tutorial_done", tutorial_done)
	cf.set_value("book", "dew_name", dew_name)
	cf.set_value("settings", "vibration", vib_level)
	cf.save("user://moonlit_pond.cfg")


func _load_book() -> void:
	var cf:= ConfigFile.new()
	if cf.load("user://moonlit_pond.cfg") != OK:
		unlocked["red"] = true
		return
	for k in cf.get_value("book", "unlocked", []):
		unlocked[str(k)] = true
	unlocked["red"] = true
	drops_total = int(cf.get_value("book", "drops_total", 0))
	drops = int(cf.get_value("book", "drops", 0))
	far_jumps = int(cf.get_value("book", "far_jumps", 0))
	giant_seen = int(cf.get_value("book", "giant_seen", 0))
	corner_taps = int(cf.get_value("book", "corner_taps", 0))
	tutorial_done = bool(cf.get_value("book", "tutorial_done", false))
	dew_name = str(cf.get_value("book", "dew_name", ""))
	vib_level = clampi(int(cf.get_value("settings", "vibration", 2)), 0, 3)


func _build_book_ui(root: Control) -> void:
	drops_fx = Node2D.new()
	drops_fx.z_index = 9
	drops_fx.draw.connect(_draw_drops)
	ui.add_child(drops_fx)
	drops_label = _label("0", 15, Color(1.0, 0.97, 0.88, 0.95))
	drops_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	drops_label.size = Vector2(90, 22)
	drops_label.position = Vector2(44, 111)
	drops_label.pivot_offset = Vector2(0, 11)
	root.add_child(drops_label)
	book_btn = Button.new()
	book_btn.text = "도감"
	book_btn.focus_mode = Control.FOCUS_NONE
	book_btn.add_theme_font_override("font", font)
	book_btn.add_theme_font_size_override("font_size", 13)
	book_btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	for st in ["normal", "hover", "pressed"]:
		var sb:= StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.14, 0.1, 0.45 if st != "pressed" else 0.65)
		sb.set_corner_radius_all(16)
		sb.border_color = Color(1.0, 0.97, 0.85, 0.35)
		sb.set_border_width_all(1)
		book_btn.add_theme_stylebox_override(st, sb)
	book_btn.size = Vector2(52, 32)
	book_btn.pivot_offset = Vector2(26, 16)
	book_btn.pressed.connect(_toggle_book)
	root.add_child(book_btn)
	restart_btn = Button.new()
	restart_btn.text = "재시작"
	restart_btn.focus_mode = Control.FOCUS_NONE
	restart_btn.add_theme_font_override("font", font)
	restart_btn.add_theme_font_size_override("font_size", 12)
	restart_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9))
	for st in ["normal", "hover", "pressed"]:
		var sb2:= StyleBoxFlat.new()
		sb2.bg_color = Color(0.25, 0.06, 0.06, 0.45 if st != "pressed" else 0.7)
		sb2.set_corner_radius_all(14)
		sb2.border_color = Color(1.0, 0.85, 0.8, 0.35)
		sb2.set_border_width_all(1)
		restart_btn.add_theme_stylebox_override(st, sb2)
	restart_btn.size = Vector2(58, 30)
	restart_btn.pressed.connect(_restart_now)
	root.add_child(restart_btn)
	vib_btn = Button.new()
	vib_btn.text = "진동 " + VIB_NAMES[vib_level]
	vib_btn.focus_mode = Control.FOCUS_NONE
	vib_btn.add_theme_font_override("font", font)
	vib_btn.add_theme_font_size_override("font_size", 11)
	vib_btn.add_theme_color_override("font_color", Color(0.92, 1.0, 0.96))
	for st in ["normal", "hover", "pressed"]:
		var sb3:= StyleBoxFlat.new()
		sb3.bg_color = Color(0.04, 0.16, 0.14, 0.45 if st != "pressed" else 0.7)
		sb3.set_corner_radius_all(14)
		sb3.border_color = Color(0.8, 1.0, 0.92, 0.3)
		sb3.set_border_width_all(1)
		vib_btn.add_theme_stylebox_override(st, sb3)
	vib_btn.size = Vector2(58, 28)
	vib_btn.pressed.connect(_cycle_vib)
	root.add_child(vib_btn)
	photo_btn = _pill_button("사진", Vector2(52, 32), Color(0.03, 0.14, 0.1))
	photo_btn.pressed.connect(_take_photo)
	root.add_child(photo_btn)
	video_btn = _pill_button("영상", Vector2(52, 32), Color(0.03, 0.14, 0.1))
	video_btn.pressed.connect(_start_video)
	video_btn.visible = not OS.has_feature("web")
	root.add_child(video_btn)
	name_btn = Button.new()
	name_btn.flat = true
	name_btn.focus_mode = Control.FOCUS_NONE
	name_btn.size = Vector2(220, 26)
	name_btn.pressed.connect(_ask_dew_name)
	root.add_child(name_btn)
	book_panel = PanelContainer.new()
	var psb:= StyleBoxFlat.new()
	psb.bg_color = Color(0.02, 0.09, 0.08, 0.88)
	psb.set_corner_radius_all(18)
	psb.set_content_margin_all(18)
	book_panel.add_theme_stylebox_override("panel", psb)
	book_panel.visible = false
	book_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	book_panel.gui_input.connect(func (ev):
		if ev is InputEventMouseButton and ev.pressed:
			_toggle_book())
	book_list = VBoxContainer.new()
	book_list.add_theme_constant_override("separation", 7)
	book_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_panel.add_child(book_list)
	root.add_child(book_panel)


func _restart_now() -> void:
	# temporary test button: back to the very first intro screen
	_log("restart_button")
	if FLOW_MODE:
		_save_book()
	if restart_btn:
		restart_btn.disabled = true
	Intro.quick = false   # v111: restart plays the whole intro again (was: jump to the title)
	var tw:= create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.3)
	await tw.finished
	get_tree().reload_current_scene()


func _toggle_book() -> void:
	book_panel.visible = not book_panel.visible
	if book_panel.visible:
		_refresh_book()
		book_panel.size = Vector2(vs.x - 40, 0)
		book_panel.position = Vector2(20, vs.y * 0.14)
	_play("nudge", 1.4, -14.0)


func _refresh_book() -> void:
	if book_list == null:
		return
	for ch in book_list.get_children():
		ch.queue_free()
	var n:= 0
	for b in BOOK:
		if unlocked.get(b.id, false):
			n += 1
	var head:= _label("연못 도감  %d / %d" % [n, BOOK.size()], 17, Color(1.0, 0.95, 0.82))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_list.add_child(head)
	var tot:= _label("모은 달빛 방울 %d" % drops_total, 12, Color(0.9, 0.95, 1.0, 0.75))
	tot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_list.add_child(tot)
	for b in BOOK:
		var got: bool = unlocked.get(b.id, false)
		var l:= _label(("● " + b.name) if got else "○ ???", 14, Color(1.0, 0.97, 0.9) if got else Color(0.8, 0.88, 0.9, 0.6))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		book_list.add_child(l)
		var h:= _label("   " + b.hint, 11, Color(0.85, 0.92, 0.95, 0.7 if got else 0.55))
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.custom_minimum_size = Vector2(vs.x - 80, 0)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		book_list.add_child(h)
	var close:= _label("화면을 누르면 닫혀요", 11, Color(0.85, 0.9, 0.95, 0.5))
	close.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_list.add_child(close)


# ---------------- v0.34 target leaf ----------------
func _target() -> LilyPad:
	return pads[step + 1] if step + 1 < pads.size() else null


func _raise_target() -> void:
	var t:= _target()
	if t == null:
		return
	t.custom_tex = TARGET_TEX
	t.sink = 0.0
	t.reveal = 0.0
	t.submerged = 1.0
	t.z_index = -2
	t.beacon = false
	(pads[step] as LilyPad).beacon = false
	_emerging = false
	_lane_latched = false
	_clear_wait = 0.0
	if PUSH_MODE:
		var twr:= create_tween()
		twr.tween_interval(0.3)
		twr.tween_property(t, "reveal", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# the way is clear: the leaf rises out of the water and the red fish dance around it
func _emerge_target() -> void:
	var t:= _target()
	if t == null or _emerging:
		return
	_emerging = true
	t.z_index = 3
	_haptic("rise")
	# rises with a gentle half-turn, easing to a stop
	var end_rot:= t.notch_angle
	var turn:= _rng.randf_range(1.1, 1.6) * (1.0 if _rng.randf() < 0.5 else -1.0)
	t.notch_angle = end_rot - turn
	var spin:= create_tween()
	spin.tween_property(t, "notch_angle", end_rot, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var tw:= create_tween()
	tw.tween_property(t, "submerged", 0.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func ():
		if is_instance_valid(t):
			t.beacon = true)
	var gp:= t.position + layer.global_position
	for k in 3:
		get_tree().create_timer(0.15 * k).timeout.connect(func ():
			if is_instance_valid(t):
				_spawn_ripple(t.position, 0.9 + 0.5 * k, 2))
	_splash(gp, 12)
	flies.burst(gp + Vector2(0, -20), 14, true)
	_play("bloom", 1.25, -8.0)
	_spawn_drops(gp, 4)
	score += 3
	hud.queue_redraw()
	_fish_dance(t)
	_log("target_emerge")


func _fish_dance(t: LilyPad) -> void:
	var i:= 0
	for f in small_fish + followers:
		if not is_instance_valid(f):
			continue
		var k:= f as Koi
		k.orbit(t.position, t.rx() + 14.0 + 6.0 * (i % 3), 3.2)
		k.orbit_dir = 1.0
		k.orbit_node = null
		k.boost_t = 0.6
		var d:= 0.25 + 0.22 * i
		get_tree().create_timer(d).timeout.connect(func ():
			if is_instance_valid(k):
				k.do_leap())
		get_tree().create_timer(d + 1.3).timeout.connect(func ():
			if is_instance_valid(k):
				k.do_leap())
		i += 1
	_dance_t = 3.2


const PLACE_MIN:= 120.0
const PLACE_MAX:= 300.0


# the player leads: a tap on open water ahead calls a leaf up right there (if the way is clear)
func _try_place_target(local: Vector2) -> bool:
	var t:= _target()
	if t == null:
		return false
	var origin: Vector2 = (pads[step] as LilyPad).position
	var v:= local - origin
	if v.y > -30.0 or v.length() < 40.0:
		return false
	var ang:= clampf(Vector2.UP.angle_to(v.normalized()), -1.2, 1.2)
	var dir:= Vector2.UP.rotated(ang)
	var d:= clampf(v.length(), PLACE_MIN, PLACE_MAX)
	var spot:= origin + dir * d
	spot.x = clampf(spot.x, 64.0, 296.0)
	if t.reveal > 0.6 and t.submerged < 0.5 and t.position.distance_to(spot) < 60.0:
		return false
	var blockers:= _blockers_between(origin, spot, t.rx())
	if not blockers.is_empty():
		for nd in blockers:
			if nd is LilyPad:
				(nd as LilyPad).nudge(0.4)
		_play("nudge", 0.75, -14.0)
		_log("place_blocked n=%d" % blockers.size())
		return false
	var shift:= spot - t.position
	for i in range(step + 1, pads.size()):
		var pp: LilyPad = pads[i]
		pp.position += shift
		pp.position.x = clampf(pp.position.x, 72.0, 288.0)
	t.position = spot
	t.reveal = 1.0
	t.submerged = 1.0
	t.sink = 0.0
	t.beacon = false
	t.z_index = -2
	_emerging = false
	_emerge_target()
	_log("place_target dist=%d ang=%.2f" % [int(d), ang])
	return true


func _blockers_between(a: Vector2, b: Vector2, end_r: float) -> Array:
	var out: Array = []
	if _descender and is_instance_valid(_descender) and _descender.blocking:
		if _dist_to_segment(_descender.position, a, b) < _giant_body_r() * 0.8 + LANE_HALF:
			out.append(_descender)
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd):
			continue
		if _dist_to_segment(nd.position, a, b) < LANE_HALF + nd.rx() * 0.35 or nd.position.distance_to(b) < end_r * 0.7 + nd.rx() * 0.5:
			out.append(nd)
	return out


func _shift_leaf(c: Dictionary, mv: Vector2) -> void:
	c.home += mv
	if c.has("out"):
		c.out += mv


func _settle_leaf(c: Dictionary, at: Vector2) -> void:
	c.home = at
	c.out = at
	c.rt = 99.0


# v0.47 tap: a ripple spreads the pads around it. A pad still drifting home is sent further out.
func _add_small_fish(from_edge: bool) -> void:
	var dl:= frog.global_position - layer.global_position
	var top:= -layer.position.y
	var f:= Koi.new()
	f.z_index = -1
	var at:= dl + Vector2(_rng.randf_range(-60, 60), 70)
	if from_edge:
		at = Vector2(-30.0 if _rng.randf() < 0.5 else vs.x + 30.0, clampf(dl.y + _rng.randf_range(-100.0, 60.0), top + 40.0, top + vs.y - 40.0))
	f.setup(at, _rng.randi())
	f.patch = 0
	f.length = _rng.randf_range(30.0, 38.0)
	f.speed = _rng.randf_range(55.0, 72.0)
	layer.add_child(f)
	kois.append(f)
	small_fish.append(f)
	_fish_pop = 1.0
	_log("fish_added n=%d" % small_fish.size())


func _update_spec(delta: float, dew_local: Vector2, top: float, bottom: float) -> void:
	if frog.jumping or locked or bloomed or in_intro or _sinking:
		return
	var pd: LilyPad = pads[step]
	# the school grows with time
	_fish_t += delta
	if _fish_t >= FISH_EVERY_S:
		_fish_t -= FISH_EVERY_S
		if small_fish.size() < FISH_MAX:
			_add_small_fish(true)
	# fish not busy with a tap or a dance circle under the dew's pad and rock it
	var rocking:= 0
	for f in small_fish:
		if not is_instance_valid(f):
			continue
		var k:= f as Koi
		if _dance_t <= 0.0 and (k.mode == "wander" or (k.mode == "orbit" and k.mode_t > 1000.0)):
			if k.mode != "orbit" or k.orbit_c.distance_to(pd.position) > 4.0:
				k.orbit(pd.position, pd.rx() * 0.8 + _rng.randf() * 22.0, 99999.0)
				k.orbit_node = null
			k.orbit_c = pd.position
			var to:= pd.position - k.position
			if to.length() > pd.rx() + 60.0:
				k.position += to.normalized() * 90.0 * delta
			else:
				rocking += 1
	_shake_t -= delta
	if rocking > 0 and _shake_t <= 0.0:
		_shake_t = 0.55
		var amp:= clampf(0.12 + 0.05 * rocking, 0.0, 0.75)
		pd._wobble = maxf(pd._wobble, amp)
		pd._tilt_wob = maxf(pd._tilt_wob, amp * 0.8)
		pd.tilt_axis = _rng.randf() * TAU
		frog.jelly_v += _rng.randf_range(-2.0, 2.0) * (1.0 + 0.3 * rocking)
		if small_fish.size() >= 5:
			_haptic("fish")
			if frog.mood_t <= 0.0:
				frog.feel(2, 0.5)
	# v114 healing mode: staying on a pad is fine; nothing sinks and nothing ends
	_stay_t += delta


func _sink_game_over() -> void:
	if _sinking:
		return
	_sinking = true
	var pd: LilyPad = pads[step]
	_log("stay_sink step=%d" % step)
	_haptic("sink")
	var tw:= create_tween()
	tw.tween_property(pd, "submerged", 1.0, 1.0)
	tw.parallel().tween_property(pd, "reveal", 0.6, 1.0)
	for k in 3:
		get_tree().create_timer(0.25 * k).timeout.connect(func ():
			_spawn_ripple(pd.position, 1.0 + 0.4 * k, 2))
	_play("plop", 0.6, -6.0)
	await get_tree().create_timer(0.6).timeout
	_dew_gone("연잎이 가라앉았어요")


const WAVE_SPEED:= 800.0


func _wave_hit(c: Dictionary, dir: Vector2, push: float, k: float) -> void:
	if not crowd.has(c):
		return
	var nd: LilyPad = c.node
	if not is_instance_valid(nd) or nd.held:
		return
	if nd.fixed_bank:
		# bank pads only nod as the ripple passes
		nd._tilt_wob = maxf(nd._tilt_wob, 0.3 * k)
		return
	# pushed pads stay where they end up: no drifting back
	var out:= nd.rest + dir * push
	c.home = out
	c.out = out
	c.rt = 99.0
	nd.vel += (out - nd.position) * 4.8
	nd.hit_t = maxf(nd.hit_t, 0.5)
	nd.tilt_axis = dir.angle() + PI * 0.5
	nd._tilt_wob = maxf(nd._tilt_wob, 0.5 + 0.5 * k)
	nd._wobble = maxf(nd._wobble, 0.35 * k)
	nd.lift = minf(nd.lift + 3.0 + 5.0 * k, 9.0)


const BANK_FREE:= 120.0


func _path_x_at(y: float) -> float:
	# x of the river's centre line at this height (the line through the dew's pads)
	var n:= pads.size()
	if n == 0:
		return 180.0
	var i0:= maxi(step - 4, 0)
	var first: LilyPad = pads[i0]
	if y >= first.position.y:
		return first.position.x
	for i in range(i0, n - 1):
		var a: Vector2 = (pads[i] as LilyPad).position
		var b: Vector2 = (pads[i + 1] as LilyPad).position
		if y <= a.y and y >= b.y:
			return lerpf(a.x, b.x, (a.y - y) / maxf(a.y - b.y, 0.001))
	return (pads[n - 1] as LilyPad).position.x


func _spec_scatter(at: Vector2, radius: float) -> void:
	var weak:= 1.0
	if _descender and is_instance_valid(_descender) and _descender.blocking and at.distance_to(_descender.position) < _giant_body_r() * 1.6:
		weak = 0.5
	radius *= weak
	_scatter_retap = false
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or nd.held:
			continue
		if not c.has("out"):
			c.out = c.home
			c.rt = 99.0
		var d:= nd.position - at
		var reach:= radius + nd.rx() * 0.5
		if d.length() >= reach:
			continue
		var k:= 1.0 - d.length() / reach
		var dir:= d.normalized() if d.length() > 1.0 else Vector2.from_angle(_rng.randf() * TAU)
		var push:= (52.0 + 104.0 * k) * weak
		var now_s:= Time.get_ticks_msec() / 1000.0
		if now_s - float(c.get("pushed_at", -99.0)) < 2.0:
			_scatter_retap = true
		c.pushed_at = now_s
		# the push rides the ripple: each pad is lifted and carried off as the ring reaches it
		var delay:= d.length() / WAVE_SPEED
		get_tree().create_timer(maxf(delay, 0.01)).timeout.connect(_wave_hit.bind(c, dir, push, k))
	_haptic("retap" if _scatter_retap else "tap")


# tap: pads under the finger get nudged up and a little to the side, and stay there
func _push_tap(local: Vector2) -> void:
	var dl:= frog.global_position - layer.global_position
	var moved:= 0
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or nd.held:
			continue
		var reach:= nd.rx() + 38.0
		var d:= nd.position.distance_to(local)
		if d >= reach:
			continue
		var side:= signf(nd.position.x - dl.x)
		if side == 0.0:
			side = 1.0 if _rng.randf() < 0.5 else -1.0
		var dir:= (Vector2.UP + Vector2(side * 0.55, 0.0)).normalized()
		var k:= 1.0 - d / reach
		var mv:= dir * (55.0 + 55.0 * k)
		nd.rest += mv
		c.home = nd.rest
		nd.vel += mv * 2.0
		nd.hit_t = maxf(nd.hit_t, 0.25)
		nd.tilt_axis = dir.angle() + PI * 0.5
		nd._tilt_wob = maxf(nd._tilt_wob, 0.5 * k)
		moved += 1
	if moved > 0:
		_play("nudge", _rng.randf_range(1.0, 1.2), -11.0)


# drag: pads the finger sweeps over are carried along with it, and stay where they are left
func _push_drag(a: Vector2, b: Vector2) -> void:
	var mv:= b - a
	if mv.length() < 0.5 or locked and frog.jumping:
		return
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or nd.held:
			continue
		if _dist_to_segment(nd.position, a, b) < nd.rx() * 0.75 + 16.0:
			nd.rest += mv * 1.1
			c.home = nd.rest
			nd.vel += (mv * 6.0).limit_length(260.0)
			nd.hit_t = maxf(nd.hit_t, 0.2)
			nd.tilt_axis = mv.angle() + PI * 0.5
			nd._tilt_wob = maxf(nd._tilt_wob, 0.35)


func _on_open_water(local: Vector2) -> bool:
	if _descender and is_instance_valid(_descender) and _descender.blocking and local.distance_to(_descender.position) < _giant_body_r():
		return false
	for c in crowd:
		var nd: LilyPad = c.node
		if is_instance_valid(nd) and nd.position.distance_to(local) < nd.rx() * 0.92:
			return false
	for i in [step]:
		var pd: LilyPad = pads[i]
		if pd.position.distance_to(local) < pd.rx() * 0.9:
			return false
	return true


func _target_blockers() -> Array:
	var out: Array = []
	var t:= _target()
	if t == null:
		return out
	var a: Vector2 = (pads[step] as LilyPad).position
	var b:= t.position
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd):
			continue
		if nd.modulate.a < 0.5:
			continue
		if _dist_to_segment(nd.position, a, b) < LANE_HALF + nd.rx() * 0.35:
			out.append(nd)
	return out


func _press_target(screen_pt: Vector2) -> bool:
	var t:= _target()
	if PUSH_MODE or t == null or screen_pt == Vector2.INF or t.reveal < 0.6 or t.submerged > 0.3:
		return false
	var local:= screen_pt - layer.global_position
	if local.distance_to(t.position + t.surface_offset()) > t.rx() * 1.3:
		return false
	_idle_tap = 0.0
	if locked or frog.jumping or bloomed:
		return true
	_target_pressed = true
	var tw:= create_tween()
	tw.tween_property(t, "sink", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spawn_ripple(t.position, 0.8, 2)
	_play("plop", 1.35, -12.0)
	if frog.pose == "sleepy":
		frog.set_pose("idle")
	frog.charge = 0.35
	return true


func _release_target() -> void:
	_target_pressed = false
	frog.charge = 0.0
	var t:= _target()
	if t == null:
		return
	if locked or frog.jumping or bloomed:
		_bob_target(t)
		return
	var blockers:= [] if t.submerged <= 0.3 else _target_blockers()
	if not blockers.is_empty():
		_bob_target(t)
		for nd in blockers:
			(nd as LilyPad).nudge(0.4)
			(nd as LilyPad).cleared_glow = maxf((nd as LilyPad).cleared_glow, 0.3)
		_play("nudge", 0.7, -12.0)
		_blocked_hints += 1
		if _blocked_hints <= 2:
			_show_quip(PHASE_HINTS[0])
		_log("target_blocked n=%d" % blockers.size())
		return
	# clear: land there
	var on_beat:= _beat_distance(song_t) <= 0.12
	if on_beat:
		rhythm_combo += 1
		score += 2
		_spawn_drops(t.position + layer.global_position, 3)
	var dist:= (pads[step] as LilyPad).position.distance_to(t.position)
	score += int(dist / 30.0)
	if dist > 250.0:
		far_jumps += 1
	_spawn_drops(t.position + layer.global_position, 2 + int(dist / 120.0))
	var tw:= create_tween()
	tw.tween_property(t, "sink", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_log("target_go dist=%d" % int(dist))
	_open_corridor((pads[step] as LilyPad).position, t.position, t.rx(), true)
	_line_channel((pads[step] as LilyPad).position, t.position, true)
	_auto_hop()


func _bob_target(t: LilyPad) -> void:
	var tw:= create_tween()
	tw.tween_property(t, "sink", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_spawn_ripple(t.position, 0.6, 1)


func _auto_target() -> void:
	if locked or frog.jumping:
		return
	if _auto_jumps % 6 == 5:
		_auto_jumps += 1
		await get_tree().create_timer(2.6).timeout
		if shots_dir != "" and not _seen_nibble:
			_seen_nibble = true
			_snap("fish_sipping")
		return
	var t:= _target()
	if t == null:
		return
	var origin0: Vector2 = (pads[step] as LilyPad).position
	var want:= origin0 + Vector2.UP.rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(150.0, 270.0)
	want.x = clampf(want.x, 70.0, 290.0)
	var tries:= 0
	if _descender and is_instance_valid(_descender) and _descender.blocking:
		await get_tree().create_timer(3.8).timeout
		if is_instance_valid(_descender) and _descender.blocking:
			last_tap = _descender.global_position
			handle_tap()
			_finger_up()
			await get_tree().create_timer(0.8).timeout
	while not _blockers_between(origin0, want, 56.0).is_empty() and tries < 10:
		var bl:= _blockers_between(origin0, want, 56.0)
		var nd: Node2D = bl[_rng.randi() % bl.size()]
		last_tap = nd.position + layer.global_position + Vector2(_rng.randf_range(-15, 15), _rng.randf_range(-15, 15))
		handle_tap()
		_finger_up()
		tries += 1
		await get_tree().create_timer(_rng.randf_range(0.18, 0.32)).timeout
		if shots_dir != "" and tries == 2 and _flow_snaps < 2:
			_flow_snaps += 1
			_snap("clear_%d" % _flow_snaps)
	if tries >= 8 and _auto_jumps % 3 == 0:
		# also try once while still blocked
		pass
	await get_tree().create_timer(0.3).timeout
	last_tap = want + layer.global_position
	handle_tap()
	_finger_up()
	if t.submerged > 0.3 and not _emerging:
		# that spot was not open water: try the next frame of the loop
		_auto_jumps += 1
		return
	var w:= 0
	while t.submerged > 0.3 and w < 12:
		await get_tree().create_timer(0.15).timeout
		w += 1
	if shots_dir != "" and _emerge_snaps < 2 and t.submerged <= 0.3:
		_emerge_snaps += 1
		await _snap("emerge_%d" % _emerge_snaps)
	last_tap = t.position + layer.global_position
	handle_tap()
	await get_tree().create_timer(0.3).timeout
	if shots_dir != "" and _press_snaps < 2:
		_press_snaps += 1
		await _snap("target_press_%d" % _press_snaps)
	_finger_up()
	_auto_jumps += 1
	await get_tree().create_timer(0.8).timeout


var _press_snaps:= 0


func _auto_push() -> void:
	if locked or frog.jumping:
		return
	if _auto_jumps % 6 == 5:
		_auto_jumps += 1
		await get_tree().create_timer(2.6).timeout
		if shots_dir != "" and not _seen_nibble:
			_seen_nibble = true
			_snap("fish_sipping")
		return
	if _descender and is_instance_valid(_descender) and _descender.blocking:
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(_descender) and _descender.blocking:
			last_tap = _descender.global_position
			handle_tap()
			_finger_up()
	var tries:= 0
	while not _target_blockers().is_empty() and tries < 16 and not frog.jumping:
		var bl:= _target_blockers()
		var nd: LilyPad = bl[_rng.randi() % bl.size()]
		var p0:= nd.position + layer.global_position
		if SPEC or tries % 2 == 0:
			last_tap = p0
			handle_tap()
			_finger_up()
		else:
			# a short upward swipe through the pad
			last_tap = p0 + Vector2(0, 20)
			_finger = last_tap - layer.global_position
			for k in 6:
				_finger_move(p0 + Vector2(0, 20 - k * 14), Vector2(0, -500))
				await get_tree().process_frame
			_finger_up()
		tries += 1
		if shots_dir != "" and tries == 3 and _flow_snaps < 3:
			_flow_snaps += 1
			_snap("push_%d" % _flow_snaps)
		await get_tree().create_timer(0.16).timeout
	_auto_jumps += 1
	await get_tree().create_timer(1.6).timeout
var _emerge_snaps:= 0


const BIG_JUMP:= 230.0
var _spin_snaps:= 0


# sparkles streaming from the dew while it somersaults
# a big red fish lifts its face out of the water, eyes the dew, and drifts on
func _giant_peek() -> void:
	if bloomed or in_intro or step >= pads.size() or _giants_alive() > 0:
		return
	var dl:= frog.global_position - layer.global_position
	var t:= _target()
	var spot:= Vector2.INF
	for k in 16:
		var cand:= dl + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(80.0, 190.0)
		if cand.x < 40.0 or cand.x > 320.0:
			continue
		if t and t.reveal > 0.5 and cand.distance_to(t.position) < t.rx() + 50.0:
			continue
		if _on_open_water(cand):
			spot = cand
			break
	if spot == Vector2.INF:
		return
	var g:= GiantFish.new()
	g.kind = "red"
	g.size = _rng.randf_range(105.0, 125.0)
	g.peek = 0.85
	g.watch = frog
	var to_dew:= (dl - spot).normalized()
	var side:= Vector2(-to_dew.y, to_dew.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	g.facing = to_dew.angle()
	g.position = spot
	g.z_index = 1
	layer.add_child(g)
	# glide sideways past the dew while peeking
	var tw:= create_tween()
	tw.tween_property(g, "position", spot + side * 90.0, 5.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tw2:= create_tween()
	tw2.tween_property(g, "facing", (dl - (spot + side * 90.0)).angle(), 5.4)
	for k in 2:
		get_tree().create_timer(1.0 + 0.35 * k).timeout.connect(func ():
			if is_instance_valid(g):
				_spawn_ripple(g.position, 0.8 + 0.4 * k, 2))
	_play("plop", 0.55, -9.0)
	_log("giant_peek")
	if shots_dir != "" and _peek_snaps < 1:
		_peek_snaps += 1
		get_tree().create_timer(2.0).timeout.connect(func (): _snap("giant_peek"))


var _peek_snaps:= 0
var _descender: GiantFish = null


# a huge red face glides down from the top and settles in front of the dew,
# shouldering lily pads back into the way. Tap its face and it dives off; otherwise it leaves after a while.
func _giants_alive() -> int:
	var n:= 0
	for ch in layer.get_children():
		if ch is GiantFish or ch is GiantLunge:
			n += 1
	return n


func _giant_descend() -> void:
	if bloomed or in_intro or step >= pads.size():
		return
	if _descender and is_instance_valid(_descender):
		return
	if _giants_alive() > 0 or Time.get_ticks_msec() / 1000.0 - _giant_gone_at < GIANT_GAP_S:
		# one big fish at a time, with a quiet stretch between visits
		return
	_giant_retry = 0
	var dl:= frog.global_position - layer.global_position
	var top:= -layer.position.y
	# v74: comes in from the left or the right edge; the face stops at the side, looking in
	# v81: radial around the centre of the screen: the body points outward, the head toward the middle,
	# so the face is what you see; mostly from the upper half
	var vh:= get_viewport_rect().size.y
	var centre:= Vector2(180.0, top + vh * 0.42)
	var out_ang:= _rng.randf_range(-PI * 0.95, -PI * 0.05) if _rng.randf() < 0.75 else (_rng.randf_range(-0.35, 0.35) + (PI if _rng.randf() < 0.5 else 0.0))
	var settle:= centre + Vector2.from_angle(out_ang) * _rng.randf_range(50.0, 90.0)
	var g:= GiantFish.new()
	g.kind = "red"
	_haptic("giant")
	frog.feel(2, 2.2)
	g.size = _rng.randf_range(320.0, 360.0)
	g.peek = 0.55
	g.soft = true
	g.watch = frog
	g.blocking = true
	# swims in along that ray from outside, nose toward the centre
	g.facing = out_ang + PI
	g.position = settle - Vector2.from_angle(g.facing) * 560.0
	g.z_index = -2
	layer.add_child(g)
	_descender = g
	last_giant = g
	var tw:= create_tween()
	tw.tween_property(g, "position", settle, 3.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for k in 3:
		get_tree().create_timer(1.2 + 0.8 * k).timeout.connect(func ():
			if is_instance_valid(g) and g.blocking:
				_spawn_ripple(g.position, 1.6 + 0.4 * k, 3))
	_play("plop", 0.4, -4.0)
	get_tree().create_timer(13.0).timeout.connect(func ():
		if is_instance_valid(g) and g.blocking:
			g.shoo())
	_log("giant_descend")
	if shots_dir != "" and _peek_snaps < 2:
		_peek_snaps += 1
		var nm:= "giant_descend_%d" % _peek_snaps
		get_tree().create_timer(3.4).timeout.connect(func (): _snap(nm))


func _giant_body_r() -> float:
	return _descender.size * 0.5 if _descender else 0.0


var _giant_gone_at:= -99.0
const GIANT_GAP_S:= 20.0
var _giant_retry:= 0


func _update_descender(delta: float) -> void:
	if _descender == null or not is_instance_valid(_descender):
		if _descender != null:
			_giant_gone_at = Time.get_ticks_msec() / 1000.0
		_descender = null
		return
	if not _descender.blocking:
		return
	var c:= _descender.position
	var R:= _giant_body_r()
	# the spot just ahead of the dew that the fish keeps stuffing with lily pads
	var dl:= frog.global_position - layer.global_position
	var front:= dl + Vector2(0, -120)
	for cc in crowd:
		var nd: LilyPad = cc.node
		if not is_instance_valid(nd) or nd.held:
			continue
		if nd.fixed_bank:
			continue
		var d:= nd.rest - c
		var lim:= R + nd.rx() * 0.6
		if d.length() < lim:
			# pads slide sideways off its back toward the nearer edge of the pond, never into the middle
			var mid_x:= get_viewport_rect().size.x * 0.5 - layer.position.x
			var sx:= signf(nd.rest.x - mid_x)
			if absf(nd.rest.x - mid_x) < 12.0:
				sx = signf(d.x) if absf(d.x) > 1.0 else (1.0 if _rng.randf() < 0.5 else -1.0)
			var dir:= Vector2(sx, -0.2).normalized()
			var mvb:= dir * (lim - d.length()) * clampf(delta * 5.0, 0.0, 1.0)
			nd.rest += mvb
			_shift_leaf(cc, mvb)
			nd.hit_t = maxf(nd.hit_t, 0.15)


func _on_dew_bounce(n: int) -> void:
	if not TARGET_MODE or step >= pads.size():
		return
	var pd: LilyPad = pads[step]
	var lp:= frog.global_position - layer.global_position
	if n == 1:
		# the pad gives under the dew: it dips into the water, water washes over the rim, then it springs back
		pd.sink = 1.0
		create_tween().tween_property(pd, "sink", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var tw:= create_tween()
		tw.tween_property(pd, "dip", 10.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pd, "dip", -4.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(pd, "dip", 2.5, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(pd, "dip", -1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(pd, "dip", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pd._wobble = maxf(pd._wobble, 0.8)
		_spawn_ripple(lp, 1.1, 1)
		_spawn_ripple(pd.position, 0.6, 1)
		_play("plop", 1.05, -12.0)   # v108: was pitch 1.5 (toy-like "뿅")
	else:
		pd.sink = maxf(pd.sink, 0.45)
		create_tween().tween_property(pd, "sink", 0.0, 0.4)
		_spawn_ripple(lp, 0.4, 1)
		# v108: no sound on the second, small bounce (three "뿅" per jump was too busy)


func _spin_trail() -> void:
	for i in 9:
		get_tree().create_timer(0.05 + 0.06 * i).timeout.connect(func ():
			if frog.jumping:
				var at:= frog.global_position + Vector2(0, -frog.air_height - 18.0)
				flies.burst(at, 3, i % 3 == 0)
				_drops.append({ "p": at, "v": Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-60, 10)), "t": 0.0, "r": _rng.randf_range(2.6, 3.6)}))
	_play("sparkle", 1.15, -8.0)
	get_tree().create_timer(0.25).timeout.connect(func (): _play("aim", 1.6, -12.0))
	if shots_dir != "" and _spin_snaps < 2:
		_spin_snaps += 1
		var nm:= "spin_jump_%d" % _spin_snaps
		get_tree().create_timer(0.3).timeout.connect(func (): _snap(nm))


# a grander landing after the double somersault
func _land_reaction(t: LilyPad, big: bool) -> void:
	var gp:= frog.global_position
	var lp:= gp - layer.global_position
	_land_glow = 1.0
	frog.feel(1, 0.9 if big else 0.6)
	t.cleared_glow = maxf(t.cleared_glow, 0.7)
	# the pond answers: a ring of water, the pads around bob away and settle back
	for k in 2:
		get_tree().create_timer(0.12 * k).timeout.connect(func ():
			_spawn_ripple(lp, 0.9 + 0.5 * k, 2))
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd):
			continue
		var d:= nd.position - lp
		var reach:= 150.0 + nd.rx()
		if d.length() < reach and d.length() > 1.0:
			var k2:= 1.0 - d.length() / reach
			nd.vel += d.normalized() * 90.0 * k2
			nd._tilt_wob = maxf(nd._tilt_wob, 0.8 * k2)
			nd._wobble = maxf(nd._wobble, 0.5 * k2)
			nd.tilt_axis = d.angle() + PI * 0.5
			nd.lift = minf(nd.lift + 5.0 * k2, 8.0)
	# fish under the pad dart off, then drift back
	# the whole school bolts when the dew lands, then comes back to circle and pester it
	var nf:= small_fish.size()
	var a0:= _rng.randf() * TAU
	for i in nf:
		var f = small_fish[i]
		if not is_instance_valid(f):
			continue
		var kf:= f as Koi
		var ang:= a0 + TAU * i / maxi(nf, 1) + _rng.randf_range(-0.25, 0.25)
		if kf.position.distance_to(t.position) > t.rx() * 0.6:
			# still on its way: it was hiding under this pad all along
			kf.position = t.position + Vector2.from_angle(ang) * t.rx() * _rng.randf_range(0.15, 0.4)
		kf.orbit_node = null
		kf.flee(t.position - Vector2.from_angle(ang) * 30.0, true)
		kf.mode_t = _rng.randf_range(0.7, 1.0)
		var exit_at:= t.position + Vector2.from_angle(ang) * (t.rx() + 14.0)
		get_tree().create_timer(0.22 + 0.04 * i).timeout.connect(func ():
			_spawn_ripple(exit_at, 0.35, 1))
	_shake_t = 1.6
	if not big:
		_splash(gp, 10)
		flies.burst(gp + Vector2(0, -18), 10, false)


func _update_dew_light(delta: float) -> void:
	if dew_light == null:
		var gr:= Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		gr.add_point(0.45, Color(1, 1, 1, 0.38))
		var gt:= GradientTexture2D.new()
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		dew_light = Sprite2D.new()
		dew_light.texture = gt
		var cm:= CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		dew_light.material = cm
		dew_light.z_index = 4
		layer.add_child(dew_light)
	_land_glow = maxf(_land_glow - delta * 1.6, 0.0)
	_light_t += delta
	dew_light.visible = not in_intro and not _dew_gone_flag
	dew_light.position = frog.position + Vector2(0, 6)
	var sc:= 2.1 + 0.08 * sin(_light_t * 1.3) + 0.9 * _land_glow
	dew_light.scale = Vector2(sc, sc * 0.9)
	dew_light.modulate = Color(1.0, 0.86, 0.38, 0.26 + 0.03 * sin(_light_t * 1.3) + 0.22 * _land_glow)


var dew_light: Sprite2D
var _land_glow:= 0.0
var _light_t:= 0.0


# ---- star candies: little friends that keep the dew company while it keeps moving ----
const CANDY_MAX:= 5
const CANDY_TAPS:= 100      # taps for one candy
const CANDY_BONUS:= 100     # score when five merge
var _candy_taps:= 0
var _candy_have:= 0
var _candy_merge_t:= -1.0
const CANDY_COLS:= [Color(1.0, 0.1, 0.75), Color(1.0, 0.85, 0.05), Color(1.0, 0.1, 0.12), Color(0.1, 0.4, 1.0), Color(0.6, 0.15, 1.0)]
var candy_fx: Node2D
var _candies: Array = []
var _pace:= 0.0


var _candy_hist: Array = []
var _candy_next:= randi() % 6


func _candy_trail(ago: float) -> Vector2:
	# where the dew was this many seconds ago
	var want:= _light_t - ago
	for h in range(_candy_hist.size() - 1, -1, -1):
		if float(_candy_hist[h].t) <= want:
			return _candy_hist[h].p
	return _candy_hist[0].p if not _candy_hist.is_empty() else frog.position


func _update_candies(delta: float) -> void:
	_resident_tick()
	# v82: star candies removed from the game
	if not _candies.is_empty():
		_candies.clear()
		if candy_fx:
			candy_fx.queue_redraw()
	return
	if candy_fx == null:
		candy_fx = Node2D.new()
		candy_fx.z_index = 4
		layer.add_child(candy_fx)
		# candies gather behind the dew so they never hide its face; they show through its glass instead
		if frog.get_parent() == layer:
			layer.move_child(candy_fx, frog.get_index())
		candy_fx.draw.connect(_draw_candies)
	if in_intro or _dew_gone_flag:
		_pace = 0.0
	# v77: candies are earned by tapping and stay; five of them merge into the score
	var want:= mini(_candy_have, CANDY_MAX)
	if _candy_merge_t >= 0.0:
		want = 0
	var staying:= 0
	for cd in _candies:
		if not cd.leaving:
			staying += 1
	var fp:= frog.position
	_candy_hist.append({ "t": _light_t, "p": fp})
	while _candy_hist.size() > 2 and float(_candy_hist[0].t) < _light_t - 2.6:
		_candy_hist.pop_front()
	while staying < want:
		var ang:= _rng.randf() * TAU
		var kind:= _rng.randi() % 3
		_candies.append({ "p": fp + Vector2.from_angle(ang) * 150.0, "col": CANDY_COLS[_rng.randi() % CANDY_COLS.size()], "ph": _rng.randf() * TAU, "a": 0.0, "leaving": false,
			"ci": _candy_have_col(), "r": _rng.randf_range(2.84, 5.67), "rot": _rng.randf() * TAU, "v": Vector2.ZERO, "kind": kind,
			"n": [5, 6, 7, 8][_rng.randi() % 4] if kind == 0 else [4, 5, 6][_rng.randi() % 3], "amp": _rng.randf_range(0.16, 0.32), "spin": _rng.randf_range(-1.6, 1.6), "hop": 0.0,
			"who": _candy_next % 6, "t": _rng.randf() * 10.0, "ang": _rng.randf() * TAU, "wt": _rng.randf_range(1.0, 3.0), "wo": Vector2.ZERO, "wback": 0.0})
		_candy_next += 1 + _rng.randi() % 2
		staying += 1
	var k:= _candies.size() - 1
	while staying > want and k >= 0:
		if not _candies[k].leaving:
			_candies[k].leaving = true
			_candies[k].v = Vector2(_rng.randf_range(-30.0, 30.0), -70.0)
			staying -= 1
		k -= 1
	var idx:= 0
	var keep: Array = []
	if _candy_merge_t >= 0.0:
		_candy_merge_t += delta
	for cd in _candies:
		cd.rot = float(cd.rot) + delta * float(cd.spin)
		if _candy_merge_t >= 0.0:
			# merge: all five swirl into the dew and pop into the score
			var mk:= clampf(_candy_merge_t / 1.1, 0.0, 1.0)
			var swirl:= Vector2.from_angle(float(cd.ph) + _candy_merge_t * 7.0) * 30.0 * (1.0 - mk)
			cd.p = (cd.p as Vector2).lerp(fp + swirl, clampf(delta * (3.0 + 9.0 * mk), 0.0, 1.0))
			cd.hop = 0.0
			cd.a = 1.0 - smoothstep(0.75, 1.0, mk)
			if mk >= 1.0:
				continue
			keep.append(cd)
			continue
		if cd.leaving:
			cd.p += (cd.v as Vector2) * delta
			cd.a = float(cd.a) - delta * 0.9
			if float(cd.a) <= 0.0:
				continue
		else:
			cd.a = minf(float(cd.a) + delta * 2.0, 1.0)
			# every candy has its own temper, and moves like it
			cd.t = float(cd.t) + delta
			var t: float = cd.t
			var who: int = cd.who
			var lag:= 0.2
			var follow:= 6.0
			var off:= Vector2.ZERO
			var rest_hop:= 0.0
			match who:
				0:
					# eager: right at the dew's side, quick little hops, first to arrive
					lag = 0.07
					follow = 12.0
					off = Vector2.from_angle(float(cd.ang) + sin(t * 1.3) * 0.6) * 27.0
					rest_hop = absf(sin(t * 6.0)) * 5.0
				1:
					# easy-going: lags far behind, drifts along slowly, always the last to catch up
					lag = 0.95
					follow = 1.8
					off = Vector2.from_angle(float(cd.ang)) * 60.0 + Vector2(sin(t * 0.6) * 10.0, 8.0)
					rest_hop = pow(maxf(sin(t * 1.4), 0.0), 2.0) * 3.0
				2:
					# shy: keeps the dew between itself and the nearest fish, and trembles a little
					lag = 0.3
					follow = 6.0
					var away:= Vector2.from_angle(float(cd.ang))
					var best:= 100000.0
					for f in small_fish:
						if is_instance_valid(f):
							var fd:= ((f as Koi).position - fp).length()
							if fd < best and fd > 1.0:
								best = fd
								away = (fp - (f as Koi).position).normalized()
					off = away * 40.0 + Vector2(_rng.randf_range(-1.3, 1.3), _rng.randf_range(-1.3, 1.3))
					rest_hop = absf(sin(t * 11.0)) * 1.5
				3:
					# playful: races circles around the dew and leaps high
					lag = 0.14
					follow = 10.0
					cd.ang = float(cd.ang) + delta * 2.7
					var pr:= 36.0 + 11.0 * sin(t * 1.7)
					off = Vector2(cos(float(cd.ang)) * pr, sin(float(cd.ang)) * pr * 0.62)
					rest_hop = pow(maxf(sin(t * 3.0), 0.0), 2.0) * 11.0
					cd.rot = float(cd.rot) + delta * 4.0
				4:
					# curious: wanders off to look at something, then hurries back
					lag = 0.25
					follow = 3.4
					cd.wt = float(cd.wt) - delta
					if float(cd.wt) <= 0.0:
						if float(cd.wback) <= 0.0:
							var look:= Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(70.0, 120.0)
							if not small_fish.is_empty() and _rng.randf() < 0.6:
								var sf = small_fish[_rng.randi() % small_fish.size()]
								if is_instance_valid(sf) and ((sf as Koi).position - fp).length() < 160.0:
									look = (sf as Koi).position - fp
							cd.wo = look
							cd.wback = 1.0
							cd.wt = _rng.randf_range(1.0, 1.8)
						else:
							cd.wo = Vector2.ZERO
							cd.wback = 0.0
							cd.wt = _rng.randf_range(2.2, 4.5)
					off = Vector2.from_angle(float(cd.ang)) * 36.0 + (cd.wo as Vector2)
					if float(cd.wback) <= 0.0:
						follow = 7.0
					rest_hop = pow(maxf(sin(t * 2.2), 0.0), 2.0) * 4.0
				_:
					# dancer: sways from side to side on the beat
					lag = 0.2
					follow = 8.0
					off = Vector2.from_angle(float(cd.ang)) * 46.0 + Vector2(sin(t * 3.6) * 13.0, sin(t * 7.2) * 5.0)
					rest_hop = absf(sin(t * 3.6)) * 7.0
					cd.rot = float(cd.rot) + delta * sin(t * 3.6) * 3.0
			var slot:= _candy_trail(lag) + Vector2(off.x, off.y * 0.8 + 4.0)
			var before: Vector2 = cd.p
			cd.p = before.lerp(slot, clampf(delta * follow, 0.0, 1.0))
			var run_hop:= minf((cd.p as Vector2).distance_to(before) / maxf(delta, 0.001) * 0.07, 16.0)
			cd.hop = lerpf(float(cd.hop), maxf(rest_hop, run_hop), clampf(delta * 12.0, 0.0, 1.0))
			idx += 1
		keep.append(cd)
	_candies = keep
	if _candy_merge_t >= 1.1:
		_candy_merge_t = -1.0
		_candy_have = 0
		_candies.clear()
		score += CANDY_BONUS
		_spawn_ripple(fp, 1.4, 3)
		_spawn_ripple(fp, 2.2, 2)
		_log("candy_merge score=%d" % score)
	candy_fx.queue_redraw()


func _candy_tap() -> void:
	return   # v82: star candies removed
	if in_intro or _candy_merge_t >= 0.0:
		return
	_candy_taps += 1
	if _candy_taps < CANDY_TAPS:
		return
	_candy_taps = 0
	_candy_have = mini(_candy_have + 1, CANDY_MAX)
	_log("candy_new have=%d" % _candy_have)
	if _candy_have >= CANDY_MAX:
		# let the fifth one arrive, then they all merge
		get_tree().create_timer(1.2).timeout.connect(func (): _candy_merge_t = 0.0)


# five saturated colours: magenta, yellow, red, blue, purple (cells 0-4 of the sheet)
func _candy_have_col() -> int:
	var used:= []
	for cd in _candies:
		if cd.has("ci"):
			used.append(int(cd.ci))
	for c in [0, 2, 3, 1, 4]:
		if not c in used:
			return c
	return _rng.randi() % 5


static var CANDY_TEX: Texture2D = null
static var _candy_tex_tried:= false


func _draw_candies() -> void:
	if CANDY_TEX == null and not _candy_tex_tried:
		_candy_tex_tried = true
		var ci:= Image.load_from_file("res://assets/candy_sheet_gpt.png")
		if ci:
			CANDY_TEX = ImageTexture.create_from_image(ci)
	for cd in _candies:
		var a: float = clampf(float(cd.a), 0.0, 1.0)
		var r: float = cd.r
		var col: Color = cd.col
		var hop: float = float(cd.hop) if not cd.leaving else 0.0
		var at: Vector2 = (cd.p as Vector2) + Vector2(0, -hop)
		# tiny shadow on the water shows the hop
		candy_fx.draw_circle((cd.p as Vector2) + Vector2(0, r * 0.9), r * (0.7 - 0.02 * hop), Color(0.0, 0.1, 0.08, 0.16 * a))
		if CANDY_TEX != null:
			# glass candies: same wet gloss as the dew, each in its own colour; they rock rather than spin so the light stays put
			var k: int = int(cd.ci) if cd.has("ci") else int(cd.who) % 5
			var half:= r * 1.75
			candy_fx.draw_set_transform(at, sin(float(cd.rot)) * 0.28, Vector2.ONE)
			candy_fx.draw_texture_rect_region(CANDY_TEX, Rect2(-half, -half, half * 2.0, half * 2.0), Rect2((k % 3) * 256, (k / 3) * 256, 256, 256), Color(1, 1, 1, a))
			candy_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		var n: int = cd.n
		var pts:= PackedVector2Array()
		for q in 28:
			var th3:= TAU * q / 28.0
			pts.append(at + Vector2.from_angle(th3 + float(cd.rot)) * r * (1.0 + float(cd.amp) * cos(th3 * float(n))))
		candy_fx.draw_circle(at, r * 2.1, Color(col.r, col.g, col.b, 0.13 * a))
		candy_fx.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.95 * a))
		candy_fx.draw_circle(at + Vector2(-r * 0.28, -r * 0.3), r * 0.24, Color(1, 1, 1, 0.8 * a))


# ---- blossoms: tap enough of them and every pad melts away for a while ----
const FLOWER_GOAL:= 5
var _flower_count:= 0
var _clear_t:= 0.0


func _pick_flower(local: Vector2) -> bool:
	if _clear_t > 0.0:
		return false
	var best: LilyPad = null
	var best_d:= 26.0
	var best_at:= Vector2.ZERO
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or nd.flower < 0 or nd.modulate.a < 0.5:
			continue
		var at:= nd.position + nd.surface_offset() + Vector2(nd.flower_off.x, nd.flower_off.y * LilyPad.TILT)
		var d:= at.distance_to(local)
		if d < best_d + nd.flower_r:
			best_d = d - nd.flower_r
			best = nd
			best_at = at
	if best == null:
		return false
	best.flower = -1
	_flower_count += 1
	var gp:= best_at + layer.global_position
	flies.burst(gp, 16, true)
	flies.burst(gp, 8, false)
	_spawn_ripple(best_at, 0.5, 1)
	_play("sparkle", 1.3 + 0.08 * _flower_count, -9.0)
	drops_fx.queue_redraw()
	if _flower_count >= FLOWER_GOAL:
		_haptic("flower_all")
		_clear_all_pads()
	else:
		_haptic("flower")
	return true


const CLEAR_SECONDS:= 7.0
var _hide_back_t:= 0.0


func _set_leaf_home(v: Vector2, c: Dictionary) -> void:
	c.home = v
	c.out = v
	c.rt = 99.0
	var nd = c.node
	if is_instance_valid(nd):
		# keep the pad right on its heels instead of trailing behind on the spring
		nd.rest = v
		nd.position = nd.position.lerp(v, 0.3)


# ---- v83: koi rest under the pads in the upper part of the screen, drifting at ease.
# Clear the pads over one (or land near it) and it is found: it rises and puffs. Tap it and it dives away.
# v102: up to two at once, so they show up about twice as often.
const REVEAL_GAP:= 1.0       # quiet seconds after one leaves, before the next settles in
const KOI_MAX:= 2
const REVEAL_CHANCE:= 0.9    # chance that a ripple reaching it reveals it
const RIPPLE_REACH:= 340.0   # v95: a tap's ripple reaches a koi this far away
const LAND_NOTICE:= 620.0    # v95: a landing this close makes a lurking koi come up
const DEW_CLEAR:= 280.0      # v94: the giant koi never comes this close to the dew
const KOI_SCRIPT:= preload("res://scripts/giant_koi.gd")
var _residents: Array = []
var _reveal_fish: Node2D = null     # the most recent one (for the bloom koi)
var _reveal_gone_at:= -99.0
var _res_top:= 0.0


func _alive_koi() -> Array:
	_residents = _residents.filter(func (g): return is_instance_valid(g))
	return _residents


func _reveal_alive() -> bool:
	return _reveal_fish != null and is_instance_valid(_reveal_fish)


func _resident_tick() -> void:
	if in_intro or bloomed:
		return
	var vsz:= get_viewport_rect().size
	var top:= -layer.position.y
	var dew_l:= frog.global_position - layer.global_position
	var live:= _alive_koi()
	for g in live:
		# it moves with the pond; an unfound koi swims back to its place near the top of the screen
		if not g.discovered:
			g.home.y += top - _res_top
		var low_k:= 0.62 if g.discovered else 0.85
		var near_dew: bool = g.position.distance_to(dew_l) < DEW_CLEAR or g.head_pos().distance_to(dew_l) < DEW_CLEAR
		if not g.is_leaving() and (near_dew or g.position.y > top + vsz.y * low_k):
			g.shoo()
	_res_top = top
	if live.size() >= KOI_MAX or Time.get_ticks_msec() / 1000.0 - _reveal_gone_at < REVEAL_GAP:
		return
	# a spot in the upper part, a little left or right of the middle, clear of the dew and of the other koi
	var spot:= Vector2(vsz.x * 0.5 + _rng.randf_range(-90.0, 90.0) - layer.position.x, top + vsz.y * _rng.randf_range(0.1, 0.38))
	if spot.distance_to(dew_l) < DEW_CLEAR + 80.0:
		return
	for g in live:
		if g.home.distance_to(spot) < 150.0:
			return
	var aim:= _rng.randf() < 0.9
	var g = _reveal_koi(spot, (dew_l - spot).angle() + _rng.randf_range(-0.3, 0.3) if aim else _rng.randf() * TAU, 8.0, false)
	g.aim_dew = aim
	# v93: it starts out of sight above the screen, under the pads, and swims in deep
	g.position = Vector2(spot.x + _rng.randf_range(-50.0, 50.0), top - 40.0)
	g.facing = (spot - g.position).angle()
	_reveal_gone_at = Time.get_ticks_msec() / 1000.0 - REVEAL_GAP + 2.5   # stagger the second one a little


func _found_fx(g) -> void:
	g.on_surface = func ():
		if is_instance_valid(g):
			_spawn_ripple(g.head_pos(), 1.2, 2)
			_play("plop", 0.5, -12.0)
	g.discover()


func _reveal_check(local: Vector2) -> void:
	if in_intro or bloomed:
		return
	for g0 in _alive_koi():
		if g0.discovered:
			continue
		var g = g0
		# wait for the ripple to push the pads aside, then see whether the water over the koi opened
		get_tree().create_timer(0.7).timeout.connect(func ():
			if not is_instance_valid(g) or g.discovered or g.is_leaving():
				return
			if g.position.distance_to(frog.global_position - layer.global_position) < DEW_CLEAR:
				return
			if (local.distance_to(g.head_pos()) < RIPPLE_REACH or local.distance_to(g.position) < RIPPLE_REACH) and _rng.randf() < REVEAL_CHANCE:
				_found_fx(g)
				koi_met += 1
				_log("koi_found")
				if shots_dir != "" and _peek_snaps < 3:
					_peek_snaps += 1
					var nm:= "koi_found_%d" % _peek_snaps
					get_tree().create_timer(2.4).timeout.connect(func (): _snap(nm)))


# v95: the dew's landing sends a soft wave through the pond; a koi resting near enough comes up to look
func _koi_notice_landing() -> void:
	if in_intro or bloomed:
		return
	for g0 in _alive_koi():
		var g = g0
		if g.discovered or g.is_leaving():
			continue
		var d: float = g.position.distance_to(frog.global_position - layer.global_position)
		if d < DEW_CLEAR or d > LAND_NOTICE or _rng.randf() > 0.9:
			continue
		get_tree().create_timer(0.5).timeout.connect(func ():
			if is_instance_valid(g) and not g.discovered and not g.is_leaving():
				_found_fx(g)
				_log("koi_found_land"))


func _tap_koi(local: Vector2) -> bool:
	# touching a koi that has been found sends it back down into the water
	for g in _alive_koi():
		if not g.discovered or g.is_leaving():
			continue
		if local.distance_to(g.head_pos()) < 60.0 or local.distance_to(g.position) < 60.0:
			g.shoo()
			_spawn_ripple(g.head_pos(), 1.0, 2)
			_play("plop", 0.7, -10.0)
			_log("koi_tapped")
			return true
	return false


func _reveal_koi(local: Vector2, heading: float, stay: float, found: bool):
	var g = KOI_SCRIPT.new()
	# v97/v102: each koi is a little different: size 0.65-1.35 (about 30% more spread than before),
	# 30% are yellow or purple, two swim styles
	g.size = 240.0 * _rng.randf_range(0.65, 1.35)
	var cr:= _rng.randf()
	g.color = "y" if cr < 0.15 else ("p" if cr < 0.3 else "r")
	g.style = 0 if _rng.randf() < 0.5 else 2   # v100: no circling style
	g.stay_time = stay
	g.facing = heading
	g.watch = frog
	g.home = local
	g.z_index = -2
	g.position = local
	layer.add_child(g)
	if found:
		g.discover()
	_reveal_fish = g
	_residents.append(g)
	g.tree_exited.connect(func (): _reveal_gone_at = Time.get_ticks_msec() / 1000.0)
	_log("koi_settle style=%d color=%s size=%.0f" % [g.style, g.color, g.size])
	return g


func _clear_all_pads() -> void:
	_flower_count = 0
	# with the pond bare for a moment, a koi passes through the middle and is soon gone
	get_tree().create_timer(1.1).timeout.connect(func ():
		for g in _alive_koi():
			g.shoo()
		var vsz0:= get_viewport_rect().size
		var mid:= Vector2(vsz0.x * 0.5 - layer.position.x, -layer.position.y + vsz0.y * 0.25)
		var hd:= _rng.randf() * TAU
		var from:= mid - Vector2.from_angle(hd) * 220.0
		_reveal_koi(mid, hd, 4.0, true)
		if is_instance_valid(_reveal_fish):
			_reveal_fish.position = from
			_reveal_fish.aim_dew = false)
	_log("flower_clear step=%d" % step)
	frog.feel(1, 2.5)
	_play("bloom", 1.0, -6.0)
	var vsz:= get_viewport_rect().size
	var top:= -layer.position.y
	var bottom:= top + vsz.y
	var mid_x:= vsz.x * 0.5 - layer.position.x
	# everything on screen slips away; the pads waiting further up the river stay where they are
	var reach:= top - 160.0
	var sweep:= 1.5
	_clear_t = sweep + 0.6
	_hide_back_t = CLEAR_SECONDS
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or nd.position.y < reach or bool(c.get("hidden", false)):
			continue
		# from the bottom of the pond to the top, each pad glows and scurries off to hide past the nearer edge
		var delay:= clampf((bottom + 60.0 - nd.position.y) / (bottom + 60.0 - reach), 0.0, 1.0) * sweep
		var from: Vector2 = c.home
		var side:= -1.0 if from.x < mid_x else 1.0
		var to:= Vector2(mid_x + side * (vsz.x * 0.5 + nd.rx() + 50.0), from.y + _rng.randf_range(-20.0, 20.0))
		c.hidden = true
		c.hide_from = from
		var tw:= create_tween()
		tw.tween_interval(delay)
		tw.tween_property(nd, "cleared_glow", 0.3, 0.3)   # v110: was 1.0 in 0.12s, every pad flashed at once
		tw.tween_callback(_leaf_scurry.bind(nd, to))
		tw.tween_method(_set_leaf_home.bind(c), from, to, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(_clear_done.bind(nd))
		var at:= nd.position + layer.global_position
		var gold:= _rng.randf() < 0.5
		get_tree().create_timer(delay + 0.18).timeout.connect(func ():
			flies.burst(at, 4, gold)
			flies.burst(at + Vector2(0, -14), 2, not gold))
	var lp:= frog.position
	for k in 4:
		get_tree().create_timer(sweep * k / 4.0).timeout.connect(func ():
			_spawn_ripple(Vector2(lp.x + _rng.randf_range(-90.0, 90.0), lerpf(bottom - 40.0, top + 60.0, k / 3.0)), 1.8, 2)
			_play("sparkle", 1.0 + 0.18 * k, -8.0))
	if shots_dir != "":
		get_tree().create_timer(0.6).timeout.connect(func (): _snap("flower_clear_a"))
		get_tree().create_timer(1.3).timeout.connect(func (): _snap("flower_clear_b"))
		get_tree().create_timer(sweep + 1.2).timeout.connect(func (): _snap("flower_clear"))


func _leaf_scurry(nd: LilyPad, to: Vector2) -> void:
	if is_instance_valid(nd):
		nd.hit_t = maxf(nd.hit_t, 1.3)
		nd.tilt_axis = (to - nd.position).angle() + PI * 0.5
		nd._tilt_wob = maxf(nd._tilt_wob, 1.0)
		nd._wobble = maxf(nd._wobble, 0.6)


func _clear_done(nd: LilyPad) -> void:
	if is_instance_valid(nd):
		nd.cleared_glow = 0.0


func _leaves_come_home() -> void:
	# the pads that hid peek back in and find their own places again, lowest first
	var top:= -layer.position.y
	var bottom:= top + get_viewport_rect().size.y
	for c in crowd:
		if not bool(c.get("hidden", false)):
			continue
		c.hidden = false
		var nd: LilyPad = c.node
		if not is_instance_valid(nd):
			continue
		var back: Vector2 = c.hide_from
		# never land on the dew, its pad or the pad it is heading for: stop just short of them
		for pass_i in 2:
			for q in [step, step + 1]:
				if q < 0 or q >= pads.size():
					continue
				var keep: LilyPad = pads[q]
				var need:= keep.rx() + nd.rx() * 0.95 + 16.0
				var dv:= back - keep.position
				if dv.length() < need:
					var dirv:= dv.normalized() if dv.length() > 1.0 else Vector2(signf(back.x - (c.home as Vector2).x + 0.01) * -1.0, 0.0)
					back = keep.position + dirv * need
		var delay:= clampf((bottom + 60.0 - back.y) / (vs.y + 300.0), 0.0, 1.0) * 1.6
		var tw:= create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(_leaf_scurry.bind(nd, back))
		# pads settling beside the dew glide in gently, without swinging past their spot
		var near_dew:= back.distance_to(frog.position) < 240.0
		tw.tween_method(_set_leaf_home.bind(c), c.home as Vector2, back, 1.0).set_trans(Tween.TRANS_CUBIC if near_dew else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play("sparkle", 0.9, -10.0)
	if shots_dir != "":
		get_tree().create_timer(1.0).timeout.connect(func (): _snap("flower_return_a"))
		get_tree().create_timer(3.2).timeout.connect(func (): _snap("flower_return_b"))


func _update_clear(delta: float) -> void:
	if _clear_t > 0.0:
		_clear_t -= delta
	if _hide_back_t > 0.0:
		_hide_back_t -= delta
		if _hide_back_t <= 0.0:
			_leaves_come_home()


func _maybe_flower(nd: LilyPad) -> void:
	# a pad that melted away earlier comes back whole when it re-enters from upstream
	nd.modulate.a = 1.0
	# a few blossoms between the pads at first, more and more as the dew travels on
	var chance:= clampf(0.02 + 0.006 * step, 0.02, 0.2)
	if LilyPad.FLOWER_TEX != null and _rng.randf() < chance:
		nd.flower = _rng.randi() % 16
		nd.flower_off = Vector2.from_angle(_rng.randf() * TAU) * nd.rx() * _rng.randf_range(0.8, 1.05)
		nd.flower_r = _rng.randf_range(8.0, 13.0)
	else:
		nd.flower = -1


func _big_landing(t: LilyPad) -> void:
	var gp:= frog.global_position
	var lp:= gp - layer.global_position
	for k in 4:
		get_tree().create_timer(0.09 * k).timeout.connect(func ():
			_spawn_ripple(lp, 1.2 + 0.55 * k, 3))
	_splash(gp, 24)
	flies.burst(gp + Vector2(0, -24), 34, true)
	_spawn_drops(gp + Vector2(0, -10), 8)
	_play("bloom", 1.1, -4.0)
	_play("p5", 1.0, -6.0)
	t.cleared_glow = 1.0
	_push_leaves(lp, 170.0, 120.0, false)
	for f in small_fish + followers:
		if is_instance_valid(f):
			(f as Koi).do_leap()
	celebrate_t = maxf(celebrate_t, 1.2)
	score += 5
	hud.queue_redraw()
	_log("big_landing")


func _flow_commit() -> void:
	if _committed or step + 1 >= pads.size():
		return
	_committed = true
	var origin:= _flow_origin()
	var L:= clampf(open_len, OPEN_MIN, OPEN_MAX)
	var nxt: LilyPad = pads[step + 1]
	var tip:= origin + open_dir * (L - nxt.rx() * 0.35)
	tip.x = clampf(tip.x, 70.0, 290.0)
	var delta_pos:= tip - nxt.position
	for i in range(step + 1, pads.size()):
		var pp: LilyPad = pads[i]
		pp.position += delta_pos
		pp.position.x = clampf(pp.position.x, 72.0, 288.0)
	open_len = L
	seg_open[step] = true
	_open_corridor(origin, nxt.position, nxt.rx(), true)
	_line_channel(origin, nxt.position, true)
	nxt.reveal = 0.0
	var tw:= create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(nxt, "reveal", 1.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_ripple(nxt.position, 1.5, 3)
	_splash(nxt.position + layer.global_position, 10)
	flies.burst(nxt.position + layer.global_position, 12, L > 220.0)
	_play("edge", 0.8, -6.0)
	_play("bloom", 1.5, -12.0)
	var pts:= int(L / 30.0)
	score += pts
	if L > 300.0:
		far_jumps += 1
	_spawn_drops(nxt.position + layer.global_position, 2 + int(L / 120.0))
	if L > 300.0:
		score += 10
		_float_text("멀리 뛰기!", nxt.position + layer.global_position + Vector2(0, -50), Color(1.0, 0.95, 0.7))
	for k in kois:
		if is_instance_valid(k) and not (k is Turtle) and not (k in small_fish):
			(k as Koi).set_home((origin + nxt.position) * 0.5, 90.0)
	hud.queue_redraw()
	_log("flow_commit L=%d dir=%.2f" % [int(L), Vector2.UP.angle_to(open_dir)])
	if giant_pending:
		giant_pending = false
		get_tree().create_timer(0.5).timeout.connect(_giant_block)


func _flow_landed() -> void:
	_committed = false
	open_len = 0.0
	_open_shown = 0.0
	_ready_ping = false
	open_dir = Vector2.UP
	_idle_tap = 0.0
	dew_size = minf(dew_size + 0.09, DEW_MAX)
	if _sipped_since_land:
		_clean_steps = 0
	else:
		_clean_steps += 1
	_sipped_since_land = false
	if not SPEC and step > 0 and step % FISH_EVERY == 0:
		get_tree().create_timer(0.4).timeout.connect(_collect_fish)
	if SPEC:
		_stay_t = 0.0
		var lp: LilyPad = pads[step]
		lp.submerged = 0.0
	_check_book()
	if step + 1 < pads.size():
		(pads[step + 1] as LilyPad).reveal = 0.0
	if TARGET_MODE:
		_raise_target()


func _dew_gone(title:= "이슬이 사라졌어요") -> void:
	_dew_gone_flag = true
	bloomed = true
	locked = false
	_log("dew_gone score=%d steps=%d" % [score, step])
	var tw:= create_tween()
	tw.tween_property(frog, "evaporate", 1.0, 1.1)
	_play("plop", 0.7, -4.0)
	_spawn_ripple(frog.global_position - layer.global_position, 1.3, 3)
	for f in small_fish:
		if is_instance_valid(f):
			(f as Koi).do_leap()
	if score > best:
		best = score
	_save_book()
	await get_tree().create_timer(1.3).timeout
	result_title.text = title
	result_img.visible = false
	result_title.visible = true
	result_sub.text = "점수 %d  ·  건넌 잎 %d  ·  물고기 %d  ·  최고 %d" % [score, step, followers.size(), best]
	result_box.visible = true
	result_box.modulate.a = 0.0
	create_tween().tween_property(result_box, "modulate:a", 1.0, 0.4)
	_snap("dew_gone")


func _draw_flow_fx() -> void:
	if not FLOW_MODE or pads.size() <= step + 1 or in_intro:
		return
	var origin:= _flow_origin()
	var L:= _open_shown
	var dew_c:= frog.global_position - layer.global_position + Vector2(0, -16)
	if open_len >= OPEN_MIN and not _committed:
		var pulse0:= 0.5 + 0.5 * sin(_flow_time * 5.0)
		var rr0:= 30.0 * maxf(frog.size_k, 0.6) + 4.0 * pulse0
		touch_fx.draw_circle(dew_c, rr0 + 8.0, Color(1.0, 0.97, 0.8, 0.06 + 0.05 * pulse0))
		touch_fx.draw_arc(dew_c, rr0, 0, TAU, 40, Color(1.0, 0.97, 0.82, 0.25 + 0.2 * pulse0), 1.6, true)
	if false and L > 4.0:
		var nrm:= Vector2(-open_dir.y, open_dir.x)
		var ready:= open_len >= OPEN_MIN
		var col:= Color(0.75, 0.92, 1.0) if not ready else Color(1.0, 0.95, 0.72)
		var a:= origin
		var b:= origin + open_dir * L
		var hw:= OPEN_HALF * 0.9
		var poly:= PackedVector2Array([a + nrm * hw, b + nrm * hw * 0.7, b - nrm * hw * 0.7, a - nrm * hw])
		touch_fx.draw_colored_polygon(poly, Color(col, 0.13))
		touch_fx.draw_line(a, b, Color(col, 0.22), 10.0, true)
		# moving glints along the lane
		var n:= int(L / 22.0)
		for q in n:
			var k:= fmod(float(q) / maxf(n, 1) + _flow_time * 0.6, 1.0)
			var gp:= a.lerp(b, k) + nrm * sin(_flow_time * 3.0 + q) * hw * 0.5
			touch_fx.draw_circle(gp, 1.8, Color(1, 1, 1, 0.45 * sin(PI * k)))
		# where the next pad will rise
		var pulse:= 0.5 + 0.5 * sin(_flow_time * 7.0)
		var rr:= 30.0 + 6.0 * pulse
		touch_fx.draw_arc(b, rr, 0, TAU, 40, Color(col, (0.55 if ready else 0.25) + 0.25 * pulse), 2.4 if ready else 1.4, true)
		if ready and not _committed:
			touch_fx.draw_arc(b, rr + 9.0, 0, TAU, 40, Color(col, 0.2 * pulse), 1.2, true)
	for m in _tap_marks:
		var life: float = clampf(1.0 - float(m.t) / 0.3, 0.0, 1.0)
		var front:= float(m.t) * WAVE_SPEED
		touch_fx.draw_set_transform(m.p, 0.0, Vector2(1.0, LilyPad.TILT))
		for q in 4:
			var rr:= front - q * 26.0
			if rr > 6.0:
				var fa:= life * (1.0 - q * 0.22)
				touch_fx.draw_arc(Vector2.ZERO, rr, 0, TAU, 56, Color(0.92, 1.0, 0.96, 0.42 * fa), 2.6 - q * 0.5, true)
				touch_fx.draw_arc(Vector2.ZERO, rr + 5.0, 0, TAU, 56, Color(0.8, 0.95, 0.9, 0.12 * fa), 5.0, true)
		touch_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _auto_flow() -> void:
	if PUSH_MODE:
		await _auto_push()
		return
	if TARGET_MODE:
		await _auto_target()
		return
	# a burst of taps in front of the dew, sometimes a pause to let the fish sip
	if _committed or locked or frog.jumping:
		return
	if _auto_jumps % 5 == 4:
		_auto_jumps += 1
		await get_tree().create_timer(2.6).timeout
		if shots_dir != "" and not _seen_nibble:
			_seen_nibble = true
			_snap("fish_sipping")
		return
	var lean:= _rng.randf_range(-70.0, 70.0)
	var taps_n:= _rng.randi_range(4, 7)
	var gap:= _rng.randf_range(0.11, 0.3)
	for t in taps_n:
		if _committed or bloomed:
			break
		last_tap = frog.global_position + Vector2(lean + _rng.randf_range(-20, 20), -_rng.randf_range(90.0, 200.0))
		handle_tap()
		if shots_dir != "" and t == 3 and _flow_snaps < 3:
			_flow_snaps += 1
			_snap("flow_tap_%d" % _flow_snaps)
		await get_tree().create_timer(gap).timeout
	_auto_jumps += 1
	await get_tree().create_timer(1.0).timeout
	if shots_dir != "" and _auto_jumps == 6 and book_panel:
		_toggle_book()
		await get_tree().create_timer(0.4).timeout
		await _snap("book")
		_toggle_book()


var _seen_nibble:= false
var _flow_snaps:= 0
var seg_open: Dictionary = {}
var _stroke_hit: Dictionary = {}
var cleared:= 0
var _since_land:= 0.0
var _wait_t:= 0.0


func _blocking_seg(nd: LilyPad) -> int:
	for i in range(step, mini(step + 3, pads.size() - 1)):
		if seg_open.get(i, false):
			continue
		var a: Vector2 = (pads[i] as LilyPad).position
		var b: Vector2 = (pads[i + 1] as LilyPad).position
		if _dist_to_segment(nd.rest, a, b) < CLEAR_HALF + nd.rx() * 0.35:
			return i
	return -1


func _blockers(i: int) -> Array:
	var out: Array = []
	var a: Vector2 = (pads[i] as LilyPad).position
	var b: Vector2 = (pads[i + 1] as LilyPad).position
	for c in crowd:
		var nd: LilyPad = c.node
		if is_instance_valid(nd) and nd.rest != Vector2.INF and _dist_to_segment(nd.rest, a, b) < CLEAR_HALF + nd.rx() * 0.35:
			out.append(nd)
	return out


func _clear_at(screen_pt: Vector2, from_tap: bool, push:= Vector2.ZERO) -> bool:
	if screen_pt == Vector2.INF:
		return false
	var local:= screen_pt - layer.global_position
	var best: LilyPad = null
	var bd:= 1000000000.0
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or _stroke_hit.has(nd):
			continue
		var d:= nd.position.distance_to(local)
		if d < nd.rx() * 1.05 and d < bd and _blocking_seg(nd) >= 0:
			bd = d
			best = nd
	if best == null:
		return false
	_clear_leaf(best, _blocking_seg(best), local, push)
	return true


func _sweep(screen_pt: Vector2) -> void:
	if in_intro or bloomed:
		return
	if not _shoo_giant(screen_pt):
		_clear_at(screen_pt, false, _finger_vel)


func _clear_leaf(nd: LilyPad, i: int, from_local: Vector2, push_dir:= Vector2.ZERO) -> void:
	_stroke_hit[nd] = true
	var a: Vector2 = (pads[i] as LilyPad).position
	var b: Vector2 = (pads[i + 1] as LilyPad).position
	var ab:= (b - a).normalized()
	var nrm:= Vector2(-ab.y, ab.x)
	var side:= signf((nd.rest - a).dot(nrm))
	if side == 0.0:
		side = 1.0 if _rng.randf() < 0.5 else -1.0
	# the finger's direction decides which bank the leaf goes to
	var pspeed:= push_dir.length()
	if pspeed > 60.0:
		var lat:= push_dir.normalized().dot(nrm)
		if absf(lat) > 0.22:
			side = signf(lat)
	var signed_d:= (nd.rest - a).dot(nrm)
	var push:= CLEAR_HALF + nd.rx() * 0.85 + 14.0 - signed_d * side
	var along:= _rng.randf_range(-24.0, 24.0)
	if pspeed > 60.0:
		along = clampf(push_dir.normalized().dot(ab) * 40.0, -40.0, 40.0)
	var dest:= nd.rest + nrm * side * maxf(push, 10.0) + ab * along
	nd.rest = dest
	var flick:= (nd.position - from_local)
	var kick:= nrm * side * _rng.randf_range(210.0, 290.0)
	if pspeed > 60.0:
		kick += push_dir.normalized() * clampf(pspeed * 0.3, 60.0, 280.0)
	elif flick.length() > 2.0:
		kick += flick.normalized() * 60.0
	nd.bump(kick)
	nd.nudge()
	nd.hit_t = 0.5
	create_tween().tween_property(nd, "notch_angle", nd.notch_angle + side * _rng.randf_range(0.4, 0.9), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_clear_feedback(nd, i, pspeed)


# One leaf has left the dew's path: shared juice for tap, drag-out, fling and knock-on.
func _clear_feedback(nd: LilyPad, i: int, speed: float, how:= "push") -> void:
	_stroke_hit[nd] = true
	create_tween().tween_property(nd, "lit", 1.0, 0.6)
	nd.cleared_glow = 1.0
	_spawn_ripple(nd.position, 0.9 + clampf(speed / 900.0, 0.0, 0.6), 2)
	_fish_burst(nd.position, i)
	_stroke_n += 1
	var pitch:= 0.92 + 0.07 * mini(_stroke_n - 1, 5) + _rng.randf_range(-0.03, 0.03)
	_play("nudge", pitch, -5.0)
	if _stroke_n >= 2:
		_play("p%d" % mini(_stroke_n - 2, 5), 1.0, -12.0)
	flies.burst(nd.position + layer.global_position, 6 + 3 * mini(_stroke_n, 4), _stroke_n >= 3)
	if speed > 500.0 or how == "knock":
		_splash(nd.position + layer.global_position, 6 if how == "knock" else 8)
	cleared += 1
	score += 1
	if _stroke_n >= 2:
		var words:= ["슥-", "싹싹!", "스르륵~", "말끔!", "반짝반짝!"]
		_float_text(words[mini(_stroke_n - 2, words.size() - 1)], nd.position + layer.global_position + Vector2(0, -26), Color(0.92, 1.0, 0.86))
		score += 1
	if how == "knock":
		_float_text("밀려났다!", nd.position + layer.global_position + Vector2(0, -20), Color(0.9, 0.97, 1.0))
	hud.queue_redraw()
	_log("clear seg=%d left=%d how=%s n=%d" % [i, _blockers(i).size(), how, _stroke_n])
	get_tree().create_timer(0.25).timeout.connect(_try_open.bind(i))


# ---------------- v0.30: hold & drag leaves out of the way ----------------
var _held: LilyPad = null
var _held_seg:= -1
var _held_off:= Vector2.ZERO
var _held_t:= 0.0
var _held_out:= false
var _held_scored:= false
var _held_wake:= 0.0
var _finger:= Vector2.INF
var _finger_vel:= Vector2.ZERO
var _press_local:= Vector2.ZERO
var _stroke_n:= 0
var _wake_pts: Array = []
var touch_fx: Node2D
var lane_fx: Node2D
var _lane_k:= 0.0
var _lane_seg:= -1
var _lane_flash:= 0.0


func _grab_at(screen_pt: Vector2) -> bool:
	if screen_pt == Vector2.INF:
		return false
	var local:= screen_pt - layer.global_position
	var best: LilyPad = null
	var bd:= 1000000000.0
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd):
			continue
		var d:= nd.position.distance_to(local)
		if d < nd.rx() * 1.12 and d < bd and _blocking_seg(nd) >= 0:
			bd = d
			best = nd
	if best == null:
		return false
	_held = best
	_held_seg = _blocking_seg(best)
	_lane_seg = _held_seg
	_held_off = (best.position - local).limit_length(best.rx() * 0.55)
	_held_t = 0.0
	_held_out = false
	_held_scored = false
	_held_wake = 0.0
	_press_local = local
	_stroke_hit[best] = true
	best.held = true
	best.hit_t = 0.5
	best.vel = Vector2.ZERO
	var g:= (local - best.position) / maxf(best.rx(), 1.0)
	best.grip = g.limit_length(0.7)
	best.nudge()
	var tw:= create_tween()
	tw.tween_property(best, "press", 0.8, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spawn_ripple(local, 0.45, 1)
	_play("nudge", 1.3, -11.0)
	_log("grab seg=%d" % _held_seg)
	return true


func _finger_move(screen_pt: Vector2, vel: Vector2) -> void:
	if in_intro or bloomed:
		return
	var local:= screen_pt - layer.global_position
	if PUSH_MODE and not SPEC and _finger != Vector2.INF:
		_push_drag(_finger, local)
	if _finger != Vector2.INF and local.distance_to(_finger) > 2.0:
		_wake_pts.append({ "p": local, "t": 0.0, "v": vel.length()})
		if _wake_pts.size() > 40:
			_wake_pts.pop_front()
	_finger = local
	_finger_vel = _finger_vel.lerp(vel, 0.6)
	if _held and is_instance_valid(_held):
		return
	if FLOW_MODE:
		return
	_sweep(screen_pt)


func _finger_up() -> void:
	if _target_pressed:
		_release_target()
	if _held:
		_release_held(_finger_vel)
	_finger = Vector2.INF


func _leaf_blocks_at(nd: LilyPad, at: Vector2) -> bool:
	var keep:= nd.rest
	nd.rest = at
	var r:= _blocking_seg(nd) >= 0
	nd.rest = keep
	return r


func _update_held(delta: float) -> void:
	_lane_k = move_toward(_lane_k, 1.0 if _held else 0.0, delta * (6.0 if _held else 2.5))
	_lane_flash = maxf(_lane_flash - delta * 1.6, 0.0)
	for w in _wake_pts:
		w.t += delta
	while not _wake_pts.is_empty() and _wake_pts[0].t > 0.75:
		_wake_pts.pop_front()
	if touch_fx:
		touch_fx.queue_redraw()
	if lane_fx:
		lane_fx.queue_redraw()
	if _held == null:
		return
	if not is_instance_valid(_held) or bloomed or in_intro:
		_held = null
		return
	_held_t += delta
	var nd:= _held
	if _finger != Vector2.INF:
		# leaf slides under the fingertip, with a little watery lag
		_held_off = _held_off.lerp(_held_off * 0.6, clampf(delta * 3.0, 0.0, 1.0))
		var target:= _finger + _held_off
		var old:= nd.position
		nd.position = nd.position.lerp(target, clampf(delta * 15.0, 0.0, 1.0))
		var mv:= nd.position - old
		nd.vel = mv / maxf(delta, 0.001)
		nd.rest = nd.position
		nd.hit_t = maxf(nd.hit_t, 0.35)
		if mv.length() > 0.6:
			nd.tilt_axis = mv.angle() + PI * 0.5
			nd._tilt_wob = maxf(nd._tilt_wob, 0.5)
			_held_wake += mv.length()
			if _held_wake > 24.0:
				_held_wake = 0.0
				_spawn_ripple(nd.position - mv.normalized() * nd.rx() * 0.75, 0.4, 1)
				_push_leaves(nd.position + mv.normalized() * nd.rx() * 0.6, 8.0, 40.0, false)
				for f in small_fish:
					if is_instance_valid(f) and (f as Koi).position.distance_to(nd.position) < 90.0:
						(f as Koi).flee(nd.position, true)
	if not _held_out and not _leaf_blocks_at(nd, nd.position):
		_held_out = true
		_lane_flash = 1.0
		if not _held_scored:
			_held_scored = true
			_clear_feedback(nd, _held_seg, nd.vel.length(), "drag")
		else:
			get_tree().create_timer(0.25).timeout.connect(_try_open.bind(_held_seg))
	elif _held_out and _leaf_blocks_at(nd, nd.position):
		# dragged back into the path again
		_held_out = false
	if _held_t > 2.6:
		_release_held(Vector2.ZERO)


func _release_held(vel: Vector2) -> void:
	var nd:= _held
	_held = null
	if not is_instance_valid(nd):
		return
	nd.held = false
	nd.grip = Vector2.INF
	var tw:= create_tween()
	tw.tween_property(nd, "press", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var seg:= _held_seg
	var v:= vel.limit_length(1100.0)
	if _held_out:
		# glide on in the throw direction, but never back into the path
		var dest:= nd.position + v * 0.2
		if _leaf_blocks_at(nd, dest):
			dest = nd.position
		nd.rest = dest
		nd.vel = v * 0.55
		nd.hit_t = 0.6
		if v.length() > 450.0:
			_splash(nd.position + layer.global_position, 5)
		_spawn_ripple(nd.position, 0.7, 2)
		_play("plop", 1.25, -14.0)
	elif seg >= 0 and seg + 1 < pads.size() and not seg_open.get(seg, false) and _leaf_blocks_at(nd, nd.position):
		# not out yet: the flick (or drag direction) finishes the push
		var dir:= v
		if dir.length() < 120.0:
			dir = (nd.position - _press_local) * 8.0
		nd.rest = nd.position
		_clear_leaf(nd, seg, nd.position - dir.normalized() * 4.0, dir)
	else:
		nd.rest = nd.position
	_log("release out=%s v=%d" % [_held_out, int(v.length())])


# A leaf shoved by another (billiard / bulldozed) that ends up off the path counts as cleared.
func _check_knocked() -> void:
	if FLOW_MODE or Engine.get_process_frames() % 4 != 0:
		return
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or nd == _held or nd.rest == Vector2.INF:
			continue
		if nd.position.distance_to(nd.rest) < nd.rx() * 0.45:
			continue
		var seg:= _blocking_seg(nd)
		if seg < 0:
			continue
		var land:= nd.position + nd.vel * 0.12
		if not _leaf_blocks_at(nd, land) and not _leaf_blocks_at(nd, nd.position):
			nd.rest = land
			nd.hit_t = maxf(nd.hit_t, 0.4)
			nd.nudge()
			_clear_feedback(nd, seg, nd.vel.length(), "knock")


func _draw_touch_fx() -> void:
	_draw_flow_fx()
	_draw_tutorial()
	# finger wake on the water
	var n:= _wake_pts.size()
	if n >= 2:
		for k in range(1, n):
			var w0: Dictionary = _wake_pts[k - 1]
			var w1: Dictionary = _wake_pts[k]
			var life: float = 1.0 - float(w1.t) / 0.75
			if life <= 0.0:
				continue
			var wd: float = (2.0 + minf(float(w1.v) / 260.0, 5.0)) * life
			if k % 2 == 0:
				touch_fx.draw_arc(w1.p, 5.0 + (10.0 + wd * 3.0) * (1.0 - life), 0, TAU, 28, Color(0.9, 1.0, 0.96, 0.3 * life), 1.6, true)
		var tip: Dictionary = _wake_pts[n - 1]
		var tl: float = 1.0 - float(tip.t) / 0.75
		if tl > 0.0:
			touch_fx.draw_arc(tip.p, 10.0 + 14.0 * (1.0 - tl), 0, TAU, 24, Color(0.9, 1.0, 0.95, 0.25 * tl), 1.5, true)
	# the dew's lane while you hold a leaf: push it past the soft edge
	if _lane_k > 0.01 and _lane_seg >= 0 and _lane_seg + 1 < pads.size():
		var a: Vector2 = (pads[_lane_seg] as LilyPad).position
		var b: Vector2 = (pads[_lane_seg + 1] as LilyPad).position
		var ab:= (b - a).normalized()
		var nrm:= Vector2(-ab.y, ab.x)
		var hw:= CLEAR_HALF + 18.0
		var col:= Color(0.95, 1.0, 0.8).lerp(Color(0.7, 1.0, 0.85), _lane_flash)
		var a_in:= 0.07 * _lane_k + 0.1 * _lane_flash
		var poly:= PackedVector2Array([a + nrm * hw, b + nrm * hw, b - nrm * hw, a - nrm * hw])
		touch_fx.draw_colored_polygon(poly, Color(col, a_in))


func _draw_lane_edges() -> void:
	if _lane_k > 0.01 and _lane_seg >= 0 and _lane_seg + 1 < pads.size():
		var a: Vector2 = (pads[_lane_seg] as LilyPad).position
		var b: Vector2 = (pads[_lane_seg + 1] as LilyPad).position
		var ab:= (b - a).normalized()
		var nrm:= Vector2(-ab.y, ab.x)
		var hw:= CLEAR_HALF + 18.0
		var col:= Color(1.0, 1.0, 0.85).lerp(Color(0.75, 1.0, 0.85), _lane_flash)
		var flow:= fmod(_hint_t * 18.0, 28.0)
		for sg: float in [-1.0, 1.0]:
			var e0:= a + nrm * hw * sg
			var e1:= b + nrm * hw * sg
			var segs:= int(e0.distance_to(e1) / 14.0) - 2
			for q in segs:
				if q % 2 == 0:
					var t0:= float(q) / segs
					var t1:= float(q + 1) / segs
					var off:= ab * flow
					lane_fx.draw_line(e0.lerp(e1, t0) - off, e0.lerp(e1, t1) - off, Color(col, (0.4 * _lane_k + 0.45 * _lane_flash)), 2.4, true)


func _fish_burst(at: Vector2, seg:= -1) -> void:
	var n:= _rng.randi_range(3, 6)
	var a:= at
	var b:= at
	if seg >= 0 and seg + 1 < pads.size():
		a = (pads[seg] as LilyPad).position
		b = (pads[seg + 1] as LilyPad).position
	var ab:= (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.UP
	var nrm:= Vector2(-ab.y, ab.x)
	for j in n:
		var f:= Koi.new()
		f.z_index = -1 if TARGET_MODE else 1

		var along:= a.lerp(b, _rng.randf()) if seg >= 0 else at
		var spot:= at.lerp(along, _rng.randf_range(0.2, 0.8)) + nrm * _rng.randf_range(-45.0, 45.0) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 18.0)
		f.setup(spot, _rng.randi())
		f.patch = 0
		f.length = _rng.randf_range(10.0, 18.0)
		f.speed = _rng.randf_range(55.0, 95.0)
		var away:= (spot - at).normalized() if spot.distance_to(at) > 2.0 else Vector2.from_angle(_rng.randf() * TAU)
		f.heading = (away.rotated(_rng.randf_range(-0.9, 0.9))).angle()
		layer.add_child(f)
		f.flee(at, true)
		f.boost_t = _rng.randf_range(0.5, 1.1)
		f.modulate.a = 0.0
		var delay:= _rng.randf_range(0.0, 0.35)
		var tw:= create_tween()
		tw.tween_interval(delay)
		tw.tween_property(f, "modulate:a", 1.0, 0.15)
		if _rng.randf() < 0.5:
			tw.tween_callback(func ():
				if is_instance_valid(f):
					f.do_leap()
					_splash(f.global_position, 3))
		else:
			tw.tween_callback(func ():
				if is_instance_valid(f):
					_spawn_ripple(f.position, 0.4, 1))
		tw.tween_interval(_rng.randf_range(0.9, 1.5))
		tw.tween_property(f, "modulate:a", 0.0, 0.5)
		tw.tween_callback(f.queue_free)


func _try_open(i: int) -> void:
	if FLOW_MODE or seg_open.get(i, false) or i + 1 >= pads.size():
		return
	if not _blockers(i).is_empty():
		return
	seg_open[i] = true
	var a: Vector2 = (pads[i] as LilyPad).position
	var b: Vector2 = (pads[i + 1] as LilyPad).position
	_open_corridor(a, b, (pads[i + 1] as LilyPad).rx(), true)
	_line_channel(a, b, true)
	var nxt: LilyPad = pads[i + 1]
	if nxt.reveal < 1.0:
		var tw:= create_tween()
		tw.tween_property(nxt, "reveal", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play("edge", 0.8, -8.0)
	_spawn_ripple((a + b) * 0.5, 1.4, 3)
	for k in kois:
		if is_instance_valid(k) and not (k is Turtle):
			(k as Koi).set_home((a + b) * 0.5, 90.0)
			(k as Koi).dash(a.lerp(b, _rng.randf_range(0.2, 0.9)), 1.6)
	_log("seg_open %d" % i)
	if giant_pending and i == step:
		giant_pending = false
		get_tree().create_timer(0.5).timeout.connect(_giant_block)


func _auto_hop() -> void:
	var target: LilyPad = pads[step + 1]
	if lunger and is_instance_valid(lunger):
		get_tree().create_timer(0.18).timeout.connect(func ():
			if is_instance_valid(lunger):
				lunger.strike())
	locked = true
	ever_jumped = true
	_wait_t = 0.0
	_scatter_from(pads[step])
	var jump_no:= step + 1
	if jump_no % 8 == 7:
		_huge_turtle(target)
	elif jump_no % 8 == 3:
		_huge_turtle(target, true)
	elif jump_no % 8 == 5:
		_huge_turtle(target, false, true)   # v98: the red turtle is back
	var hop_pw:= 0.62
	var big_jump:= false
	if FLOW_MODE:
		var dist:= (pads[step] as LilyPad).position.distance_to(target.position)
		hop_pw = clampf(dist / 250.0, 0.35, 1.45)
		big_jump = TARGET_MODE and dist >= BIG_JUMP
	if big_jump:
		frog.spin_turns = 2.0 * (1.0 if target.position.x >= (pads[step] as LilyPad).position.x else -1.0)
		_spin_trail()
	(pads[step] as LilyPad).left = true
	# the red fish slip under the pad the dew is heading for
	for f in small_fish:
		if is_instance_valid(f):
			var kf:= f as Koi
			kf.orbit(target.position, _rng.randf_range(6.0, target.rx() * 0.4), 4.0)
			kf.orbit_node = target
			kf.boost_t = 1.2
	await _hop(target, target.uv_to_global(Vector2.ZERO), true, hop_pw)
	_haptic("big_land" if big_jump else "land")
	_land_reaction(target, big_jump)
	if big_jump:
		_big_landing(target)
	_since_land = 0.0
	if jump_no in LUNGE_STALK and step + 1 < pads.size():
		_start_lunge()
	elif not FLOW_MODE and _giant_due(jump_no) and step + 1 < pads.size():
		if seg_open.get(step, false):
			_giant_block()
		else:
			giant_pending = true
	elif not FLOW_MODE and jump_no >= 2 and _rng.randf() < 0.4 and jump_no % 8 != 7 and jump_no % 8 != 3:
		get_tree().create_timer(_rng.randf_range(0.3, 1.2)).timeout.connect(func ():
			if step + 1 < pads.size() and not bloomed:
				_giant_fish(pads[step + 1]))


func _update_waiting(delta: float) -> void:
	if in_intro or bloomed or locked or frog.jumping:
		return
	_since_land += delta
	if seg_open.get(step, false):
		return
	_wait_t += delta

	if FLOW_MODE:
		return
	if fmod(_wait_t, 2.2) < delta:
		for nd in _blockers(step):
			(nd as LilyPad).nudge(0.4)
		if _wait_t > 2.0 and _wait_t < 2.3 + delta:
			_show_quip("앞이 막혔어요! 연잎을 밀어 주세요")


func handle_release(pw: float) -> void:
	if not can_act():
		_log("release_ignored")
		return
	var pt:= landing_point(pw)
	var kind:= landing_kind(pt)
	locked = true
	ever_jumped = true
	if title_box.visible:
		var tw:= create_tween()
		tw.tween_property(title_box, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func (): title_box.visible = false)
	_log("release power=%.2f kind=%s" % [pw, kind])
	_scatter_from(pads[step])
	var arc:= clampf(pw, 0.0, 1.6)
	match kind:
		"skip_center", "skip_edge":
			await _hop(pads[step + 2], pt, kind == "skip_center", arc, true)
		"center", "edge":
			await _hop(pads[step + 1], pt, kind == "center", arc)
		"stay":
			await _hop_in_place(pt, arc)
		"water":
			await _hop_into_water(pt, arc)


func _hop_in_place(pt: Vector2, power: float) -> void:
	var cur: LilyPad = pads[step]
	_play("jump", 1.2, -6.0)
	frog.hop_to(cur, cur.landing_uv(pt), Vector2.INF, power)
	await frog.landed
	cur.land(false)
	_play("edge", 1.3, -8.0)
	get_tree().create_timer(0.7).timeout.connect(_gather_fish.bind(cur, false))
	_float_text("폴짝", frog.global_position, Color(0.85, 0.95, 1.0))
	locked = false


func _hop_into_water(pt: Vector2, power: float) -> void:
	var from_pad: LilyPad = pads[step]
	var from_uv: Vector2 = frog.uv
	_play("jump", _rng.randf_range(0.95, 1.08), -3.0)
	frog.hop_to(null, Vector2.ZERO, pt, power)
	await frog.landed

	falls += 1
	combo = 0
	light_on = true
	rhythm_combo = 0
	_play("plop", 1.0, 0.0)
	_spawn_ripple(pt - layer.global_position, 1.5, 3)
	_splash(pt, 20)
	_float_text("퐁당!", pt, Color(0.7, 0.85, 1.0))
	_koi_splash(pt, false)
	(pads[step + 1] as LilyPad).nudge()
	frog.set_pose("land")
	var tw:= create_tween()
	tw.tween_property(frog.sprite, "modulate", Color(0.55, 0.7, 0.9, 0.45), 0.25)
	await tw.finished
	await get_tree().create_timer(0.35).timeout

	var back:= from_pad.uv_to_global(from_uv)
	var swim:= create_tween()
	swim.tween_property(frog, "global_position", back, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in 4:
		get_tree().create_timer(0.2 * i).timeout.connect(func ():
			_spawn_ripple(frog.global_position - layer.global_position, 0.45, 1))
	await swim.finished
	frog.place_on(from_pad, from_uv)
	frog.set_pose("idle")
	_gather_fish(from_pad, false)
	var tw2:= create_tween()
	tw2.tween_property(frog.sprite, "modulate", Color.WHITE, 0.25)
	from_pad.land(false)
	_play("croak", 1.1, -8.0)
	_log("fell_in_water falls=%d" % falls)
	_hint_t = 0.0
	locked = false


func _hop(target: LilyPad, p: Vector2, center: bool, power:= 0.6, skip:= false) -> void:
	var uv:= target.landing_uv(p)
	var from_pad: LilyPad = pads[step]
	_spawn_ripple(from_pad.uv_to_global(frog.uv) - layer.global_position, 0.55, 1)
	_splash(frog.global_position, 6)
	_play("jump", _rng.randf_range(0.95, 1.08), -3.0)
	(pads[step + 1] as LilyPad).set_target(false)
	target.set_target(false)
	frog.hop_to(target, uv, Vector2.INF, power)
	await frog.landed
	target.land(center)
	var land_pt:= frog.global_position
	_spawn_ripple(land_pt - layer.global_position, 1.25 if center else 0.9, 3 if center else 2)
	_splash(land_pt, 14 if center else 8)
	if center:
		_play("p%d" % mini(combo, 5), 1.0, 0.0)
		combo += 1
		centers += 1
		pass
	else:
		_play("edge", _rng.randf_range(0.96, 1.04), -3.0)
		combo = 0
		pass
	if skip:
		landings += 2
		results.append(true)
		centers += 1
		results.append(center)
		step += 2
		skips += 1
		_celebrate(land_pt)
	else:
		landings += 1
		results.append(center)
		step += 1
	if FLOW_MODE:
		_flow_landed()
	_koi_splash(land_pt, center)
	_push_leaves(land_pt - layer.global_position, 120.0, 70.0, false)
	_update_dew_stage()
	for f in small_fish:
		(f as Koi).flee(land_pt - layer.global_position, true)
		(f as Koi).mode_t = 1.0
		(f as Koi).boost_t = 0.8
	hud.queue_redraw()
	_log("landed n=%d center=%s centers=%d" % [landings, center, centers])
	_koi_notice_landing()
	light_on = true
	pass
	while pads.size() < step + 8:
		_add_pad(true)
	_cleanup_behind()
	await get_tree().create_timer(0.12).timeout
	_try_open(step)
	get_tree().create_timer(1.4).timeout.connect(_gather_fish.bind(pads[step], false))
	await _scroll_to(step)
	if not FLOW_MODE:
		(pads[step + 1] as LilyPad).set_target(true)
	locked = false


func _spawn_stars() -> void:
	stars.clear()
	for i in range(1, LANDINGS_PER_ROUND + 1):
		if (i + pattern_index) % 2 == 0 and i != 1:
			continue
		var a: Vector2 = (pads[i - 1] as LilyPad).position
		var b: Vector2 = (pads[i] as LilyPad).position
		var d:= (b - a).length()
		var pc:= CENTER_P
		var apex:= Frog.ARC * lerpf(0.55, 1.35, pc) + absf(b.y - a.y) * 0.12 + 34.0
		stars.append({ "pos": (a + b) * 0.5 + Vector2(0, -apex), "alive": true, "ph": _rng.randf() * TAU})


func _check_stars() -> void:
	if not frog.jumping:
		return
	var body:= frog.global_position + Vector2(0, -frog.air_height - 34)
	for st in stars:
		if not st.alive:
			continue
		var g: Vector2 = layer.global_position + st.pos
		if g.distance_to(body) < 20.0:
			st.alive = false
			stars_caught += 1
			flies.burst(g, 8, true)
			_play("sparkle", 1.3, -6.0)
			_float_text("반딧불 +1", g + Vector2(0, 40), Color(1.0, 0.9, 0.5))
			hud.queue_redraw()
			_log("star_caught total=%d" % stars_caught)


func _draw_stars() -> void:
	for st in stars:
		if not st.alive:
			continue
		var p: Vector2 = st.pos + Vector2(sin(_hint_t * 1.7 + st.ph) * 4.0, cos(_hint_t * 1.3 + st.ph) * 5.0)
		var tw:= 0.75 + 0.25 * sin(_hint_t * 4.0 + st.ph)
		for k in 4:
			stars_node.draw_circle(p, 16.0 - k * 4.0, Color(1.0, 0.85, 0.4, (0.08 + k * 0.12) * tw))
		stars_node.draw_circle(p, 3.0, Color(1, 1, 0.9, tw))


func _scroll_to(i: int) -> void:
	var goal_y: float = home_y - (pads[i] as LilyPad).position.y
	var tw:= create_tween()
	tw.tween_property(layer, "position:y", goal_y, SCROLL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _bloom() -> void:
	bloomed = false
	_bloom_count_this_round += 1
	var full_moon:= centers == LANDINGS_PER_ROUND
	await get_tree().create_timer(0.3).timeout
	lotus.bloom(_lotus_kind())
	_open_to_lotus()
	for k in kois:
		(k as Koi).orbit(lotus.position, 70.0 + _rng.randf() * 40.0, 8.0)
	frog.set_pose("celebrate" if full_moon else "lookup")
	_play("bloom", 1.0, 0.0)
	_play("croak", 1.0 if full_moon else 1.08, -4.0)
	var lp:= lotus.global_position + Vector2(0, -30)
	flies.burst(lp, 10, false)
	_spawn_ripple(lotus.global_position - layer.global_position, 1.6, 3)
	if full_moon:
		await get_tree().create_timer(0.45).timeout
		_play("sparkle", 1.0, -6.0)
		flies.burst(lp, 22, true)
	_log("bloom full_moon=%s centers=%d" % [full_moon, centers])
	await get_tree().create_timer(1.1).timeout
	result_title.text = "만월 개화!" if full_moon else "연꽃이 피었어요"
	var rt:= typo_atlas(2 if full_moon else 3)
	result_img.visible = rt != null
	result_title.visible = rt == null
	if rt:
		result_img.texture = rt
	result_sub.text = "달빛 방울 %d / %d  ·  두 칸 %d  ·  반딧불 %d  ·  퐁당 %d" % [centers, LANDINGS_PER_ROUND, skips, stars_caught, falls]
	result_box.visible = true
	result_box.modulate.a = 0.0
	var tw:= create_tween()
	tw.tween_property(result_box, "modulate:a", 1.0, 0.4)
	bloomed = true
	locked = false
	await get_tree().create_timer(0.6).timeout
	_snap("bloom_r%d" % round_no)


func _spawn_ripple(local_pos: Vector2, size: float, rings: int) -> void:
	var r:= Ripple.new()
	r.position = local_pos
	r.size = size
	r.rings = rings
	ripples.add_child(r)


var _dot_tex: Texture2D

func _splash(global_pt: Vector2, amount: int) -> void:
	if _dot_tex == null:
		var g:= Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt:= GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 16
		gt.height = 16
		_dot_tex = gt
	var ps:= CPUParticles2D.new()
	ps.texture = _dot_tex
	ps.one_shot = true
	ps.emitting = false
	ps.amount = amount
	ps.lifetime = 0.55
	ps.explosiveness = 0.95
	ps.direction = Vector2(0, -1)
	ps.spread = 70.0
	ps.initial_velocity_min = 50.0
	ps.initial_velocity_max = 110.0
	ps.gravity = Vector2(0, 320)
	ps.scale_amount_min = 0.25
	ps.scale_amount_max = 0.55
	ps.color = Color(0.85, 0.95, 1.0, 0.85)
	ps.z_index = 6
	add_child(ps)
	ps.global_position = global_pt
	ps.emitting = true
	get_tree().create_timer(1.2).timeout.connect(ps.queue_free)


func _float_text(t: String, global_pt: Vector2, col: Color) -> void:
	var row:= -1
	if t.begins_with("퐁!"):
		row = 5
	elif t == "톡":
		row = 6
	elif t == "퐁당!":
		row = 7
	var l: Control = _label(t, 18, col)
	if row >= 0 and typo_atlas(row):
		var tr:= typo_node(row, t, 18, col)
		if t.length() > 2:
			var c:= _label(t.substr(2).strip_edges(), 15, col)
			c.position = Vector2(0, 32)
			c.size = Vector2(120, 22)
			tr.add_child(c)
		l = tr
	var big:= l is TextureRect
	l.size = Vector2(150, 48) if big else Vector2(120, 30)
	l.position = global_pt + (Vector2(-75, -112) if big else Vector2(-60, -100))
	l.z_index = 8
	add_child(l)
	var tw:= create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 28, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


# v105: sound effects 30% quieter (x0.7 amplitude) so the background music comes through
const SFX_DB:= -3.1
const POP_DB:= -6.0   # v113: the "뿅" pair (jump / plop) at half loudness
const CHIME_DB:= -18.0  # v107: rhythm chimes (p0..p5) 80% quieter than v106 (-4 - 14dB)

# v108: every sound effect goes through its own bus that sits under the music:
# high end rounded off (no piercing chirps), a touch of room so it blends, a little lower.
static var _sfx_bus:= -1

static func _sfx_bus_index() -> int:
	if _sfx_bus >= 0 and _sfx_bus < AudioServer.bus_count and AudioServer.get_bus_name(_sfx_bus) == "SFX":
		return _sfx_bus
	_sfx_bus = AudioServer.get_bus_index("SFX")
	if _sfx_bus < 0:
		_sfx_bus = AudioServer.bus_count
		AudioServer.add_bus(_sfx_bus)
		AudioServer.set_bus_name(_sfx_bus, "SFX")
		AudioServer.set_bus_send(_sfx_bus, "Master")
		AudioServer.set_bus_volume_db(_sfx_bus, -14.0)   # v109: sound effects ~10dB under the music (v108 -3)
		var lp:= AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 2600.0
		lp.resonance = 0.5
		AudioServer.add_bus_effect(_sfx_bus, lp)
		var rv:= AudioEffectReverb.new()
		rv.room_size = 0.35
		rv.damping = 0.7
		rv.wet = 0.12
		rv.dry = 0.92
		AudioServer.add_bus_effect(_sfx_bus, rv)
	return _sfx_bus

func _play(name: String, pitch:= 1.0, vol:= 0.0) -> void:
	var p:= AudioStreamPlayer.new()
	p.bus = AudioServer.get_bus_name(_sfx_bus_index())
	p.stream = SND[name]
	p.pitch_scale = pitch
	p.volume_db = vol + SFX_DB + (CHIME_DB if name.length() == 2 and name.begins_with("p") else 0.0) + (POP_DB if name in ["jump", "plop"] else 0.0)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _process(delta: float) -> void:
	scroll = layer.position.y - (home_y - (pads[0] as LilyPad).position.y) if pads.size() > 0 else 0.0
	_update_bg()
	if water_rect:
		var wmat:= water_rect.material as ShaderMaterial
		wmat.set_shader_parameter("world_y", layer.position.y)
		wmat.set_shader_parameter("screen_size", vs)
	_hint_t += delta
	if not locked and not bloomed:
		idle_time += delta
		if idle_time > 7.0 and frog.pose == "idle" and not frog.jumping:
			frog.set_pose("sleepy")
	hint.queue_redraw()
	if name_tag:
		_tag_t += delta
		_tag_a = lerpf(_tag_a, 0.55 if frog.jumping else 1.0, minf(1.0, delta * 6.0))
		name_tag.position = frog.position
		name_tag.queue_redraw()
	if not _rec.is_empty():
		_video_tick(delta)
	_update_held(delta)
	if FLOW_MODE:
		_update_flow(delta)
	_leaf_physics(delta)
	_update_clear(delta)
	_update_dew_light(delta)
	_update_candies(delta)
	_check_knocked()
	_update_waiting(delta)
	_update_billiards(delta)
	_update_food()
	celebrate_t = maxf(celebrate_t - delta, 0.0)
	stars_node.queue_redraw()
	_check_stars()
	_update_beat(delta)
	_update_groove(delta)
	if charging:
		if not can_act():
			charging = false
			pressing = false
			power = 0.0
			frog.charge = 0.0
		else:
			if pressing:
				power = minf(power + HOLD_RATE * delta, MAX_POWER)
			frog.charge = minf(power, 1.2) * 0.7
	if autoplay:
		_autoplay_tick(delta)


func _hint_visible() -> bool:
	if in_intro:
		return false
	if locked or bloomed or frog.jumping:
		return false
	if FLOW_MODE:
		return seg_open.get(step, false)
	if not ever_jumped:
		return true
	return idle_time > 4.0


func _draw_aim() -> void:
	var pw:= charge_power()
	var land:= landing_point(pw)
	var kind:= landing_kind(land)
	var a: Vector2 = frog.position + Vector2(0, -30)
	var b:= land - layer.global_position
	var col:= Color(0.75, 0.85, 1.0, 0.6)
	match kind:
		"center":
			col = Color(1.0, 0.88, 0.45, 1.0)
		"edge":
			col = Color(0.85, 1.0, 0.7, 0.95)
		"stay":
			col = Color(1, 1, 1, 0.5)
		"skip_center", "skip_edge":
			col = Color(1.0, 0.62, 0.85, 1.0)
	var ctrl:= (a + b) * 0.5 + Vector2(0, -50 - 40 * minf(pw, 1.6))
	var n:= 16
	for i in n + 1:
		var k:= i / float(n)
		var p:= a.lerp(ctrl, k).lerp(ctrl.lerp(b, k), k)
		hint.draw_circle(p, 2.8 if i % 2 == 0 else 1.8, Color(col, col.a * (0.35 + 0.65 * k)))
	hint.draw_set_transform(b, 0.0, Vector2(1.0, 0.34))
	hint.draw_arc(Vector2.ZERO, 14.0 + 4.0 * sin(_hint_t * 12.0), 0, TAU, 32, col, 3.0, true)
	hint.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var fp: Vector2 = frog.position + Vector2(0, -10)
	hint.draw_set_transform(fp, 0.0, Vector2(1.0, 0.4))
	hint.draw_arc(Vector2.ZERO, 46.0, -PI / 2, -PI / 2 + TAU * minf(pw / CENTER_P / 1.6, 1.0), 40, Color(1, 1, 1, 0.85), 4.0, true)
	if pw > CENTER_P * 1.6:
		var k2:= clampf((pw - CENTER_P * 1.6) / (MAX_POWER - CENTER_P * 1.6), 0.0, 1.0)
		hint.draw_arc(Vector2.ZERO, 56.0, -PI / 2, -PI / 2 + TAU * k2, 40, Color(1.0, 0.62, 0.85, 0.95), 4.0, true)
	hint.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_celebration() -> void:
	if celebrate_t <= 0.0:
		return
	var c: Vector2 = frog.position + Vector2(0, -frog.air_height - 10)
	var k:= 1.0 - celebrate_t / 1.2
	for i in 10:
		var ang:= TAU * i / 10.0 + k * 2.0
		var r:= 30.0 + 50.0 * k
		var p:= c + Vector2(cos(ang), sin(ang) * 0.8) * r
		var a:= (1.0 - k)
		var col:= Color(1.0, 0.85, 0.45, a) if i % 2 == 0 else Color(1.0, 0.65, 0.85, a)
		var s:= 4.0 + 3.0 * (1.0 - k)
		hint.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), col, 2.0, true)
		hint.draw_line(p - Vector2(0, s), p + Vector2(0, s), col, 2.0, true)
	hint.draw_arc(c, 24.0 + 70.0 * k, 0, TAU, 40, Color(1.0, 0.9, 0.6, 0.6 * (1.0 - k)), 3.0, true)


func _draw_hint() -> void:
	_draw_celebration()
	if FLOW_MODE:
		return
	if charging and can_act():
		_draw_aim()
		return
	if not _hint_visible() or pads.size() <= step + 1:
		return
	var a: Vector2 = frog.position + Vector2(0, -26)
	var target: LilyPad = pads[step + 1]
	var b: Vector2 = target.position + target.surface_offset()
	var ctrl:= (a + b) * 0.5 + Vector2(0, -60)
	var fade_in:= clampf(_hint_t * 2.0, 0.0, 1.0)
	var n:= 22
	var shift:= fmod(_hint_t * 1.6, 1.0)
	for i in n:
		var k:= (i + shift) / float(n)
		if k < 0.12 or k > 0.82:
			continue
		var p:= a.lerp(ctrl, k).lerp(ctrl.lerp(b, k), k)
		var alpha:= sin(PI * (k - 0.12) / 0.7) * 0.85 * fade_in
		hint.draw_circle(p, 2.6, Color(1, 1, 1, alpha))

	var tip:= a.lerp(ctrl, 0.88).lerp(ctrl.lerp(b, 0.88), 0.88)
	var dir:= (b - tip).normalized()
	var nrm:= Vector2(-dir.y, dir.x)
	var col:= Color(1, 1, 1, 0.85 * fade_in)
	hint.draw_line(tip, tip - dir * 9 + nrm * 6, col, 2.4, true)
	hint.draw_line(tip, tip - dir * 9 - nrm * 6, col, 2.4, true)


func _toggle_sound() -> void:
	sound_on = not sound_on
	AudioServer.set_bus_mute(0, not sound_on)
	_update_sound_icon()


func _update_sound_icon() -> void:
	var at:= AtlasTexture.new()
	at.atlas = UI_SHEET
	at.region = Rect2((3 if sound_on else 4) * 256, 0, 256, 256)
	sound_btn.texture_normal = at


func _pad_variant(i: int, n: int) -> String:
	if i >= n - 2:
		return "young_bud"
	return ["v1", "notch_left", "v1", "aged", "notch_left", "v1"][(i + pattern_index * 2) % 6]


func _lotus_kind() -> String:
	if centers >= 5:
		return "fullmoon"
	if centers >= 3:
		return "white"
	if centers >= 1:
		return "lavender"
	return "pink"


func _draw_hud() -> void:
	if in_intro:
		return
	var cx:= vs.x * 0.5
	# v114: no score or combo on screen (healing mode); a quiet note of today's walk instead
	var who:= dew_name if dew_name != "" else "이슬"
	var sub:= "%s   ·   건넌 잎 %d   ·   만난 친구 %d" % [who, step, koi_met + turtles]
	var sw:= font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	hud.draw_string(font, Vector2(cx - sw * 0.5 + 1, 128), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0.05, 0.06, 0.35))
	hud.draw_string(font, Vector2(cx - sw * 0.5, 127), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.93, 1.0, 0.96, 0.85))


func _log(msg: String) -> void:
	if autoplay or OS.has_feature("web"):
		print(_log_prefix, msg)


func _snap(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots_dir, name])
	_log("shot %s" % name)


var _auto_jumps:= 0
var _seen_bloom:= false

# Recording aid (--showcase): now and then the autoplayer clears the pads over a hidden koi, and
# taps a found one after a while so it dives. Off in normal play.
var _flower_show_t:= 0.0

func _showcase_flower() -> bool:
	# test/trailer only (--showcase): pick the blossoms on screen so the pond clears
	var now:= Time.get_ticks_msec() / 1000.0
	if now - _flower_show_t < 1.6 or _clear_t > 0.0:
		return false
	var vs0:= get_viewport_rect().size
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd) or nd.flower < 0 or nd.modulate.a < 0.5:
			continue
		var at:= nd.position + nd.surface_offset() + Vector2(nd.flower_off.x, nd.flower_off.y * LilyPad.TILT)
		var g:= at + layer.global_position
		if g.x < 30.0 or g.x > vs0.x - 30.0 or g.y < vs0.y * 0.12 or g.y > vs0.y * 0.85:
			continue
		_flower_show_t = now
		_auto_wait = 99.0
		_flow_tap(g)
		await get_tree().create_timer(0.7).timeout
		_auto_wait = 0.3
		return true
	return false


func _showcase_koi() -> bool:
	var now:= Time.get_ticks_msec() / 1000.0
	if now - _show_t < 3.5:
		return false
	var dew_l:= frog.global_position - layer.global_position
	for g in _alive_koi():
		if g.is_leaving():
			continue
		if not g.discovered and g.position.distance_to(dew_l) > DEW_CLEAR + 20.0 and g.position.distance_to(g.home) < 160.0:
			_show_t = now
			_auto_wait = 99.0
			last_tap = g.global_position + Vector2(0.0, 30.0)
			handle_tap()
			await get_tree().create_timer(0.6).timeout
			last_tap = g.global_position + Vector2(40.0, -20.0)
			handle_tap()
			await get_tree().create_timer(0.5).timeout
			_auto_wait = 0.4
			return true
		if g.discovered and g._found_t > 3.0 and g._up > 0.9:
			_show_t = now
			_auto_wait = 99.0
			last_tap = g.global_position
			handle_tap()
			await get_tree().create_timer(0.5).timeout
			_auto_wait = 0.4
			return true
	return false


func _autoplay_tick(delta: float) -> void:
	_auto_wait -= delta
	if _auto_wait > 0.0:
		return
	if bloomed:
		if not _seen_bloom:
			_seen_bloom = true
			_auto_wait = 2.4
			return
		_seen_bloom = false
		if quit_after_rounds > 0 and round_no >= quit_after_rounds:
			_log("summary runs=%d best=%d" % [round_no, best])
			get_tree().quit()
			return
		_auto_wait = 1.5
		_auto_jumps = 0
		_on_again()
		return
	if locked or frog.jumping:
		return
	var target: LilyPad = pads[step + 1]


	if in_intro:
		if _auto_jumps == 0:
			_auto_jumps = -2
			await get_tree().create_timer(2.2).timeout
			await _snap("intro_day")
			await get_tree().create_timer(5.0).timeout
			await _snap("intro_sunset")
			await get_tree().create_timer(4.0).timeout
			await _snap("intro")
			intro.begin()
		return
	if _auto_jumps == -2:
		_auto_jumps = 0
	if showcase and await _showcase_koi():
		return
	if showcase and await _showcase_flower():
		return
	if landings >= auto_landings:
		_log("summary score=%d combo_best=%d turtles=%d steps=%d cleared=%d leaves=%d" % [score, best_combo, turtles, step, cleared, crowd.size()])
		get_tree().quit()
		return
	_auto_wait = 99.0
	var wait:= _time_to_next_beat(song_t)
	if wait < 0.12:
		wait += BEAT
	await get_tree().create_timer(wait).timeout
	var target_leaf: LilyPad = null
	if _giant_blocking():
		await get_tree().create_timer(4.2).timeout
		last_tap = last_giant.global_position
		handle_tap()
		_auto_wait = 0.3
		return
	if FLOW_MODE:
		await _auto_flow()
		_auto_wait = 0.05
		return
	for i in range(step, mini(step + 2, pads.size() - 1)):
		var bl:= _blockers(i)
		if not bl.is_empty():
			target_leaf = bl[0]
			break
	if target_leaf:
		await _auto_drag(target_leaf)
		_auto_jumps += 1
		_auto_wait = 0.05
		return
	elif _auto_jumps % 4 == 1:
		last_tap = frog.global_position + Vector2(_rng.randf_range(-60, 60), 80)
	else:
		_auto_wait = 0.3
		_auto_jumps += 1
		return
	handle_tap()
	if _auto_jumps == 3:
		get_tree().create_timer(0.3).timeout.connect(func (): _snap("clear_burst"))
	_auto_jumps += 1
	if landings == 5 and not _seen_mid:
		_seen_mid = true
		_snap("run_mid")
	_auto_wait = 0.05


var _seen_mid:= false


func _power_for(target: LilyPad, uv: Vector2) -> float:
	var from:= frog.global_position
	var c1:= (pads[step + 1] as LilyPad).uv_to_global(Vector2.ZERO)
	var d1:= (c1 - from).length()
	var d:= d1
	if target != pads[step + 1]:
		d = d1 + (target.uv_to_global(Vector2.ZERO) - c1).length()
	d += uv.y * target.ry()
	return d * CENTER_P / d1


func _auto_hold_snap(pw: float) -> void:
	charging = true
	pressing = true
	power = pw
	await get_tree().process_frame
	power = pw
	await get_tree().process_frame
	await _snap("charge")
	charging = false
	pressing = false
	power = 0.0
	frog.charge = 0.0


func _auto_skip_snap() -> void:
	var far: LilyPad = pads[step + 2]
	var pw:= _power_for(far, Vector2.ZERO)
	charging = true
	pressing = true
	power = pw
	await get_tree().process_frame
	power = pw
	await get_tree().process_frame
	await _snap("charge_skip")
	charging = false
	pressing = false
	power = 0.0
	frog.charge = 0.0
	handle_release(pw)


func _celebrate(pt: Vector2) -> void:
	_play("sparkle", 1.0, -2.0)
	_play("croak", 1.2, -4.0)
	flies.burst(pt + Vector2(0, -20), 26, true)
	for k in 3:
		get_tree().create_timer(0.12 * k).timeout.connect(func ():
			_spawn_ripple(pt - layer.global_position, 1.0 + 0.5 * k, 2))
	var l:= _label("두 칸 폴짝!", 24, Color(1.0, 0.85, 0.45))
	l.size = Vector2(220, 40)
	l.position = Vector2(vs.x * 0.5 - 110, vs.y * 0.22)
	l.z_index = 9
	l.pivot_offset = Vector2(110, 20)
	l.scale = Vector2(0.4, 0.4)
	add_child(l)
	var tw:= create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

	var fb:= create_tween()
	fb.tween_property(frog, "air_height", 26.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fb.tween_property(frog, "air_height", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fb.tween_property(frog, "air_height", 14.0, 0.12)
	fb.tween_property(frog, "air_height", 0.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	celebrate_t = 1.2
	var n:= 0
	for k in kois:
		if n < 3 and (k as Koi).position.distance_to(pt - layer.global_position) < 260.0:
			(k as Koi).do_leap()
			n += 1
	_log("skip_celebrate")
	if shots_dir != "":
		await get_tree().create_timer(0.3).timeout
		_snap("celebrate")


var crowd: Array = []
var kois: Array = []
var small_fish: Array = []
var lotus_pad: LilyPad


func _water_tex(i: int) -> Texture2D:
	var cols:= [[Color(0.1, 0.27, 0.19), Color(0.06, 0.19, 0.13)],
		[Color(0.08, 0.25, 0.24), Color(0.05, 0.17, 0.18)],
		[Color(0.1, 0.2, 0.24), Color(0.06, 0.12, 0.17)]]
	var g:= Gradient.new()
	g.set_color(0, cols[i % 3][0])
	g.set_color(1, cols[i % 3][1])
	var gt:= GradientTexture2D.new()
	gt.gradient = g
	gt.width = 360
	gt.height = 640
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	return gt


func _build_pond() -> void:
	for c in crowd:
		if is_instance_valid(c.node):
			(c.node as Node).queue_free()
	crowd.clear()
	open_segs.clear()
	opened_upto = 0
	seg_open.clear()
	cleared = 0
	giant_pending = false
	_next_giant = 2
	_giant_round_n = 0
	for sl in sunken:
		if is_instance_valid(sl):
			(sl as Node).queue_free()
	sunken.clear()
	for k in kois:
		if is_instance_valid(k):
			(k as Node).queue_free()
	kois.clear()
	if lotus_pad:
		lotus_pad.queue_free()
		lotus_pad = null
	for i in pads.size():
		(pads[i] as LilyPad).reveal = 1.0 if i <= 1 else 0.0
	_spawn_crowd((pads[0] as LilyPad).position.y + 420.0, (pads[pads.size() - 1] as LilyPad).position.y - 40.0)
	for i in range(2, pads.size()):
		_spawn_blockers(i)

	for i in 9:
		var k:= Koi.new()
		k.z_index = -3
		var at:= (pads[0] as LilyPad).position.lerp((pads[1] as LilyPad).position, _rng.randf()) + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-40, 40))
		k.setup(at, round_no * 100 + i)

		k.patch = 0
		k.length = _rng.randf_range(26.0, 46.0)
		k.speed = lerpf(52.0, 26.0, clampf((k.length - 34.0) / 50.0, 0.0, 1.0))
		layer.add_child(k)
		kois.append(k)

	small_fish.clear()
	for i in (1 if SPEC else (7 if FLOW_MODE else 4)):
		var f:= Koi.new()
		f.z_index = -1 if TARGET_MODE else 1
		var at0: Vector2 = (pads[0] as LilyPad).position + Vector2.from_angle(i * TAU / 7.0) * 70.0
		f.setup(at0, round_no * 1000 + 50 + i)
		f.length = _rng.randf_range(15.0, 19.0)
		f.speed = _rng.randf_range(45.0, 60.0)
		f.patch = 0
		f.length = _rng.randf_range(8.0, 12.0) if not FLOW_MODE else _rng.randf_range(30.0, 38.0)
		if FLOW_MODE:
			f.speed = _rng.randf_range(55.0, 72.0)
		layer.add_child(f)
		kois.append(f)
		small_fish.append(f)
	if FLOW_MODE and not SPEC:
		_book_extra_fish()
	_gather_fish(pads[0], true)
	_log("pond_built crowd=%d koi=%d" % [crowd.size(), kois.size()])


func _spawn_crowd(y_bottom: float, y_top: float) -> void:
	var near: Array = []
	for c in crowd:
		if is_instance_valid(c.node) and (c.node as LilyPad).position.y < y_bottom + 140.0 and (c.node as LilyPad).position.y > y_top - 140.0:
			near.append({ "p": (c.node as LilyPad).position, "r": (c.node as LilyPad).rx()})
	for p in pads:
		if TARGET_MODE and (p as LilyPad).reveal < 0.5 and not (step < pads.size() and p == pads[step]):
			continue
		var pp:= (p as LilyPad).position
		if pp.y < y_bottom + 200.0 and pp.y > y_top - 200.0:
			near.append({ "p": pp, "r": (p as LilyPad).base_width * 0.45})
	var tries:= int(absf(y_bottom - y_top) * (3.2 if TARGET_MODE else 2.2))
	for t in tries:
		var at:= Vector2(_rng.randf_range(-40.0, 400.0), _rng.randf_range(y_top, y_bottom))
		var r:= _rng.randf_range(46.0, 78.0)
		if SPEC and absf(at.x - _path_x_at(at.y)) > BANK_FREE:
			# anchored bank pads vary more in size: some small, some really big
			r = _rng.randf_range(40.0, 90.0)
		var ok:= true
		for q in near:
			if at.distance_to(q.p) < (r + q.r) * (0.62 if TARGET_MODE else 0.8):
				ok = false
				break
		if not ok:
			continue
		if _channel_clear(at, r).distance_to(at) > 1.0:
			continue
		if step < pads.size() - 1 and pads.size() > 1 and _dist_to_segment(at, (pads[0] as LilyPad).position, (pads[1] as LilyPad).position) < r + 64.0 and step == 0 and not TARGET_MODE:
			continue
		var c:= LilyPad.new()
		c.setup(r * 2.0, _rng.randf() * TAU)
		c.decor = true
		c.position = at
		layer.add_child(c)
		if TARGET_MODE:
			c.apply_height(_rng.randf())
		_maybe_flower(c)
		crowd.append({ "node": c, "home": at})
		near.append({ "p": at, "r": r})


func _cleanup_behind() -> void:
	var limit: float = (pads[step] as LilyPad).position.y + 520.0
	var keep: Array = []
	for c in crowd:
		if not is_instance_valid(c.node):
			continue
		if (c.node as LilyPad).position.y > limit:
			(c.node as Node).queue_free()
		else:
			keep.append(c)
	crowd = keep
	var keep2: Array = []
	for sl in sunken:
		if is_instance_valid(sl) and (sl as Node2D).position.y > limit:
			(sl as Node).queue_free()
		elif is_instance_valid(sl):
			keep2.append(sl)
	sunken = keep2
	for i in range(0, maxi(step - 4, 0)):
		var p: LilyPad = pads[i]
		if is_instance_valid(p) and p.visible:
			p.visible = false
			p.process_mode = Node.PROCESS_MODE_DISABLED


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab:= b - a
	var t:= clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


const CHANNEL_HALF:= 58.0
var sunken: Array = []


func _line_channel(a: Vector2, b: Vector2, animate: bool) -> void:
	var j:= 0
	for sg in _last_curve:
		if _rng.randf() < 0.35:
			continue
		var pa: Vector2 = sg[0]
		var pb: Vector2 = sg[1]
		var ab:= (pb - pa).normalized()
		var nrm:= Vector2(-ab.y, ab.x)
		var sd:= 1.0 if _rng.randf() < 0.5 else -1.0
		var sl:= SunkenLeaf.new()
		sl.r = _rng.randf_range(26.0, 46.0)
		sl.rot = _rng.randf() * TAU
		sl.position = pa.lerp(pb, _rng.randf()) + nrm * sd * (float(sg[2]) + _rng.randf_range(-24.0, 4.0))
		sl.z_index = -5
		layer.add_child(sl)
		sunken.append(sl)
		if animate:
			var tw:= create_tween()
			tw.tween_interval(0.5 + j * 0.12)
			tw.tween_property(sl, "show", 1.0, 1.2)
		else:
			sl.show = 1.0
		j += 1


func _open_path(i: int, animate: bool) -> void:
	if i + 1 >= pads.size():
		return
	var a: Vector2 = (pads[i] as LilyPad).position
	var b: Vector2 = (pads[i + 1] as LilyPad).position
	var goal:= mini(i + 1 + _rng.randi_range(2, 4), pads.size() - 1)
	var from_i:= maxi(opened_upto, i)
	var n:= 0
	for s_i in range(from_i, goal):
		extra_delay = n * 0.32 if animate else 0.0
		var pa: Vector2 = (pads[s_i] as LilyPad).position
		var pb: Vector2 = (pads[s_i + 1] as LilyPad).position
		_open_corridor(pa, pb, (pads[s_i + 1] as LilyPad).rx(), animate)
		_line_channel(pa, pb, animate)
		seg_open[s_i] = true
		var pp: LilyPad = pads[s_i + 1]
		if pp.reveal < 1.0:
			if animate:
				var twp:= create_tween()
				twp.tween_interval(0.25 + extra_delay)
				twp.tween_property(pp, "reveal", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				pp.reveal = 1.0
		n += 1
	extra_delay = 0.0
	opened_upto = maxi(opened_upto, goal)
	var nxt: LilyPad = pads[i + 1]
	if nxt.reveal < 1.0:
		if animate:
			var tw:= create_tween()
			tw.tween_interval(0.25)
			tw.tween_property(nxt, "reveal", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_play("edge", 0.7, -10.0)
		else:
			nxt.reveal = 1.0

	for k in kois:
		(k as Koi).set_home((a + b) * 0.5, 90.0)
		if animate and not (k is Turtle):
			var kk:= k as Koi
			get_tree().create_timer(_rng.randf_range(0.0, 0.35)).timeout.connect(func ():
				if is_instance_valid(kk):
					kk.dash(a.lerp(b, _rng.randf_range(0.2, 0.9)) + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-30, 30)), 1.8))


func _open_to_lotus() -> void:
	if lotus_pad == null:
		return
	var a: Vector2 = (pads[step] as LilyPad).position
	_open_corridor(a, lotus_pad.position, 50.0, true)


var open_segs: Array = []
var _last_curve: Array = []


func _add_channel(a: Vector2, b: Vector2) -> void:
	var ab:= b - a
	var nrm:= Vector2(-ab.y, ab.x).normalized()
	var ctrl:= (a + b) * 0.5 + nrm * (_rng.randf_range(-60.0, 60.0) if not TARGET_MODE else _rng.randf_range(-34.0, 34.0))
	var n:= 6
	var prev:= a
	_last_curve.clear()
	var w0:= _rng.randf_range(58.0, 96.0) if not TARGET_MODE else _rng.randf_range(54.0, 64.0)
	var w1:= _rng.randf_range(58.0, 96.0) if not TARGET_MODE else _rng.randf_range(54.0, 64.0)
	for k in range(1, n + 1):
		var t:= k / float(n)
		var q:= a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		var half:= lerpf(w0, w1, t) + sin(t * PI * 2.0 + w0) * 10.0 + _rng.randf_range(-8.0, 8.0)
		open_segs.append([prev, q, half])
		_last_curve.append([prev, q, half])
		prev = q
	while open_segs.size() > 80:
		open_segs.pop_front()


func _channel_nearest(p: Vector2) -> Array:
	var best:= Vector2.INF
	var bh:= CHANNEL_HALF
	var bd:= 1000000000.0
	for sg in open_segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		if p.y < minf(a.y, b.y) - 220.0 or p.y > maxf(a.y, b.y) + 220.0:
			continue
		var ab:= b - a
		var t:= clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q:= a + ab * t
		var d:= p.distance_to(q) - float(sg[2])
		if d < bd:
			bd = d
			best = q
			bh = sg[2]
	return [best, bh]


func _channel_clear(p: Vector2, r: float, bank:= 0.72) -> Vector2:
	var out:= p
	for it in 4:
		var info:= _channel_nearest(out)
		var q: Vector2 = info[0]
		if q == Vector2.INF:
			return out
		var need: float = float(info[1]) + r * bank
		var d:= out.distance_to(q)
		if d >= need - 0.5:
			return out
		var dirv:= (out - q).normalized() if d > 0.5 else Vector2(1.0 if out.x < 180.0 else -1.0, 0.0) * -1.0
		out = q + dirv * (need + 3.0)
	return out


var extra_delay:= 0.0


func _open_corridor(a: Vector2, b: Vector2, end_r: float, animate: bool) -> void:
	var ab:= (b - a).normalized()
	var nrm:= Vector2(-ab.y, ab.x)
	var half:= CHANNEL_HALF
	var moved:= 0
	_add_channel(a, b)
	for c in crowd:
		var node: LilyPad = c.node
		var cur: Vector2 = node.position
		var r:= node.rx()
		var d:= _dist_to_segment(cur, a, b)
		if d < r + half + 70.0 and node.lit < 1.0:
			if animate:
				create_tween().tween_property(node, "lit", 1.0, 0.8)
			else:
				node.lit = 1.0
		var dest:= _channel_clear(cur, r, node.bank)
		if dest.distance_to(cur) < 1.0:
			continue
		var side:= signf((dest - cur).dot(nrm))
		if side == 0.0:
			side = 1.0
		moved += 1
		if animate:

			var delay:= clampf(cur.distance_to(a) / 520.0, 0.0, 0.6) + extra_delay
			var swirl:= ab * _rng.randf_range(50.0, 120.0) * (1.0 if _rng.randf() < 0.6 else -1.0)
			var shove:= (dest - cur).normalized() * _rng.randf_range(60.0, 110.0)
			get_tree().create_timer(delay).timeout.connect(func ():
				if is_instance_valid(node):
					node.rest = dest
					_settle_leaf(c, dest)
					node.nudge(0.0)   # v110: no rim flash when the path pushes pads aside (it flickered across the pond)
					node.bump(swirl + shove)
					_spawn_ripple(node.position, 0.5, 1))
			var spin:= create_tween()
			spin.tween_interval(delay)
			spin.tween_property(node, "notch_angle", node.notch_angle + side * _rng.randf_range(0.3, 0.7), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			node.position = dest
			node.rest = dest
			_settle_leaf(c, dest)
	if animate and moved > 0:
		_spawn_ripple((a + b) * 0.5, 1.4, 2)
		_play("nudge", 0.8, -10.0)
	_log("path_open moved=%d" % moved)


func _koi_gather(dest: Vector2) -> void:
	var local:= dest - layer.global_position
	for k in kois:
		if (k as Koi).position.distance_to(local) < 260.0:
			(k as Koi).orbit(local, 70.0, 0.8)


func _koi_splash(global_pt: Vector2, center: bool) -> void:
	var local:= global_pt - layer.global_position
	var nearest: Koi = null
	var best:= 1000000000.0
	for k in kois:
		var kk:= k as Koi
		kk.flee(local)
		var d:= kk.position.distance_to(local)
		if d < best:
			best = d
			nearest = kk
	if nearest and best < 220.0:
		nearest.do_leap()
		_splash(nearest.global_position, 8)

	var n:= 0
	for f in small_fish:
		if not is_instance_valid(f):
			continue
		var ff:= f as Koi
		if ff.position.distance_to(local) < 180.0 and n < 2:
			n += 1
			var delay:= 0.05 + n * 0.12
			get_tree().create_timer(delay).timeout.connect(func ():
				if is_instance_valid(ff):
					ff.do_leap()
					_splash(ff.global_position, 5)
					_spawn_ripple(ff.position, 0.5, 2))
	_spawn_ripple(local, 1.1, 3)


func _apply_water(i: int) -> void:
	var pal: Array = [
		[Color(0.05, 0.22, 0.15), Color(0.09, 0.33, 0.22), Color(0.28, 0.54, 0.36)],
		[Color(0.03, 0.2, 0.24), Color(0.07, 0.36, 0.38), Color(0.32, 0.62, 0.58)],
		[Color(0.05, 0.12, 0.26), Color(0.1, 0.25, 0.42), Color(0.36, 0.52, 0.68)],
	][i % 3]
	if water_sv == null:
		water_sv = SubViewport.new()
		water_sv.disable_3d = true
		water_sv.transparent_bg = false
		water_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		water_sv.size = Vector2i(180, 320)
		add_child(water_sv)
		water_rect = ColorRect.new()
		water_rect.size = Vector2(180, 320)
		var wm:= ShaderMaterial.new()
		wm.shader = preload("res://scripts/water.gdshader")
		water_rect.material = wm
		water_sv.add_child(water_rect)
		bg.material = null
		bg.texture = water_sv.get_texture()
		_layout()
	var mat:= water_rect.material as ShaderMaterial
	mat.set_shader_parameter("deep", pal[0])
	mat.set_shader_parameter("mid", pal[1])
	mat.set_shader_parameter("light", pal[2])


func _gather_fish(pad: LilyPad, instant: bool) -> void:
	if not is_instance_valid(pad):
		return
	for f in small_fish:
		var k:= f as Koi
		if instant:
			k.position = pad.position + Vector2.from_angle(_rng.randf() * TAU) * (pad.rx() + 16.0)
		k.orbit(pad.position, pad.rx() + 14.0 + _rng.randf() * 10.0, 9999.0)
		k.orbit_node = pad


func _scatter_from(pad: LilyPad) -> void:
	pad.nudge()
	pad.takeoff()
	for f in small_fish:
		(f as Koi).flee(pad.position, true)
		(f as Koi).mode_t = 1.4
	for k in kois:
		if k in followers:
			continue
		(k as Koi).flee(pad.position)
	_spawn_ripple(pad.position, 1.1, 2)


func _load_best() -> void:
	var cf:= ConfigFile.new()
	if cf.load("user://moonlit_pond.cfg") == OK:
		best = int(cf.get_value("score", "best", 0))


func _save_best() -> void:
	var cf:= ConfigFile.new()
	cf.set_value("score", "best", best)
	cf.save("user://moonlit_pond.cfg")


func _update_beat(delta: float) -> void:
	song_t += delta
	if bgm and bgm.playing:
		var p:= bgm.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		if p > 0.05 and absf(p - song_t) < 1.0:
			song_t = lerpf(song_t, p, 0.2)
	var b:= _beat_index(song_t)
	if b != _last_beat:
		if b > _last_beat or b == 0:
			_on_beat()
		_last_beat = b
	beat_pulse = maxf(beat_pulse - delta * 3.0, 0.0)
	hud.queue_redraw()


func _on_beat() -> void:
	beat_pulse = 1.0
	if not in_intro and not bloomed and not locked and not frog.jumping and seg_open.get(step, false) and _held == null and not _giant_blocking() and not giant_pending and not (lunger != null and is_instance_valid(lunger) and lunger.state == "stalk" and lunger.stalk_t < 2.4) and _since_land > BEAT * 1.4 and step + 1 < pads.size():
		_auto_hop()
	if not in_intro:
		frog.beat_bounce()
	for k in kois:
		if is_instance_valid(k):
			(k as Koi).add_echo()


func _beat_index(t: float) -> int:
	var lo:= 0
	var hi: int = BeatMap.BEATS.size() - 1
	if t < BeatMap.BEATS[0]:
		return -1
	while lo < hi:
		var mid:= (lo + hi + 1) / 2
		if BeatMap.BEATS[mid] <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo


func _beat_distance(t: float) -> float:
	var i:= _beat_index(t)
	var d:= 99.0
	for j in [i, i + 1]:
		if j >= 0 and j < BeatMap.BEATS.size():
			d = minf(d, absf(t - float(BeatMap.BEATS[j])))
	return d


func _time_to_next_beat(t: float) -> float:
	var i:= _beat_index(t) + 1
	if i >= BeatMap.BEATS.size():
		return BEAT
	return float(BeatMap.BEATS[i]) - t


func _judge_rhythm() -> void:
	var d:= _beat_distance(song_t)
	var at:= frog.global_position + Vector2(0, -60)
	if d <= 0.09:
		rhythm_combo += 1
		score += 3 * (1 + mini(rhythm_combo, 20) / 5)
		if not FLOW_MODE:
			_float_text("맑음!", at, Color(0.8, 1.0, 0.95))
		_play("p%d" % mini(rhythm_combo % 6, 5), 1.0, -4.0 if not FLOW_MODE else -12.0)
	elif d <= 0.17:
		rhythm_combo += 1
		score += 1 * (1 + mini(rhythm_combo, 20) / 5)
		if not FLOW_MODE:
			_float_text("좋아", at, Color(0.95, 1.0, 0.85))
	else:
		rhythm_combo = 0
	best_combo = maxi(best_combo, rhythm_combo)
	if FLOW_MODE and rhythm_combo >= 20:
		_unlock("white")
	if rhythm_combo > 0 and rhythm_combo % TURTLE_EVERY == 0:
		_deep_turtle()
	_log("rhythm d=%.3f combo=%d score=%d" % [d, rhythm_combo, score])
	hud.queue_redraw()


func _deep_turtle() -> void:
	if last_giant and is_instance_valid(last_giant):
		await last_giant.tree_exited
	turtles += 1
	var at:= frog.global_position
	_play("bloom", 1.0, -3.0)
	flies.burst(at + Vector2(0, -30), 36, true)
	celebrate_t = 1.2
	for k in 4:
		get_tree().create_timer(0.15 * k).timeout.connect(func ():
			_spawn_ripple(at - layer.global_position, 1.2 + 0.7 * k, 2))
	var l:= _label("깊은 물속의 거북이가 인사해요", 18, Color(0.88, 1.0, 0.95))
	l.size = Vector2(300, 34)
	l.position = Vector2(vs.x * 0.5 - 150, vs.y * 0.22)
	l.modulate.a = 0.0
	l.z_index = 9
	add_child(l)
	var tw:= create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	if big_turtle and is_instance_valid(big_turtle):
		big_turtle.queue_free()
	big_turtle = Turtle.new()
	big_turtle.z_index = -4
	var center:= _path_point(float(step) + 0.7)
	var from_left:= _rng.randf() < 0.5
	big_turtle.setup(center + Vector2(-80 if from_left else 80, 20), round_no * 31 + turtles)
	big_turtle.deep = true
	big_turtle.length = 240.0
	big_turtle.speed = 22.0
	big_turtle.heading = -0.5 if from_left else PI + 0.5
	big_turtle.goal = center + Vector2(160 if from_left else -160, -120)
	big_turtle.home = big_turtle.goal
	big_turtle.home_radius = 10.0
	layer.add_child(big_turtle)

	_log("deep_turtle n=%d" % turtles)
	if shots_dir != "":
		await get_tree().create_timer(2.2).timeout
		_snap("turtle_%d" % turtles)


var last_giant: Node = null


func _giant_block() -> void:
	if step + 1 >= pads.size():
		return
	var g:= GiantFish.new()
	last_giant = g
	g.z_index = -1
	var a: Vector2 = (pads[step] as LilyPad).position
	var b: Vector2 = (pads[step + 1] as LilyPad).position
	g.position = a.lerp(b, 0.58)
	g.facing = (a - g.position).angle() + _rng.randf_range(-0.4, 0.4)
	g.size = 200.0
	giant_count += 1
	g.kind = "red"
	g.watch = frog
	g.peek = 0.9
	g.blocking = true
	_giant_round_n += 1
	layer.add_child(g)
	_play("plop", 0.5, -2.0)
	for k in 3:
		get_tree().create_timer(0.8 + 0.25 * k).timeout.connect(func ():
			_spawn_ripple(g.position, 1.2 + 0.6 * k, 2))
	get_tree().create_timer(1.6).timeout.connect(func ():
		if is_instance_valid(g) and g.blocking and _giant_round_n <= 2:
			_show_quip("커다란 물고기가 길을 막았어요! 밀어 주세요"))
	_log("giant_block kind=%s" % g.kind)
	if shots_dir != "":
		var gk: String = g.kind
		get_tree().create_timer(1.2).timeout.connect(func (): _snap("giant_" + gk + "_deep"))
		get_tree().create_timer(3.9).timeout.connect(func (): _snap("giant_" + gk))


var giant_pending:= false
const LUNGE_STALK:= []
var lunger: GiantLunge = null


func _start_lunge() -> void:
	var g:= GiantLunge.new()
	g.prey_pt = (pads[step] as LilyPad).position
	g.length = 300.0
	g.z_index = -4
	layer.add_child(g)
	lunger = g
	g.splashed.connect(_on_lunge_splash)
	g.missed.connect(_on_lunge_missed)
	_log("lunge_stalk step=%d" % step)
	get_tree().create_timer(1.4).timeout.connect(func ():
		if is_instance_valid(g) and g.state == "stalk":
			_show_quip("…발밑에 뭔가 있어요"))
	if shots_dir != "":
		get_tree().create_timer(2.0).timeout.connect(func (): _snap("lunge_stalk"))


func _on_lunge_splash(at_global: Vector2, big: bool) -> void:
	var local:= at_global - layer.global_position
	_spawn_ripple(local, 1.6 if big else 1.0, 3)
	_splash(at_global, 14 if big else 7)
	if big:
		_play("plop", 0.55, -1.0)
		(pads[maxi(step - 1, 0)] as LilyPad).nudge()
		_push_leaves(local, 90.0, 110.0, false)
		for f in small_fish:
			if is_instance_valid(f):
				(f as Koi).flee(local, true)
		if shots_dir != "":
			_snap("lunge_breach")
	else:
		_play("plop", 0.8, -6.0)


func _on_lunge_missed() -> void:
	_log("lunge_missed")
	get_tree().create_timer(0.35).timeout.connect(func ():
		_show_quip(["휴~ 아슬아슬했어요!", "간발의 차이! 잡힐 뻔했다", "어림없지롱~"][_rng.randi() % 3]))
	lunger = null
var giant_count:= 0
var _next_giant:= 2
var _giant_round_n:= 0


# v0.30: a blocking giant every 2-3 hops (was every 6th)
func _giant_due(jump_no: int) -> bool:
	if jump_no < _next_giant or _giant_blocking():
		return false
	_next_giant = jump_no + _rng.randi_range(2, 3)
	return true


func _auto_drag(nd: LilyPad) -> void:
	var start:= nd.position + layer.global_position
	last_tap = start
	_finger = start - layer.global_position
	_stroke_n = 0
	handle_tap()
	var seg:= _held_seg
	if _held == null or seg < 0 or seg + 1 >= pads.size():
		_finger_up()
		return
	var a: Vector2 = (pads[seg] as LilyPad).position
	var b: Vector2 = (pads[seg + 1] as LilyPad).position
	var ab:= (b - a).normalized()
	var nrm:= Vector2(-ab.y, ab.x)
	var side:= signf((nd.position - a).dot(nrm))
	if side == 0.0:
		side = 1.0
	var steps:= 10
	for k in steps:
		await get_tree().process_frame
		await get_tree().process_frame
		var p:= start + nrm * side * (k + 1) * 13.0
		_finger_move(p, nrm * side * 600.0)
		if shots_dir != "" and k == 7 and _drag_snaps < 4:
			_drag_snaps += 1
			_snap("drag_hold_%d" % _drag_snaps)
	_finger_up()


var _drag_snaps:= 0


func _giant_blocking() -> bool:
	return last_giant != null and is_instance_valid(last_giant) and (last_giant as GiantFish).blocking


func _shoo_giant(screen_pt: Vector2) -> bool:
	if not _giant_blocking() or screen_pt == Vector2.INF:
		return false
	var g:= last_giant as GiantFish
	if not g.hit_test(screen_pt):
		return false
	g.shoo()
	_spawn_ripple(g.position, 2.0, 3)
	_fish_burst(g.position)
	_fish_burst(g.position + Vector2(30, -10))
	flies.burst(screen_pt, 24, true)
	_play("bloom", 0.8, -4.0)
	score += 5
	hud.queue_redraw()
	_banner("큰 물고기가 비켜 줬어요", Color(0.9, 1.0, 0.95))
	_log("giant_shoo")
	return true


func _giant_fish(target: LilyPad) -> void:
	if _giants_alive() > 0:
		return
	var g:= GiantFish.new()
	g.z_index = -4
	var side:= -1.0 if target.position.x > 180.0 else 1.0

	g.position = target.position + Vector2(side * 150.0, -30.0)
	g.facing = (frog.global_position - layer.global_position - g.position).angle()
	g.size = _rng.randf_range(190.0, 240.0)
	g.kind = "gold"
	g.watch = frog
	g.peek = 0.72
	layer.add_child(g)
	_play("plop", 0.55, -2.0)
	for k in 3:
		get_tree().create_timer(1.2 + 0.25 * k).timeout.connect(func ():
			_spawn_ripple(g.position + Vector2.from_angle(g.facing) * 100.0, 1.0 + 0.6 * k, 2))
	for f in kois:
		if (f as Koi).position.distance_to(g.position) < 260.0:
			(f as Koi).flee(g.position, true)
	_log("giant_fish")
	if shots_dir != "":
		get_tree().create_timer(2.4).timeout.connect(func (): _snap("giant_fish"))


func _huge_turtle(target: LilyPad, white:= false, red:= false) -> void:
	var t:= Turtle.new()
	if white or red:
		t.white = white
		t.red = red
		t.TEX = Turtle.TEX_WHITE
	t.z_index = -4
	var from_left:= _rng.randf() < 0.5
	# v98: crosses the upper or middle part of the screen (it used to follow the dew's next pad, so it
	# always passed along the bottom of the screen right by the dew)
	var vsz:= get_viewport_rect().size
	var y:= -layer.position.y + vsz.y * _rng.randf_range(0.18, 0.5)
	t.setup(Vector2(-160.0 if from_left else 520.0, y + 90.0), round_no * 53 + step)
	t.deep = true
	t.life = 0.0
	t.length = 520.0
	t.speed = 78.0
	t.heading = -0.25 if from_left else PI + 0.25
	t.goal = Vector2(560.0 if from_left else -200.0, y - 120.0)
	t.home = t.goal
	t.home_radius = 5.0
	t.pass_through = true
	layer.add_child(t)
	_play("bloom", 0.7, -4.0)
	for f in kois:
		(f as Koi).flee(t.position, true)
	_log("huge_turtle white=%s red=%s" % [white, red])
	if shots_dir != "":
		get_tree().create_timer(3.0).timeout.connect(func (): _snap("huge_turtle_red" if red else ("huge_turtle_white" if white else "huge_turtle")))


const DEW_STAGE_TEXT:= {
	1: "이슬이 모양을 바꾸는 연습을 해요",
	2: "조금만 더… 귀가 살짝 나왔어요",
	3: "작은 곰돌이가 되었어요!",
	4: "톡, 다시 이슬로 돌아가요",
}
func _dew_stage_for(n: int) -> int:
	var m:= n % 16
	if m == 15: return 4
	if m >= 12: return 3
	if m >= 8: return 2
	if m >= 4: return 1
	return 0


func _update_dew_stage() -> void:
	var st:= _dew_stage_for(landings)
	if st == frog.stage:
		return
	frog.set_stage(st)
	var at:= frog.global_position + Vector2(0, -30)
	if st == 3:
		_play("bloom", 1.3, -4.0)
		flies.burst(at, 28, true)
	elif st == 4:
		_play("plop", 1.4, -3.0)
		flies.burst(at, 16, false)
		get_tree().create_timer(1.2).timeout.connect(func (): if frog.stage == 4: frog.set_stage(0))
	if DEW_STAGE_TEXT.has(st):
		var l:= _label(DEW_STAGE_TEXT[st], 15, Color(1.0, 0.98, 0.92))
		l.size = Vector2(320, 30)
		l.position = Vector2(vs.x * 0.5 - 160, vs.y * 0.16)
		l.modulate.a = 0.0
		l.z_index = 9
		add_child(l)
		var tw:= create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.5)
		tw.tween_interval(1.5)
		tw.tween_property(l, "modulate:a", 0.0, 0.7)
		tw.tween_callback(l.queue_free)
	_log("dew_stage %d" % st)
	if shots_dir != "" and (st == 1 or st == 3):
		get_tree().create_timer(1.0).timeout.connect(func (): _snap("dew_stage_%d" % st))


func _boat_pass() -> void:
	var b:= Boat.new()
	var lane:= 1.0 if _rng.randf() < 0.5 else -1.0
	var pts:= PackedVector2Array()

	var idx:= float(step) + 1.9
	while idx >= float(step) - 1.8:
		var p0:= _path_point(idx)
		var p1:= _path_point(idx + 0.1)
		var nrm:= (p1 - p0).normalized().orthogonal()
		pts.append(p0 + nrm * lane * 36.0)
		idx -= 0.25
	b.route = pts
	b.speed = 48.0
	b.z_index = 2
	layer.add_child(b)
	_play("plop", 0.7, -8.0)
	_log("boat_pass")
	if shots_dir != "":
		get_tree().create_timer(1.5).timeout.connect(func ():
			_log("boat at %s alpha=%.2f len=%d frog=%s" % [b.global_position if is_instance_valid(b) else Vector2.ZERO, b.alpha if is_instance_valid(b) else -1.0, pts.size(), frog.global_position])
			_snap("boat"))


const QUIPS:= [
	["통!", "어이쿠, 미끄러워라", "잎사귀야, 실례할게~", "오늘 컨디션 촉촉한데?", "발이 없어도 점프는 해요", "출발이 좋아요, 손가락님"],
	["나 사실 물이야… 쉿", "점프할 때마다 0.1g씩 빠지는 기분", "물고기들아, 박수 좀 쳐 줄래?", "거북이 형님, 안녕하세요~", "이 정도면 국가대표 이슬", "연잎 위 착지, 10점 만점에 10점!", "어지러워… 아니 신나!"],
	["엄마, 나 연못 건너는 중이야!", "이슬 인생 최장 기록 경신 중", "손가락님 리듬 장난 아니네요", "누가 나 좀 말려줘… 아니 말리지 마", "이러다 증발하는 거 아냐? 농담~", "연잎들이 길을 비켜 주다니, 나 유명해졌나?", "나 지금 좀 멋있는 것 같아"],
	["슬슬 연못의 전설이 되어가는 중", "누르는 손가락에서 사랑이 느껴져요", "이쯤 되면 물방울계의 아이돌", "곰돌이 연습 일지: 귀 만들기 성공(?)", "이 연못, 사실 내가 다 건넜다고 소문내 줘", "아직도 누르는 당신… 최고예요", "통통통, 이건 내 노래야"],
]
const QUIP_MISS:= ["앗, 박자 놓쳤다… 괜찮아 난 물이니까", "방금 건 연습이었어요", "리듬이 살짝 미끄러졌네", "쉿, 아무도 못 봤지?"]
const QUIP_BEAR:= ["곰… 곰돌이 됐다! 꿀 어딨어?", "귀가 생겼어! 잘 들린다~", "곰돌이 모드: 포근함 200%"]


func _maybe_quip() -> void:
	if FLOW_MODE:
		return
	var tier:= clampi(taps / 8, 0, QUIPS.size() - 1)
	var every:= 3 if taps < 16 else 2
	var text:= ""
	if rhythm_combo == 0 and taps > 2 and _rng.randf() < 0.5:
		text = QUIP_MISS[_rng.randi() % QUIP_MISS.size()]
	elif frog.stage == 3 and _rng.randf() < 0.6:
		text = QUIP_BEAR[_rng.randi() % QUIP_BEAR.size()]
	elif taps % every == 0:
		var pool: Array = QUIPS[tier]
		var fresh: Array = []
		for q in pool:
			if not _quip_used.has(q):
				fresh.append(q)
		if fresh.is_empty():
			for q in pool:
				_quip_used.erase(q)
			fresh = pool.duplicate()
		text = fresh[_rng.randi() % fresh.size()]
		_quip_used[text] = true
	if text != "":
		_show_quip(text)


var _quip_label: Label = null


func _show_quip(text: String) -> void:
	if _quip_label and is_instance_valid(_quip_label):
		_quip_label.queue_free()
	var l:= _label(text, 13, Color(1.0, 0.99, 0.94))
	_quip_label = l
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.12, 0.09, 0.62)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	l.add_theme_stylebox_override("normal", sb)
	l.z_index = 9
	l.modulate.a = 0.0
	add_child(l)
	await get_tree().process_frame
	var w:= l.get_combined_minimum_size().x
	l.size = Vector2(w, 0)
	var tw:= create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_method(func (k: float):
		if is_instance_valid(l) and is_instance_valid(frog):
			var at:= frog.global_position + Vector2(-w * 0.5, -78.0 - k * 22.0)
			at.x = clampf(at.x, 8.0, vs.x - w - 8.0)
			l.position = at, 0.0, 1.0, 2.0)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(l.queue_free)
	_log("quip " + text)
	if shots_dir != "" and taps == 9:
		get_tree().create_timer(0.5).timeout.connect(func (): _snap("quip"))


var _wind_t:= 0.0
var _entry_of: Dictionary = {}


func _leaf_physics(delta: float) -> void:
	_wind_t += delta
	if crowd.is_empty():
		return
	var top:= -layer.position.y - 250.0
	var bottom:= -layer.position.y + vs.y + 250.0
	var act: Array = []
	_entry_of.clear()
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd):
			continue
		if nd.rest == Vector2.INF:
			nd.rest = nd.position
		if nd.position.y < top or nd.position.y > bottom:
			continue
		if nd.modulate.a < 0.05:
			continue
		act.append(nd)
		_entry_of[nd.get_instance_id()] = c
	act.sort_custom(func (p1, p2): return (p1 as LilyPad).position.y < (p2 as LilyPad).position.y)
	var rads: Array[float] = []
	var rmax:= 0.0
	for nd in act:
		var rr:= (nd as LilyPad).rx()
		rads.append(rr)
		rmax = maxf(rmax, rr)
	for x in act.size():
		var pa: LilyPad = act[x]
		var ra: float = rads[x]
		for y in range(x + 1, act.size()):
			var pb: LilyPad = act[y]
			if pb.position.y - pa.position.y > (ra + rmax) * 0.56:
				break
			if SPEC and pa.fixed_bank != pb.fixed_bank:
				# loose pads tuck in under the anchored bank instead of shoving it
				continue
			var d:= pa.position - pb.position
			var lim:= (ra + rads[y]) * 0.56
			var dl:= d.length()
			if SPEC and dl < lim and dl > 0.01 and (pa.hit_t > 0.0) != (pb.hit_t > 0.0):
				# the moving pad clears room: the one in its way gives up its spot for good
				var mover:= pa if pa.hit_t > 0.0 else pb
				var other:= pb if mover == pa else pa
				var away:= (other.position - mover.position) / dl
				var mv:= away * (lim - dl) * clampf(delta * 8.0, 0.0, 1.0)
				var ce = _entry_of.get(other.get_instance_id())
				if ce != null and not other.held:
					ce.home += mv
					ce.out = ce.home
					other.rest += mv
					if (lim - dl) > 10.0:
						other.hit_t = maxf(other.hit_t, 0.2)
			if dl < lim and dl > 0.01:
				var nn:= d / dl
				var closing:= (pb.vel - pa.vel).dot(nn)
				if (pa.hit_t > 0.0 or pb.hit_t > 0.0) and closing > 90.0 and billiard_n < 8 and not pa.held and not pb.held:

					var dv:= nn * closing * 0.7
					pa.vel += dv
					pb.vel -= dv
					var fresh:= pb if pa.hit_t > 0.0 else pa
					if fresh.hit_t <= 0.0:
						_billiard_hit(fresh, (pa.position + pb.position) * 0.5)
					fresh.hit_t = 0.45
				var f:= nn * (lim - dl) * 6.0
				pa.vel += f * delta
				pb.vel -= f * delta
	var dew:= frog.global_position - layer.global_position
	for nd in act:
		var pd:= nd as LilyPad
		var dd:= pd.position - dew
		var lim2:= pd.rx() * 0.85 + 14.0
		if dd.length() < lim2 and not frog.jumping:
			pd.vel += dd.normalized() * (lim2 - dd.length()) * 4.0 * delta

		if not pd.held and not open_segs.is_empty() and (pd.get_instance_id() + Engine.get_process_frames()) % 3 == 0:
			var q:= _channel_clear(pd.position, pd.rx() * 0.9, pd.bank)
			if q.distance_to(pd.position) > 0.5:
				pd.vel += (q - pd.position) * 10.0 * delta
				pd.position = pd.position.lerp(q, clampf(delta * 4.0, 0.0, 1.0))
			if (pd.get_instance_id() + Engine.get_process_frames()) % 30 == 0:
				pd.rest = _channel_clear(pd.rest, pd.rx(), pd.bank)

		var gust:= sin(_wind_t * 0.55 + pd.position.y * 0.012) * 0.6 + sin(_wind_t * 0.23 + pd.position.x * 0.02) * 0.4
		pd.vel += Vector2(gust * 7.0, cos(_wind_t * 0.4 + pd.position.x * 0.015) * 3.0) * delta * 4.0
		if pd.held:
			continue
		var spring:= (4.2 if SPEC else 0.7) if pd.hit_t > 0.0 else 3.2
		pd.vel += (pd.rest - pd.position) * spring * delta
		pd.vel *= exp(-((4.2 if SPEC else 1.4) if pd.hit_t > 0.0 else 2.6) * delta)
		pd.position += pd.vel * delta


func _push_leaves(at: Vector2, radius: float, power: float, sparkle: bool) -> void:
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd):
			continue
		var d:= nd.position - at
		var reach:= radius + nd.rx()
		if d.length() < reach:
			var k:= 1.0 - d.length() / reach
			nd.bump(d.normalized() * power * (0.4 + k))
			if sparkle and k > 0.5:
				flies.burst(nd.position + layer.global_position, 6, false)


func _touch_leaf(screen_pt: Vector2) -> void:
	if screen_pt == Vector2.INF:
		return
	var local:= screen_pt - layer.global_position
	var best: LilyPad = null
	var bd:= 1000000000.0
	for c in crowd:
		var nd: LilyPad = c.node
		if not is_instance_valid(nd):
			continue
		var d:= nd.position.distance_to(local)
		if d < nd.rx() and d < bd:
			bd = d
			best = nd
	if best == null:
		_spawn_ripple(local, 0.6, 1)
		var on_pad:= false
		for pp in pads:
			if is_instance_valid(pp) and (pp as LilyPad).visible and (pp as LilyPad).position.distance_to(local) < (pp as LilyPad).rx():
				on_pad = true
				break
		if not on_pad:
			_drop_food(local)
		return
	var dew:= frog.global_position - layer.global_position
	var near:= clampf(1.0 - best.position.distance_to(dew) / 260.0, 0.0, 1.0)
	var away:= (best.position - local).normalized() if bd > 4.0 else Vector2.from_angle(_rng.randf() * TAU)
	best.bump(away * (220.0 + 200.0 * near))
	best.nudge()
	best.hit_t = 1.4
	billiard_n = 0
	billiard_t = 1.6
	_push_leaves(local, 40.0, 50.0 + 60.0 * near, false)
	_spawn_ripple(local, 0.8 + near, 2)
	flies.burst(screen_pt, int(10 + 18 * near), near > 0.5)
	_play("sparkle", _rng.randf_range(0.9, 1.2), -8.0)
	_log("touch_leaf near=%.2f" % near)


var billiard_n:= 0
var billiard_t:= 0.0


func _billiard_hit(nd: LilyPad, at: Vector2) -> void:
	billiard_n += 1
	billiard_t = 1.2
	nd.nudge(0.35)   # v110: pad-to-pad bumps light the rim only softly
	_spawn_ripple(at, 0.6, 1)
	flies.burst(at + layer.global_position, 5 + billiard_n * 2, billiard_n >= 3)
	_play("p%d" % mini(billiard_n - 1, 4), 1.0, -9.0)


func _update_billiards(delta: float) -> void:
	if FLOW_MODE:
		billiard_t = 0.0
		billiard_n = 0
		return
	if billiard_t <= 0.0:
		return
	billiard_t -= delta
	if billiard_t <= 0.0 and billiard_n >= 2:
		var bonus:= billiard_n * 2
		score += bonus
		var txt:= "연잎 당구 %d연쇄! +%d" % [billiard_n, bonus]
		if billiard_n >= 5:
			txt = "연잎 당구 마스터! %d연쇄 +%d" % [billiard_n, bonus]
		_banner(txt, Color(0.95, 1.0, 0.75))
		_log("billiards n=%d" % billiard_n)
		hud.queue_redraw()


func _banner(txt: String, col: Color) -> void:
	var l:= _label(txt, 16, col)
	l.size = Vector2(320, 30)
	l.position = Vector2(vs.x * 0.5 - 160, vs.y * 0.33)
	l.z_index = 9
	l.modulate.a = 0.0
	add_child(l)
	var tw:= create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(l, "position:y", vs.y * 0.3, 1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


var foods: Array = []
var fed:= 0


func _drop_food(at: Vector2) -> void:
	var f:= FishFood.new()
	f.position = at
	f.z_index = -1
	layer.add_child(f)
	foods.append(f)
	_play("plop", _rng.randf_range(1.3, 1.6), -10.0)

	var cands: Array = []
	for k in kois:
		if is_instance_valid(k) and not (k is Turtle) and (k as Koi).position.distance_to(at) < 320.0:
			cands.append(k)
	cands.sort_custom(func (x, y): return (x as Koi).position.distance_to(at) < (y as Koi).position.distance_to(at))
	for idx in mini(cands.size(), 3):
		(cands[idx] as Koi).dash(at, 2.5)
		(cands[idx] as Koi).orbit_r = 4.0


func _update_food() -> void:
	if foods.is_empty():
		return
	var keep: Array = []
	for f in foods:
		if not is_instance_valid(f):
			continue
		var fd:= f as FishFood
		var eater: Koi = null
		for k in kois:
			if is_instance_valid(k) and not (k is Turtle):
				var kk:= k as Koi
				if kk.position.distance_to(fd.position) < 10.0 + kk.length * 0.3:
					eater = kk
					break
		if eater:
			fed += 1
			score += 1
			eater.full = minf(eater.full + 1.0, 6.0)
			eater.length = minf(eater.length + 1.2, 52.0)
			eater.do_leap()
			_spawn_ripple(fd.position, 0.9, 2)
			flies.burst(fd.position + layer.global_position, 8, false)
			_play("sparkle", 1.5, -8.0)
			if fed % 5 == 0:
				_banner("물고기들이 배불러요! 함께 춤춰요", Color(1.0, 0.85, 0.75))
				for k in kois:
					if is_instance_valid(k) and not (k is Turtle):
						(k as Koi).orbit(frog.global_position - layer.global_position, 70.0, 2.5)
						(k as Koi).do_leap()
			else:
				var l:= _label("냠!", 13, Color(1.0, 0.95, 0.8))
				l.size = Vector2(60, 20)
				l.position = fd.position + layer.global_position + Vector2(-30, -30)
				l.z_index = 9
				add_child(l)
				var tw:= create_tween()
				tw.tween_property(l, "position:y", l.position.y - 20.0, 0.7)
				tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
				tw.tween_callback(l.queue_free)
			hud.queue_redraw()
			_log("fed n=%d" % fed)
			fd.queue_free()
		else:
			keep.append(fd)
	foods = keep


func _path_point(idx: float) -> Vector2:
	if idx <= 0.0:
		return (pads[0] as LilyPad).position + Vector2(0, -idx * 160.0)
	var i:= mini(int(floor(idx)), pads.size() - 2)
	var f:= idx - float(i)
	return (pads[i] as LilyPad).position.lerp((pads[i + 1] as LilyPad).position, f)


var _spectrum: AudioEffectSpectrumAnalyzerInstance = null
var groove:= 0.0


func _update_groove(delta: float) -> void:
	if _spectrum == null:
		if AudioServer.get_bus_effect_count(0) == 0:
			var fx:= AudioEffectSpectrumAnalyzer.new()
			fx.buffer_length = 0.1
			AudioServer.add_bus_effect(0, fx)
		_spectrum = AudioServer.get_bus_effect_instance(0, 0) as AudioEffectSpectrumAnalyzerInstance
		if _spectrum == null:
			return
	var mag:= _spectrum.get_magnitude_for_frequency_range(40.0, 5000.0).length()
	var e:= clampf((linear_to_db(maxf(mag, 1.0000000000000001e-05)) + 42.0) / 30.0, 0.0, 1.0)
	groove = lerpf(groove, e, clampf(delta * 3.0, 0.0, 1.0))
	frog.groove = groove


# ---------------------------------------------------------------- v115: naming and photos
func _pill_button(text: String, sz: Vector2, base: Color) -> Button:
	var b:= Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	for st in ["normal", "hover", "pressed"]:
		var sb:= StyleBoxFlat.new()
		sb.bg_color = Color(base, 0.45 if st != "pressed" else 0.7)
		sb.set_corner_radius_all(16)
		sb.border_color = Color(1.0, 0.97, 0.85, 0.35)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override(st, sb)
	b.size = sz
	b.pivot_offset = sz * 0.5
	return b


func _ask_dew_name() -> void:
	if _name_panel and is_instance_valid(_name_panel):
		return
	locked = true
	var shade:= ColorRect.new()
	shade.color = Color(0.0, 0.04, 0.03, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(shade)
	_name_panel = shade
	var box:= PanelContainer.new()
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.15, 0.11, 0.94)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(1.0, 0.96, 0.82, 0.4)
	sb.set_border_width_all(1)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 20
	sb.content_margin_bottom = 18
	box.add_theme_stylebox_override("panel", sb)
	box.size = Vector2(280, 0)
	box.position = Vector2(vs.x * 0.5 - 140, vs.y * 0.34)
	shade.add_child(box)
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	box.add_child(col)
	var title:= _label("이슬에게 이름을 지어 주세요", 16, Color(1.0, 0.98, 0.9))
	col.add_child(title)
	var sub:= _label("연못을 함께 건널 작은 친구예요", 12, Color(0.85, 0.95, 0.9, 0.85))
	col.add_child(sub)
	var edit:= LineEdit.new()
	edit.max_length = 8
	edit.text = dew_name
	edit.placeholder_text = "이슬"
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_override("font", font)
	edit.add_theme_font_size_override("font_size", 16)
	edit.custom_minimum_size = Vector2(0, 40)
	var esb:= StyleBoxFlat.new()
	esb.bg_color = Color(1.0, 1.0, 1.0, 0.1)
	esb.set_corner_radius_all(12)
	esb.content_margin_left = 10
	esb.content_margin_right = 10
	edit.add_theme_stylebox_override("normal", esb)
	edit.add_theme_stylebox_override("focus", esb)
	col.add_child(edit)
	var row:= HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var later:= _pill_button("나중에", Vector2(92, 36), Color(0.03, 0.14, 0.1))
	later.custom_minimum_size = Vector2(92, 36)
	var ok:= _pill_button("이름 짓기", Vector2(110, 36), Color(0.1, 0.32, 0.2))
	ok.custom_minimum_size = Vector2(110, 36)
	row.add_child(later)
	row.add_child(ok)
	var finish:= func (keep: bool) -> void:
		var nm:= edit.text.strip_edges()
		if keep and nm != "":
			dew_name = nm
		elif dew_name == "":
			dew_name = "이슬"
		_save_book()
		_log("dew_name %s" % dew_name)
		DisplayServer.virtual_keyboard_hide()
		shade.queue_free()
		_name_panel = null
		locked = false
		hud.queue_redraw()
		if keep and nm != "":
			_show_quip("안녕, %s! 같이 연못을 건너요" % dew_name)
			_haptic("tap")
	ok.pressed.connect(finish.bind(true))
	later.pressed.connect(finish.bind(false))
	edit.text_submitted.connect(func (_t): finish.call(true))
	edit.grab_focus()


# --- v116: name tag, photos and short clips into the phone album ---------------

func _draw_name_tag() -> void:
	if dew_name == "" or in_intro or frog == null or not frog.visible:
		return
	var a:= clampf(_tag_a * (1.0 - frog.evaporate), 0.0, 1.0)
	if a <= 0.02:
		return
	var depth:= Main.depth_at(frog.global_position.y)
	var r:= Frog.DEW_R * depth * frog.size_k
	var fs:= 13
	var tw:= font.get_string_size(dew_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w:= tw + 22.0
	var h:= 21.0
	var cy:= -frog.air_height - r * 1.9 - 18.0 + sin(_tag_t * 2.2) * 1.5
	var rect:= Rect2(-w * 0.5, cy - h * 0.5, w, h)
	var bg:= Color(0.02, 0.12, 0.09, 0.7 * a)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.85, 1.0, 0.8, 0.35 * a)
	sb.anti_aliasing = true
	name_tag.draw_style_box(sb, rect)
	var by:= cy + h * 0.5
	name_tag.draw_colored_polygon(PackedVector2Array([Vector2(-4, by - 0.5), Vector2(4, by - 0.5), Vector2(0, by + 5)]), bg)
	var base:= Vector2(-tw * 0.5, cy + fs * 0.36)
	name_tag.draw_string_outline(font, base, dew_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.01, 0.05, 0.04, 0.5 * a))
	name_tag.draw_string(font, base, dew_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.98, 0.88, a))


func _android_rt() -> Object:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return null
	return Engine.get_singleton("AndroidRuntime")


func _jx(tag: String) -> bool:
	# true when the last Java call threw; the exception is logged and cleared
	var ex = JavaClassWrapper.get_exception()
	if ex != null:
		_log("java %s: %s" % [tag, str(ex.toString())])
		return true
	return false


# Android 10+: put the file into the shared album through MediaStore (no storage permission needed).
# Returns the content Uri (a JavaObject) or null.
func _save_to_album(bytes: PackedByteArray, fname: String, mime: String, video: bool):
	var rt = _android_rt()
	if rt == null:
		return null
	var ver = JavaClassWrapper.wrap("android.os.Build$VERSION")
	if ver == null or int(ver.SDK_INT) < 29:
		return null
	var ctx = rt.getApplicationContext()
	var resolver = ctx.getContentResolver()
	var cv = JavaClassWrapper.wrap("android.content.ContentValues").ContentValues()
	cv.put("_display_name", fname)
	cv.put("mime_type", mime)
	cv.put("relative_path", ("Movies" if video else "Pictures") + "/MoonlitPond")
	var coll = JavaClassWrapper.wrap("android.net.Uri").parse("content://media/external/%s/media" % ("video" if video else "images"))
	var uri = resolver.insert(coll, cv)
	if _jx("insert") or uri == null:
		return null
	var os = resolver.openOutputStream(uri)
	if _jx("open") or os == null:
		return null
	os.write(bytes)
	os.flush()
	os.close()
	if _jx("write"):
		return null
	_log("album saved %s (%d bytes)" % [fname, bytes.size()])
	return uri


func _share(uri, mime: String) -> void:
	var rt = _android_rt()
	if rt == null or uri == null:
		return
	var who:= dew_name if dew_name != "" else "이슬"
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var it = Intent.Intent()
	it.setAction("android.intent.action.SEND")
	it.setType(mime)
	it.putExtra("android.intent.extra.STREAM", uri)
	it.putExtra("android.intent.extra.TEXT", "폴짝, 달빛 연못 · %s의 산책" % who)
	it.addFlags(1)
	var chooser = Intent.createChooser(it, "공유하기")
	rt.getActivity().startActivity(chooser)
	_jx("share")


func _offer_share(uri, mime: String) -> void:
	if _share_btn and is_instance_valid(_share_btn):
		_share_btn.queue_free()
	if uri == null:
		return
	var b:= _pill_button("공유하기", Vector2(96, 34), Color(0.1, 0.32, 0.2))
	b.position = Vector2(vs.x * 0.5 - 48, vs.y - 150)
	b.pressed.connect(func ():
		_haptic("tap")
		_share(uri, mime)
		b.queue_free())
	ui.add_child(b)
	_share_btn = b
	b.modulate.a = 0.0
	var tw:= create_tween()
	tw.tween_property(b, "modulate:a", 1.0, 0.25)
	tw.tween_interval(6.0)
	tw.tween_property(b, "modulate:a", 0.0, 0.6)
	tw.tween_callback(b.queue_free)


func _fallback_dir(sub: String) -> String:
	var u:= OS.get_user_data_dir().path_join(sub)
	DirAccess.make_dir_recursive_absolute(u)
	return u


func _stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")


# hide buttons and counters, add a small signature; returns what to restore
func _hide_ui_for_capture() -> Array:
	var hidden:= []
	for c in [sound_btn, book_btn, restart_btn, vib_btn, photo_btn, video_btn, name_btn, hud, drops_label, credit, _share_btn]:
		if c and is_instance_valid(c) and c.visible:
			c.visible = false
			hidden.append(c)
	if drops_fx and drops_fx.visible:
		drops_fx.visible = false
		hidden.append(drops_fx)
	if drops_fx and drops_fx.has_meta("fish_label"):
		var fl: Label = drops_fx.get_meta("fish_label")
		if is_instance_valid(fl) and fl.visible:
			fl.visible = false
			hidden.append(fl)
	if _quip_label and is_instance_valid(_quip_label) and _quip_label.visible:
		_quip_label.visible = false
		hidden.append(_quip_label)
	var who:= dew_name if dew_name != "" else "이슬"
	var sig:= _label("폴짝, 달빛 연못  ·  %s의 산책" % who, 13, Color(1.0, 0.98, 0.9, 0.9))
	sig.size = Vector2(vs.x, 20)
	sig.position = Vector2(0, vs.y - 34)
	ui.add_child(sig)
	hidden.append(sig)
	return hidden


func _restore_ui(hidden: Array) -> void:
	for c in hidden:
		if c and is_instance_valid(c):
			if c is Label and String(c.text).begins_with("폴짝, 달빛 연못  ·"):
				c.queue_free()
			else:
				c.visible = true


func _shutter() -> void:
	var flash:= ColorRect.new()
	flash.color = Color(1, 1, 1, 0.55)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)
	var tw:= create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.45)
	tw.tween_callback(flash.queue_free)
	_play("sparkle", 1.2, -14.0)


func _take_photo() -> void:
	if _photo_busy or in_intro or not _rec.is_empty():
		return
	_photo_busy = true
	_haptic("tap")
	var hidden:= _hide_ui_for_capture()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	_restore_ui(hidden)
	var fname:= "moonlitpond_%s.png" % _stamp()
	var bytes:= img.save_png_to_buffer()
	_shutter()
	var uri = _save_to_album(bytes, fname, "image/png", false)
	if uri != null:
		_show_quip("사진을 앨범에 담았어요")
		_offer_share(uri, "image/png")
	elif OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, fname, "image/png")
		_show_quip("사진을 저장했어요")
	else:
		var path:= _fallback_dir("photos").path_join(fname)
		var err:= img.save_png(path)
		_log("photo %s err=%d" % [path, err])
		_show_quip("사진을 저장했어요" if err == OK else "사진을 저장하지 못했어요")
	_photo_busy = false


# --- five-second clip ------------------------------------------------------------
# Each frame the screen is read back, scaled, and drawn onto MediaRecorder's input
# surface; MediaRecorder encodes H.264 into an mp4 that then goes to the album.
const CLIP_SEC:= 5.0
const CLIP_FPS:= 24.0
const CLIP_W:= 576
const REC_BAR_PX:= 8   # bottom rows hold the progress bar; they are cut from the clip

func _start_video() -> void:
	if _photo_busy or in_intro or not _rec.is_empty():
		return
	var tex_sz:= Vector2(get_viewport().get_texture().get_size())
	var w:= CLIP_W
	var h:= int(round(w * (tex_sz.y - REC_BAR_PX) / tex_sz.x / 16.0)) * 16
	var rec:= {"t": 0.0, "acc": 1.0, "w": w, "h": h, "n": 0, "tex": tex_sz}
	var rt = _android_rt()
	if rt != null:
		var ctx = rt.getApplicationContext()
		var path: String = str(ctx.getCacheDir().getAbsolutePath()).path_join("clip_%s.mp4" % _stamp())
		var mr = JavaClassWrapper.wrap("android.media.MediaRecorder").MediaRecorder()
		if _jx("recorder") or mr == null:
			_show_quip("이 기기에서는 영상을 찍을 수 없어요")
			return
		mr.setVideoSource(2)          # SURFACE
		mr.setOutputFormat(2)         # MPEG_4
		mr.setOutputFile(path)
		mr.setVideoEncoder(2)         # H264
		mr.setVideoSize(w, h)
		mr.setVideoFrameRate(int(CLIP_FPS))
		mr.setVideoEncodingBitRate(6000000)
		mr.prepare()
		if _jx("prepare"):
			mr.release()
			_show_quip("이 기기에서는 영상을 찍을 수 없어요")
			return
		var surf = mr.getSurface()
		mr.start()
		if _jx("start") or surf == null:
			mr.release()
			_show_quip("이 기기에서는 영상을 찍을 수 없어요")
			return
		var cfg = JavaClassWrapper.wrap("android.graphics.Bitmap$Config").valueOf("ARGB_8888")
		rec["mr"] = mr
		rec["surf"] = surf
		rec["path"] = path
		rec["bmp"] = JavaClassWrapper.wrap("android.graphics.Bitmap").createBitmap(w, h, cfg)
		rec["paint"] = JavaClassWrapper.wrap("android.graphics.Paint").Paint(2)   # FILTER_BITMAP_FLAG
		rec["bb"] = JavaClassWrapper.wrap("java.nio.ByteBuffer")
		_jx("bitmap")
	else:
		rec["frames"] = []
	_haptic("tap")
	_play("sparkle", 0.9, -16.0)
	rec["hidden"] = _hide_ui_for_capture()
	# the progress bar lives in the bottom rows, which are cropped out of the clip
	var bar:= ColorRect.new()
	bar.color = Color(1.0, 0.55, 0.45, 0.9)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bh:= (REC_BAR_PX - 2) * vs.y / tex_sz.y
	bar.position = Vector2(0, vs.y - bh)
	bar.size = Vector2(0, bh)
	ui.add_child(bar)
	rec["bar"] = bar
	_rec = rec


func _video_tick(delta: float) -> void:
	_rec.t += delta
	_rec.acc += delta
	var bar: ColorRect = _rec.bar
	bar.size.x = vs.x * clampf(_rec.t / CLIP_SEC, 0.0, 1.0)
	if _rec.t > 0.05 and _rec.acc >= 1.0 / CLIP_FPS:
		_rec.acc = minf(_rec.acc - 1.0 / CLIP_FPS, 1.0 / CLIP_FPS)
		var img:= get_viewport().get_texture().get_image()
		var full:= img.get_size()
		img = img.get_region(Rect2i(0, 0, full.x, full.y - REC_BAR_PX))
		img.resize(_rec.w, _rec.h, Image.INTERPOLATE_BILINEAR)
		img.convert(Image.FORMAT_RGBA8)
		if _rec.has("mr"):
			_push_frame(img)
		elif _rec.frames.size() < 3 and _rec.n % 40 == 0:
			_rec.frames.append(img)
		_rec.n += 1
	if _rec.t >= CLIP_SEC:
		_finish_video()


func _push_frame(img: Image) -> void:
	var buf = _rec.bb.wrap(img.get_data())
	_rec.bmp.copyPixelsFromBuffer(buf)
	var surf = _rec.surf
	var cv = surf.lockHardwareCanvas()
	if _jx("lock") or cv == null:
		return
	cv.drawBitmap(_rec.bmp, 0.0, 0.0, _rec.paint)
	surf.unlockCanvasAndPost(cv)
	_jx("post")


func _finish_video() -> void:
	var rec:= _rec
	_rec = {}
	_restore_ui(rec.hidden)
	(rec.bar as ColorRect).queue_free()
	_shutter()
	_log("clip frames=%d size=%dx%d" % [rec.n, rec.w, rec.h])
	if rec.has("mr"):
		var mr = rec.mr
		mr.stop()
		var bad:= _jx("stop")
		mr.release()
		var uri = null
		if not bad:
			var bytes:= FileAccess.get_file_as_bytes(rec.path)
			if bytes.size() > 0:
				uri = _save_to_album(bytes, "moonlitpond_%s.mp4" % _stamp(), "video/mp4", true)
		DirAccess.remove_absolute(rec.path)
		if uri != null:
			_show_quip("5초 영상을 앨범에 담았어요")
			_offer_share(uri, "video/mp4")
		else:
			_show_quip("영상을 저장하지 못했어요")
	else:
		# desktop: keep a few sample frames so the capture can be checked
		var d:= _fallback_dir("clips")
		for i in rec.frames.size():
			(rec.frames[i] as Image).save_png(d.path_join("clip_%s_%d.png" % [_stamp(), i]))
		_show_quip("영상 미리보기를 저장했어요")
