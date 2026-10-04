class_name Param
extends RefCounted
## Identifiers of planetary parameters.
##
## Use these constants instead of string literals so a typo fails
## validation instead of silently reading the wrong value.
## The source of truth for which parameters exist is the schema data.

const TEMPERATURE := &"temperature"
const HUMIDITY := &"humidity"
const OXYGEN := &"oxygen"
const BIOMASS := &"biomass"
