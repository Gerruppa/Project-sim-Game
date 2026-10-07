class_name ThreatLog
extends RunObserver
## Early warnings as the window needs them: the ones that arrived since the
## last look, each flagged when it is the first of its kind in this game (the
## window stops the game for that one and explains). Watches the run, changes
## nothing in it. Which kinds the player has met is saved with the game.

## Event ids already warned about in this game.
var _met: Array[String] = []
var _new: Array[Dictionary] = []


func attach(bus: EventBus) -> void:
	bus.subscribe(EventSystem.WARNED_EVENT, _on_warned)


func _on_warned(event: SimEvent) -> void:
	var id := str(event.data.get("id"))
	_new.append({"id": id, "name": str(event.data.get("name")), "text": str(event.data.get("story")),
			"counters": Array(event.data.get("counters", [])), "first_time": not _met.has(id)})
	if not _met.has(id):
		_met.append(id)


## Warnings that arrived since the last call, oldest first (cleared on read).
func take_new_warnings() -> Array[Dictionary]:
	var warnings := _new
	_new = []
	return warnings


func save_state() -> Dictionary:
	return {"met": _met.duplicate()}


## Missing or damaged data starts fresh; it never blocks a game.
func load_state(data: Dictionary) -> void:
	_met.clear()
	var met: Variant = data.get("met", [])
	if typeof(met) == TYPE_ARRAY:
		for id: Variant in met:
			if typeof(id) == TYPE_STRING and not _met.has(id):
				_met.append(id)
