extends Node3D
## Procedural, original low-poly 3D art: no imported models or copyrighted characters.

var ship: Node3D
var clouds: Array[Node3D] = []
var animated_sails: Array[MeshInstance3D] = []
var storm_nodes: Array[Node3D] = []
var salvage_nodes: Array[Node3D] = []
var rival_nodes: Array[Node3D] = []
var water: MeshInstance3D
var time_elapsed: float = 0.0

const PORTS = [
	{"name": "HAVEN PORT", "land": Vector2(-94, -86), "dock": Vector3(-70, 0, -60), "color": Color("efc576")},
	{"name": "CORAL BAZAAR", "land": Vector2(94, -86), "dock": Vector3(70, 0, -60), "color": Color("f5a673")},
	{"name": "EMBER COVE", "land": Vector2(94, 86), "dock": Vector3(70, 0, 60), "color": Color("eaa6c2")},
	{"name": "WHISPER CAY", "land": Vector2(-94, 86), "dock": Vector3(-70, 0, 60), "color": Color("83d8b0")}
]
const REEFS = [
	[Vector2(-2, -18), 15.0], [Vector2(9, 31), 16.0],
	[Vector2(-38, 16), 11.0], [Vector2(38, -5), 13.0],
	[Vector2(-5, -81), 10.0], [Vector2(7, 91), 9.0]
]
const STORMS = [Vector2(26, 15), Vector2(-30, 46)]

func _ready() -> void:
	_build_lighting()
	_build_ocean()
	for i in range(PORTS.size()):
		_build_island(PORTS[i], i)
	for i in range(REEFS.size()):
		_build_reef(REEFS[i][0], float(REEFS[i][1]), i)
	for i in range(STORMS.size()):
		_build_storm(STORMS[i], i)
	for i in range(8):
		_build_cloud(Vector3(-135 + i * 42, 29 + (i % 3) * 4, -95 + (i % 4) * 65), i)
	ship = _build_ship(self, Color("f2e7cf"), Color("bd6749"), 1.0)
	ship.name = "PlayerShip"
	ship.position = Vector3(-66.0, 0.75, -53.0)
	ship.rotation.y = -PI / 2.0
	for i in range(3):
		var rival: Node3D = _build_ship(self, Color("d4e5ff"), [Color("547eaa"), Color("a786b5"), Color("d27c60")][i], 0.68)
		rival.name = "RivalSloop%d" % i
		rival.position = Vector3(-17.0 + 37.0 * i, 0.65, -45.0 + 43.0 * i)
		rival_nodes.append(rival)
	for i in range(11):
		var angle: float = float(i) * 2.399
		var rad: float = 28.0 + float(i % 4) * 17.0
		var pos: Vector3 = Vector3(cos(angle) * rad, 0.25, sin(angle) * rad)
		var salvage: Node3D = Node3D.new()
		salvage.name = "Salvage_%d" % i
		add_child(salvage)
		salvage.position = pos
		_mesh(salvage, _sphere(0.9), _mat(Color("f2c763"), 0.35, true), Vector3(0, 1.1, 0), Vector3(0, 0, 0), Vector3(0.9, 0.9, 0.9))
		_mesh(salvage, _cylinder(0.4, 1.6), _mat(Color("fff2b5"), 0.3, true), Vector3(0, 1.8, 0), Vector3(0, 0, 0), Vector3.ONE)
		salvage_nodes.append(salvage)

func _build_lighting() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	add_child(env)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("416d9d")
	sky_mat.sky_horizon_color = Color("c7a9a2")
	sky_mat.ground_horizon_color = Color("f5c99a")
	sky_mat.ground_bottom_color = Color("356d76")
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("7d9da3")
	environment.fog_density = 0.0014
	env.environment = environment
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-42, -42, 0)
	sun.light_energy = 1.65
	sun.light_color = Color("ffe0b2")
	sun.shadow_enabled = true

func _build_ocean() -> void:
	water = MeshInstance3D.new()
	water.name = "AnimatedOcean"
	add_child(water)
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2(760, 760)
	mesh.subdivide_width = 180
	mesh.subdivide_depth = 180
	water.mesh = mesh
	water.position.y = -0.45
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 deep_color : source_color = vec4(0.032, 0.27, 0.38, 1.0);
uniform vec4 bright_color : source_color = vec4(0.12, 0.59, 0.64, 1.0);
varying float wave_line;
void vertex() {
    float x = VERTEX.x;
    float z = VERTEX.z;
    float a = sin(x * 0.18 + TIME * 1.15) * 0.48;
    float b = cos(z * 0.24 - TIME * 1.53) * 0.31;
    float c = sin((x + z) * 0.11 + TIME * 0.85) * 0.25;
    VERTEX.y += a + b + c;
    wave_line = a + b + c;
}
void fragment() {
    float crest = smoothstep(0.2, 0.9, wave_line);
    float ripples = 0.5 + 0.5 * sin((UV.x + UV.y) * 700.0 + TIME * 1.3);
    ALBEDO = mix(deep_color.rgb, bright_color.rgb, crest * 0.66 + ripples * 0.09);
    ROUGHNESS = 0.23;
    SPECULAR = 0.82;
    METALLIC = 0.04;
    EMISSION = bright_color.rgb * crest * 0.09;
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	water.material_override = material

func _build_island(info: Dictionary, idx: int) -> void:
	var island: Node3D = Node3D.new()
	island.name = "Island_%d" % idx
	add_child(island)
	island.position = Vector3(info["land"].x, 0.0, info["land"].y)
	_mesh(island, _cylinder(31.0, 3.2), _mat(Color("dcb878")), Vector3(0, 0.5, 0))
	_mesh(island, _cylinder(25.0, 3.9), _mat(Color("5e9b6c")), Vector3(0, 2.0, 0))
	_mesh(island, _sphere(12.0), _mat(Color("447d66")), Vector3(-6, 3.2, 4), Vector3.ZERO, Vector3(1.55, 0.45, 1.2))
	_mesh(island, _sphere(12.0), _mat(Color("719a62")), Vector3(9, 3.0, -7), Vector3.ZERO, Vector3(1.2, 0.4, 1.1))
	for k in range(7):
		var ang: float = float(k) * 2.399 + float(idx)
		var px: float = cos(ang) * 17
		var pz: float = sin(ang) * 17
		_palm(island, Vector3(px, 4.4, pz), 5.2 + float(k % 3), ang)
	_build_hut(island, Vector3(-3, 5.1, -2), Color("b36a4b"), 1.2)
	_build_hut(island, Vector3(10, 5.1, 8), Color("6b8f98"), 0.8)
	if idx == 0:
		_build_lighthouse(island, Vector3(3, 4.5, 12))
	else:
		_mesh(island, _sphere(5.0), _mat(info["color"], 0.9, true), Vector3(-8, 5, -10), Vector3.ZERO, Vector3(1, 1.45, 1))
	var dock_world: Vector3 = info["dock"]
	var dock_offset: Vector3 = dock_world - island.position
	var beam: MeshInstance3D = _mesh(island, _box(Vector3(5, 0.55, 17)), _mat(Color("855b45")), dock_offset + Vector3(0, 0.75, 0))
	beam.rotation.y = PI / 4.0 if dock_offset.x * dock_offset.z > 0 else -PI / 4.0
	for j in range(5):
		_mesh(island, _box(Vector3(0.25, 1.7, 0.25)), _mat(Color("6c4a39")), dock_offset + Vector3(-2.1, 0.0, -7 + j * 3))
	_mesh(island, _cylinder(0.35, 8.2), _mat(Color("9e795e")), dock_offset + Vector3(1, 5, 0))
	var pennant: MeshInstance3D = _mesh(island, _box(Vector3(4.0, 1.5, 0.12)), _mat(info["color"], 0.45), dock_offset + Vector3(3.0, 8.0, 0))
	pennant.rotation.y = 0.25
	var label: Label3D = Label3D.new()
	island.add_child(label)
	label.position = dock_offset + Vector3(0, 12.5, 0)
	label.text = str(info["name"])
	label.font_size = 36
	label.pixel_size = 0.013
	label.modulate = Color("fff2cd")
	label.outline_size = 9
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Interactive treasure docks have a visible, original low-poly chest.
	var chest_base: Vector3 = dock_offset + Vector3(0, 1.35, 1.3)
	_mesh(island, _box(Vector3(3.1, 1.65, 2.25)), _mat(Color("784934")), chest_base)
	_mesh(island, _box(Vector3(3.4, 0.6, 2.45)), _mat(Color("b8834b")), chest_base + Vector3(0, 1.04, 0))
	for side_x in [-1.22, 1.22]:
		_mesh(island, _box(Vector3(0.20, 1.95, 2.4)), _mat(Color("e4bd75"), 0.35, true), chest_base + Vector3(side_x, 0.15, 0))
	_mesh(island, _box(Vector3(0.65, 0.75, 0.28)), _mat(Color("f6d386"), 0.25, true), chest_base + Vector3(0, 0.37, -1.23))

func _build_reef(center: Vector2, radius: float, idx: int) -> void:
	var reef: Node3D = Node3D.new()
	reef.name = "Reef_%d" % idx
	add_child(reef)
	reef.position = Vector3(center.x, 0, center.y)
	_mesh(reef, _cylinder(radius + 3.0, 0.22), _mat(Color("9bdcc4"), 0.32, true), Vector3(0, 0.0, 0))
	for i in range(6):
		var ang: float = float(i) * TAU / 6.0
		var rr: float = radius * (0.36 + 0.20 * float(i % 3))
		var rock: MeshInstance3D = _mesh(reef, _sphere(3.8), _mat([Color("66847d"), Color("527a77"), Color("9b9e85")][i % 3]), Vector3(cos(ang) * rr, 0.8, sin(ang) * rr), Vector3(0, float(i), 0), Vector3(1.15, 0.5 + float(i % 2) * 0.35, 0.85))
		rock.rotation.y = float(i) * 1.4

func _build_storm(center: Vector2, idx: int) -> void:
	var storm: Node3D = Node3D.new()
	storm.name = "Storm_%d" % idx
	add_child(storm)
	storm.position = Vector3(center.x, 0, center.y)
	for i in range(8):
		var ang: float = float(i) * TAU / 8.0
		_mesh(storm, _sphere(4.3), _mat(Color("4d6378"), 0.9), Vector3(cos(ang) * 13.0, 13 + i % 3, sin(ang) * 13.0), Vector3.ZERO, Vector3(1.8, 0.65, 1.25))
	_mesh(storm, _cylinder(18.0, 0.12), _mat(Color("68b1c3"), 0.25, true), Vector3(0, 0.25, 0))
	var light: OmniLight3D = OmniLight3D.new()
	storm.add_child(light)
	light.position = Vector3(0, 10, 0)
	light.light_color = Color("8bcdfb")
	light.light_energy = 0.4
	light.omni_range = 30.0
	storm_nodes.append(storm)

func _build_cloud(pos: Vector3, idx: int) -> void:
	var cloud: Node3D = Node3D.new()
	cloud.position = pos
	cloud.name = "Cloud_%d" % idx
	add_child(cloud)
	for j in range(3):
		_mesh(cloud, _sphere(7.0), _mat(Color("ebdfe1"), 0.9), Vector3((j - 1) * 7, (j % 2) * 1.2, 0), Vector3.ZERO, Vector3(1.1, 0.36, 0.7))
	clouds.append(cloud)

func _build_ship(parent: Node3D, sail_color: Color, trim_color: Color, factor: float) -> Node3D:
	var vessel: Node3D = Node3D.new()
	parent.add_child(vessel)
	vessel.scale = Vector3.ONE * factor
	_mesh(vessel, _sphere(1.0), _mat(Color("4e3029")), Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(2.9, 0.90, 6.5))
	_mesh(vessel, _box(Vector3(4.65, 0.50, 10.2)), _mat(Color("9b6646")), Vector3(0, 0.95, 0))
	_mesh(vessel, _box(Vector3(0.35, 1.0, 10.7)), _mat(Color("5b3429")), Vector3(-2.25, 1.37, 0))
	_mesh(vessel, _box(Vector3(0.35, 1.0, 10.7)), _mat(Color("5b3429")), Vector3(2.25, 1.37, 0))
	_mesh(vessel, _box(Vector3(4.7, 0.7, 0.45)), _mat(trim_color), Vector3(0, 1.15, -4.9))
	_mesh(vessel, _box(Vector3(4.7, 0.8, 0.5)), _mat(Color("422b27")), Vector3(0, 1.15, 4.8))
	_mesh(vessel, _cylinder(0.25, 12.0), _mat(Color("ead3a1")), Vector3(0, 6.5, 0.8))
	_mesh(vessel, _box(Vector3(6.2, 0.18, 0.2)), _mat(Color("a3774a")), Vector3(0, 10.7, 0.8))
	_mesh(vessel, _box(Vector3(6.0, 0.18, 0.2)), _mat(Color("a3774a")), Vector3(0, 3.0, 0.8))
	var sail: MeshInstance3D = _mesh(vessel, _sail_mesh(), _mat(sail_color, 0.86), Vector3(0, 0, 0.9))
	animated_sails.append(sail)
	_mesh(vessel, _cylinder(0.13, 8.5), _mat(Color("e4d3ab")), Vector3(0, 5.0, -4.4), Vector3(0.4, 0, 0))
	_mesh(vessel, _box(Vector3(1.8, 1.4, 1.7)), _mat(Color("654030")), Vector3(0, 1.78, 3.8))
	for x in [-1, 1]:
		_mesh(vessel, _sphere(0.22), _mat(Color("e4ae5a"), 0.28, true), Vector3(x * 1.8, 1.8, -3.7))
	var flag: MeshInstance3D = _mesh(vessel, _box(Vector3(2.5, 0.9, 0.09)), _mat(trim_color), Vector3(1.25, 11.9, 0.8))
	animated_sails.append(flag)
	return vessel

func _build_hut(parent: Node3D, p: Vector3, color: Color, factor: float) -> void:
	_mesh(parent, _box(Vector3(8, 5.8, 7) * factor), _mat(color), p + Vector3(0, 2.8 * factor, 0))
	var roof: MeshInstance3D = _mesh(parent, _box(Vector3(9, 0.55, 8) * factor), _mat(Color("50382e")), p + Vector3(0, 6.2 * factor, 0))
	roof.rotation.z = 0.12
	_mesh(parent, _box(Vector3(1.8, 3.2, 0.3) * factor), _mat(Color("4d382f")), p + Vector3(0, 1.7 * factor, -3.5 * factor))
	_mesh(parent, _box(Vector3(1.8, 1.7, 0.3) * factor), _mat(Color("a6d9e4"), 0.3, true), p + Vector3(2.5 * factor, 3.3 * factor, -3.51 * factor))

func _build_lighthouse(parent: Node3D, p: Vector3) -> void:
	_mesh(parent, _cylinder(2.9, 18.0), _mat(Color("f2eadb")), p + Vector3(0, 8, 0))
	for i in range(3):
		_mesh(parent, _cylinder(3.1, 0.9), _mat(Color("c85c4e")), p + Vector3(0, 3 + float(i) * 5, 0))
	_mesh(parent, _cylinder(3.7, 1.0), _mat(Color("b95349")), p + Vector3(0, 17, 0))
	var lantern: OmniLight3D = OmniLight3D.new()
	parent.add_child(lantern)
	lantern.position = p + Vector3(0, 19, 0)
	lantern.light_color = Color("ffe8a8")
	lantern.light_energy = 1.4
	lantern.omni_range = 26.0

func _palm(parent: Node3D, p: Vector3, height: float, tilt: float) -> void:
	var trunk: MeshInstance3D = _mesh(parent, _cylinder(0.56, height), _mat(Color("886342")), p + Vector3(0, height * 0.5, 0))
	trunk.rotation.z = sin(tilt) * 0.13
	for i in range(5):
		var leaf: MeshInstance3D = _mesh(parent, _sphere(2.0), _mat(Color("316b58")), p + Vector3(cos(tilt + float(i) * TAU / 5.0) * 2.6, height + 0.1, sin(tilt + float(i) * TAU / 5.0) * 2.6), Vector3(0, float(i), 0), Vector3(2.3, 0.22, 0.65))
		leaf.rotation.y = tilt + float(i) * TAU / 5.0

func _mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rotation: Vector3 = Vector3.ZERO, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	parent.add_child(instance)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rotation
	instance.scale = scale_v
	return instance

func _mat(color: Color, roughness: float = 0.82, emission: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.06
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.5
	return material

func _box(sz: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = sz
	return mesh

func _sphere(radius: float) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.1
	mesh.height = height
	mesh.radial_segments = 12
	return mesh

func _sail_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-3.1, 10.6, 0), Vector3(3.1, 10.6, 0), Vector3(2.6, 3.2, -0.5),
		Vector3(-3.1, 10.6, 0), Vector3(2.6, 3.2, -0.5), Vector3(-2.6, 3.2, -0.5)
	])
	var normals: PackedVector3Array = PackedVector3Array()
	for _i in range(vertices.size()):
		normals.append(Vector3(0, 0, 1))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _process(delta: float) -> void:
	time_elapsed += delta
	for i in range(clouds.size()):
		clouds[i].position.x += delta * (1.5 + float(i % 3) * 0.6)
		if clouds[i].position.x > 195.0:
			clouds[i].position.x = -180.0
	for i in range(storm_nodes.size()):
		storm_nodes[i].rotation.y += delta * (0.045 + 0.02 * float(i))
	for i in range(rival_nodes.size()):
		rival_nodes[i].position.x += sin(time_elapsed * 0.14 + float(i)) * delta * 1.6
		rival_nodes[i].rotation.y = sin(time_elapsed * 0.1 + float(i)) * 0.9
		rival_nodes[i].position.y = 0.62 + sin(time_elapsed * 1.5 + float(i)) * 0.18
	for i in range(animated_sails.size()):
		if is_instance_valid(animated_sails[i]):
			animated_sails[i].rotation.y = sin(time_elapsed * 1.6 + float(i)) * 0.052
			animated_sails[i].scale.x = 1.0 + sin(time_elapsed * 1.4 + float(i)) * 0.035
	for i in range(salvage_nodes.size()):
		if is_instance_valid(salvage_nodes[i]):
			salvage_nodes[i].rotation.y += delta * 1.1
			salvage_nodes[i].position.y = 0.3 + sin(time_elapsed * 2.0 + float(i)) * 0.2
