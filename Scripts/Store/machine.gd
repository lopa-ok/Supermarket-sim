extends Node3D
class_name StoreMachine

enum MachineType { PHOTO_COPIER, VENDING_MACHINE }

@export var machine_type: MachineType = MachineType.PHOTO_COPIER
@export var base_usage_income: float = 2.50
@export var max_uses_before_maintenance: int = 15
@export var use_duration_seconds: float = 2.0
@export var interact_radius: float = 1.25

# For PHOTO_COPIER machines, which level unlocks this specific copier.
# Example: set 1/2/3 for Printer1/Printer2/Printer3.
@export var copier_index: int = 1

var is_unlocked: bool = false
var current_uses: int = 0
var needs_maintenance: bool = false

func _ready() -> void:
	add_to_group("machines")
	
	# Convenience defaults if you drop the scene in without setting exports.
	# Treat "printer" as a photo copier too.
	var lower_name := name.to_lower()
	if lower_name.find("vending") != -1:
		machine_type = MachineType.VENDING_MACHINE
		base_usage_income = 1.50
		max_uses_before_maintenance = 25
		use_duration_seconds = 1.8
	else:
		machine_type = MachineType.PHOTO_COPIER
		base_usage_income = 3.00
		max_uses_before_maintenance = 15
		use_duration_seconds = 2.4

	# Auto-assign copier_index from names like Printer1/Printer2/Printer3 if not set.
	if machine_type == MachineType.PHOTO_COPIER:
		var digits := ""
		for c in lower_name:
			if c >= "0" and c <= "9":
				digits += c
		if digits != "":
			copier_index = maxi(1, int(digits))

	# Listen for when upgrades are purchased
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	
	# Initial check
	_check_unlock_status()

func get_use_spot_world_pos() -> Vector3:
	var marker := get_node_or_null("UseSpot") as Node3D
	if marker:
		return marker.global_position
	return global_position

func _check_unlock_status() -> void:
	var upgrade_mgr = get_node_or_null("/root/UpgradeManager")
	if upgrade_mgr == null:
		is_unlocked = false
	else:
		if machine_type == MachineType.PHOTO_COPIER:
			# Level 1 unlocks copier 1, level 2 unlocks copier 2, etc.
			var lvl: int = upgrade_mgr.get_level("photo_copier")
			is_unlocked = lvl >= copier_index
		else:
			is_unlocked = upgrade_mgr.has_upgrade("vending_machine")
	
	# Hide or disable processing if not unlocked
	visible = is_unlocked
	process_mode = Node.PROCESS_MODE_INHERIT if is_unlocked else Node.PROCESS_MODE_DISABLED

func _on_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	_check_unlock_status()

func can_be_used() -> bool:
	return is_unlocked and not needs_maintenance

# Called by Customer AI when they interact with the machine
func use_machine() -> bool:
	if not can_be_used():
		return false
		
	# Add money to the store
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.add_money(base_usage_income)
		
	current_uses += 1
	if current_uses >= max_uses_before_maintenance:
		needs_maintenance = true
		_show_maintenance_indicator(true)
		
	return true

# Called by the Player when maintaining the machine
func perform_maintenance() -> void:
	if needs_maintenance:
		current_uses = 0
		needs_maintenance = false
		_show_maintenance_indicator(false)
		print("Machine repaired!")

func _show_maintenance_indicator(_show: bool) -> void:
	# Add visual logic here later (e.g., show a wrench icon above the machine)
	pass
