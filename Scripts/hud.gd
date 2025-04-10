extends Control

@onready var health_bar = $HealthBar
@onready var health_label = $HealthLabel
@onready var weapon_slots = $WeaponSlots
@onready var passive_items = $PassiveItems

var player = null

func _ready():
	# Set up anchors and margins
	anchor_right = 1
	anchor_bottom = 1
	
	# Wait for player to spawn
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Connect signals
		player.connect("health_changed", _on_player_health_changed)
		player.connect("weapon_switched", _on_weapon_switched)
		player.connect("passive_item_added", _on_passive_item_added)
		
		# Update initial display
		_update_health_display(player.health, player.max_health)
		_update_weapon_display()
	else:
		print("ERROR: Player not found for HUD")

func _on_player_health_changed(current, maximum):
	_update_health_display(current, maximum)

func _update_health_display(current, maximum):
	# Update progress bar
	health_bar.max_value = maximum
	health_bar.value = current
	
	# Update label
	health_label.text = str(int(current)) + " / " + str(int(maximum))
	
	# Change color based on health percentage
	var health_percent = current / maximum
	if health_percent < 0.3:
		health_bar.modulate = Color(1, 0, 0) # Red when low
	elif health_percent < 0.6:
		health_bar.modulate = Color(1, 1, 0) # Yellow when medium
	else:
		health_bar.modulate = Color(0, 1, 0) # Green when high

func _on_weapon_switched(index):
	_update_weapon_display()

func _on_passive_item_added(item):
	_update_passive_items()

func _update_weapon_display():
	# Clear previous slots
	for child in weapon_slots.get_children():
		child.queue_free()
	
	if not player or not player.inventory:
		return
	
	var weapons = player.inventory.active_weapons
	var active_index = player.inventory.current_active_slot
	
	# Create weapon slots
	for i in range(weapons.size()):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(60, 60)
		
		if weapons[i]:
			var weapon = weapons[i]
			# Add weapon icon
			var weapon_icon = TextureRect.new()
			weapon_icon.expand = true
			weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			weapon_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			weapon_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			# Add weapon name
			var weapon_name = Label.new()
			weapon_name.text = weapon.item_name
			weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			slot.add_child(weapon_icon)
			slot.add_child(weapon_name)
		else:
			var empty_label = Label.new()
			empty_label.text = "Empty"
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(empty_label)
		
		# Highlight active slot
		if i == active_index:
			slot.add_theme_color_override("panel_bg_color", Color(0.3, 0.7, 0.9, 0.5))
		
		weapon_slots.add_child(slot)

func _update_passive_items():
	# Clear previous items
	for child in passive_items.get_children():
		child.queue_free()
	
	if not player or not player.inventory:
		return
	
	var items = player.inventory.passive_items
	
	# Create passive item icons
	for item in items:
		var icon = TextureRect.new()
		icon.expand = true
		icon.custom_minimum_size = Vector2(40, 40)
		icon.tooltip_text = item.item_name + ": " + item.description
		
		passive_items.add_child(icon)
