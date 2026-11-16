class_name Ripple
extends Node2D


var life:= 1.1
var size:= 1.0
var rings:= 2
var _t:= 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= life + 0.25 * (rings - 1):
		queue_free()
		return
	queue_redraw()


var _seed:= randf() * 100.0


func _draw() -> void:
	var depth:= Main.depth_at(global_position.y)
	for r in rings:
		var k:= (_t - r * 0.22) / life
		if k <= 0.0 or k >= 1.0:
			continue
		var e:= 1.0 - pow(1.0 - k, 2.2)
		var a:= 85.0 * size * depth * (0.35 + e)
		var b:= a * LilyPad.TILT
		var fade:= (1.0 - k) * (1.0 if r == 0 else 0.6)
		var n:= 72
		var prev:= Vector2(a, 0)
		for i in range(1, n + 1):
			var ang:= TAU * i / n
			var p:= Vector2(cos(ang) * a, sin(ang) * b)

			var s:= sin(ang * 5.0 + _seed + r) * 0.6 + sin(ang * 11.0 - _seed * 1.7 + k * 3.0) * 0.4 + 0.15
			if s > 0.0:
				var w:= (0.6 + 1.8 * s) * (0.6 + 0.8 * (1.0 - k)) * 0.9
				var col:= Color(0.7, 0.88, 0.84).lerp(Color(0.92, 0.98, 0.9), s * 0.5)
				draw_line(prev, p, Color(col, 0.38 * fade * clampf(s * 1.6, 0.0, 1.0)), w, true)
			prev = p
