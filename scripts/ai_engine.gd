extends RefCounted
## Pure course algorithms: A* graph search, Bayesian update and one-step MDP.
## No trained model. The project deliberately uses explicit assumptions.

const GRID_SIZE = 19
const CELL_SIZE = 14.0
const ORIGIN = -126.0
const SENSITIVITY = 0.84
const FALSE_ALARM_RATE = 0.17

func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((p.x - ORIGIN) / CELL_SIZE), 0, GRID_SIZE - 1), clampi(roundi((p.z - ORIGIN) / CELL_SIZE), 0, GRID_SIZE - 1))

func cell_to_world(p: Vector2i) -> Vector3:
	return Vector3(ORIGIN + float(p.x) * CELL_SIZE, 0.4, ORIGIN + float(p.y) * CELL_SIZE)

func posterior(prior: float, alert: bool) -> Dictionary:
	var likelihood_danger: float = SENSITIVITY if alert else 1.0 - SENSITIVITY
	var likelihood_safe: float = FALSE_ALARM_RATE if alert else 1.0 - FALSE_ALARM_RATE
	var numerator: float = likelihood_danger * prior
	var denominator: float = numerator + likelihood_safe * (1.0 - prior)
	var updated: float = numerator / maxf(denominator, 0.000001)
	return {"prior": prior, "alert": alert, "sensitivity": SENSITIVITY, "false_alarm": FALSE_ALARM_RATE, "likelihood_danger": likelihood_danger, "likelihood_safe": likelihood_safe, "numerator": numerator, "denominator": denominator, "posterior": updated}

func mdp_decision(risk: float, fuel: float = 70.0) -> Dictionary:
	# Two states: calm/danger. Two actions: sail/anchor.
	# Explicit expected immediate rewards (one-step MDP demonstration).
	var reward_sail_calm: float = 11.0
	var reward_sail_danger: float = -23.0
	var reward_anchor: float = -3.0
	if fuel < 20.0:
		reward_sail_calm -= 4.0
	# Within this single decision, weather persists under either action.
	# Rows are current calm/danger, columns are next calm/danger.
	var transition := [Vector2(1, 0), Vector2(0, 1)]
	var next_state: Vector2 = (1.0 - risk) * transition[0] + risk * transition[1]
	var sail: float = next_state.dot(Vector2(reward_sail_calm, reward_sail_danger))
	var anchor: float = reward_anchor
	return {"risk": risk, "sail_calm": reward_sail_calm, "sail_danger": reward_sail_danger, "anchor_reward": reward_anchor, "expected_sail": sail, "expected_anchor": anchor, "action": "SAIL" if sail >= anchor else "ANCHOR"}

func heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))

func astar(start: Vector2i, goal: Vector2i, blocked: Dictionary, costs: Dictionary) -> Dictionary:
	# Four-neighbor grid, nonnegative cell costs >= 1. Manhattan heuristic is admissible.
	var frontier: Array[Vector2i] = [start]
	var g: Dictionary = {}
	g[start] = 0.0
	var parent: Dictionary = {}
	var expanded: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var best_index: int = 0
		var best_score: float = INF
		for i in range(frontier.size()):
			var candidate: Vector2i = frontier[i]
			var score: float = float(g[candidate]) + heuristic(candidate, goal)
			if score < best_score:
				best_score = score
				best_index = i
		var here: Vector2i = frontier[best_index]
		frontier.remove_at(best_index)
		if expanded.has(here):
			continue
		expanded.append(here)
		if here == goal:
			var path: Array[Vector2i] = [goal]
			var cursor: Vector2i = goal
			while cursor != start:
				cursor = parent[cursor]
				path.push_front(cursor)
			return {"path": path, "cost": float(g[goal]), "expanded": expanded.size(), "visited": expanded, "reachable": true}
		for direction in dirs:
			var next: Vector2i = here + direction
			if next.x < 0 or next.y < 0 or next.x >= GRID_SIZE or next.y >= GRID_SIZE:
				continue
			if blocked.has(next):
				continue
			var step_cost: float = maxf(1.0, float(costs.get(next, 1.0)))
			var candidate_g: float = float(g[here]) + step_cost
			if candidate_g + 0.00001 < float(g.get(next, INF)):
				g[next] = candidate_g
				parent[next] = here
				frontier.append(next)
	return {"path": [], "cost": INF, "expanded": expanded.size(), "visited": expanded, "reachable": false}

func map_info(start: Vector3, target: Vector3, storm_positions: Array, storm_beliefs: Array, obstacle_positions: Array) -> Dictionary:
	var blocked: Dictionary = {}
	var costs: Dictionary = {}
	var from_cell: Vector2i = world_to_cell(start)
	var to_cell: Vector2i = world_to_cell(target)
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell: Vector2i = Vector2i(x, y)
			var p: Vector3 = cell_to_world(cell)
			for reef in obstacle_positions:
				var r: Vector2 = reef[0]
				var radius: float = float(reef[1])
				if Vector2(p.x, p.z).distance_to(r) < radius:
					blocked[cell] = true
			for i in range(storm_positions.size()):
				var storm: Vector2 = storm_positions[i]
				var distance: float = Vector2(p.x, p.z).distance_to(storm)
				if distance < 46.0:
					var influence: float = (46.0 - distance) / 46.0
					costs[cell] = float(costs.get(cell, 1.0)) + influence * 7.0 * float(storm_beliefs[i])
	blocked.erase(from_cell)
	blocked.erase(to_cell)
	return {"blocked": blocked, "costs": costs, "start": from_cell, "goal": to_cell}
