class_name SpeciesCatalog
extends RefCounted
## Validated list of species, in processing order, loaded from JSON.
## Adding a species means adding data, not code.

const DEFAULT_PATH := "res://resources/biosphere/species.json"

var _species: Array[SpeciesData] = []


static func load_json(path: String) -> SimResult:
	var read := CoefficientLoader.read_json(path, "species")
	return from_data(read.value) if read.is_ok() else read


## Validates everything and reports all errors at once.
static func from_data(data: Dictionary) -> SimResult:
	var result := SimResult.new()
	var raw_list: Variant = data.get("species")
	if typeof(raw_list) != TYPE_ARRAY or (raw_list as Array).is_empty():
		return SimResult.failure("species catalog needs a non-empty 'species' list")

	var catalog := SpeciesCatalog.new()
	var total_weight := 0.0
	for i in (raw_list as Array).size():
		var raw: Variant = raw_list[i]
		if typeof(raw) != TYPE_DICTIONARY:
			result.add_error("species #%d must be an object" % i)
			continue
		var parsed := _parse_species(raw, i, result)
		if parsed == null:
			continue
		if catalog.index_of(parsed.id) != -1:
			result.add_error("species #%d: duplicate id '%s'" % [i, parsed.id])
			continue
		catalog._species.append(parsed)
		total_weight += parsed.weight

	if total_weight > 1.0:
		result.add_error("sum of species weight is %s; it must not exceed 1 (biomass scale)" % total_weight)
	_check_succession(catalog, result)
	if result.is_ok():
		result.value = catalog
	return result


static func _parse_species(raw: Dictionary, index: int, result: SimResult) -> SpeciesData:
	var label := "species #%d (%s)" % [index, raw.get("id", "?")]
	var numbers := raw.duplicate()
	var species := SpeciesData.new()
	var ok := true
	for field in SpeciesData.TEXT_FIELDS:
		numbers.erase(field)
		if typeof(raw.get(field)) != TYPE_STRING:
			result.add_error("%s: '%s' must be a string" % [label, field])
			ok = false
	if ok:
		if (raw["id"] as String).is_empty():
			result.add_error("%s: 'id' must not be empty" % label)
			ok = false
		if not SpeciesData.WATER_SOURCES.has(StringName(raw["water"])):
			result.add_error("%s: water must be one of %s" % [label, SpeciesData.WATER_SOURCES])
			ok = false
	var filled := CoefficientLoader.fill(species, numbers, SpeciesData.SPEC, SpeciesData.ORDERED_PAIRS, label)
	for error in filled.errors:
		result.add_error("%s: %s" % [label, error])
	if not ok or not filled.is_ok():
		return null
	species.id = StringName(raw["id"])
	species.water = StringName(raw["water"])
	species.emerges_from = StringName(raw["emerges_from"])
	return species


## Every precursor exists and following precursors never loops.
static func _check_succession(catalog: SpeciesCatalog, result: SimResult) -> void:
	for species in catalog._species:
		if species.emerges_from.is_empty():
			continue
		if catalog.index_of(species.emerges_from) == -1:
			result.add_error("species '%s': unknown precursor '%s'" % [species.id, species.emerges_from])
			continue
		var current := species
		for step in catalog._species.size():
			if current.emerges_from.is_empty() or catalog.index_of(current.emerges_from) == -1:
				break
			current = catalog._species[catalog.index_of(current.emerges_from)]
			if current == species:
				result.add_error("species '%s': succession forms a cycle" % species.id)
				break


func size() -> int:
	return _species.size()


func all() -> Array[SpeciesData]:
	return _species.duplicate()


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for species in _species:
		result.append(species.id)
	return result


## Returns -1 for unknown ids.
func index_of(id: StringName) -> int:
	for i in _species.size():
		if _species[i].id == id:
			return i
	return -1


func get_species(id: StringName) -> SpeciesData:
	var index := index_of(id)
	return null if index == -1 else _species[index]
