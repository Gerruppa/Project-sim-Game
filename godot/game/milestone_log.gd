class_name MilestoneLog
extends RunObserver
## New, returned and lost life since the window last looked, for the toasts
## that celebrate (or mourn) a step on the ladder of life. Watches the run,
## changes nothing in it.

const KINDS := {&"species_emerged": "emerged", &"species_returned": "returned", &"species_extinct": "extinct"}

var _news: Array[Dictionary] = []


func attach(bus: EventBus) -> void:
	for type: StringName in KINDS:
		bus.subscribe(type, _on_event)


func _on_event(event: SimEvent) -> void:
	_news.append({"kind": KINDS[event.type], "species": str(event.data.get("species")), "tick": event.tick})


## What happened since the last call, oldest first (cleared on read).
func take_news() -> Array[Dictionary]:
	var news := _news
	_news = []
	return news
