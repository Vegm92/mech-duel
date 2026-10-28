extends SceneTree

const Sim = preload("res://src/sim.gd")
const TOP := 100.0

var main: Node
var tick := 700
var out := ""
var top := false
var hidden := false
var wait := 2


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tick="):
			tick = a.substr(7).to_int()
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--top":
			top = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	RenderingServer.frame_post_draw.connect(drawn)


func _process(_dt: float) -> bool:
	var st = main.get("state")
	if hidden or st == null or st.is_empty() or st.tick < tick:
		return false
	main.frozen = true
	main.view.pops.clear()
	hide_fx(main.view)
	for mech in main.view.mechs:
		mech.aim_line.visible = false
	if top:
		main.set_physics_process(false)
		main.hud.visible = false
		main.dist = TOP
		main.focus = Vector3(Sim.CX, 0, Sim.CY + TOP * 0.09)
		main.place_camera()
	hidden = true
	return false


func hide_fx(n: Node) -> void:
	for c in n.get_children():
		if c is Label3D or c is CPUParticles3D or c is GPUParticles3D:
			c.visible = false
		elif c is GeometryInstance3D:
			var m = c.material_override
			if m == null and c is MeshInstance3D and c.mesh != null and c.mesh.get_surface_count() > 0:
				m = c.get_active_material(0)
			if (m is BaseMaterial3D and (m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or (m.emission_enabled and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED))) or (m is ShaderMaterial and m.shader != null and "blend_add" in m.shader.code):
				c.visible = false
		hide_fx(c)


func drawn() -> void:
	if not hidden:
		return
	wait -= 1
	if wait > 0:
		return
	root.get_texture().get_image().save_png(out)
	quit()
