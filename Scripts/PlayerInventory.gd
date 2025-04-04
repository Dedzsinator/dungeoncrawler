extends Node

class_name PlayerInventory

# Signals
signal item_added(item)
signal item_removed(item)
signal active_weapon_changed(index)
signal active_weapon_used(weapon)

# Active weapon slots
@export var active_slots = 2
var active_weapons = []
var current_active_slot = 0

# Passive items
var passive_items = []

func _ready():
	# Initialize empty weapon slots
	for i in range(active_slots):
		active_weapons.append(null)

func handle_input_action(action: String):
	if action == "switch_weapon":
		cycle_active_weapon()
	elif action == "use_weapon":
		use_active_weapon()

func cycle_active_weapon():
	current_active_slot = (current_active_slot + 1) % active_slots
	emit_signal("active_weapon_changed", current_active_slot)
	
	# Debug output
	print("Switched to weapon slot " + str(current_active_slot + 1))
	if active_weapons[current_active_slot] != null:
		print("Current weapon: " + active_weapons[current_active_slot].item_name)
	else:
		print("Current slot empty")

func use_active_weapon():
	var weapon = active_weapons[current_active_slot]
	if weapon != null:
		await weapon.use()  # Add await here
		emit_signal("active_weapon_used", weapon)
		print("Used weapon: " + weapon.item_name)
	else:
		print("No weapon in active slot")

func add_weapon(weapon, slot = -1):
	if slot >= 0 and slot < active_slots:
		# Put in specific slot
		active_weapons[slot] = weapon
		emit_signal("item_added", weapon)
		return true
	else:
		# Find first empty slot
		for i in range(active_slots):
			if active_weapons[i] == null:
				active_weapons[i] = weapon
				emit_signal("item_added", weapon)
				return true
	
	# No empty slots
	return false

func add_passive_item(item):
	passive_items.append(item)
	emit_signal("item_added", item)
	
	# Apply passive effect if applicable
	if item.has_method("apply_effect"):
		var player = get_tree().get_first_node_in_group("player")
		if player:
			item.apply_effect(player)
	
	return true

func remove_weapon(slot):
	if slot >= 0 and slot < active_slots and active_weapons[slot] != null:
		var weapon = active_weapons[slot]
		active_weapons[slot] = null
		emit_signal("item_removed", weapon)
		return weapon
	return null

func remove_passive_item(item_name):
	for i in range(passive_items.size()):
		if passive_items[i].item_name == item_name:
			var item = passive_items[i]
			passive_items.remove_at(i)
			
			# Remove effect if applicable
			if item.has_method("remove_effect"):
				var player = get_tree().get_first_node_in_group("player")
				if player:
					item.remove_effect(player)
					
			emit_signal("item_removed", item)
			return item
	return null

func get_active_weapon():
	return active_weapons[current_active_slot]

func has_passive_item(item_name):
	for item in passive_items:
		if item.item_name == item_name:
			return true
	return false
