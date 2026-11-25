extends SceneTree
## Run with tests/run_career_test.ps1 to isolate the career save.
var game
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func navigate() -> bool:
	# Steer the ship toward each computed waypoint. Movement, collision checks
	# and supplies use the game's voyage loop. The driver supplies the throttle.
	var points: Array = []
	for cell in game.last_path.path.slice(1):
		points.append(game.ai.cell_to_world(cell))
	points.append(game.destination)
	for point in points:
		var reached := false
		for tick in range(180):
			var direction: Vector3 = point - game.ship.position
			direction.y = 0.0
			if direction.length() < 2.0:
				reached = true
				break
			game.ship.rotation.y = atan2(-direction.x, -direction.z)
			game.advice_sail_timer = 1.0
			game._process_voyage(1.0 / 30.0)
		if not reached:
			return false
	return true

func run() -> void:
	var temp_root := OS.get_environment("LAST_CURRENT_TEST_ROOT")
	if temp_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp_root.replace("\\", "/") + "/") or FileAccess.file_exists("user://the_last_current_career.json"):
		printerr("Use the PowerShell runner with a fresh isolated data directory.")
		quit(2)
		return
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.mode == "MENU", "Main menu")
	game._start_new()
	check(game.mode == "PORT", "Port menu")
	game.game_rng.seed = 42
	for mission in range(5):
		game._start_contract()
		check(game.mode == "PLAY" and game.last_path.reachable, "Outbound route")
		game._unhandled_key(KEY_F)
		check(game.lab_panel.visible == game.lab_visible, "Lab visibility")
		var charges: int = game.sonar_charges
		game._unhandled_key(KEY_Q)
		check(game.sonar_charges == charges - 1 and game.last_scan.has("posterior"), "Scan")
		game._unhandled_key(KEY_G)
		check(game.advice_anchor_timer > 0 or game.advice_sail_timer > 0, "Advisor")
		game.advice_anchor_timer = 0
		if not navigate():
			check(false, "Outbound sailing contract %d" % (mission + 1))
			break
		game._unhandled_key(KEY_E)
		check(game.cargo_held and game.last_path.reachable, "Pickup and return route")
		if not navigate():
			check(false, "Return sailing contract %d" % (mission + 1))
			break
		var gold: int = game.career.gold
		game._unhandled_key(KEY_E)
		check(game.career.completed == mission + 1 and game.career.gold > gold, "Delivery and payment")
		if mission == 0:
			game._upgrade("engine")
			game._continue_career()
			check(game.career.engine == 1 and game.career.completed == 1, "Upgrade and reload")
	check(game.mode == "END" and game.career.completed == 5, "Final rank screen")
	print("Completed contracts: ", game.career.completed, "/5. Failed checks: ", failures)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
