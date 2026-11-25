extends Node3D
## THE LAST CURRENT — playable 3D Godot 4 career adventure.
## Everything is original, procedural art. All navigation algorithms live in ai_engine.gd.

const World = preload("res://scripts/world_builder.gd")
const AI = preload("res://scripts/ai_engine.gd")
const SAVE_FILE = "user://the_last_current_career.json"
const HOME = 0
const CONTRACTS = [
	{"name":"01 / FIRST HORIZON", "island":1, "cargo":"Compass of the Dawn", "reward":280, "desc":"Reach Coral Bazaar, secure the navigator's compass and bring it back to Haven Port."},
	{"name":"02 / WHISPERING TIDES", "island":3, "cargo":"Tidebound Star", "reward":390, "desc":"Cross the northern reefs to Whisper Cay. The lookout's readings cannot be trusted blindly."},
	{"name":"03 / EMBER RUN", "island":2, "cargo":"Emberheart Relic", "reward":510, "desc":"Reach Ember Cove through the storm belt. Choose speed or caution based on evidence."},
	{"name":"04 / TRADE WINDS", "island":1, "cargo":"Ancient Sea Chart", "reward":640, "desc":"A return voyage to Coral Bazaar. The cost of a route matters more than its length."},
	{"name":"05 / THE LAST CURRENT", "island":3, "cargo":"The Last Current", "reward":900, "desc":"The final expedition: retrieve the legendary current and return to Haven Port."}
]
const GOLD = Color("f6ca77")
const CREAM = Color("fbf0d7")
const MUTED = Color("a4b8c3")
const NAVY = Color("071e30")
const SEA = Color("0c5364")
const RED = Color("f29a87")

var world
var ai = AI.new()
var ship: Node3D
var camera: Camera3D
var route_root: Node3D
var goal_marker: Node3D
var ui_layer: CanvasLayer
var ui_root: Control
var menu: Control
var port_menu: Control
var hud: Control
var end_menu: Control
var pause_menu: Control
var mission_label: Label
var status_label: Label
var objective_label: Label
var gold_label: Label
var speed_label: Label
var hull_label: Label
var fuel_label: Label
var sonar_label: Label
var port_gold_label: Label
var port_rank_label: Label
var port_contract_label: Label
var port_description_label: Label
var upgrade_buttons: Dictionary = {}
var hint_label: Label
var ai_title_label: Label
var ai_content_label: Label
var lab_panel: PanelContainer
var toast_label: Label
var route_visible: bool = true
var music_on: bool = true
var ocean_audio: AudioStreamPlayer
var music_audio: AudioStreamPlayer
var effects_audio: AudioStreamPlayer
var advice_anchor_timer: float = 0.0
var advice_sail_timer: float = 0.0
var lab_visible: bool = false
var mode: String = "MENU"  # MENU, PORT, PLAY, PAUSE, END
var career: Dictionary = {}
var storm_beliefs: Array = [0.30, 0.30]
var storm_active: Array = [false, true]
var storm_time: float = 0.0
var last_scan: Dictionary = {}
var last_path: Dictionary = {}
var last_mdp: Dictionary = {}
var score_this_voyage: int = 0
var cargo_held: bool = false
var velocity: float = 0.0
var supplies: float = 100.0
var hull: float = 100.0
var sonar_charges: int = 4
var time_in_voyage: float = 0.0
var collision_delay: float = 0.0
var toast_time: float = 0.0
var sea_time: float = 0.0
var destination: Vector3
var target_port: int = 1
var game_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var preferred_seed: int = 70119

func _ready() -> void:
	game_rng.randomize()
	preferred_seed = int(game_rng.randi_range(10000, 999999))
	_load_career()
	world = World.new()
	world.name = "Original3DWorld"
	add_child(world)
	ship = world.ship
	route_root = Node3D.new()
	route_root.name = "AStarWaypoints"
	add_child(route_root)
	_build_goal_marker()
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.current = true
	camera.fov = 65.0
	add_child(camera)
	camera.position = Vector3(-30.0, 30.0, -15.0)
	camera.look_at(Vector3(-78, 3, -74), Vector3.UP)
	_build_interface()
	_build_audio()
	_switch("MENU")

func _build_goal_marker() -> void:
	goal_marker = Node3D.new()
	goal_marker.name = "MissionWaypointBeacon"
	add_child(goal_marker)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color("ffe2a0")
	glow.emission_enabled = true
	glow.emission = GOLD
	glow.emission_energy_multiplier = 2.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var platform: MeshInstance3D = MeshInstance3D.new()
	var disk: CylinderMesh = CylinderMesh.new()
	disk.top_radius = 3.7
	disk.bottom_radius = 3.7
	disk.height = 0.14
	platform.mesh = disk
	platform.material_override = glow
	goal_marker.add_child(platform)
	var pole: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.6
	sphere.height = 3.2
	pole.mesh = sphere
	pole.position.y = 4.5
	pole.material_override = glow
	goal_marker.add_child(pole)
	var label: Label3D = Label3D.new()
	label.text = "OBJECTIVE"
	label.font_size = 70
	label.pixel_size = 0.008
	label.position.y = 8.4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = CREAM
	label.outline_size = 9
	goal_marker.add_child(label)
	goal_marker.visible = false

func _new_career() -> Dictionary:
	return {"gold":150, "completed":0, "engine":0, "hull_upgrade":0, "sonar":0, "voyages":0, "treasure":0, "total_distance":0.0, "best_score":0}

func _load_career() -> void:
	career = _new_career()
	if not FileAccess.file_exists(SAVE_FILE):
		return
	var file: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		return
	var result: Variant = JSON.parse_string(file.get_as_text())
	if result is Dictionary:
		for key in career.keys():
			if result.has(key):
				career[key] = result[key]

func _save_career() -> void:
	var file: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(career, "  "))

func _rank() -> String:
	var progress: int = int(career["completed"])
	if progress >= 5: return "LEGEND OF THE SEA"
	if progress >= 4: return "MASTER NAVIGATOR"
	if progress >= 2: return "SEA EXPLORER"
	if progress >= 1: return "DECK OFFICER"
	return "ROOKIE CAPTAIN"

func _switch(next: String) -> void:
	mode = next
	menu.visible = (next == "MENU")
	port_menu.visible = (next == "PORT")
	hud.visible = (next == "PLAY" or next == "PAUSE")
	pause_menu.visible = (next == "PAUSE")
	end_menu.visible = (next == "END")
	if goal_marker != null:
		goal_marker.visible = (next == "PLAY" or next == "PAUSE")
	if next == "PORT":
		_refresh_port()
	if next == "PLAY":
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus != null: focus.release_focus()
		_refresh_hud()

func _start_new() -> void:
	career = _new_career()
	_save_career()
	_reset_ship()
	_switch("PORT")

func _continue_career() -> void:
	_load_career()
	_reset_ship()
	_switch("PORT" if int(career["completed"]) < CONTRACTS.size() else "END")

func _reset_ship() -> void:
	ship.position = Vector3(-66, 0.75, -53)
	ship.rotation = Vector3(0, -PI / 2.0, 0)
	velocity = 0.0
	hull = 100.0 + 25.0 * float(career["hull_upgrade"])
	supplies = 100.0
	sonar_charges = 3 + int(career["sonar"])
	advice_anchor_timer = 0.0
	advice_sail_timer = 0.0
	for salvage in world.salvage_nodes:
		if is_instance_valid(salvage): salvage.show()
	_remove_route()

func _start_contract() -> void:
	if int(career["completed"]) >= CONTRACTS.size():
		_switch("END")
		return
	var current: Dictionary = CONTRACTS[int(career["completed"])]
	target_port = int(current["island"])
	cargo_held = false
	score_this_voyage = 0
	time_in_voyage = 0.0
	storm_time = 0.0
	storm_beliefs = [0.30, 0.30]
	for i in range(storm_active.size()):
		storm_active[i] = game_rng.randf() < float(storm_beliefs[i])
	last_scan = {}
	_reset_ship()
	_select_destination()
	_switch("PLAY")
	_toast("MISSION ACCEPTED  /  Follow the golden route to %s." % str(World.PORTS[target_port]["name"]))
	_play_effect("mission")

func _select_destination() -> void:
	destination = World.PORTS[HOME]["dock"] if cargo_held else World.PORTS[target_port]["dock"]
	goal_marker.global_position = destination + Vector3(0, 0.5, 0)
	goal_marker.visible = true
	_recalculate_route()

func _recalculate_route() -> void:
	var obstacles: Array = []
	for reef in World.REEFS:
		obstacles.append([reef[0], float(reef[1]) + 5.0])
	for i in range(World.PORTS.size()):
		var land: Vector2 = World.PORTS[i]["land"]
		obstacles.append([land, 31.0])
	var info: Dictionary = ai.map_info(ship.global_position, destination, World.STORMS, storm_beliefs, obstacles)
	last_path = ai.astar(info["start"], info["goal"], info["blocked"], info["costs"])
	last_mdp = ai.mdp_decision(_relevant_risk(), supplies)
	_draw_route()
	_refresh_lab()

func _draw_route() -> void:
	_remove_route()
	if not route_visible or not bool(last_path.get("reachable", false)):
		return
	var marks: Array = last_path.get("path", [])
	if marks.size() < 2:
		return
	var orb_mesh: SphereMesh = SphereMesh.new()
	orb_mesh.radius = 0.68
	orb_mesh.height = 1.36
	orb_mesh.radial_segments = 8
	orb_mesh.rings = 4
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = GOLD
	material.emission_enabled = true
	material.emission = GOLD
	material.emission_energy_multiplier = 1.7
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(1, marks.size()):
		var m: MeshInstance3D = MeshInstance3D.new()
		m.name = "Waypoint_%02d" % i
		m.mesh = orb_mesh
		m.material_override = material
		m.position = ai.cell_to_world(marks[i]) + Vector3(0, 0.7, 0)
		m.scale = Vector3.ONE * (0.8 if i % 2 == 0 else 1.0)
		route_root.add_child(m)

func _remove_route() -> void:
	if route_root == null: return
	for child in route_root.get_children():
		child.queue_free()

func _relevant_storm() -> int:
	# Choose the storm closest to the segment to the active objective.
	var a: Vector2 = Vector2(ship.position.x, ship.position.z)
	var b: Vector2 = Vector2(destination.x, destination.z)
	var best: float = INF
	var best_index: int = 0
	for i in range(World.STORMS.size()):
		var p: Vector2 = World.STORMS[i]
		var delta: Vector2 = b - a
		var fraction: float = clampf((p - a).dot(delta) / maxf(delta.length_squared(), 0.01), 0.0, 1.0)
		var distance: float = p.distance_to(a + delta * fraction)
		if distance < best:
			best = distance
			best_index = i
	return best_index

func _relevant_risk() -> float:
	return float(storm_beliefs[_relevant_storm()])

func _scan() -> void:
	if mode != "PLAY": return
	if sonar_charges <= 0:
		_toast("NO SCANS LEFT  /  Refill your sonar between voyages.")
		return
	sonar_charges -= 1
	_play_effect("scan")
	var index: int = _relevant_storm()
	var actual: bool = bool(storm_active[index])
	var alert: bool = game_rng.randf() < (AI.SENSITIVITY if actual else AI.FALSE_ALARM_RATE)
	last_scan = ai.posterior(float(storm_beliefs[index]), alert)
	last_scan["front"] = index + 1
	storm_beliefs[index] = float(last_scan["posterior"])
	_recalculate_route()
	_toast("LOOKOUT: %s  /  Hazard estimate: %.1f%%" % ["ALERT" if alert else "CLEAR", float(last_scan["posterior"]) * 100.0])
	_refresh_hud()

func _anchor(delta: float) -> void:
	velocity = move_toward(velocity, 0.0, delta * 31.0)
	if absf(velocity) < 0.35:
		supplies = minf(100.0, supplies + delta * 0.9)

func _unhandled_key(code: int) -> void:
	if code == KEY_ESCAPE:
		if mode == "PLAY": _switch("PAUSE")
		elif mode == "PAUSE": _switch("PLAY")
		return
	if mode != "PLAY": return
	match code:
		KEY_Q: _scan()
		KEY_T:
			route_visible = not route_visible
			_draw_route()
			_toast("A* ROUTE %s" % ("VISIBLE" if route_visible else "HIDDEN"))
		KEY_F:
			lab_visible = not lab_visible
			lab_panel.visible = lab_visible
		KEY_E: _interact()
		KEY_G: _follow_advisor()
		KEY_M:
			music_on = not music_on
			music_audio.stream_paused = not music_on
			_toast("MUSIC: %s" % ("ON" if music_on else "OFF"))
		KEY_R: _recalculate_route(); _toast("ROUTE RECALCULATED")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_unhandled_key(event.keycode)

func _follow_advisor() -> void:
	# An MDP recommendation can actually change the captain's action.
	last_mdp = ai.mdp_decision(_relevant_risk(), supplies)
	if str(last_mdp["action"]) == "ANCHOR":
		advice_anchor_timer = 5.0
		_toast("NAVIGATOR: ANCHOR FOR 5 SECONDS  /  Predicted risk is high.")
	else:
		advice_sail_timer = 5.0
		_toast("NAVIGATOR: FULL SAIL FOR 5 SECONDS  /  Expected gain is positive.")
	_play_effect("scan")

func _near_port(port_index: int) -> bool:
	return ship.position.distance_to(World.PORTS[port_index]["dock"] + Vector3(0, 0.75, 0)) < 16.0

func _interact() -> void:
	if mode != "PLAY": return
	if not cargo_held and _near_port(target_port):
		cargo_held = true
		score_this_voyage += 100
		_toast("RELIC SECURED  /  Bring it safely back to Haven Port!")
		_play_effect("mission")
		_select_destination()
	elif cargo_held and _near_port(HOME):
		_complete_contract()
	else:
		_toast("NOT CLOSE ENOUGH  /  Sail near your objective marker.")

func _complete_contract() -> void:
	var current: Dictionary = CONTRACTS[int(career["completed"])]
	var reward: int = int(current["reward"]) + score_this_voyage + int(hull * 1.2)
	career["gold"] = int(career["gold"]) + reward
	career["completed"] = int(career["completed"]) + 1
	career["voyages"] = int(career["voyages"]) + 1
	career["best_score"] = maxi(int(career["best_score"]), reward)
	_save_career()
	_remove_route()
	_reset_ship()
	if int(career["completed"]) >= CONTRACTS.size():
		_switch("END")
	else:
		_switch("PORT")
	_toast("VOYAGE COMPLETE  /  +%d gold" % reward)
	_play_effect("mission")

func _upgrade(kind: String) -> void:
	var level_key: String = "hull_upgrade" if kind == "hull" else kind
	var level: int = int(career[level_key])
	var cost: int = 150 + level * 175
	if level >= 3:
		_toast("THIS UPGRADE IS ALREADY MAXED OUT.")
		return
	if int(career["gold"]) < cost:
		_toast("NOT ENOUGH GOLD. Complete another voyage.")
		return
	career["gold"] = int(career["gold"]) - cost
	career[level_key] = level + 1
	_save_career()
	_refresh_port()
	_toast("UPGRADE INSTALLED  /  %s level %d" % [kind.to_upper(), level + 1])

func _process(delta: float) -> void:
	sea_time += delta
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.visible = toast_time > 0.0
	if goal_marker != null and goal_marker.visible:
		goal_marker.rotation.y += delta * 0.35
		goal_marker.scale = Vector3.ONE * (1.0 + sin(sea_time * 2.2) * 0.05)
	if mode == "PLAY":
		_process_voyage(delta)
		_update_camera(delta)
	elif mode == "PAUSE":
		_update_camera(delta)
	else:
		var angle: float = sea_time * 0.07
		var look_at_position: Vector3 = Vector3(-78, 3, -70)
		var desired: Vector3 = look_at_position + Vector3(cos(angle) * 57, 28, sin(angle) * 57)
		camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 1.6))
		camera.look_at(look_at_position, Vector3.UP)

func _process_voyage(delta: float) -> void:
	time_in_voyage += delta
	collision_delay = maxf(0.0, collision_delay - delta)
	storm_time += delta
	if storm_time > 24.0:
		storm_time = 0.0
		for i in range(storm_active.size()):
			storm_active[i] = game_rng.randf() < 0.35
			storm_beliefs[i] = 0.35
		_recalculate_route()
		_toast("WEATHER UPDATE  /  Conditions are changing. Consider a new scan.")
	var steer: float = Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A): steer -= 1.0
	if Input.is_key_pressed(KEY_D): steer += 1.0
	steer = clampf(steer, -1.0, 1.0)
	var forward_input: float = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): forward_input = 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): forward_input = -0.4
	advice_anchor_timer = maxf(0.0, advice_anchor_timer - delta)
	advice_sail_timer = maxf(0.0, advice_sail_timer - delta)
	var anchored: bool = Input.is_key_pressed(KEY_SPACE) or advice_anchor_timer > 0.0
	if advice_sail_timer > 0.0: forward_input = 1.0
	var speed_max: float = 20.0 + 4.5 * float(career["engine"])
	if advice_sail_timer > 0.0: speed_max *= 1.22
	if supplies <= 0.0: speed_max = 7.0  # Never soft-lock a voyage.
	if anchored:
		_anchor(delta)
	else:
		velocity = move_toward(velocity, forward_input * speed_max, delta * 9.0)
	ship.rotation.y -= steer * delta * (0.62 + absf(velocity) / 65.0)
	var displacement: Vector3 = -ship.transform.basis.z * velocity * delta
	var next_position: Vector3 = ship.position + displacement
	var hit: bool = false
	for reef in World.REEFS:
		if Vector2(next_position.x, next_position.z).distance_to(reef[0]) < float(reef[1]) + 3.0:
			hit = true
	for port in World.PORTS:
		if Vector2(next_position.x, next_position.z).distance_to(port["land"]) < 29.0:
			hit = true
	if absf(next_position.x) > 128.0 or absf(next_position.z) > 128.0:
		hit = true
	if hit:
		if collision_delay <= 0.0:
			hull = maxf(10.0, hull - 7.0)
			collision_delay = 1.4
			_toast("REEF OR SHORELINE  /  Hull integrity reduced.")
		velocity = -velocity * 0.24
	else:
		ship.position.x = next_position.x
		ship.position.z = next_position.z
		career["total_distance"] = float(career["total_distance"]) + displacement.length()
	if absf(velocity) > 1.0:
		supplies = maxf(0.0, supplies - delta * (0.45 + absf(velocity) * 0.017))
	ship.position.y = 0.75 + sin(sea_time * 1.8) * 0.22
	ship.rotation.x = sin(sea_time * 1.5) * 0.035
	ship.rotation.z = -steer * 0.065 + sin(sea_time * 1.3) * 0.025
	for i in range(World.STORMS.size()):
		if storm_active[i] and Vector2(ship.position.x, ship.position.z).distance_to(World.STORMS[i]) < 23.0:
			hull = maxf(10.0, hull - delta * (1.0 + 0.25 * float(i)))
			supplies = maxf(0.0, supplies - delta * 0.55)
	for salvage in world.salvage_nodes:
		if is_instance_valid(salvage) and salvage.visible and ship.position.distance_to(salvage.position) < 5.5:
			salvage.hide()
			var bonus: int = 25 + game_rng.randi_range(0, 25)
			score_this_voyage += bonus
			career["treasure"] = int(career["treasure"]) + 1
			_toast("GOLD DISCOVERED  /  +%d bonus" % bonus)
			_play_effect("treasure")
	var goal_dist: float = ship.position.distance_to(destination)
	if goal_dist < 16.0:
		hint_label.text = "E  ·  %s" % ("DELIVER THE RELIC" if cargo_held else "RECOVER THE RELIC")
	else:
		hint_label.text = "WASD SAIL   ·   Q SCAN   ·   G MDP   ·   F AI LAB   ·   T ROUTE   ·   SPACE ANCHOR"
	_refresh_hud()

func _update_camera(delta: float) -> void:
	var behind: Vector3 = ship.global_transform.basis.z * 21.0
	var desired: Vector3 = ship.global_position + behind + Vector3(0, 14.5, 0)
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 3.6))
	camera.look_at(ship.global_position + Vector3(0, 3.7, 0), Vector3.UP)

func _toast(message: String) -> void:
	toast_label.text = message
	toast_time = 4.7
	toast_label.visible = true

func _build_audio() -> void:
	ocean_audio = AudioStreamPlayer.new()
	ocean_audio.name = "OceanAmbience"
	ocean_audio.volume_db = -14.0
	add_child(ocean_audio)
	ocean_audio.stream = load("res://assets/audio/ocean.wav")
	ocean_audio.finished.connect(func(): ocean_audio.play())
	ocean_audio.play()
	music_audio = AudioStreamPlayer.new()
	music_audio.name = "OriginalSoundtrack"
	music_audio.volume_db = -17.0
	add_child(music_audio)
	music_audio.stream = load("res://assets/audio/voyage_theme.wav")
	music_audio.finished.connect(func(): music_audio.play())
	music_audio.play()
	effects_audio = AudioStreamPlayer.new()
	effects_audio.name = "UIAndTreasureFX"
	effects_audio.volume_db = -8.0
	add_child(effects_audio)

func _play_effect(kind: String) -> void:
	if effects_audio != null:
		var filename: String = "res://assets/audio/" + kind + ".wav"
		effects_audio.stream = load(filename)
		effects_audio.play()

# ---------- presentation/UI utilities ----------
func _style(bg: Color = NAVY, border: Color = Color("4b8290"), radius: int = 15) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _label(parent: Node, content: String, size: int, color: Color, bold: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = content
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.44))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _button(parent: Node, title: String, bg: Color = SEA) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(190, 51)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(bg, Color("668f96"), 9))
	button.add_theme_stylebox_override("hover", _style(bg.lightened(0.18), GOLD, 9))
	button.add_theme_stylebox_override("pressed", _style(bg.darkened(0.15), GOLD, 9))
	parent.add_child(button)
	return button

func _panel(parent: Node, rect: Rect2, bg: Color = Color(0.015, 0.08, 0.14, 0.90)) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.position = rect.position
	p.custom_minimum_size = rect.size
	p.add_theme_stylebox_override("panel", _style(bg))
	parent.add_child(p)
	return p

func _spacer(parent: Node, min_height: int = 12) -> Control:
	var s: Control = Control.new()
	s.custom_minimum_size = Vector2(0, min_height)
	parent.add_child(s)
	return s

func _column(parent: Node, gap: int = 10) -> VBoxContainer:
	var c: VBoxContainer = VBoxContainer.new()
	c.add_theme_constant_override("separation", gap)
	parent.add_child(c)
	return c

func _overlay_root() -> Control:
	var node: Control = Control.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(node)
	return node

func _build_interface() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 12
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)
	_build_menu()
	_build_port()
	_build_hud()
	_build_pause()
	_build_ending()
	toast_label = _label(ui_root, "", 19, GOLD, true)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-350, 94)
	toast_label.custom_minimum_size = Vector2(700, 46)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_shadow_color", NAVY)
	toast_label.add_theme_constant_override("shadow_outline_size", 5)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false

func _build_menu() -> void:
	menu = _overlay_root()
	var mask: ColorRect = ColorRect.new()
	mask.color = Color(0.016, 0.06, 0.10, 0.51)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(mask)
	var left: MarginContainer = MarginContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left.offset_left = 76
	left.offset_right = -520
	left.offset_top = 100
	left.offset_bottom = -95
	menu.add_child(left)
	var col: VBoxContainer = _column(left, 14)
	_label(col, "AN ORIGINAL 3D NAVIGATION ADVENTURE", 19, GOLD, true)
	_spacer(col, 24)
	_label(col, "THE LAST", 67, CREAM, true)
	_label(col, "CURRENT", 77, GOLD, true)
	_spacer(col, 8)
	_label(col, "LEGENDS OF THE SEA", 26, CREAM)
	_spacer(col, 24)
	_label(col, "A ship. A secret chart. Five voyages across an uncertain ocean.", 20, CREAM)
	_label(col, "Explore the islands, recover relics and become a legendary navigator.", 18, MUTED)
	_spacer(col, 36)
	_label(col, "CREATED BY  MUSTAFIN ARLAN  ·  TOKMAGAMBET BEKNAZAR", 17, GOLD)
	_label(col, "QAIRU  /  AI FUNDAMENTALS FINAL PROJECT", 15, MUTED)
	var right: PanelContainer = PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right.position = Vector2(-485, -245)
	right.custom_minimum_size = Vector2(425, 490)
	right.add_theme_stylebox_override("panel", _style(Color(0.016, 0.065, 0.105, 0.95), Color("827653"), 20))
	menu.add_child(right)
	var menu_col: VBoxContainer = _column(right, 14)
	_label(menu_col, "CAPTAIN'S LOG", 29, GOLD, true)
	_label(menu_col, "Choose a voyage", 18, MUTED)
	_spacer(menu_col, 12)
	_button(menu_col, "START NEW CAREER", Color("956944")).pressed.connect(_start_new)
	_button(menu_col, "CONTINUE CAREER", SEA).pressed.connect(_continue_career)
	_spacer(menu_col, 16)
	_label(menu_col, "THREE REAL AI SYSTEMS", 17, GOLD)
	_label(menu_col, "A*  — risk-weighted navigation", 17, CREAM)
	_label(menu_col, "BAYES  — update storm probability", 17, CREAM)
	_label(menu_col, "MDP  — sail or anchor?", 17, CREAM)
	_spacer(menu_col, 10)
	_label(menu_col, "WASD to sail  ·  Q to scan  ·  G for AI recommendation", 16, MUTED)

func _build_port() -> void:
	port_menu = _overlay_root()
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.018, 0.065, 0.10, 0.70)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port_menu.add_child(dim)
	var p: PanelContainer = _panel(port_menu, Rect2(65, 75, 820, 680), Color(0.02, 0.09, 0.14, 0.96))
	var c: VBoxContainer = _column(p, 11)
	_label(c, "HAVEN PORT   /   THE CAREER BOARD", 31, GOLD, true)
	port_rank_label = _label(c, "", 18, CREAM)
	port_gold_label = _label(c, "", 22, GOLD, true)
	_spacer(c, 12)
	port_contract_label = _label(c, "", 28, CREAM, true)
	port_description_label = _label(c, "", 18, MUTED)
	port_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spacer(c, 15)
	_button(c, "ACCEPT THE NEXT CONTRACT", Color("926840")).pressed.connect(_start_contract)
	_spacer(c, 16)
	_label(c, "SHIPYARD  /  INVEST YOUR GOLD", 22, GOLD, true)
	var upgrade_row: HBoxContainer = HBoxContainer.new()
	upgrade_row.add_theme_constant_override("separation", 14)
	c.add_child(upgrade_row)
	for kind in ["engine", "hull", "sonar"]:
		var b: Button = _button(upgrade_row, "", SEA)
		b.custom_minimum_size = Vector2(240, 75)
		b.pressed.connect(_upgrade.bind(kind))
		upgrade_buttons[kind] = b
	_spacer(c, 18)
	_button(c, "RETURN TO TITLE", NAVY).pressed.connect(func(): _switch("MENU"))
	var side: PanelContainer = _panel(port_menu, Rect2(930, 110, 380, 500), Color(0.02, 0.08, 0.13, 0.92))
	var sc: VBoxContainer = _column(side, 15)
	_label(sc, "THE NAVIGATOR'S CODE", 24, GOLD, true)
	_label(sc, "1. Plot a route with A*", 18, CREAM)
	_label(sc, "2. Scan suspicious waters with Q", 18, CREAM)
	_label(sc, "3. Press G to let MDP choose Sail / Anchor", 18, CREAM)
	_spacer(sc, 20)
	_label(sc, "CAREER PROGRESSION", 20, GOLD)
	_label(sc, "Complete contracts to unlock higher ranks.", 18, MUTED)
	_label(sc, "Upgrade speed, hull and sonar between voyages.", 18, MUTED)
	_label(sc, "Progress is saved on this PC automatically.", 18, MUTED)

func _refresh_port() -> void:
	port_gold_label.text = "GOLD  /  %d doubloons" % int(career["gold"])
	port_rank_label.text = "RANK  /  %s      |      CONTRACTS  %d / %d" % [_rank(), int(career["completed"]), CONTRACTS.size()]
	if int(career["completed"]) < CONTRACTS.size():
		var c: Dictionary = CONTRACTS[int(career["completed"])]
		port_contract_label.text = str(c["name"]) + "  •  +%d GOLD" % int(c["reward"])
		port_description_label.text = str(c["desc"])
	else:
		port_contract_label.text = "THE CAMPAIGN IS COMPLETE"
		port_description_label.text = "Your crew has become a legend of the sea."
	for kind in upgrade_buttons.keys():
		var k: String = "hull_upgrade" if kind == "hull" else kind
		var lvl: int = int(career[k])
		var cost: int = 150 + lvl * 175
		upgrade_buttons[kind].text = "%s  LV %d/3\n%s" % [kind.to_upper(), lvl, "MAX LEVEL" if lvl == 3 else "%d GOLD" % cost]

func _build_hud() -> void:
	hud = _overlay_root()
	var top: PanelContainer = PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_right = -22
	top.offset_top = 16
	top.custom_minimum_size.y = 79
	top.add_theme_stylebox_override("panel", _style(Color(0.013, 0.07, 0.11, 0.90)))
	hud.add_child(top)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 30)
	top.add_child(bar)
	mission_label = _label(bar, "", 21, GOLD, true)
	mission_label.custom_minimum_size.x = 330
	status_label = _label(bar, "", 17, CREAM)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_label = _label(bar, "", 19, GOLD, true)
	var bottom: PanelContainer = PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(22, -218)
	bottom.custom_minimum_size = Vector2(460, 196)
	bottom.add_theme_stylebox_override("panel", _style(Color(0.012, 0.065, 0.10, 0.90)))
	hud.add_child(bottom)
	var bcol: VBoxContainer = _column(bottom, 8)
	_label(bcol, "SHIP STATUS", 19, GOLD, true)
	hull_label = _label(bcol, "", 18, CREAM)
	fuel_label = _label(bcol, "", 18, CREAM)
	speed_label = _label(bcol, "", 18, CREAM)
	sonar_label = _label(bcol, "", 18, CREAM)
	objective_label = _label(bcol, "", 17, GOLD)
	hint_label = _label(hud, "", 18, CREAM, true)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-360, -52)
	hint_label.custom_minimum_size.x = 720
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab_panel = PanelContainer.new()
	lab_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lab_panel.position = Vector2(-455, 117)
	lab_panel.custom_minimum_size = Vector2(428, 570)
	lab_panel.add_theme_stylebox_override("panel", _style(Color(0.014, 0.067, 0.11, 0.95), Color("bb9d62")))
	hud.add_child(lab_panel)
	var ac: VBoxContainer = _column(lab_panel, 11)
	ai_title_label = _label(ac, "AI LAB  /  REAL ALGORITHMS", 22, GOLD, true)
	var scroller: ScrollContainer = ScrollContainer.new()
	scroller.custom_minimum_size = Vector2(387, 505)
	ac.add_child(scroller)
	ai_content_label = _label(scroller, "", 16, CREAM)
	ai_content_label.custom_minimum_size.x = 362
	ai_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab_panel.visible = false

func _refresh_hud() -> void:
	if mode != "PLAY" and mode != "PAUSE": return
	var c: Dictionary = CONTRACTS[int(career["completed"])]
	mission_label.text = str(c["name"])
	status_label.text = "RETURN TO HAVEN PORT" if cargo_held else "FIND %s  /  %s" % [str(c["cargo"]), str(World.PORTS[target_port]["name"])]
	gold_label.text = "BONUS  %d" % score_this_voyage
	hull_label.text = "HULL       %d%%" % roundi(hull / (100.0 + 25.0 * float(career["hull_upgrade"])) * 100.0)
	fuel_label.text = "SUPPLIES   %d%%" % roundi(supplies)
	speed_label.text = "SPEED      %d knots" % roundi(absf(velocity))
	sonar_label.text = "LOOKOUT     %d scans left" % sonar_charges
	objective_label.text = "TARGET     %d metres away" % roundi(ship.position.distance_to(destination))
	if lab_visible: _refresh_lab()

func _refresh_lab() -> void:
	if ai_content_label == null: return
	var route: String = "NOT PLANNED"
	if bool(last_path.get("reachable", false)):
		route = "%d waypoints  |  cost %.2f  |  expanded %d" % [last_path["path"].size(), float(last_path["cost"]), int(last_path["expanded"])]
	var prob: float = _relevant_risk()
	var bayes_info: String = "No scan yet. Prior storm risk %.1f%%" % (prob * 100.0)
	if not last_scan.is_empty():
		bayes_info = "P(D)=%.3f, P(signal|D)=%.2f\nP(signal|safe)=%.2f\nP(D|signal)=%.3f / %.3f = %.3f" % [float(last_scan["prior"]), float(last_scan["likelihood_danger"]), float(last_scan["likelihood_safe"]), float(last_scan["numerator"]), float(last_scan["denominator"]), float(last_scan["posterior"])]
	last_mdp = ai.mdp_decision(prob, supplies)
	ai_content_label.text = "A* SEARCH\nInput: start, destination, reef cells, risk costs\nf(n)=g(n)+Manhattan(n, goal)\nOutput: %s\n\nBAYESIAN INFERENCE\n%s\n\nONE-STEP MDP\nStates: calm or dangerous\nActions: sail or anchor\nE[SAIL] = (1-p)*%.0f + p*(%.0f) = %.2f\nE[ANCHOR] = %.2f\nRecommendation: %s" % [route, bayes_info, float(last_mdp["sail_calm"]), float(last_mdp["sail_danger"]), float(last_mdp["expected_sail"]), float(last_mdp["expected_anchor"]), str(last_mdp["action"])]

func _build_pause() -> void:
	pause_menu = _overlay_root()
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0, 0.03, 0.05, 0.75)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(veil)
	var panel: PanelContainer = _panel(pause_menu, Rect2(485, 240, 470, 375))
	var c: VBoxContainer = _column(panel, 15)
	_label(c, "PAUSED", 36, GOLD, true)
	_label(c, "The ocean can wait.", 18, CREAM)
	_button(c, "RESUME VOYAGE").pressed.connect(func(): _switch("PLAY"))
	_button(c, "ABANDON VOYAGE", Color("7d5748")).pressed.connect(func(): _reset_ship(); _switch("PORT"))
	_button(c, "MAIN MENU", NAVY).pressed.connect(func(): _switch("MENU"))

func _build_ending() -> void:
	end_menu = _overlay_root()
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.075, 0.10, 0.68)
	end_menu.add_child(dim)
	var p: PanelContainer = _panel(end_menu, Rect2(340, 160, 760, 560), Color(0.018, 0.09, 0.14, 0.96))
	var c: VBoxContainer = _column(p, 21)
	_label(c, "THE LAST CURRENT", 46, GOLD, true)
	_label(c, "LEGEND OF THE SEA", 35, CREAM, true)
	_label(c, "Five contracts completed. The archipelago will remember your name.", 20, CREAM)
	_label(c, "CAPTAINS  /  MUSTAFIN ARLAN  &  TOKMAGAMBET BEKNAZAR", 18, MUTED)
	_spacer(c, 32)
	_label(c, "AI SYSTEMS DEPLOYED:   A*  •  BAYES  •  ONE-STEP MDP", 18, GOLD)
	_button(c, "RETURN TO TITLE", SEA).pressed.connect(func(): _switch("MENU"))
	_button(c, "START ANOTHER CAREER", Color("98734b")).pressed.connect(_start_new)
