extends Node

enum Role { STOCKER, CASHIER, SECURITY }

const ROLE_DEFS: Dictionary = {
	Role.STOCKER: {
		"name": "Stocker",
		"hire_cost": 100.0,
		"base_salary": 25.0,
		"base_speed": 0.5,
		"speed_per_level": 0.15,
		"max_level": 5,
		"upgrade_cost_base": 60.0,
		"upgrade_cost_exp": 1.5,
	},
	Role.CASHIER: {
		"name": "Cashier",
		"hire_cost": 120.0,
		"base_salary": 30.0,
		"base_speed": 1.0,
		"speed_per_level": 0.2,
		"max_level": 5,
		"upgrade_cost_base": 70.0,
		"upgrade_cost_exp": 1.5,
	},
	Role.SECURITY: {
		"name": "Security Guard",
		"hire_cost": 150.0,
		"base_salary": 35.0,
		"base_speed": 0.3,
		"speed_per_level": 0.1,
		"max_level": 5,
		"upgrade_cost_base": 80.0,
		"upgrade_cost_exp": 1.6,
	},
}

const WORKER_BOT_SCENE: String = "res://Scenes/Workers/worker_bot.tscn"

var workers: Array[Dictionary] = []
var _next_id: int = 1

var _bot_packed: PackedScene = null

func _ready() -> void:
	EventBus.day_ended.connect(_on_day_ended)
	_bot_packed = load(WORKER_BOT_SCENE) as PackedScene

func hire_worker(role: int) -> bool:
	var def: Dictionary = ROLE_DEFS[role]
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or not gm.spend_money(def["hire_cost"]):
		return false

	var worker_id := _next_id
	_next_id += 1

	var record := {
		"id": worker_id,
		"role": role,
		"role_name": def["name"],
		"level": 1,
		"salary": def["base_salary"],
	}
	workers.append(record)

	call_deferred("_spawn_bot", record)

	EventBus.worker_hired.emit(record)
	EventBus.workers_changed.emit()
	return true

func fire_worker(worker_id: int) -> bool:
	for i in workers.size():
		if workers[i]["id"] == worker_id:
			var record := workers[i]
			workers.remove_at(i)
			_despawn_bot(worker_id)
			EventBus.worker_fired.emit(record)
			EventBus.workers_changed.emit()
			return true
	return false

func upgrade_worker(worker_id: int) -> bool:
	for record in workers:
		if record["id"] != worker_id:
			continue
		var def: Dictionary = ROLE_DEFS[record["role"]]
		if record["level"] >= def["max_level"]:
			return false
		var cost := get_worker_upgrade_cost(record)
		var gm = get_node_or_null("/root/GameManager")
		if gm == null or not gm.spend_money(cost):
			return false
		record["level"] += 1
		record["salary"] = def["base_salary"] + (record["level"] - 1) * 5.0
		var bot := _find_bot(worker_id)
		if bot:
			bot.level = record["level"]
			bot.salary = record["salary"]
		EventBus.workers_changed.emit()
		return true
	return false

func get_worker_upgrade_cost(worker: Dictionary) -> float:
	var def: Dictionary = ROLE_DEFS[worker["role"]]
	return def["upgrade_cost_base"] * pow(def["upgrade_cost_exp"], float(worker["level"] - 1))

func get_worker_efficiency(worker: Dictionary) -> float:
	var def: Dictionary = ROLE_DEFS[worker["role"]]
	return def["base_speed"] + def["speed_per_level"] * (worker["level"] - 1)

func get_workers_by_role(role: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for w in workers:
		if w["role"] == role:
			result.append(w)
	return result

func get_worker_count_by_role(role: int) -> int:
	var count := 0
	for w in workers:
		if w["role"] == role:
			count += 1
	return count

func get_total_daily_wages() -> float:
	var total := 0.0
	for w in workers:
		total += w["salary"]
	return total

func get_active_tasks() -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	var bots := get_tree().get_nodes_in_group("worker_bots")
	for bot in bots:
		if not (bot is WorkerBot):
			continue
		if bot.bot_state == WorkerBot.BotState.IDLE:
			continue
		var task_desc: String = bot.get_state_name()
		if bot.role == WorkerBot.Role.STOCKER and not bot._carried_product_id.is_empty():
			var db = get_node_or_null("/root/ProductDatabase")
			if db:
				var p = db.get_product(bot._carried_product_id)
				if p:
					task_desc += " (%s)" % p.product_name
		tasks.append({
			"worker_id": bot.worker_id,
			"role_name": bot.get_role_name(),
			"task": task_desc,
		})
	return tasks

func get_detection_chance_at(target_pos: Vector3) -> float:
	var bots := get_tree().get_nodes_in_group("worker_bots")
	var combined := 0.0
	for bot in bots:
		if bot is WorkerBot and bot.role == WorkerBot.Role.SECURITY:
			var chance: float = bot.get_detection_chance_for(target_pos)
			combined = 1.0 - (1.0 - combined) * (1.0 - chance)
	return clampf(combined, 0.0, 0.95)

func get_total_detection_chance() -> float:
	var guards := get_workers_by_role(Role.SECURITY)
	if guards.is_empty():
		return 0.0
	var chance := 0.0
	for g in guards:
		chance += get_worker_efficiency(g)
	return clampf(chance, 0.0, 0.95)

func get_cashier_speed_bonus() -> float:
	var cashiers := get_workers_by_role(Role.CASHIER)
	var total := 1.0
	for c in cashiers:
		total += get_worker_efficiency(c) * 0.25
	return total

func get_nearest_guard_bot(pos: Vector3) -> Node:
	var bots := get_tree().get_nodes_in_group("worker_bots")
	var best: Node = null
	var best_dist := INF
	for bot in bots:
		if bot is WorkerBot and bot.role == WorkerBot.Role.SECURITY:
			var d: float = bot.global_position.distance_squared_to(pos)
			if d < best_dist:
				best_dist = d
				best = bot
	return best

func get_bot_state_name(worker_id: int) -> String:
	var bot := _find_bot(worker_id)
	if bot and bot.has_method("get_state_name"):
		return bot.get_state_name()
	return ""

func _spawn_bot(record: Dictionary) -> void:
	if _bot_packed == null:
		return

	var bot: Node = _bot_packed.instantiate()
	get_tree().current_scene.add_child(bot)

	var spawn_pos := _get_spawn_position()
	bot.setup(record["role"], record["id"], record["level"], record["salary"], spawn_pos)

	EventBus.worker_bot_spawned.emit(bot)

func _despawn_bot(worker_id: int) -> void:
	var bot := _find_bot(worker_id)
	if bot:
		EventBus.worker_bot_removed.emit(bot)
		bot.queue_free()

func _find_bot(worker_id: int) -> Node:
	var bots := get_tree().get_nodes_in_group("worker_bots")
	for bot in bots:
		if bot is WorkerBot and bot.worker_id == worker_id:
			return bot
	return null

func _get_spawn_position() -> Vector3:
	var scene := get_tree().current_scene
	var entrance := scene.get_node_or_null("Entrance")
	if entrance:
		return entrance.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	var sms := get_tree().get_nodes_in_group("store_manager")
	if not sms.is_empty():
		var sm = sms[0]
		if sm.has_node("Entrance"):
			return sm.get_node("Entrance").global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	var crates := get_tree().get_nodes_in_group("restock_crates")
	if not crates.is_empty():
		return crates[0].global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	return Vector3(0, 4.0, 0)

func _on_day_ended(_day: int) -> void:
	var total_wages := get_total_daily_wages()
	if total_wages > 0.0:
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.spend_money(total_wages)
	EventBus.worker_wage_deducted.emit(total_wages)
