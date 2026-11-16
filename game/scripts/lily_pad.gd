class_name LilyPad
extends Node2D


const TOUCH_MARGIN:= 1.3
const CENTER_RATIO:= 0.45

var base_width:= 120.0
var depth:= 1.0
# v0.45 stacking: 0 = low leaf (sits a layer down), 1 = high leaf (on top, casts a longer shadow)
var height:= -1.0
var is_target:= false
var decor:= false
var lit:= 0.0
var press:= 0.0
var press_strength:= 1.0
var bob_phase:= 0.0
var drift_amp:= 0.0
var drift_speed:= 0.9
var notch_angle:= 0.0
var tone:= 0.0
var reveal:= 1.0
var _t:= 0.0
var _glow_t:= 0.0
var _wobble:= 0.0
var _flash:= 0.0
var rim: Node2D

var vel:= Vector2.ZERO
var rest:= Vector2.INF

var tilt_axis:= 0.0
var tilt_amt:= 0.9
var lift:= 0.0
var _tilt_wob:= 0.0
var bank:= 0.72
var hit_t:= 0.0
# v0.30 hand-clear feel
var held:= false
var held_k:= 0.0
var grip:= Vector2.INF
var stretch:= 0.0
var stretch_dir:= 0.0
var cleared_glow:= 0.0
var treasure:= false
var custom_tex: Texture2D = null
static var FLOWER_TEX: Texture2D = null
var flower:= -1
var left:= false
var dip:= 0.0
var fixed_bank:= false
var _visit_init:= false
var _visit_k:= 0.0
var flower_off:= Vector2.ZERO
var flower_r:= 14.0
var sink:= 0.0
var beacon:= false
var submerged:= 0.0
var _beacon_k:= 0.0
const CUSTOM_CONTENT:= 420.0
var _tr_t:= 0.0
var _rim_dirty:= false
const TD_TEX:= preload("res://assets/td_lily_pad.png")
const TD_CONTENT:= 840.0


static func light_field(p: Vector2, t: float) -> float:
	var v:= sin(p.x * 0.017 + t * 0.12) * sin(p.y * 0.013 - t * 0.08) + 0.6 * sin((p.x - p.y) * 0.008 + t * 0.05 + 1.3)
	return clampf(v * 0.9, -1.0, 1.0)


func setup(width: float, phase: float, _v:= "") -> void:
	base_width = width
	bob_phase = phase
	notch_angle = fmod(phase * 3.7, TAU)
	tone = sin(phase * 5.3)
	tilt_axis = fmod(phase * 11.3, PI)
	tilt_amt = 1.0
	bank = 0.45 + 0.5 * (0.5 + 0.5 * sin(phase * 13.7))


var shade: Node2D


func _ready() -> void:
	shade = Node2D.new()
	shade.z_as_relative = false
	shade.z_index = -2
	shade.draw.connect(_draw_shadow)
	add_child(shade)
	rim = Node2D.new()
	rim.draw.connect(_draw_rim)
	add_child(rim)


const TILT:= 0.9


func visual_width() -> float:
	return base_width * depth * reveal * (1.0 - 0.05 * press * press_strength)


func rx() -> float:
	return base_width * depth * 0.5


func ry() -> float:
	return base_width * depth * 0.5 * TILT


func surface_offset() -> Vector2:
	return Vector2(sin(_t * drift_speed + bob_phase) * drift_amp + sin(_t * 0.7 + bob_phase) * 1.2,
		cos(_t * 0.6 + bob_phase) * 1.2 - lift + dip)


func norm_dist(global_point: Vector2) -> float:
	var d:= global_point - (global_position + surface_offset())
	return Vector2(d.x / rx(), d.y / ry()).length()


func contains_touch(global_point: Vector2) -> bool:
	return norm_dist(global_point) <= TOUCH_MARGIN


func is_center(global_point: Vector2) -> bool:
	return norm_dist(global_point) <= CENTER_RATIO


func landing_uv(global_point: Vector2) -> Vector2:
	var d:= global_point - (global_position + surface_offset())
	d = Vector2(d.x / rx(), d.y / ry())
	if d.length() > 0.5:
		d = d.normalized() * 0.5
	return d


func uv_to_global(uv: Vector2) -> Vector2:
	return global_position + surface_offset() + Vector2(uv.x * rx(), uv.y * ry())


func set_target(on: bool) -> void:
	is_target = on
	_glow_t = 0.0


func land(center: bool) -> void:
	press_strength = 1.6 if center else 1.0
	var tw:= create_tween()
	tw.tween_property(self, "press", 1.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "press", 0.0, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func takeoff() -> void:
	press_strength = 0.6
	var tw:= create_tween()
	tw.tween_property(self, "press", 1.0, 0.06)
	tw.tween_property(self, "press", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func nudge(flash_amt:= 1.0) -> void:
	# v110: flash_amt lets crowd moves (the water path opening) wobble pads without lighting every rim at once
	_wobble = 1.0
	if not decor:
		_flash = maxf(_flash, flash_amt)
	_tilt_wob = 1.0


func bump(impulse: Vector2) -> void:
	vel += impulse
	_tilt_wob = 1.0
	tilt_axis = impulse.angle() + PI * 0.5
	lift = minf(lift + 4.0, 8.0)


var _frame_slot:= randi() % 2


func _process(delta: float) -> void:
	# the pad the dew is on or heading for is blue; it turns back to green once the dew has left
	var want_blue:= 1.0 if (custom_tex != null and not left) else 0.0
	if not _visit_init:
		_visit_init = true
		_visit_k = want_blue
	_visit_k = move_toward(_visit_k, want_blue, delta * 1.2)
	_t += delta
	_glow_t += delta
	_wobble = maxf(_wobble - delta * 2.2, 0.0)
	_flash = maxf(_flash - delta * 2.0, 0.0)
	_tilt_wob = maxf(_tilt_wob - delta * 1.2, 0.0)
	lift = maxf(lift - delta * 6.0, 0.0)
	hit_t = maxf(hit_t - delta, 0.0)
	_beacon_k = move_toward(_beacon_k, 1.0 if beacon else 0.0, delta * 2.0)
	held_k = move_toward(held_k, 1.0 if held else 0.0, delta * (9.0 if held else 4.0))
	cleared_glow = maxf(cleared_glow - delta * 1.1, 0.0)
	if treasure:
		_tr_t += delta
		cleared_glow = maxf(cleared_glow, 0.55 + 0.3 * sin(_tr_t * 3.0))
	if held:
		lift = maxf(lift, 9.0)
	var spd:= vel.length()
	var st:= clampf((spd - 40.0) / 1100.0, 0.0, 0.16)
	stretch = lerpf(stretch, st, clampf(delta * 10.0, 0.0, 1.0))
	if spd > 40.0:
		stretch_dir = lerp_angle(stretch_dir, vel.angle(), clampf(delta * 12.0, 0.0, 1.0))
	depth = Main.depth_at(global_position.y)
	if decor:

		var gy:= global_position.y
		var on:= gy > -140.0 and gy < 800.0
		if visible != on:
			visible = on
		if not on:
			return
	# calm background pads only need a fresh picture every other frame
	var busy:= not decor or spd > 6.0 or _wobble > 0.0 or _tilt_wob > 0.0 or hit_t > 0.0 or held_k > 0.0 or cleared_glow > 0.0 or submerged > 0.0 or sink > 0.0 or absf(dip) > 0.05 or stretch > 0.005
	if not busy and (Engine.get_process_frames() + _frame_slot) % 2 != 0:
		return
	queue_redraw()
	if rim:
		var fx_on:= held_k > 0.0 or cleared_glow > 0.0
		if not decor or fx_on or _rim_dirty:
			rim.queue_redraw()
		_rim_dirty = fx_on
	if shade:
		shade.queue_redraw()


func _circle_pts(c: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts:= PackedVector2Array()
	for i in n + 1:
		var a:= lerpf(a0, a1, i / float(n))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _leaf_xf(c: Vector2) -> Transform2D:
	var wob:= sin(_t * 9.0) * 0.1 * _tilt_wob
	var amt:= 1.0
	var tilt:= Transform2D(tilt_axis, Vector2.ZERO) * Transform2D(0.0, Vector2(1.0, amt), 0.0, Vector2.ZERO) * Transform2D(-tilt_axis, Vector2.ZERO)
	return Transform2D(0.0, Vector2(1.0, TILT), 0.0, c) * tilt


func _draw() -> void:
	var r:= visual_width() * 0.5
	if r < 1.0:
		return
	var c:= surface_offset() + Vector2(0, 3.5 * sink)
	var rot:= notch_angle + sin(_wobble * 18.0) * 0.12 * _wobble + sin(_t * 0.7 + bob_phase * 2.0) * 0.035

	var mod:= Color(1, 1, 1)
	if decor:
		var v:= 1.0 + 0.08 * tone + 0.14 * lit
		if height >= 0.0:
			v *= lerpf(0.82, 1.07, height)
		mod = Color(v * 1.04, v * 1.1, v * 0.82)
	if is_target:
		var g:= 1.08 + 0.06 * sin(_glow_t * 3.2)
		mod = Color(g, g, g * 0.92)
	if held_k > 0.0:
		var hb:= 1.0 + 0.1 * held_k
		mod = Color(mod.r * hb, mod.g * hb, mod.b * (1.0 + 0.04 * held_k))
	if treasure:
		mod = Color(mod.r * 1.3, mod.g * 1.12, mod.b * 0.62)
	if cleared_glow > 0.0:
		var cg:= 1.0 + 0.18 * cleared_glow
		mod = Color(mod.r * cg, mod.g * cg, mod.b * (1.0 + 0.1 * cleared_glow))
	if submerged > 0.0:
		# under the water: a soft, cool, see-through shape
		mod = mod.lerp(Color(0.35, 0.55, 0.6), 0.6 * submerged)
		mod.a = lerpf(1.0, 0.32, submerged)
	if sink > 0.0:
		var sk:= 1.0 - 0.1 * sink
		mod = Color(mod.r * sk * 0.95, mod.g * sk, mod.b * (sk + 0.1 * sink))
	if _visit_k > 0.0:
		# pads the dew has stepped on keep a faint blue cast
		mod = Color(mod.r * lerpf(1.0, 0.5, _visit_k), mod.g * lerpf(1.0, 0.84, _visit_k), mod.b * lerpf(1.0, 1.55, _visit_k), mod.a)
	var sc:= (r * 2.0) / (CUSTOM_CONTENT if custom_tex else TD_CONTENT) * (1.0 + 0.05 * held_k) * (1.0 - 0.035 * sink) * (1.0 - 0.1 * submerged) * (lerpf(0.95, 1.05, height) if height >= 0.0 else 1.0)
	var sx:= Transform2D(stretch_dir, Vector2.ZERO) * Transform2D(0.0, Vector2(1.0 + stretch, 1.0 - stretch * 0.55), 0.0, Vector2.ZERO) * Transform2D(-stretch_dir, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D(0.0, Vector2(1.0, TILT), 0.0, c) * sx * Transform2D(rot, Vector2(sc, sc), 0.0, Vector2.ZERO))
	if custom_tex:
		if _beacon_k > 0.0 and submerged < 0.5:
			# soft moonlight breathing around the leaf the dew should go to
			var bp:= 0.5 + 0.5 * sin(_t * 2.2)
			var hr:= 256.0 * (0.9 + 0.06 * bp)
			draw_circle(Vector2.ZERO, hr * 1.02, Color(1.0, 0.97, 0.8, (0.05 + 0.05 * bp) * _beacon_k * (1.0 - sink)))
			draw_arc(Vector2.ZERO, hr, 0, TAU, 64, Color(1.0, 0.98, 0.85, (0.25 + 0.25 * bp) * _beacon_k * (1.0 - sink)), 5.0, true)
		draw_texture(custom_tex, -Vector2(256, 256), mod)
	else:
		draw_texture(TD_TEX, -Vector2(512, 512), mod)

	draw_set_transform(c, 0.0, Vector2(1.0, TILT))
	if custom_tex == null:
		draw_arc(Vector2.ZERO, r * 0.955, rot + 0.3, rot + TAU - 0.3, 40, Color(0.62, 0.32, 0.6, 0.13), r * 0.07, true)
		draw_arc(Vector2.ZERO, r * 0.99, rot + 0.3, rot + TAU - 0.3, 40, Color(0.5, 0.25, 0.45, 0.08), r * 0.03, true)
	if sink > 0.0:
		# a thin film of water washes over the pressed leaf
		draw_circle(Vector2.ZERO, r * 0.97, Color(0.4, 0.62, 0.6, 0.2 * minf(sink, 1.2)))
		draw_arc(Vector2.ZERO, r * (0.97 - 0.3 * minf(sink, 1.0)), 0, TAU, 40, Color(0.9, 1.0, 1.0, 0.22 * minf(sink, 1.0)), 1.6, true)
		draw_arc(Vector2.ZERO, r * 1.0, 0, TAU, 48, Color(0.9, 1.0, 1.0, 0.35 * sink), 2.0, true)
		draw_arc(Vector2.ZERO, r * (1.08 + 0.06 * sink), 0, TAU, 48, Color(0.9, 1.0, 1.0, 0.15 * sink), 1.4, true)

	draw_set_transform(c, 0.0, Vector2(1.0, TILT))
	var gp:= global_position
	var f:= light_field(gp, _t)
	if f > 0.0:
		draw_circle(Vector2.ZERO, r * 0.62, Color(0.9, 0.95, 0.45, 0.11 * f))
	if held_k > 0.0 and grip != Vector2.INF:
		# soft fingertip dimple where the leaf is held
		var gp2:= Vector2(grip.x * r, grip.y * r)
		for k in 3:
			draw_circle(gp2, r * (0.3 - k * 0.08), Color(0.05, 0.2, 0.1, 0.07 * held_k))
		draw_arc(gp2, r * 0.32, 0, TAU, 28, Color(0.95, 1.0, 0.85, 0.22 * held_k), 1.6, true)

	if flower >= 0 and FLOWER_TEX != null and submerged < 0.5:
		# a little blossom peeking out at the pad's edge
		var fc:= c + Vector2(flower_off.x, flower_off.y * TILT)
		draw_set_transform(fc, 0.0, Vector2(1.0, TILT))
		draw_circle(Vector2(2.0, 3.0), flower_r * 0.92, Color(0.0, 0.08, 0.06, 0.22))
		var bob:= 1.0 + 0.03 * sin(_t * 1.1 + bob_phase)
		var fr:= flower_r * 1.07 * bob
		draw_texture_rect_region(FLOWER_TEX, Rect2(-fr, -fr, fr * 2.0, fr * 2.0), Rect2((flower % 4) * 128, (flower / 4) * 128, 128, 128), Color(1, 1, 1, mod.a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func apply_height(h: float) -> void:
	height = h
	z_index = 2 if h >= 0.55 else 0
	if shade:
		shade.z_index = 1 if h >= 0.55 else -2


func _draw_shadow() -> void:
	var r:= visual_width() * 0.5
	if r < 1.0:
		return
	var c:= surface_offset()

	var hh:= maxf(height, 0.0)
	var sc0:= c + Vector2(r * 0.16, r * 0.22) + Vector2(lift, lift) * 0.6 + Vector2(1.0, 1.25) * hh * 11.0
	var shc:= Color(0.0, 0.06, 0.12) if hh < 0.55 else Color(0.0, 0.1, 0.06)
	shade.draw_set_transform(sc0, 0.0, Vector2(1.0, TILT))
	for k in 4:
		shade.draw_circle(Vector2.ZERO, r * (1.22 - k * 0.1), Color(shc, (0.07 + k * 0.02) * (1.0 + 0.5 * hh)))
	for i in 3:
		var ang:= bob_phase * 3.1 + i * TAU / 3.0 + sin(_t * 0.3 + i) * 0.2
		var pc:= Vector2.from_angle(ang) * r * 0.62
		shade.draw_circle(pc, r * (0.48 + 0.08 * sin(i * 2.7 + bob_phase)), Color(shc, 0.055))
	shade.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rim() -> void:
	if not is_target and _flash <= 0.0 and held_k <= 0.0 and cleared_glow <= 0.0:
		return
	var r:= visual_width() * 0.5
	var c:= surface_offset()
	var pulse:= 0.5 + 0.5 * sin(_glow_t * 3.2)
	var a:= (0.55 + 0.35 * pulse) if is_target else 0.0
	a = maxf(a, _flash)
	a = maxf(a, 0.7 * held_k)
	a = maxf(a, 0.8 * cleared_glow)
	rim.draw_set_transform(c, 0.0, Vector2(1.0, TILT))
	for k in 3:
		rim.draw_arc(Vector2.ZERO, r * (1.04 + 0.05 * k + 0.03 * pulse), 0, TAU, 48, Color(1.0, 0.95, 0.6, a * (0.6 - k * 0.18)), 3.0, true)
	rim.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 3:
		var ang:= _glow_t * 0.5 + TAU * i / 3.0
		var p:= c + Vector2(cos(ang), sin(ang) * TILT) * r * 1.02
		var tw:= 0.5 + 0.5 * sin(_glow_t * 5.0 + i * 2.1)
		var rr:= 3.0 + 3.0 * tw
		var col:= Color(1.0, 1.0, 0.85, a * tw)
		rim.draw_line(p - Vector2(rr, 0), p + Vector2(rr, 0), col, 1.4, true)
		rim.draw_line(p - Vector2(0, rr), p + Vector2(0, rr), col, 1.4, true)
