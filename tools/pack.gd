extends SceneTree
const SRC:= "/home/claude/web/stage"
var pk:= PCKPacker.new()
var count:= 0
func _walk(d: String) -> void:
	var da:= DirAccess.open(d)
	da.include_hidden = true
	da.list_dir_begin()
	var n:= da.get_next()
	while n != "":
		var p:= d.path_join(n)
		if da.current_is_dir(): _walk(p)
		else:
			pk.add_file("res://" + p.substr(SRC.length() + 1), p); count += 1
		n = da.get_next()
func _init():
	pk.pck_start("/home/claude/web/out/index.pck")
	_walk(SRC)
	pk.flush()
	print("packed ", count)
	quit()
