class_name PersonalityArchetype
extends RefCounted
## One planet character: a named, weighted set of coefficient modifiers.
## Loaded by PersonalityCatalog; treat as read-only.

var id: StringName
## Relative chance of being drawn when the personality is random.
var weight: float
var description: String
## Each entry: {"target": "climate.drift_noise", "operation": "multiply", "value": 1.35}
var modifiers: Array[Dictionary] = []
