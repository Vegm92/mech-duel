extends SceneTree

const FROM_MS := 8000
const TO_MS := 38000

var acc := {"gpu": 0.0, "cpu": 0.0, "draws": 0.0, "prims": 0.0, "objs": 0.0}
var n := 0
var peak := 0.0


func _initialize() -> void:
	root.add_child(load("res://main.tscn").instantiate())
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _process(_dt: float) -> bool:
	var t := Time.get_ticks_msec()
	if t > FROM_MS and t <= TO_MS:
		var rid := root.get_viewport_rid()
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		acc.gpu += gpu
		peak = maxf(peak, gpu)
		acc.cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		acc.draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		acc.prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		acc.objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		n += 1
	if t > TO_MS:
		print("PERF frames=%d gpu_ms=%.2f gpu_peak_ms=%.2f render_cpu_ms=%.2f draws=%d prims=%d objects=%d vram_mb=%.0f nodes=%d" % [n, acc.gpu / n, peak, acc.cpu / n, acc.draws / n, acc.prims / n, acc.objs / n, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		quit()
	return false
