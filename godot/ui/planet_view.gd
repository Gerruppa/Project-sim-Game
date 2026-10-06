class_name PlanetView
extends SubViewportContainer
## The planet as a globe the player turns with the mouse: the main view of
## the window. The continents are fixed for a planet (drawn from its number);
## sea level, ice, desert, heat, clouds, the colour of the air and life by
## layers follow the planet's state. The simulation has no regions: the globe
## shows global values, it never invents local ones. Presentation only.

const SPIN_SPEED := 0.06
const DRAG_SPEED := 0.008
const MAX_TILT := 1.2
const ZOOM_MIN := 2.2
const ZOOM_MAX := 4.5
const ZOOM_STEP := 0.2
const LOW_O2_AIR := Color("e39b54")
const RICH_O2_AIR := Color("6fb7ff")
## Polar ice edge (|sin latitude|) against temperature (0-100): no ice above
## the last point, caps at 0 degrees Celsius (16), ice to the tropics at 0.
const ICE_POINTS: Array[Vector2] = [Vector2(0, 0.25), Vector2(16, 0.72), Vector2(30, 0.86), Vector2(40, 0.97), Vector2(50, 1.1)]
## Species drawn on the globe and the population (0-100) that covers all of
## their ground.
const LIFE_IDS: Array[String] = ["bacteria", "algae", "moss", "shrub", "tree"]
const FULL_COVER := 60.0
## A point counts as facing the camera when its surface normal's dot with the
## direction to the camera is above this (a little margin at the rim).
const VISIBLE_DOT := 0.05

## Turned with the mouse and spinning slowly while nobody holds it.
var auto_spin := true

var _viewport: SubViewport
## Tilt toward the viewer (x) holds the spin around the planet's axis (y).
var _tilt: Node3D
var _pivot: Node3D
var _camera: Camera3D
var _surface: ShaderMaterial
var _clouds: ShaderMaterial
var _air: ShaderMaterial
var _dragging := false
var _look := {}


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("06090f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.45)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.35, -0.75, 0.0)
	sun.light_energy = 1.3
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0, 3.0)
	_camera.fov = 45.0
	_viewport.add_child(_camera)
	_tilt = Node3D.new()
	_tilt.rotation.x = 0.25
	_viewport.add_child(_tilt)
	_pivot = Node3D.new()
	_tilt.add_child(_pivot)
	var hint := Label.new()
	hint.text = "przeciągnij: obrót · kółko: przybliżenie"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	hint.add_theme_font_size_override("font_size", 12)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.offset_right = -8
	add_child(hint)
	_surface = _shell(1.0, "res://ui/planet_surface.gdshader", 128)
	_clouds = _shell(1.015, "res://ui/planet_clouds.gdshader", 96)
	_air = _shell(1.06, "res://ui/planet_atmosphere.gdshader", 64)


func _shell(radius: float, shader_path: String, segments: int) -> ShaderMaterial:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = segments / 2
	var material := ShaderMaterial.new()
	material.shader = load(shader_path)
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	_pivot.add_child(instance)
	return material


## The planet's number fixes its continents and cloud pattern.
func set_planet(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var offset := Vector3(rng.randf_range(0, 50), rng.randf_range(0, 50), rng.randf_range(0, 50))
	_surface.set_shader_parameter("seed_offset", offset)
	_clouds.set_shader_parameter("seed_offset", offset * 0.7)
	_pivot.rotation.y = rng.randf_range(0, TAU)


## values: parameter id -> value (0-100); life: species id -> population.
func show_state(values: Dictionary, life: Dictionary = {}) -> void:
	_look = look(values, life)
	for key: String in ["sea_level", "ice_line", "dryness", "heat"] + LIFE_IDS:
		_surface.set_shader_parameter(key, _look[key])
	_clouds.set_shader_parameter("cover", _look["clouds"])
	_air.set_shader_parameter("glow_color", _look["air_color"])
	_air.set_shader_parameter("strength", _look["air_strength"])


## What the globe shows for a planet state (tests read this, not pixels).
static func look(values: Dictionary, life: Dictionary) -> Dictionary:
	var temperature: float = values.get("temperature", 30.0)
	var humidity: float = values.get("humidity", 15.0)
	var oxygen: float = values.get("oxygen", 2.0)
	var result := {
		# A wetter planet has more sea; a dry one shows its continental shelves.
		"sea_level": lerpf(0.53, 0.45, clampf(humidity / 60.0, 0.0, 1.0)),
		"ice_line": _ice_line(temperature),
		"dryness": clampf((35.0 - humidity) / 30.0, 0.0, 1.0),
		"heat": clampf((temperature - 40.0) / 20.0, 0.0, 1.0),
		"clouds": clampf(float(values.get("cloud_cover", 10.0)) / 100.0, 0.0, 1.0),
		"air_color": LOW_O2_AIR.lerp(RICH_O2_AIR, clampf(oxygen / 22.0, 0.0, 1.0)),
		"air_strength": lerpf(0.35, 0.9, clampf(oxygen / 30.0, 0.0, 1.0)),
	}
	for id in LIFE_IDS:
		result[id] = clampf(float(life.get(id, 0.0)) / FULL_COVER, 0.0, 1.0)
	return result


static func _ice_line(temperature: float) -> float:
	for i in range(1, ICE_POINTS.size()):
		if temperature <= ICE_POINTS[i].x:
			var a := ICE_POINTS[i - 1]
			var b := ICE_POINTS[i]
			return lerpf(a.y, b.y, clampf((temperature - a.x) / (b.x - a.x), 0.0, 1.0))
	return ICE_POINTS[-1].y


## The last look shown (empty before the first state).
func current_look() -> Dictionary:
	return _look.duplicate()


func _process(delta: float) -> void:
	if auto_spin and not _dragging:
		_pivot.rotation.y += SPIN_SPEED * delta


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(ZOOM_STEP)
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		turn(motion.relative * DRAG_SPEED)
		accept_event()


## Turns the globe: x around its axis, y tilts it toward the viewer.
func turn(by: Vector2) -> void:
	_pivot.rotation.y += by.x
	_tilt.rotation.x = clampf(_tilt.rotation.x + by.y, -MAX_TILT, MAX_TILT)


func zoom(by: float) -> void:
	_camera.position.z = clampf(_camera.position.z + by, ZOOM_MIN, ZOOM_MAX)


## (tilt, spin) in radians.
func rotation_now() -> Vector2:
	return Vector2(_tilt.rotation.x, _pivot.rotation.y)


func distance() -> float:
	return _camera.position.z


## Where a point of the globe (degrees) falls in this container, or null while
## it is on the side turned away from the camera. The container stretches its
## viewport, so the projected pixel is already in its own coordinates.
func screen_point(lat_deg: float, lon_deg: float) -> Variant:
	var lat := deg_to_rad(lat_deg)
	var lon := deg_to_rad(lon_deg)
	var unit := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
	var world := _pivot.global_transform * unit
	var normal := (world - _pivot.global_position).normalized()
	var to_camera := (_camera.global_position - world).normalized()
	if normal.dot(to_camera) <= VISIBLE_DOT:
		return null
	return _camera.unproject_position(world)
