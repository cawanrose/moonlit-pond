extends Node2D
# v86: the giant red koi, rebuilt from scratch.
# Parts: a body strip (closed-mouth and puff frames) that bends behind the pectoral fins, and two
# pectoral fins as their own sprites that turn about their roots. No shader warping anywhere.
# Life: lurks deep and faint under the pads -> discovered (rises, puffs) -> leaves (head turns first,
# the body follows round, it swims off and sinks). Touching a discovered koi makes it leave.

const SHADER:= preload("res://scripts/koi_simple.gdshader")
const SEGS:= 24
const RIGID_S:= 0.3            # head + fin section never bends
const FIN_ROOT_L:= Vector2(-102.0, -276.0)   # in body-texture pixels, from its centre
const FIN_ROOT_R:= Vector2(104.0, -276.0)
const FIN_PIVOT_L:= Vector2(92.0, 30.0)      # root inside the fin textures
const FIN_PIVOT_R:= Vector2(10.0, 30.0)

static var T_BACK: Texture2D
static var T_COL: Dictionary = {}   # v97: colour sets "y" / "p" -> [back, face]
static var T_FACE: Texture2D
static var T_FIN_L: Texture2D
static var T_FIN_R: Texture2D
static var _loaded:= false

var size:= 240.0
var facing:= 0.0
var home:= Vector2.ZERO
var stay_time:= 10.0
var watch: Node2D = null
var discovered:= false
# v100: style 0 = wanderer, 2 = darter (quick dash now and then). The circler (1) was removed.
var style:= 0
var color:= "r"
var aim_dew:= true          # v91: mostly keeps its head turned toward the dew
var _rise:= 0.0            # eased surfacing 0..1
# v92: swimming drives the body: a kick pushes it forward and bends it, a glide straightens it
var _kick:= 0.0
var _vel:= Vector2.ZERO
var _goal:= Vector2.ZERO
var _goal_t:= 0.0
var _orbit_a:= 0.0
var _found_facing:= 0.0
var _speed:= 0.0
var _wave:= 0.0
var _spine: PackedVector2Array = PackedVector2Array()
var _hist: Array = []
var _fx: Node2D
var on_surface: Callable   # v93: called once when a found koi actually reaches the surface
var _surfaced:= false
var _lt:= 0.0                  # time since it began to leave (0 = not leaving)
var _leaving:= false
var _dive_dir:= 0.0
var _t:= 0.0
var _age:= 0.0
var _phase:= 0.0
var _up:= 0.15
var _up_hold:= 0.15
var _found_t:= 0.0
var _puff:= 0.0
var _ring:= -1.0
var _mouth:= Vector2.ZERO

var _root: Node2D
var _body: Polygon2D
var _face: Polygon2D
var _fin_l: Sprite2D
var _fin_r: Sprite2D
var _mats: Array = []
var _tw:= 248.0
var _th:= 1152.0


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for c in ["y", "p"]:
		var bi:= Image.load_from_file("res://assets/koi_body_back_%s.png" % c)
		var fi:= Image.load_from_file("res://assets/koi_body_face_%s.png" % c)
		if bi and fi:
			T_COL[c] = [ImageTexture.create_from_image(bi), ImageTexture.create_from_image(fi)]
	for pair in [["koi_body_back", "b"], ["koi_body_face", "f"], ["koi_fin_l", "l"], ["koi_fin_r", "r"]]:
		var im:= Image.load_from_file("res://assets/%s.png" % pair[0])
		var tx: Texture2D = ImageTexture.create_from_image(im) if im else null
		match pair[1]:
			"b": T_BACK = tx
			"f": T_FACE = tx
			"l": T_FIN_L = tx
			"r": T_FIN_R = tx


func _mat(fin: bool) -> ShaderMaterial:
	var m:= ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("is_fin", 1.0 if fin else 0.0)
	_mats.append(m)
	return m


func _ready() -> void:
	_load()
	_phase = randf() * TAU
	_tw = float(T_BACK.get_width())
	_th = float(T_BACK.get_height())
	_root = Node2D.new()
	add_child(_root)
	# fins first so their roots tuck under the body edge
	_fin_l = Sprite2D.new()
	_fin_l.texture = T_FIN_L
	_fin_l.centered = false
	_fin_l.offset = -FIN_PIVOT_L
	_fin_l.position = FIN_ROOT_L
	_fin_l.material = _mat(true)
	_fin_r = Sprite2D.new()
	_fin_r.texture = T_FIN_R
	_fin_r.centered = false
	_fin_r.offset = -FIN_PIVOT_R
	_fin_r.position = FIN_ROOT_R
	_fin_r.material = _mat(true)
	_root.add_child(_fin_l)
	_root.add_child(_fin_r)
	_body = Polygon2D.new()
	_body.texture = T_COL[color][0] if T_COL.has(color) else T_BACK
	_body.material = _mat(false)
	_root.add_child(_body)
	_face = Polygon2D.new()
	_face.texture = T_COL[color][1] if T_COL.has(color) else T_FACE
	_face.material = _mat(false)
	_root.add_child(_face)
	var uv:= PackedVector2Array()
	var polys:= []
	for i in SEGS + 1:
		var v:= float(i) / SEGS * _th
		uv.append(Vector2(0.0, v))
		uv.append(Vector2(_tw, v))
	for i in SEGS:
		polys.append(PackedInt32Array([i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2]))
	for p in [_body, _face]:
		p.uv = uv
		p.polygons = polys
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_bend()
	_apply(0.0)


func discover() -> void:
	if not discovered and not _leaving:
		discovered = true
		_found_facing = facing
		_found_t = 0.0


func head_pos() -> Vector2:
	return position + _mouth


func is_leaving() -> bool:
	return _leaving


# Touch or timeout: turn back out the way it came and go down.
func shoo() -> void:
	if _leaving:
		return
	_leaving = true
	_lt = 0.0
	_up_hold = _up
	# v101: only a slight turn (about 45 degrees) to the side that leads away from the dew, never a U-turn
	var a1:= facing + 0.8
	var a2:= facing - 0.8
	_dive_dir = a1 if randf() < 0.5 else a2
	if watch and is_instance_valid(watch):
		var away:= (global_position - watch.global_position).angle()
		_dive_dir = a1 if absf(wrapf(a1 - away, -PI, PI)) < absf(wrapf(a2 - away, -PI, PI)) else a2


func _process(delta: float) -> void:
	_t += delta
	_age += delta
	if _leaving:
		_lt += delta
	else:
		# surfacing eases in and out (about 2.4 s), sinking back to lurk is slower still
		_up = move_toward(_up, 1.0 if discovered else (0.2 + 0.14 * maxf(sin(_t * 0.35 + _phase), 0.0)), delta * (0.28 if discovered else 0.12))
		if discovered:
			_found_t += delta
			if _found_t > stay_time:
				shoo()
		# v99: swims like the small koi: a velocity that eases toward a wandering goal, the head
		# following the velocity, and the body wave growing with speed. Never stop-and-go.
		_goal_t -= delta
		var to_home:= home - position
		var arriving:= to_home.length() > 60.0
		if arriving:
			_goal = home
		elif _goal_t <= 0.0 or position.distance_to(_goal) < 18.0:
			_goal_t = randf_range(3.0, 6.0)
			# v101: the next goal is always ahead of it (within ~45 degrees); when it has wandered off,
			# that cone just leans toward home, so it curves back instead of turning round
			var lean:= 0.0
			if to_home.length() > 30.0:
				lean = clampf(wrapf(to_home.angle() - facing, -PI, PI), -0.6, 0.6)
			_goal = position + Vector2.from_angle(facing + lean + randf_range(-0.6, 0.6)) * randf_range(35.0, 70.0)
		var cruise:= 16.0
		if arriving:
			cruise = 38.0
		elif discovered:
			cruise = 6.0
		elif style == 2:
			# darter: a quick burst now and then, otherwise slow
			var cyc:= fmod(_t + _phase * 2.0, 4.2)
			cruise = 8.0 + 46.0 * (1.0 - smoothstep(0.0, 0.9, cyc)) * smoothstep(0.0, 0.1, cyc)
		var desired:= (_goal - position).normalized() * cruise
		if discovered and not arriving and aim_dew and watch and is_instance_valid(watch):
			# hangs facing the dew, drifting a touch toward it and back
			desired = Vector2.from_angle(facing) * cruise * (0.5 + 0.5 * sin(_t * 0.4 + _phase))
		_vel = _vel.lerp(desired, clampf(delta * (2.4 if style == 2 else 0.9), 0.0, 1.0))
		position += _vel * delta
		var spd:= _vel.length()
		var want_f:= facing
		if discovered and not arriving and aim_dew and watch and is_instance_valid(watch):
			# looks toward the dew, but turns at most ~60 degrees from where it was heading when found
			var to_d:= (watch.global_position - global_position).angle()
			want_f = _found_facing + clampf(wrapf(to_d - _found_facing, -PI, PI), -1.05, 1.05)
		elif spd > 1.5:
			want_f = _vel.angle()
		# a big fish turns slowly: at most about 23 degrees a second
		var turn:= clampf(wrapf(want_f - facing, -PI, PI) * clampf(delta * 1.2, 0.0, 1.0), -0.4 * delta, 0.4 * delta)
		facing += turn
		_speed = spd
		# the swimming effort that drives the body wave: proportional to speed
		_kick = clampf(spd / 40.0, 0.06, 1.0)
		if discovered and not _surfaced and _up > 0.9:
			_surfaced = true
			if on_surface.is_valid():
				on_surface.call()
	if _leaving:
		var hp:= smoothstep(0.0, 2.0, _lt)
		_kick = lerpf(_kick, 0.9, clampf(delta * 1.2, 0.0, 1.0))
		position += Vector2.from_angle(lerp_angle(facing, _dive_dir, hp)) * (8.0 + 46.0 * smoothstep(0.3, 3.6, _lt)) * delta
	_apply(delta)
	if _leaving and _lt > 4.6:
		queue_free()
	queue_redraw()
	_fx.queue_redraw()


func _apply(delta: float) -> void:
	var up0:= _up if not _leaving else _up_hold
	var up:= up0 * up0 * (3.0 - 2.0 * up0)     # eased
	var hp:= smoothstep(0.0, 2.0, _lt)
	var sinkk:= smoothstep(0.4, 4.6, _lt)
	var dturn:= wrapf(_dive_dir - facing, -PI, PI) if _leaving else 0.0
	var sc:= size * 1.22 / _th * lerpf(0.92, 1.0, up) * (1.0 - 0.08 * sinkk)
	var flen:= _th * 0.95 * sc
	var rot:= facing + PI * 0.5 + sin(_wave + 1.2) * 0.04 * (0.3 + _kick) + dturn * hp
	_root.rotation = rot
	_root.scale = Vector2(sc, sc)
	# v88: the koi turns about the middle of its body (not its mouth); its position is the body centre
	_root.position = Vector2.ZERO
	_bend()
	var depth:= clampf(lerpf(1.0 - up, 1.0, sinkk), 0.0, 1.0)
	var fade:= smoothstep(0.0, 2.0, _age) * lerpf(0.52, 1.0, up) * (1.0 - smoothstep(2.2, 4.4, _lt))
	# puff while it holds at the surface
	var cyc:= fmod(_t + 0.6, 3.6)
	var want:= 0.0
	if up > 0.85 and not _leaving:
		want = smoothstep(0.0, 0.35, cyc) * (1.0 - smoothstep(2.3, 2.9, cyc))
		if cyc < 0.3 and _ring < 0.0:
			_ring = 0.0
	_puff = move_toward(_puff, want, delta * 3.0)
	if _ring >= 0.0:
		_ring += delta * 0.6
		if _ring > 1.0:
			_ring = -1.0
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("depth", depth)
		(m as ShaderMaterial).set_shader_parameter("fade", fade)
	(_face.material as ShaderMaterial).set_shader_parameter("fade", fade * _puff)
	# pectoral fins: together in soft beats; while turning the inside one reaches forward
	var flap:= sin(_t * 2.3 + 0.5 * sin(_t * 2.3)) * 0.85 + 0.15 * sin(_t * 4.6 + 0.7)
	var base:= 0.16 * flap * (1.0 - 0.5 * absf(sin(PI * hp)))
	var asym:= signf(dturn) * sin(PI * hp) * 0.18
	_fin_l.rotation = base + asym
	_fin_r.rotation = -base + asym
	_mouth = _root.position + Vector2(0.0, -_th * 0.47 * sc).rotated(rot)


# Spine: rigid through the head and fins, then a slow single curve toward the tail, with the tail
# trailing the beat. While turning away, each part behind the fins reaches the new heading later.
func _bend() -> void:
	var pts:= PackedVector2Array()
	var seg:= _th / SEGS
	var p:= Vector2(0.0, -_th * 0.5)
	var ang:= 0.0
	var dt:= get_process_delta_time()
	# v96: remember where the head pointed, so the body and tail follow the path the head took
	var rot_now:= _root.rotation if _root else 0.0
	_hist.push_front(Vector2(_t, rot_now))
	while _hist.size() > 2 and _t - _hist[_hist.size() - 1].x > 2.2:
		_hist.pop_back()
	# the waist swings with the swimming effort: small while gliding or hanging, bigger on a kick
	var amp:= 0.08 + 0.42 * _kick
	_wave += dt * (0.7 + 1.6 * _kick)
	var tail_a:= 0.0
	for i in SEGS + 1:
		var s:= float(i) / SEGS
		var sb:= maxf(s - RIGID_S, 0.0) / (1.0 - RIGID_S)
		var a:= 0.0
		if sb > 0.0:
			# one travelling wave along the body: grows smoothly toward the tail
			var env:= sb * sb * (3.0 - 2.0 * sb)
			a = amp * env * sin(_wave + _phase - sb * 4.2)
			# follow-through: each part points where the head pointed a moment ago
			var lag:= _rot_at(_t - sb * 0.9)
			a += clampf(wrapf(rot_now - lag, -PI, PI), -1.0, 1.0) * sb
		if s > 0.87:
			# the tail fin is one rigid paddle: it keeps the line of the tail stalk, softened
			a = tail_a
		else:
			tail_a = a
		if i > 0:
			ang = lerpf(ang, a, 0.45)
			p += Vector2(sin(ang), cos(ang)) * seg
		var n:= Vector2(cos(ang), -sin(ang))
		pts.append(p - n * _tw * 0.5)
		pts.append(p + n * _tw * 0.5)
		if i >= _spine.size():
			_spine.append(p)
		else:
			_spine[i] = p
	_body.polygon = pts
	_face.polygon = pts


func _rot_at(when: float) -> float:
	for h in _hist:
		if h.x <= when:
			return h.y
	return _hist[_hist.size() - 1].y if not _hist.is_empty() else 0.0


func _draw() -> void:
	# a soft shadow on the pond floor: tight when deep, wider and offset as it nears the surface
	if _spine.is_empty():
		return
	var up0:= _up if not _leaving else _up_hold
	var vis:= smoothstep(0.0, 3.0, _age) * smoothstep(0.35, 0.9, up0) * (1.0 - smoothstep(2.6, 5.4, _lt))
	var off:= Vector2(8.0, 12.0) * (0.4 + up0)
	var xf:= _root.transform
	for i in range(2, _spine.size(), 2):
		var s:= float(i) / SEGS
		var w:= _tw * xf.get_scale().x * (0.42 - 0.3 * s)
		var c:= xf * _spine[i] + off
		for q in 3:
			draw_circle(c, w * (0.7 + 0.3 * q), Color(0.0, 0.04, 0.05, 0.05 * vis * (0.6 + 0.4 * up0)))


func _draw_fx() -> void:
	# one big soft bubble ring at the mouth on each puff
	if _ring >= 0.0:
		var r:= _ring
		var rr:= 14.0 + r * 46.0
		_fx.draw_circle(_mouth, rr, Color(0.9, 1.0, 1.0, 0.06 * (1.0 - r)))
		_fx.draw_arc(_mouth, rr, 0, TAU, 48, Color(0.92, 1.0, 1.0, 0.55 * (1.0 - r)), 2.2, true)
		_fx.draw_arc(_mouth + Vector2(-rr * 0.3, -rr * 0.3), rr * 0.35, PI * 1.05, PI * 1.55, 12, Color(1, 1, 1, 0.45 * (1.0 - r)), 1.6, true)
