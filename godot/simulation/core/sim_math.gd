class_name SimMath
extends RefCounted
## Deterministic math for simulation code.
##
## Only IEEE 754 correctly rounded operations are used here
## (+, -, *, /, comparisons), so results are bit-identical on every
## conforming platform. Engine built-ins such as sin, exp, pow or lerp
## are forbidden in simulation code; see docs/simulation.md.

const U32_RANGE := 4294967296.0


static func lerp(from: float, to: float, weight: float) -> float:
	return from + (to - from) * weight


static func smoothstep(edge0: float, edge1: float, x: float) -> float:
	if edge0 == edge1:
		return 0.0 if x < edge0 else 1.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Exponentiation by squaring. Integer exponents only.
static func int_pow(base: float, exponent: int) -> float:
	if exponent < 0:
		return 1.0 / int_pow(base, -exponent)
	var result := 1.0
	var factor := base
	var remaining := exponent
	while remaining > 0:
		if remaining & 1:
			result *= factor
		factor *= factor
		remaining >>= 1
	return result


## Maps an unsigned 32-bit integer to [0, 1). Division by a power of two is exact.
static func u32_to_unit_float(value: int) -> float:
	return float(value) / U32_RANGE
