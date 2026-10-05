class_name BiosphereSystem
extends SimulationSystem
## Populations, not organisms: logistic growth shaped by the environment,
## light competition between layers, succession, fires, photorespiration
## and oxygen-sensitive anaerobes.
##
## Owns biomass, kept equal to the weighted sum of species populations.
## Contributes photosynthesis, respiration, transpiration and wildfire deltas
## to oxygen, co2 and humidity (owned by Atmosphere and Climate).
## Species populations are internal state (save_state).
## Formulas: docs/biosphere.md. Data: resources/biosphere/*.json.

const ID := &"biosphere"
const STATE_FORMAT := "biosphere_state"
## Biomass drift smaller than this is float noise, not a real mismatch.
const CENSUS_TOLERANCE := 1e-6

var _k: BiosphereConfig
var _species: Array[SpeciesData]
var _rng: SeededRng
## Population 0..100 per species, in catalog order.
var _populations := PackedFloat64Array()
var _established: Array[bool] = []


func _init(config: BiosphereConfig, catalog: SpeciesCatalog, global_seed: int) -> void:
	_k = config
	_species = catalog.all()
	_rng = SeededRng.new(global_seed, String(ID))
	_populations.resize(_species.size())
	_established.resize(_species.size())
	_established.fill(false)


func system_id() -> StringName:
	return ID


## Coefficients in use. The pipeline keeps the ones returned at registration
## as the untouched base and hands back modified copies (personality, events).
func coefficients() -> Object:
	return _k


func coefficient_spec() -> Dictionary:
	return BiosphereConfig.SPEC


func apply_coefficients(effective: Object) -> void:
	_k = effective


## NAN for unknown species.
func population(species_id: StringName) -> float:
	var index := _index_of(species_id)
	return NAN if index == -1 else _populations[index]


## For tests and SaveSystem. Values are clamped to 0..100. A restored
## population counts as established without emitting an emergence event.
func set_population(species_id: StringName, value: float) -> void:
	var index := _index_of(species_id)
	if index != -1:
		_populations[index] = clampf(value, 0.0, 100.0)
		_established[index] = _populations[index] >= _k.established_population


## Populations, established flags and the RNG stream. Flags are stored, not
## derived: a species stays established until it dies out, even below the
## emergence threshold, so deriving them would announce it a second time.
func save_state() -> Dictionary:
	var species: Array[String] = []
	for data in _species:
		species.append(String(data.id))
	return {
		"format": STATE_FORMAT,
		"species": species,
		"populations_exact": ExactCodec.floats_to_text(_populations),
		"established": _established.duplicate(),
		"rng_state": ExactCodec.int_to_text(_rng.get_state()),
	}


func load_state(data: Dictionary) -> SimResult:
	if data.get("format") != STATE_FORMAT:
		return SimResult.failure("biosphere: format must be '%s'" % STATE_FORMAT)
	var result := SimResult.new()
	var expected: Array[String] = []
	for species in _species:
		expected.append(String(species.id))
	if typeof(data.get("species")) != TYPE_ARRAY or Array(data["species"]) != Array(expected):
		result.add_error("biosphere: saved species %s differ from the catalog %s" % [data.get("species"), expected])
	var populations := ExactCodec.floats_from_text(data.get("populations_exact"), _species.size(), "biosphere: 'populations_exact'")
	result.errors.append_array(populations.errors)
	var flags: Variant = data.get("established")
	if typeof(flags) != TYPE_ARRAY or (flags as Array).size() != _species.size() 			or not (flags as Array).all(func(flag: Variant) -> bool: return typeof(flag) == TYPE_BOOL):
		result.add_error("biosphere: 'established' must hold %d true/false values" % _species.size())
	var rng_read := ExactCodec.int_from_text(data.get("rng_state"), "biosphere: 'rng_state'")
	result.errors.append_array(rng_read.errors)
	if not result.is_ok():
		return result
	for value: float in (populations.value as PackedFloat64Array):
		if value < 0.0 or value > 100.0:
			return SimResult.failure("biosphere: population %s outside 0..100" % value)
	_populations = populations.value
	for i in _species.size():
		_established[i] = flags[i]
	_rng.set_state(rng_read.value)
	return SimResult.success(self)


## Weighted sum of populations: what planet biomass should be.
func biomass_total() -> float:
	var total := 0.0
	for i in _species.size():
		total += _species[i].weight * _populations[i]
	return total


## Called exactly once per tick (advances populations and noise).
func compute(snapshot: PlanetSnapshot) -> Array[Delta]:
	var deltas: Array[Delta] = []
	var oxygen := snapshot.get_value(Param.OXYGEN)
	var fire := _k.fire_rate * SimMath.smoothstep(_k.fire_o2_low, _k.fire_o2_high, oxygen) \
			* (1.0 - _k.fire_wet_damping * SimMath.smoothstep(_k.fire_humidity_low, _k.fire_humidity_high,
				snapshot.get_value(Param.HUMIDITY)))
	var photo_limit := 1.0 - SimMath.smoothstep(_k.photorespiration_low, _k.photorespiration_high, oxygen)

	var census := biomass_total() - snapshot.get_value(Param.BIOMASS)
	if absf(census) > CENSUS_TOLERANCE:
		_add(deltas, Param.BIOMASS, census, &"census")

	# Every species reads the populations of the previous tick, so the
	# result does not depend on the order of species in the catalog.
	var next := _populations.duplicate()
	for i in _species.size():
		var species := _species[i]
		var p := _populations[i]
		var suit := species.suitability(snapshot)
		next[i] = p + _population_change(i, species, p, suit, fire, oxygen)
		_add_effects(deltas, species, p, suit, photo_limit, fire)
		_add(deltas, Param.BIOMASS, species.weight * (next[i] - p),
				StringName("%s_%s" % [species.id, "growth" if next[i] > p else "dieback"]))
		_report_milestones(i, species, next[i])
	_populations = next
	return deltas


func _population_change(index: int, species: SpeciesData, p: float, suit: float, fire: float, oxygen: float) -> float:
	var capacity := species.capacity * species.oxygen_capacity_factor(oxygen) \
			* (1.0 - species.shade * _taller_cover(species.layer) / 100.0)
	var crowding := p / capacity if capacity > 0.0 else 2.0
	var noise := 1.0 + _rng.next_range(-_k.growth_noise, _k.growth_noise)
	var growth := species.growth * _k.growth_scale * suit * noise * p * (1.0 - crowding)
	var death := (species.base_mortality + species.stress_mortality * _k.stress_scale * (1.0 - suit)
			+ fire * species.flammable) * p
	var seeding := species.seed * suit * _precursor_share(species)
	var next_population := clampf(p + growth - death + seeding, 0.0, 100.0)
	if next_population < _k.extinction_threshold and next_population < p:
		next_population = 0.0
	return next_population - p


## Photosynthesis and respiration (atmosphere), transpiration (climate), fire.
## Causes name the species ("algae_photosynthesis"), so logs show who
## oxygenates, dries or burns the planet.
func _add_effects(deltas: Array[Delta], species: SpeciesData, p: float, suit: float, photo_limit: float, fire: float) -> void:
	var share := p / 100.0
	var photosynthesis := suit * photo_limit * share
	var photo_cause := StringName("%s_photosynthesis" % species.id)
	var breath_cause := StringName("%s_respiration" % species.id)
	_add(deltas, Param.OXYGEN, species.oxygen * photosynthesis, photo_cause)
	_add(deltas, Param.CO2, -species.co2_uptake * photosynthesis, photo_cause)
	_add(deltas, Param.OXYGEN, -species.respiration * share, breath_cause)
	_add(deltas, Param.CO2, species.respiration * share, breath_cause)
	_add(deltas, Param.HUMIDITY, species.transpiration * suit * share, StringName("%s_transpiration" % species.id))
	var burned := fire * species.flammable * p * species.weight
	var fire_cause := StringName("%s_wildfire" % species.id)
	_add(deltas, Param.OXYGEN, -burned * _k.fire_o2, fire_cause)
	_add(deltas, Param.CO2, burned * _k.fire_co2, fire_cause)


func _report_milestones(index: int, species: SpeciesData, population_now: float) -> void:
	if not _established[index] and population_now >= _k.established_population:
		_established[index] = true
		emit_event(&"species_emerged", {"species": String(species.id), "population": population_now})
	elif _established[index] and population_now == 0.0:
		_established[index] = false
		emit_event(&"species_extinct", {"species": String(species.id)})


## Cover of all taller land layers (layer 0 is soil and water: never shaded, never shades).
func _taller_cover(layer: int) -> float:
	if layer == 0:
		return 0.0
	var cover := 0.0
	for i in _species.size():
		if _species[i].layer > layer:
			cover += _populations[i]
	return minf(cover, 100.0)


## Spontaneous species have share 1; others need their precursor.
func _precursor_share(species: SpeciesData) -> float:
	if species.emerges_from.is_empty():
		return 1.0
	return _populations[_index_of(species.emerges_from)] / 100.0


func _index_of(species_id: StringName) -> int:
	for i in _species.size():
		if _species[i].id == species_id:
			return i
	return -1


## Zero amounts are skipped to keep logs readable.
static func _add(deltas: Array[Delta], parameter: StringName, amount: float, cause: StringName) -> void:
	if amount != 0.0:
		deltas.append(Delta.new(parameter, amount, ID, cause))
