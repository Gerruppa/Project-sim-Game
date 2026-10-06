class_name PerkSystem
extends ModifierProvider
## The player's purse and shelf: Sparks (Iskry) earned from the planet's life
## and spent on perks.
##
## Phase 1 (Begin) applies commands: grant Sparks, buy a perk, refund a perk.
## Phase 2 registers the modifiers of newly bought perks (permanent, source
## "perk:<id>"), removes those of refunded ones and accrues income from the
## biomass of the previous tick. Never returns deltas: a perk reaches the
## planet only through modifiers and, via unlocks(), the interventions the
## player may use. Design: docs/perks.md.

const ID := &"perks"
const FORMAT := "perks_state"
const ACTION_GRANT := &"grant"
const ACTION_BUY := &"buy"
const ACTION_REFUND := &"refund"
const BOUGHT_EVENT := &"perk_bought"
const REFUNDED_EVENT := &"perk_refunded"
const REJECTED_EVENT := &"perk_rejected"
## No story on purpose: bubbles pay out often and would flood the chronicle.
const GRANTED_EVENT := &"sparks_granted"
## One grant never exceeds this, so a bad caller cannot print money.
const MAX_GRANT := 100.0
## Absorbs float noise so that 10 * 0.7 refunds 7, not 6.
const REFUND_EPSILON := 1e-9

var _catalog: PerkCatalog
var _sparks := 0.0
## Bought perks, in purchase order.
var _owned: Array[StringName] = []
## Bought this tick in Begin, registered in phase 2 of the same tick.
var _to_register: Array[StringName] = []
## Refunded this tick in Begin, removed from the registry in phase 2.
var _to_remove: Array[StringName] = []


func _init(catalog: PerkCatalog) -> void:
	_catalog = catalog


func system_id() -> StringName:
	return ID


func catalog() -> PerkCatalog:
	return _catalog


func sparks() -> float:
	return _sparks


func owns(perk_id: StringName) -> bool:
	return _owned.has(perk_id)


## Bought perks in purchase order (a copy).
func owned() -> Array[StringName]:
	return _owned.duplicate()


## Free interventions and those unlocked by an owned perk.
func unlocks(intervention_id: StringName) -> bool:
	if _catalog.free_interventions.has(intervention_id):
		return true
	return _owned.any(func(id: StringName) -> bool: return _catalog.get_def(id).unlocks.has(intervention_id))


## The perk that unlocks the intervention; null for free (or unknown) ones.
func unlocking_perk(intervention_id: StringName) -> PerkDef:
	if _catalog.free_interventions.has(intervention_id):
		return null
	for def in _catalog.defs():
		if def.unlocks.has(intervention_id):
			return def
	return null


## Perks the given perk requires that are not owned yet, in its own order.
func missing_requirements(perk_id: StringName) -> Array[StringName]:
	var missing: Array[StringName] = []
	var def := _catalog.get_def(perk_id)
	if def == null:
		return missing
	for id in def.requires:
		if not _owned.has(id):
			missing.append(id)
	return missing


func validate_command(command: SimCommand) -> SimResult:
	var errors := _command_errors(command)
	if not errors.is_empty():
		var def := _def_of(command)
		var prefix := "" if def == null else def.name + ": "
		return SimResult.failure("\n".join(errors.map(func(error: String) -> String: return prefix + error)))
	return SimResult.success(command)


func apply_command(command: SimCommand) -> Array[SimCommand]:
	# A command queued for a later tick may meet a purse or shelf that changed since.
	var errors := _command_errors(command)
	var reason := "; ".join(PackedStringArray(errors))
	if command.action == ACTION_GRANT:
		if errors.is_empty():
			_sparks += float(command.args["amount"])
			emit_event(GRANTED_EVENT, {"amount": float(command.args["amount"]), "source": str(command.args.get("source", "")),
					"sparks": _sparks})
		else:
			emit_event(REJECTED_EVENT, {"id": "", "name": "", "reason": reason,
					"story": "Praktykant nie dostaje Iskier: %s." % reason})
		return []
	var def := _def_of(command)
	if def == null:
		return []
	if not errors.is_empty():
		emit_event(REJECTED_EVENT, {"id": String(def.id), "name": def.name, "reason": reason,
				"story": "Praktykant nie może %s: %s." % [_verb(command.action, def), reason]})
	elif command.action == ACTION_BUY:
		_sparks -= float(def.cost)
		_owned.append(def.id)
		_to_register.append(def.id)
		emit_event(BOUGHT_EVENT, {"id": String(def.id), "name": def.name, "story": def.story["bought"],
				"cost": def.cost, "sparks": _sparks})
	else:
		var refund := refund_of(def)
		_sparks += float(refund)
		_owned.erase(def.id)
		_to_register.erase(def.id)
		_to_remove.append(def.id)
		emit_event(REFUNDED_EVENT, {"id": String(def.id), "name": def.name, "story": def.story["refunded"],
				"refund": refund, "sparks": _sparks})
	return []


func provide_modifiers(snapshot: PlanetSnapshot, _tick: int, registry: ModifierRegistry) -> void:
	for id in _to_remove:
		registry.remove_source(_catalog.get_def(id).source())
	_to_remove.clear()
	for id in _to_register:
		_register(id, registry)
	_to_register.clear()
	var biomass := snapshot.get_value(Param.BIOMASS)
	if is_finite(biomass) and biomass > 0.0:
		_sparks += biomass * _catalog.income_per_biomass_tick


func restore_modifiers(registry: ModifierRegistry) -> void:
	for id in _owned:
		registry.remove_source(_catalog.get_def(id).source())
	for id in _owned:
		_register(id, registry)


func _register(perk_id: StringName, registry: ModifierRegistry) -> void:
	var def := _catalog.get_def(perk_id)
	for raw in def.modifiers:
		var modifier := Modifier.new(StringName(raw["target"]), StringName(raw["operation"]), float(raw["value"]),
				def.source(), Modifier.PERMANENT)
		# Planets without the target system (e.g. no biosphere) skip it.
		if registry.has_target(modifier.system_id()):
			registry.add(modifier)


## What refunding the perk pays back, whole Sparks.
func refund_of(def: PerkDef) -> int:
	return int(floorf(float(def.cost) * _catalog.refund_ratio + REFUND_EPSILON))


static func _verb(action: StringName, def: PerkDef) -> String:
	return ("kupić „%s”" if action == ACTION_BUY else "zwrócić „%s”") % def.name


## The perk a buy or refund names; null if it names none that exists.
func _def_of(command: SimCommand) -> PerkDef:
	var raw: Variant = command.args.get("perk")
	if (command.action == ACTION_BUY or command.action == ACTION_REFUND) and typeof(raw) == TYPE_STRING:
		return _catalog.get_def(StringName(raw))
	return null


## Everything wrong with the command against the current state; empty if fine.
func _command_errors(command: SimCommand) -> Array[String]:
	var errors: Array[String] = []
	match command.action:
		ACTION_GRANT:
			_grant_errors(command.args, errors)
		ACTION_BUY, ACTION_REFUND:
			_perk_errors(command, errors)
		_:
			errors.append("unknown perk action '%s'; known: grant, buy, refund" % command.action)
	return errors


func _grant_errors(args: Dictionary, errors: Array[String]) -> void:
	for arg: Variant in args:
		if arg != "amount" and arg != "source":
			errors.append("grant: unknown argument '%s'" % arg)
	var amount: Variant = args.get("amount")
	if not (typeof(amount) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(amount)) \
			or float(amount) <= 0.0 or float(amount) > MAX_GRANT:
		errors.append("grant: 'amount' must be a number above 0 and at most %d" % int(MAX_GRANT))
	if args.has("source") and typeof(args["source"]) != TYPE_STRING:
		errors.append("grant: 'source' must be text")


func _perk_errors(command: SimCommand, errors: Array[String]) -> void:
	for arg: Variant in command.args:
		if arg != "perk":
			errors.append("%s: unknown argument '%s'" % [command.action, arg])
	var def := _def_of(command)
	if def == null:
		errors.append("%s: unknown perk '%s'; known: %s" % [command.action, command.args.get("perk"),
				", ".join(PackedStringArray(_catalog.ids().map(func(id: StringName) -> String: return String(id))))])
		return
	if command.action == ACTION_BUY:
		_buy_errors(def, errors)
	else:
		_refund_errors(def, errors)


func _buy_errors(def: PerkDef, errors: Array[String]) -> void:
	if _owned.has(def.id):
		errors.append("już kupione")
		return
	for id in missing_requirements(def.id):
		errors.append("najpierw kup „%s”" % _catalog.get_def(id).name)
	if _sparks < float(def.cost):
		errors.append("brakuje %d Iskier (koszt %d)" % [int(ceilf(float(def.cost) - _sparks)), def.cost])


func _refund_errors(def: PerkDef, errors: Array[String]) -> void:
	if not _owned.has(def.id):
		errors.append("nie jest kupione")
		return
	for id in _owned:
		var other := _catalog.get_def(id)
		if other.requires.has(def.id):
			errors.append("wymaga go kupiony „%s”" % other.name)


func save_state() -> Dictionary:
	return {"format": FORMAT, "sparks": ExactCodec.floats_to_text(PackedFloat64Array([_sparks])),
			"owned": _owned.map(func(id: StringName) -> String: return String(id))}


func load_state(data: Dictionary) -> SimResult:
	if data.get("format") != FORMAT:
		return SimResult.failure("perks: format must be '%s'" % FORMAT)
	var raw_owned: Variant = data.get("owned")
	if typeof(raw_owned) != TYPE_ARRAY:
		return SimResult.failure("perks: 'owned' must be a list")
	var sparks_result := ExactCodec.floats_from_text(data.get("sparks"), 1, "perks: sparks")
	if not sparks_result.is_ok():
		return sparks_result
	var sparks_value: float = (sparks_result.value as PackedFloat64Array)[0]
	if sparks_value < 0.0:
		return SimResult.failure("perks: sparks must not be negative")
	var restored: Array[StringName] = []
	for raw: Variant in raw_owned:
		if typeof(raw) != TYPE_STRING or _catalog.get_def(StringName(raw)) == null:
			return SimResult.failure("perks: owned perk '%s' is not in the catalog" % [raw])
		if restored.has(StringName(raw)):
			return SimResult.failure("perks: owned perk '%s' listed twice" % raw)
		restored.append(StringName(raw))
	for id in restored:
		for required in _catalog.get_def(id).requires:
			if not restored.has(required):
				return SimResult.failure("perks: '%s' is owned without its requirement '%s'" % [id, required])
	_sparks = sparks_value
	_owned = restored
	_to_register.clear()
	_to_remove.clear()
	return SimResult.success(self)
