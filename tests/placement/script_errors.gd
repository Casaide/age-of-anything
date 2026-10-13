extends Logger
## Counts script errors (a failed assert, an invalid call or access) while the placement checks run.
## An error inside a check aborts that function and the rules after it are never noted, which read
## as a pass: the sheet tool passed every TC1 row while its new composite checks were crashing
## (2026-10-13). The sheet tool and tests/placement_check.gd fail when any were counted.
## Install: OS.add_logger(errors); read `count` and `first` at the end.

var count := 0
var first := ""
var _lock := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_lock.lock()
	count += 1
	if first == "":
		first = "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
	_lock.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass
