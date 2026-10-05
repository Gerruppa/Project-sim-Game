class_name PlanetView
extends Control
## The planet as a simple drawing, so the player sees its state at a glance:
## the disk's colour follows temperature, polar ice grows when it is cold,
## green spreads with biomass, clouds with cloud cover and a blue halo with
## oxygen. Code-drawn, no textures. Presentation only.

const SPACE := Color("0b1018")
const COLD := Color("cfe3f2")
const TEMPERATE := Color("2f6f8f")
const WARM := Color("9a7b45")
const HOT := Color("b0472a")
const ICE := Color("eef6fb")
const LIFE := Color("3f9b4a")
const CLOUD := Color(1, 1, 1)
const HALO := Color("6fb7ff")
## Fixed spots where vegetation shows (fractions of the radius), drawn in
## order as biomass grows. Kept inside 0.7 of the radius to stay on the disk.
const LIFE_SPOTS: Array[Vector2] = [
	Vector2(-0.30, 0.10), Vector2(0.25, -0.05), Vector2(0.05, 0.35), Vector2(-0.10, -0.30),
	Vector2(0.40, 0.25), Vector2(-0.45, -0.10), Vector2(0.15, 0.10), Vector2(-0.25, 0.40),
	Vector2(0.35, -0.35), Vector2(-0.05, 0.55), Vector2(0.55, 0.0), Vector2(-0.50, 0.25),
]
const CLOUD_SPOTS: Array[Vector2] = [
	Vector2(-0.20, -0.45), Vector2(0.30, 0.45), Vector2(0.50, -0.20), Vector2(-0.55, 0.15),
	Vector2(0.0, 0.0), Vector2(0.20, -0.60), Vector2(-0.35, 0.55), Vector2(0.60, 0.30),
]

var temperature := 30.0
var humidity := 15.0
var oxygen := 2.0
var biomass := 0.0
var cloud_cover := 10.0


## values: parameter id -> value (0-100), as GameSession.planet_rows gives.
func show_state(values: Dictionary) -> void:
	temperature = values.get("temperature", temperature)
	humidity = values.get("humidity", humidity)
	oxygen = values.get("oxygen", oxygen)
	biomass = values.get("biomass", biomass)
	cloud_cover = values.get("cloud_cover", cloud_cover)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SPACE)
	var center := size / 2.0
	var radius := minf(size.x, size.y) * 0.40
	# Oxygen: a blue halo, stronger as the air fills with it.
	draw_circle(center, radius * 1.08, Color(HALO, clampf(oxygen / 40.0, 0.05, 0.45)))
	draw_circle(center, radius, surface_color(temperature))
	_draw_ice(center, radius)
	var spots := clampi(roundi(biomass / 4.0), 0, LIFE_SPOTS.size())
	for i in spots:
		draw_circle(center + LIFE_SPOTS[i] * radius, radius * 0.17, Color(LIFE, 0.85))
	var clouds := clampi(roundi(cloud_cover / 12.0), 0, CLOUD_SPOTS.size())
	for i in clouds:
		draw_circle(center + CLOUD_SPOTS[i] * radius, radius * 0.14, Color(CLOUD, 0.35))
	draw_arc(center, radius, 0.0, TAU, 96, Color(1, 1, 1, 0.25), 2.0, true)


## Cold white, temperate blue-green, warm sand, hot red.
static func surface_color(t: float) -> Color:
	if t < 20.0:
		return COLD.lerp(TEMPERATE, clampf((t - 5.0) / 15.0, 0.0, 1.0))
	if t < 40.0:
		return TEMPERATE.lerp(WARM, clampf((t - 30.0) / 10.0, 0.0, 1.0))
	return WARM.lerp(HOT, clampf((t - 40.0) / 15.0, 0.0, 1.0))


## Polar caps: none above 30 degrees, growing to half the planet at 0.
func _draw_ice(center: Vector2, radius: float) -> void:
	var share := clampf((30.0 - temperature) / 30.0, 0.0, 1.0) * 0.5
	if share <= 0.0:
		return
	var depth := radius * 2.0 * share
	for pole: float in [-1.0, 1.0]:
		draw_colored_polygon(cap_polygon(center, radius, depth, pole), ICE)


## A circle segment of the given depth at the top (pole -1) or bottom (1).
static func cap_polygon(center: Vector2, radius: float, depth: float, pole: float) -> PackedVector2Array:
	var half := acos(clampf(1.0 - depth / radius, -1.0, 1.0))
	var middle := PI / 2.0 * pole
	var points := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var angle := middle - half + 2.0 * half * float(i) / steps
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
