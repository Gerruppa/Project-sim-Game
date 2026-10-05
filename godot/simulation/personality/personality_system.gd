class_name PersonalitySystem
extends ModifierProvider
## The planet's character. Not intelligence: a set of permanent coefficient
## modifiers that make each planet feel different (DESIGN_PRINCIPLES.md).
##
## Outputs modifiers only, never deltas. The archetype is drawn from the seed
## (weighted) or forced by configuration; "none" means no personality.
## Reactions of the planet (e.g. a guardian healing after a mass extinction)
## come with EventSystem in step 7; see docs/events.md.

const ID := &"personality"
const STREAM_ID := "personality"
const STATE_FORMAT := "personality_state"

var _archetype: PersonalityArchetype
var _applied := false


## choice: an archetype id, PersonalityCatalog.RANDOM or PersonalityCatalog.NONE.
static func create(catalog: PersonalityCatalog, choice: StringName, global_seed: int) -> SimResult:
	var system := PersonalitySystem.new()
	if choice == PersonalityCatalog.NONE:
		return SimResult.success(system)
	if choice == PersonalityCatalog.RANDOM:
		system._archetype = _draw(catalog, global_seed)
		return SimResult.success(system)
	system._archetype = catalog.get_archetype(choice)
	if system._archetype == null:
		return SimResult.failure("unknown personality '%s'; known: %s, random, none" % [choice, catalog.ids()])
	return SimResult.success(system)


## Weighted draw from the personality's own RNG stream.
static func _draw(catalog: PersonalityCatalog, global_seed: int) -> PersonalityArchetype:
	var archetypes := catalog.all()
	var total := 0.0
	for archetype in archetypes:
		total += archetype.weight
	var pick := SeededRng.new(global_seed, STREAM_ID).next_unit_float() * total
	for archetype in archetypes:
		pick -= archetype.weight
		if pick < 0.0:
			return archetype
	return archetypes[archetypes.size() - 1]


func system_id() -> StringName:
	return ID


func archetype_id() -> StringName:
	return PersonalityCatalog.NONE if _archetype == null else _archetype.id


## Registers the archetype's modifiers once, on the first tick. Modifiers for
## systems the planet does not run (e.g. no biosphere) are skipped.
func provide_modifiers(_snapshot: PlanetSnapshot, _tick: int, registry: ModifierRegistry) -> void:
	if _applied or _archetype == null:
		return
	_applied = true
	_register_modifiers(registry)
	emit_event(&"planet_personality", {"archetype": String(_archetype.id), "description": _archetype.description})


func save_state() -> Dictionary:
	return {"format": STATE_FORMAT, "archetype": String(archetype_id()), "applied": _applied}


func load_state(data: Dictionary) -> SimResult:
	if data.get("format") != STATE_FORMAT:
		return SimResult.failure("personality: format must be '%s'" % STATE_FORMAT)
	if data.get("archetype") != String(archetype_id()):
		return SimResult.failure("personality: saved for archetype '%s', this planet is '%s'"
				% [data.get("archetype"), archetype_id()])
	if typeof(data.get("applied")) != TYPE_BOOL:
		return SimResult.failure("personality: 'applied' must be true or false")
	_applied = data["applied"]
	return SimResult.success(self)


## A restored planet gets its character back without announcing it again.
func restore_modifiers(registry: ModifierRegistry) -> void:
	if _applied and _archetype != null:
		registry.remove_source(_source())
		_register_modifiers(registry)


func _register_modifiers(registry: ModifierRegistry) -> void:
	for entry in _archetype.modifiers:
		var modifier := Modifier.new(StringName(entry["target"]), StringName(entry["operation"]), entry["value"], _source())
		if registry.has_target(modifier.system_id()):
			registry.add(modifier)


func _source() -> StringName:
	return StringName("personality:%s" % _archetype.id)
