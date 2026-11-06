extends Logger
## Counts script errors the engine logs while a test file runs, so a test that hits one fails.

var errors := 0
var _lock := Mutex.new()


func _init() -> void:
	OS.add_logger(self)


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_lock.lock()
	errors += 1
	_lock.unlock()
	print("script error: %s (%s:%d %s)" % [rationale if rationale else code, file, line, function])


## Returns how many script errors were logged; the caller adds it to its failure count.
func report() -> int:
	if errors:
		print("test file failed: %d script error(s)" % errors)
	return errors
