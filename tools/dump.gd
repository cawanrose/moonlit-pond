extends SceneTree
# dump every file of the mounted pack to OUT
const OUT:= "/home/claude/web/stage"
func _walk(d: String) -> void:
	var da:= DirAccess.open(d)
	if da == null: return
	da.include_hidden = true
	da.list_dir_begin()
	var n:= da.get_next()
	while n != "":
		var p:= d.path_join(n) if d != "res://" else "res://" + n
		if da.current_is_dir():
			_walk(p)
		else:
			var rel:= p.substr(6)
			DirAccess.make_dir_recursive_absolute(OUT.path_join(rel.get_base_dir()))
			var f:= FileAccess.open(OUT.path_join(rel), FileAccess.WRITE)
			f.store_buffer(FileAccess.get_file_as_bytes(p)); f.close()
		n = da.get_next()
func _init():
	_walk("res://")
	quit()
