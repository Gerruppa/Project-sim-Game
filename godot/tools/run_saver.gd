class_name RunSaver
extends RefCounted
## Saves one console run: autosaves every N ticks and a save on request.
##
## Autosaves overwrite one file per run (<run id>.autosave.json), so a long
## run never fills the disk; --save names a save worth keeping.

var _manager: SimulationManager
var _run: Dictionary
var _autosave_path: String
var _every: int
var _next: int


## run: {"personality", "data_fingerprints", "lineage"} for SaveSystem.capture.
## every: ticks between autosaves, 0 = off.
func _init(manager: SimulationManager, run: Dictionary, autosave_path: String, every: int) -> void:
	_manager = manager
	_run = run
	_autosave_path = autosave_path
	_every = every
	_next = _next_after(manager.tick())


## Call after ticks ran. Saves once when one or more boundaries were crossed
## (real time can run many ticks per frame). Value: saved path or null.
func after_ticks() -> SimResult:
	if _every == 0 or _manager.tick() < _next or _manager.is_halted():
		return SimResult.success(null)
	_next = _next_after(_manager.tick())
	return save_to(_autosave_path)


func save_to(path: String) -> SimResult:
	return SaveSystem.write(path, SaveSystem.capture(_manager, _run))


func autosave_path() -> String:
	return _autosave_path


func _next_after(tick: int) -> int:
	return tick - tick % _every + _every if _every > 0 else 0
