class_name CheckoutCounter
extends Interactable

@export_group("Checkout Settings")
@export var player_operated: bool = true
@export var scan_time: float = 0.0

var customer_queue: Array[Node] = []
var current_customer: Node = null
var _is_processing: bool = false
var _scan_elapsed: float = 0.0
var _pending_customer: Node = null

@onready var queue_positions: Node3D = $QueuePositions if has_node("QueuePositions") else null
@onready var service_point: Node3D = $ServicePoint if has_node("ServicePoint") else null

func _ready() -> void:
	add_to_group("checkout_counters")

func _process(delta: float) -> void:
	if _pending_customer == null:
		return
	_scan_elapsed += delta
	if _scan_elapsed >= get_effective_scan_time():
		_finish_transaction(_pending_customer)
		_pending_customer = null

func get_effective_scan_time() -> float:
	if scan_time <= 0.0:
		return 0.0
	var um = get_node_or_null("/root/UpgradeManager")
	if um:
		var speed_mult: float = um.get_upgrade_value("checkout_speed")
		if speed_mult > 0.0:
			return scan_time / speed_mult
	return scan_time

func join_queue(customer: Node) -> Node3D:
	if customer in customer_queue:
		return null
	customer_queue.append(customer)
	EventBus.checkout_queue_changed.emit(self, customer_queue.size())
	return _get_queue_position(customer_queue.size() - 1)

func leave_queue(customer: Node) -> void:
	customer_queue.erase(customer)
	if current_customer == customer:
		current_customer = null
		_is_processing = false
	EventBus.checkout_queue_changed.emit(self, customer_queue.size())

func get_queue_size() -> int:
	return customer_queue.size()

func get_queue_position_for(customer: Node) -> Node3D:
	var idx := customer_queue.find(customer)
	if idx >= 0:
		return _get_queue_position(idx)
	return null

func get_service_position() -> Vector3:
	if service_point:
		return service_point.global_position
	return global_position + Vector3(0, 0, -1)

func try_advance_queue() -> void:
	if _is_processing or customer_queue.is_empty():
		return
	current_customer = customer_queue[0]
	if current_customer.has_method("on_checkout_ready"):
		current_customer.on_checkout_ready(self)

func interact(_player: Node) -> void:
	if not player_operated:
		return
	if current_customer == null:
		try_advance_queue()
		return
	if current_customer.has_method("get_shopping_cart"):
		_process_transaction(current_customer)

func get_prompt() -> String:
	if not player_operated:
		return ""
	if current_customer:
		return "Process payment [E]"
	elif not customer_queue.is_empty():
		return "Call next customer [E]"
	else:
		return "No customers in line"

func _process_transaction(customer: Node) -> void:
	_is_processing = true
	EventBus.checkout_started.emit(self, customer)
	if get_effective_scan_time() > 0.0:
		_scan_elapsed = 0.0
		_pending_customer = customer
	else:
		_finish_transaction(customer)

func _finish_transaction(customer: Node) -> void:
	var total: float = 0.0
	if customer.has_method("get_shopping_cart"):
		var cart: Array = customer.get_shopping_cart()
		var db = get_node_or_null("/root/ProductDatabase")
		for item in cart:
			if db:
				var data = db.get_product(item["product_id"])
				if data:
					total += data.sell_price * item.get("quantity", 1)

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.add_money(total)
		gm.record_customer_served()

	EventBus.transaction_completed.emit(total)
	EventBus.checkout_completed.emit(self, customer, total)

	if customer.has_method("on_checkout_completed"):
		customer.on_checkout_completed(total)

	customer_queue.erase(customer)
	current_customer = null
	_is_processing = false
	EventBus.checkout_queue_changed.emit(self, customer_queue.size())

	_update_queue_positions()

func _get_queue_position(index: int) -> Node3D:
	if queue_positions:
		var children := queue_positions.get_children()
		if index < children.size():
			return children[index] as Node3D
	return null

func _update_queue_positions() -> void:
	for i in customer_queue.size():
		var customer = customer_queue[i]
		if customer.has_method("move_to_queue_position"):
			var pos_node := _get_queue_position(i)
			if pos_node:
				customer.move_to_queue_position(pos_node.global_position)
			else:
				var offset := global_position + Vector3(0, 0, 1.5 * (i + 1))
				customer.move_to_queue_position(offset)
