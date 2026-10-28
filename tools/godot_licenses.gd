extends SceneTree


func _initialize() -> void:
	var out := "Godot Engine\n" + Engine.get_license_text() + "\n\nThird-party components inside the Godot Engine:\n"
	for part in Engine.get_copyright_info():
		out += "\n- " + part.name
		for p in part.parts:
			out += "\n  " + ", ".join(p.copyright) + " (" + p.license + ")"
	out += "\n\nLicense texts:\n"
	var info := Engine.get_license_info()
	for k in info:
		out += "\n==== " + k + " ====\n" + info[k] + "\n"
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(out)
	quit()
