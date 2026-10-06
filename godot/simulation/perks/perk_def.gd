class_name PerkDef
extends RefCounted
## One perk as written in data. Read-only after loading.
##
## A perk reaches the planet only through channels the simulation already
## has: permanent modifiers on system coefficients and unlocked interventions.
## Never through deltas, so a perk can be bought and refunded at any time.

var id: StringName
var name: String
## One sentence for the player: what the perk does.
var help := ""
## Which tree the perk sits in: &"environment" or &"life".
var tree: StringName
## Price in Sparks.
var cost := 0
## Perks that must be owned first.
var requires: Array[StringName] = []
## Each entry: {"target", "operation", "value"}; active while the perk is owned.
var modifiers: Array[Dictionary] = []
## Interventions the player may use while the perk is owned.
var unlocks: Array[StringName] = []
## The price of the perk in the world, shown before buying.
var side_effect := ""
## "bought" and "refunded": one sentence each for the chronicle.
var story: Dictionary[String, String] = {}


func source() -> StringName:
	return StringName("perk:" + String(id))
