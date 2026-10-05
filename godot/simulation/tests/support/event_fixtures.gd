extends RefCounted
## EventSystem test data: definitions, catalogs and hand-built snapshots.

const P := preload("res://simulation/tests/support/schema_fixtures.gd")
const Q := preload("res://simulation/tests/support/personality_fixtures.gd")

const ARCHETYPES: Array[StringName] = [&"harmonious", &"chaotic", &"guardian"]


## A simple event: starts when humidity < 20, ends when humidity > 30.
static func def(id: String, overrides: Dictionary = {}) -> Dictionary:
	var data := {
		"id": id,
		"name": "Test " + id,
		"story": {"start": id + " begins.", "end": id + " is over.", "end_time_limit": id + " fades out."},
		"trigger": {"condition": {"measure": "value", "param": "humidity", "op": "<", "value": 20}, "for_ticks": 1},
		"end": {"condition": {"measure": "value", "param": "humidity", "op": ">", "value": 30}, "for_ticks": 1},
		"min_duration": 0,
		"max_duration": 100,
		"cooldown": 0,
		"modifiers": [{"target": "climate.water_availability", "operation": "multiply", "value": 0.5}],
	}
	data.merge(overrides, true)
	return data


static func catalog_data(defs: Array) -> Dictionary:
	return {"events_version": 1, "events": defs}


static func parse(defs: Array) -> SimResult:
	return EventCatalog.from_data(catalog_data(defs), P.project_schema(), Q.specs(), ARCHETYPES)


static func catalog(defs: Array) -> EventCatalog:
	var result := parse(defs)
	assert(result.is_ok(), "fixture event catalog must be valid: %s" % [result.errors])
	return result.value


static func project_catalog() -> EventCatalog:
	return EventCatalog.load_json(EventCatalog.DEFAULT_PATH, P.project_schema(), Q.specs(), ARCHETYPES).value


## Registry that knows the coefficients of the project's systems.
static func registry() -> ModifierRegistry:
	var result := ModifierRegistry.new()
	for id: StringName in Q.specs():
		result.register_target(id, Q.specs()[id])
	return result


## Project initial values with `values` (id -> value) on top.
static func snapshot(values: Dictionary, tick: int = 0) -> PlanetSnapshot:
	var schema := P.project_schema()
	var all := schema.initial_values()
	for id: String in values:
		all[schema.index_of(StringName(id))] = values[id]
	return PlanetSnapshot.new(schema, all, tick)


static func history_of(id: StringName, values: Array, capacity: int = 0) -> ParamHistory:
	var history := ParamHistory.new({id: capacity if capacity > 0 else values.size()})
	for value: float in values:
		history.record(snapshot({String(id): value}))
	return history
