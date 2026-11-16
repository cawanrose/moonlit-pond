class_name GiantFish
extends Node2D


const RISE:= 1.6
const STAY:= 1.8
const SINK:= 2.0
var size:= 230.0
var facing:= -PI * 0.5
var life:= 0.0
var _t:= 0.0
var _gulp:= 0.0
var kind:= "stripe"
var watch: Node2D = null
var peek:= 0.7
var blocking:= false
var soft:= false
var _sink_fast:= 1.0
var rise:= 3.0
var _diving:= 0.0
var _dive_dir:= 0.0
var _shadow_pos:= Vector2.ZERO
var _spr: Sprite2D = null
const SPRITES:= { "gold": preload("res://assets/koi_gold.png"), "spotted": preload("res://assets/koi_spotted.png")}
const WIGGLE:= preload("res://scripts/koi_wiggle.gdshader")


func _ready() -> void:
	if SPRITES.has(kind):
		_spr = Sprite2D.new()
		_spr.texture = SPRITES[kind]
		var mat:= ShaderMaterial.new()
		mat.shader = WIGGLE
		mat.set_shader_parameter("phase", randf() * TAU)
		_spr.material = mat
		rise = 3.4
		add_child(_spr)


func shoo() -> void:
	blocking = false
	_sink_fast = 1.4
	_diving = 0.001
	_dive_dir = facing + (0.9 if randf() < 0.5 else -0.9)
	life = maxf(life, rise + STAY)


func hit_test(p: Vector2) -> bool:
	var c:= global_position - (Vector2.from_angle(facing) * size * 0.1 if _spr else Vector2.ZERO)
	return p.distance_to(c) < size * (0.75 if _spr else 0.55)


func _base() -> Color:
	match kind:
		"blue": return Color(0.25, 0.5, 0.95)
		"yellow": return Color(0.98, 0.8, 0.2)
		"stripe": return Color(0.15, 0.38, 0.88)
		"orange": return Color(1.0, 0.55, 0.15)
		"white", "catfish": return Color(0.95, 0.94, 0.9)
	return Color(0.95, 0.36, 0.2)


func _surface_k() -> float:
	if life < rise:
		var k:= life / rise
		return k * k * (3.0 - 2.0 * k)
	if life < rise + STAY:
		return 1.0
	var k2:= clampf((life - rise - STAY) / SINK, 0.0, 1.0)
	return 1.0 - k2 * k2


func _process(delta: float) -> void:
	_t += delta
	if _diving > 0.0:
		_diving = minf(_diving + delta * 0.45, 1.0)
	life += delta * (_sink_fast if life > rise + STAY else 1.0)
	if _spr:
		var k:= _surface_k()

		var depth_k:= 1.0 - k
		var dir:= Vector2.from_angle(facing)
		var side:= Vector2(-dir.y, dir.x)

		var glide:= sin(_t * 0.35) * 14.0
		var drift:= sin(_t * 0.23 + 1.3) * 10.0
		var pos:= dir * (lerpf(-90.0, 0.0, k) + glide) + side * drift - dir * size * 0.1
		if _diving > 0.0:
			pos += Vector2.from_angle(_dive_dir) * _diving * _diving * 220.0
		var sc:= size * 1.5 / 512.0 * lerpf(0.6, 1.0, k)
		_spr.scale = Vector2(sc, sc)
		var turn:= sin(_t * 0.3) * 0.12 + (_dive_dir - facing) * clampf(_diving * 2.0, 0.0, 1.0)
		_spr.rotation = facing + PI * 0.5 + turn
		_spr.position = pos
		var mat:= _spr.material as ShaderMaterial
		mat.set_shader_parameter("depth", clampf(depth_k, 0.0, 1.0))
		mat.set_shader_parameter("speed", 2.2 + 2.5 * clampf(_diving * 3.0, 0.0, 1.0))
		_spr.modulate = Color(1, 1, 1, clampf(life * 1.2, 0.0, 1.0))
		_shadow_pos = pos
	if blocking and life > rise + 0.6:
		life = rise + 0.6
	if life > rise + STAY + SINK:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k:= _surface_k()
	if _spr:

		var dir0:= Vector2.from_angle(facing)
		var spread:= 1.0 + (1.0 - k) * 0.5
		draw_set_transform(_shadow_pos + Vector2(14, 22) * (1.6 - k), facing, Vector2(1.0, 0.34) * spread)
		for i in 4:
			draw_circle(Vector2.ZERO, size * (0.66 - i * 0.09), Color(0.0, 0.05, 0.07, 0.06 * k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		for i in 3:
			var off:= Vector2(sin(_t * 0.5 + i * 2.0) * size * 0.3, cos(_t * 0.4 + i) * size * 0.2)
			draw_circle(_shadow_pos + off, size * 0.35, Color(0.8, 1.0, 0.9, 0.025 * k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if k > 0.5:
			var m0:= _shadow_pos + dir0 * size * 0.72
			for i in 5:
				var ph:= fmod(_t * 0.7 + i * 0.29, 1.0)
				draw_arc(m0 + Vector2(sin(i * 2.1) * 10.0, -ph * 18.0), 2.0 + ph * 4.0, 0, TAU, 14, Color(0.9, 1.0, 1.0, 0.6 * (k - 0.5) * 2.0 * (1.0 - ph)), 1.2, true)
		return
	var dir:= Vector2.from_angle(facing)
	var nrm:= Vector2(-dir.y, dir.x)
	var S:= size * lerpf(0.82, 1.0, k)
	var lift:= dir * lerpf(-40.0, 0.0, k)
	var deep:= Color(0.1, 0.28, 0.3)
	var red:= deep.lerp(_base(), 0.25 + 0.6 * k)
	var a:= 0.12 + 0.68 * k
	if soft:
		# a deep, hazy presence: slow breathing, no hard edge
		a *= 0.82 + 0.18 * sin(_t * 1.3)
	k *= peek

	for i in 0:
		var t:= i / 6.0
		var c:= lift - dir * S * (0.25 + t * 1.3) + nrm * sin(_t * 1.2 - t * 2.0) * S * 0.08 * t
		draw_circle(c, S * (0.42 - 0.22 * t), Color(red, a * (0.6 - 0.5 * t)))

	for i in 4:
		var o:= Vector2.from_angle(i * TAU / 4.0 + _t) * (8.0 * (1.0 - k) + 2.0)
		draw_circle(lift + o, S * 0.48, Color(red, a * 0.12))

	var cat:= kind == "catfish"
	draw_set_transform(lift, facing, Vector2(0.9, 1.12) if cat else Vector2(1.0, 0.86))
	if soft:
		# feathered body: many faint layers fading out instead of one crisp circle
		for i in 9:
			draw_circle(Vector2.ZERO, S * (0.64 - i * 0.026), Color(red, a * 0.075))
		draw_circle(Vector2.ZERO, S * 0.4, Color(red, a * 0.35))
		for i in 4:
			draw_circle(Vector2(S * 0.12, 0), S * (0.4 - i * 0.03), Color(red.lightened(0.08), a * 0.1))
	else:
		draw_circle(Vector2.ZERO, S * 0.46, Color(red, a))
		draw_circle(Vector2(S * 0.12, 0), S * 0.38, Color(red.lightened(0.08), a))
	if kind == "stripe":
		for i in 3:
			var x:= S * (0.05 - 0.14 * i)
			draw_line(Vector2(x, -S * 0.38), Vector2(x, S * 0.38), Color(Color(1.0, 0.85, 0.2).lerp(deep, 1.0 - k), a), S * 0.06, true)
	if cat:

		for i in 7:
			var fp:= Vector2(-S * 0.25 + (i % 4) * S * 0.12, (i * 37 % 7 - 3) * S * 0.08)
			draw_circle(fp, S * 0.025, Color(0.55, 0.6, 0.62, a * 0.35))

	if not cat: draw_circle(Vector2(-S * 0.05, 0), S * 0.17, Color(Color(0.98, 0.93, 0.86).lerp(deep, 1.0 - k), a * 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var look:= Vector2.ZERO
	if watch and is_instance_valid(watch):
		look = (watch.global_position - global_position).normalized()
	var blink:= 1.0 if fmod(_t + 0.7, 3.3) > 0.16 else 0.15
	for sgn: float in [-1.0, 1.0]:
		var e:= lift + dir * S * (0.26 if cat else 0.16) + nrm * S * (0.36 if cat else 0.27) * sgn
		var er:= S * (0.045 if cat else 0.075)
		draw_circle(e, er, Color(0.98, 0.92, 0.75, a))
		draw_circle(e + look * er * 0.45, er * 0.6, Color(0.03, 0.04, 0.05, a))
		draw_circle(e + look * er * 0.45 + Vector2(-er * 0.18, -er * 0.2), er * 0.18, Color(1, 1, 1, a * 0.9))

		var lid:= 0.55 + 0.45 * (1.0 - blink)
		var lc:= e - dir * er * (1.0 - lid) * 0.2
		var pts:= PackedVector2Array()
		for q in 13:
			var ang:= lerpf(0.0, PI, q / 12.0)
			pts.append(lc - dir * cos(ang) * 0.0 + (nrm * cos(ang) * er * 1.08) - dir * sin(ang) * er * 1.08)
		for q in 13:
			var ang:= lerpf(PI, 0.0, q / 12.0)
			pts.append(lc + nrm * cos(ang) * er * 1.08 - dir * sin(ang) * er * 1.08 * (1.0 - 2.0 * lid))
		draw_colored_polygon(pts, Color(red.darkened(0.15), a))

	_gulp = 0.5 + 0.5 * sin(_t * 3.0)
	var m:= lift + dir * S * 0.44
	if cat:
		m = lift + dir * S * 0.42
	draw_set_transform(m, facing, Vector2(0.4 + 0.2 * _gulp, 2.4) if cat else Vector2(0.55 + 0.25 * _gulp, 1.0))
	draw_circle(Vector2.ZERO, S * 0.1, Color(0.35, 0.06, 0.05, a))
	draw_circle(Vector2.ZERO, S * 0.06, Color(0.08, 0.02, 0.02, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if cat:
		for sgn: float in [-1.0, 1.0]:
			for lng: float in [1.0, 0.45]:
				var base:= m + nrm * S * (0.2 if lng > 0.5 else 0.1) * sgn
				var bpts:= PackedVector2Array()
				for i in 12:
					var t:= i / 11.0
					bpts.append(base + dir * S * 0.12 * t * lng + nrm * sgn * S * 0.75 * t * lng - dir * S * 0.45 * t * t * lng + dir.rotated(PI * 0.5) * sin(_t * 1.6 + t * 4.0 + sgn) * S * 0.05 * t)
				draw_polyline(bpts, Color(0.92, 0.9, 0.86, a * 0.9), 3.0 if lng > 0.5 else 2.0, true)
	for sgn: float in ([] if cat else [-1.0, 1.0]):
		var base:= lift + dir * S * 0.38 + nrm * S * 0.12 * sgn
		var pts:= PackedVector2Array()
		for i in 8:
			var t:= i / 7.0
			pts.append(base + dir * S * 0.1 * t + nrm * sgn * S * 0.28 * t + dir.rotated(PI * 0.5) * sin(_t * 2.0 + t * 3.0) * S * 0.04 * t)
		draw_polyline(pts, Color(0.95, 0.6, 0.4, a * 0.8), 2.5, true)

	if k > 0.5:
		for i in 6:
			var ph:= fmod(_t * 0.7 + i * 0.29, 1.0)
			var bp:= m + nrm * sin(i * 2.1) * S * 0.12 - dir * ph * S * 0.1
			draw_arc(bp, 2.0 + ph * 4.0, 0, TAU, 14, Color(0.9, 1.0, 1.0, 0.7 * (k - 0.5) * 2.0 * (1.0 - ph)), 1.2, true)
