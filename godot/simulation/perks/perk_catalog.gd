class_name PerkCatalog
extends RefCounted
## Perks loaded from JSON and validated against what the planet can be asked
## to do: modifier targets come from system coefficient specs, unlocks from the
## intervention catalog. A typo is a load error, not a perk that does nothing,
## and every intervention is either free or reachable through some perk.

const DEFAULT_PATH := "res://resources/perks/perks.json"
const TREES: Array[StringName] = [&"environment", &"life"]
const KEYS := ["id", "name", "help", "tree", "cost", "requires", "modifiers", "unlocks", "side_effect", "story"]
const TOP_KEYS := ["perks_version", "refund_ratio", "income_per_biomass_tick", "free_interventions", "perks"]
const STORY_KEYS: Array[String] = ["bought", "refunded"]

var _defs: Array[PerkDef] = []
## Share of the price returned when a perk is refunded.
var refund_ratio := 0.0
## Sparks earned per tick for each unit of biomass.
var income_per_biomass_tick := 0.0
## Interventions usable without any perk.
var free_interventions: Array[StringName] = []


## specs: system id -> coefficient spec (modifier targets).
## intervention_ids: every intervention the game has.
static func load_json(path: String, specs: Dictionary, intervention_ids: Array[StringName]) -> SimResult:
	var read := CoefficientLoader.read_json(path, "perks")
	return from_data(read.value, specs, intervention_ids) if read.is_ok() else read


## Reports all errors at once.
static func from_data(data: Dictionary, specs: Dictionary, intervention_ids: Array[StringName]) -> SimResult:
	var result := SimResult.new()
	var raw: Variant = data.get("perks")
	if typeof(raw) != TYPE_ARRAY:
		return SimResult.failure("perks: 'perks' must be a list")
	for key: Variant in data:
		if not TOP_KEYS.has(key):
			result.add_error("perks: unknown key '%s'" % key)
	var catalog := PerkCatalog.new()
	catalog.refund_ratio = _number(data.get("refund_ratio"), "refund_ratio", 0.0, 1.0, result)
	catalog.income_per_biomass_tick = _number(data.get("income_per_biomass_tick"), "income_per_biomass_tick", 0.0, INF, result)
	_parse_free(data.get("free_interventions"), catalog, intervention_ids, result)
	var seen: Array[StringName] = []
	for i in (raw as Array).size():
		var def := _parse(raw[i], i, specs, intervention_ids, result)
		if def == null:
			continue
		if seen.has(def.id):
			result.add_error("perks: duplicate id '%s'" % def.id)
		seen.append(def.id)
		catalog._defs.append(def)
	catalog._check_requirements(result)
	catalog._check_interventions_reachable(intervention_ids, result)
	if result.is_ok():
		result.value = catalog
	return result


static func _parse_free(raw: Variant, catalog: PerkCatalog, intervention_ids: Array[StringName], result: SimResult) -> void:
	if typeof(raw) != TYPE_ARRAY or not (raw as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_STRING):
		result.add_error("perks: 'free_interventions' must be a list of intervention ids")
		return
	for id: String in raw:
		if not intervention_ids.has(StringName(id)):
			result.add_error("perks: free intervention '%s' is not a known intervention" % id)
		catalog.free_interventions.append(StringName(id))


static func _parse(raw: Variant, index: int, specs: Dictionary, intervention_ids: Array[StringName], result: SimResult) -> PerkDef:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("perks[%d] must be an object" % index)
		return null
	var data := raw as Dictionary
	var def := PerkDef.new()
	var label := "perks[%d]" % index
	for key: Variant in data:
		if not KEYS.has(key):
			result.add_error("%s: unknown key '%s'" % [label, key])
	if typeof(data.get("id")) != TYPE_STRING or (data["id"] as String).is_empty():
		result.add_error("%s: 'id' must be a non-empty string" % label)
	else:
		def.id = StringName(data["id"])
		label = "perk '%s'" % def.id
	for key: String in ["name", "help", "side_effect"]:
		if typeof(data.get(key)) != TYPE_STRING or (data[key] as String).is_empty():
			result.add_error("%s: '%s' must be a non-empty string" % [label, key])
		else:
			def.set(key, data[key])
	if typeof(data.get("tree")) != TYPE_STRING or not TREES.has(StringName(data["tree"])):
		result.add_error("%s: 'tree' must be one of %s" % [label, TREES])
	else:
		def.tree = StringName(data["tree"])
	var cost: Variant = data.get("cost")
	if not (typeof(cost) in [TYPE_INT, TYPE_FLOAT]) or float(cost) != floorf(float(cost)) or float(cost) < 1.0:
		result.add_error("%s: 'cost' must be an integer >= 1" % label)
	else:
		def.cost = int(cost)
	_parse_names(data.get("requires", []), "requires", def.requires, label, result)
	var unlocks: Array[StringName] = []
	_parse_names(data.get("unlocks", []), "unlocks", unlocks, label, result)
	for id in unlocks:
		if not intervention_ids.has(id):
			result.add_error("%s: unlocks unknown intervention '%s'" % [label, id])
		def.unlocks.append(id)
	_parse_modifiers(data.get("modifiers", []), def, label, specs, result)
	if def.modifiers.is_empty() and def.unlocks.is_empty():
		result.add_error("%s: needs at least one modifier or unlock" % label)
	_parse_story(data.get("story"), def, label, result)
	return def


static func _parse_names(raw: Variant, key: String, into: Array[StringName], label: String, result: SimResult) -> void:
	if typeof(raw) != TYPE_ARRAY or not (raw as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_STRING and not (v as String).is_empty()):
		result.add_error("%s: '%s' must be a list of ids" % [label, key])
		return
	for name: String in raw:
		into.append(StringName(name))


static func _parse_modifiers(raw: Variant, def: PerkDef, label: String, specs: Dictionary, result: SimResult) -> void:
	if typeof(raw) != TYPE_ARRAY:
		result.add_error("%s: 'modifiers' must be a list" % label)
		return
	for modifier: Variant in raw:
		Modifier.check_data(modifier, label, specs, result)
		if typeof(modifier) == TYPE_DICTIONARY:
			def.modifiers.append(modifier)


static func _parse_story(raw: Variant, def: PerkDef, label: String, result: SimResult) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		result.add_error("%s: 'story' must be an object with %s" % [label, STORY_KEYS])
		return
	for key: Variant in raw:
		if not STORY_KEYS.has(key):
			result.add_error("%s: unexpected story key '%s'" % [label, key])
	for key in STORY_KEYS:
		var text: Variant = (raw as Dictionary).get(key)
		if typeof(text) != TYPE_STRING or (text as String).is_empty():
			result.add_error("%s: story '%s' must be a non-empty string" % [label, key])
		else:
			def.story[key] = text


static func _number(value: Variant, key: String, low: float, high: float, result: SimResult) -> float:
	if not (typeof(value) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(value)) or float(value) < low or float(value) > high:
		result.add_error("perks: '%s' must be a number in %s..%s" % [key, low, high])
		return 0.0
	return float(value)


## Every requirement names a perk, and requirements never loop back.
func _check_requirements(result: SimResult) -> void:
	var known := ids()
	for def in _defs:
		for id in def.requires:
			if not known.has(id):
				result.add_error("perk '%s': requires unknown perk '%s'" % [def.id, id])
	# Depth-first walk: 1 = on the current path, 2 = done.
	var state := {}
	for def in _defs:
		_visit(def.id, [] as Array[StringName], state, result)


func _visit(id: StringName, path: Array[StringName], state: Dictionary, result: SimResult) -> void:
	if state.get(id, 0) == 2:
		return
	if state.get(id, 0) == 1:
		var loop := path.slice(path.find(id))
		loop.append(id)
		result.add_error("perks: requirement cycle %s" % " -> ".join(PackedStringArray(loop.map(func(n: StringName) -> String: return String(n)))))
		return
	var def := get_def(id)
	if def == null:
		return
	state[id] = 1
	path.append(id)
	for next in def.requires:
		_visit(next, path, state, result)
	path.pop_back()
	state[id] = 2


## An intervention nobody can ever use is a data mistake.
func _check_interventions_reachable(intervention_ids: Array[StringName], result: SimResult) -> void:
	for id in intervention_ids:
		if not free_interventions.has(id) and not _defs.any(func(d: PerkDef) -> bool: return d.unlocks.has(id)):
			result.add_error("perks: intervention '%s' is neither free nor unlocked by any perk" % id)


func get_def(id: StringName) -> PerkDef:
	for def in _defs:
		if def.id == id:
			return def
	return null


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for def in _defs:
		result.append(def.id)
	return result


func defs() -> Array[PerkDef]:
	return _defs.duplicate()
