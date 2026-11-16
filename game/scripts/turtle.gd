class_name Turtle
extends Koi


const TEX_BLUE:= preload("res://assets/blue_turtle.png")
const TEX_WHITE:= preload("res://assets/white_turtle.png")
var white:= false
var red:= false
var TEX: Texture2D = TEX_BLUE
const HEAD_ANGLE:= -0.72
# v102: swims with its flippers. The picture is cut into a shell and four flippers (head up);
# the front flippers beat together in a slow "flying" stroke, the back ones trail and steer.
const PARTS_ROOT:= {"fl": Vector2(-60, -121), "fr": Vector2(52, -124), "bl": Vector2(-69, 87), "br": Vector2(64, 69)}
static var _parts: Dictionary = {}
var _base_speed:= -1.0
var _stroke:= 0.0


static func _part_tex(col: String) -> Dictionary:
	if not _parts.has(col):
		var d:= {}
		for k in ["body", "fl", "fr", "bl", "br"]:
			var im:= Image.load_from_file("res://assets/turtle_%s_%s.png" % [col, k])
			d[k] = ImageTexture.create_from_image(im) if im else null
		_parts[col] = d
	return _parts[col]


# Draws the turtle from its parts at the current transform (head pointing along `rot`).
func _draw_parts(off: Vector2, rot: float, sc: float, mod: Color) -> void:
	_paint_parts_on(self, off, rot, sc, mod)


func _paint_parts_on(ci: CanvasItem, off: Vector2, rot: float, sc: float, mod: Color) -> void:
	var col:= "white" if (white or red) else "blue"   # red is the white picture tinted, as before
	var P:= _part_tex(col)
	if P["body"] == null:
		ci.draw_set_transform(off, rot - HEAD_ANGLE, Vector2(sc, sc))
		ci.draw_texture(TEX, -Vector2(256, 256), mod)
		return
	var ph:= _t * 1.25 + float(get_instance_id() % 97)
	# power stroke down-and-back is quicker than the slow recovery
	var beat:= sin(ph + 0.35 * sin(ph))
	_stroke = beat
	var base:= Transform2D(rot + PI * 0.5, off) * Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2.ZERO)
	var swing:= {"fl": -0.55 * beat - 0.1, "fr": 0.55 * beat + 0.1, "bl": 0.18 * sin(ph - 1.2), "br": -0.18 * sin(ph - 1.2)}
	for k in ["bl", "br", "fl", "fr"]:
		var r: Vector2 = PARTS_ROOT[k]
		var L:= Transform2D(swing[k], r) * Transform2D(0.0, -r)
		ci.draw_set_transform_matrix(base * L)
		ci.draw_texture(P[k], -Vector2(256, 256), mod)
	# the shell rises a hair on the power stroke, the head sways a little
	var bob:= Transform2D(sin(ph * 0.5) * 0.03, Vector2(0.0, -2.0 * maxf(beat, 0.0)))
	ci.draw_set_transform_matrix(base * bob)
	ci.draw_texture(P["body"], -Vector2(256, 256), mod)

var deep:= false
var _grp: CanvasGroup
var _pnt: Node2D
var _paint_args: Array = []


func _ensure_group() -> void:
	if _grp:
		return
	_grp = CanvasGroup.new()
	_grp.show_behind_parent = true
	_grp.fit_margin = 16.0
	_pnt = Node2D.new()
	_grp.add_child(_pnt)
	add_child(_grp)
	_pnt.draw.connect(_paint_deep)


func _paint_deep() -> void:
	if _paint_args.is_empty():
		return
	var rot: float = _paint_args[0]
	var s2: float = _paint_args[1]
	var tint: Color = _paint_args[2]
	var k: float = _paint_args[3]
	for i in 2:
		var o:= Vector2.from_angle(i * PI + _t) * (6.0 * (1.0 - k) + 1.5)
		_paint_parts_on(_pnt, o, rot, s2, Color(tint, 0.3))
	_paint_parts_on(_pnt, Vector2.ZERO, rot, s2, Color(tint, 1.0))
	_pnt.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
var pass_through:= false
var life:= 0.0
const RISE:= 1.8
const STAY:= 3.6
const SINK:= 2.4


func setup(at: Vector2, seed_v: int) -> void:
	super.setup(at, seed_v)
	speed = 22.0
	length = 70.0


func add_echo() -> void:
	pass


func _process(delta: float) -> void:
	if pass_through:
		home_radius = 5.0
		if position.distance_to(goal) < 30.0:
			goal += Vector2.from_angle(heading) * 200.0
	if _base_speed < 0.0:
		_base_speed = speed
	speed = _base_speed * (0.7 + 0.45 * maxf(_stroke, 0.0))
	super._process(delta)
	if deep:
		life += delta * (0.55 if pass_through else 1.0)
		if life > RISE + STAY + SINK:
			queue_free()


func _surface_k() -> float:
	if life < RISE:
		var k:= life / RISE
		return k * k * (3.0 - 2.0 * k)
	if life < RISE + STAY:
		return 1.0
	var k2:= clampf((life - RISE - STAY) / SINK, 0.0, 1.0)
	return 1.0 - k2 * k2


func _draw() -> void:
	var dp:= Main.depth_at(global_position.y)
	var sc:= length / 384.0 * dp
	var rot:= heading
	if not deep:
		_draw_parts(Vector2(5, 7), rot, sc, Color(0, 0.08, 0.05, 0.35))
		_draw_parts(Vector2.ZERO, rot, sc, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var k:= _surface_k()
	var s2:= sc * lerpf(0.72, 1.0, k)

	var tint:= Color(0.1, 0.24, 0.32).lerp(Color(0.42, 0.6, 0.78), k * 0.55)
	if white:
		tint = Color(0.16, 0.32, 0.34).lerp(Color(0.92, 0.96, 0.95), k * 0.75)
	if red:
		tint = Color(0.42, 0.08, 0.06).lerp(Color(1.0, 0.28, 0.18), k * 0.95)
	var a:= 0.06 + 0.34 * k

	# v112: the see-through turtle is painted solid into a CanvasGroup and faded as one picture,
	# so the flipper roots no longer show through the shell where the parts overlap.
	_ensure_group()
	_grp.self_modulate = Color(1, 1, 1, a)
	_paint_args = [rot, s2, tint, k]
	_pnt.queue_redraw()

	for i in 6:
		var p:= Vector2.from_angle(_t * 0.6 + i * 1.7) * length * 0.22 * dp
		draw_circle(p, 6.0 + 3.0 * sin(_t * 2.0 + i), Color(0.8, 1.0, 0.9, 0.08 * k))

	for i in 5:
		var ph:= fmod(_t * 0.5 + i * 0.37, 1.0)
		var bp:= Vector2(sin(i * 2.3) * length * 0.25, -ph * length * 0.6)
		draw_arc(bp, 2.0 + ph * 2.0, 0, TAU, 12, Color(0.85, 1.0, 1.0, 0.5 * k * (1.0 - ph)), 1.0, true)
