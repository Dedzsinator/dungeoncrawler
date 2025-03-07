extends Control

@onready var health_container = $HealthContainer
@onready var inventory_container = $InventoryContainer
@onready var active_slots = $ActiveWeapons

var full_heart = preload("res://Assets/UI/full_heart.png")  # Create these textures
var half_heart = preload("res://Assets/UI/half_heart.png")
var empty_heart = preload("res://Assets/UI/empty_heart.png")

var heart_textures = []

func _ready():
    var player = get_tree().get_first_node_in_group("player")  # Add your player to a group
    if player:
        player.connect("health_changed", _on_player_health_changed)
    
    # Create heart containers
    var max_hearts = player.max_health / 2  # Each heart is 2 health points
    for i in range(max_hearts):
        var heart = TextureRect.new()
        heart.texture = full_heart
        health_container.add_child(heart)
        heart_textures.append(heart)
    
    update_hearts(player.health, player.max_health)

func _on_player_health_changed(current_health, max_health):
    update_hearts(current_health, max_health)

func update_hearts(current_health, max_health):
    var full_hearts = floor(current_health / 2)
    var half_heart_visible = (current_health % 2) == 1
    var max_hearts = ceil(max_health / 2)
    
    for i in range(max_hearts):
        if i < full_hearts:
            heart_textures[i].texture = full_heart
        elif i == full_hearts and half_heart_visible:
            heart_textures[i].texture = half_heart
        else:
            heart_textures[i].texture = empty_heart

func update_active_weapons(weapons, active_index):
    # Clear existing slots
    for child in active_slots.get_children():
        child.queue_free()
    
    # Create new slots
    for i in range(weapons.size()):
        var slot = Panel.new()
        var label = Label.new()
        label.text = weapons[i].name if weapons[i] else "Empty"
        
        if i == active_index:
            slot.add_theme_stylebox_override("panel", preload("res://Assets/UI/active_slot_style.tres"))
        else:
            slot.add_theme_stylebox_override("panel", preload("res://Assets/UI/slot_style.tres"))
            
        slot.add_child(label)
        active_slots.add_child(slot)

func update_inventory(items):
    # Clear existing items
    for child in inventory_container.get_children():
        child.queue_free()
    
    # Create new item slots
    for item in items:
        var slot = Panel.new()
        var label = Label.new()
        label.text = item.name
        slot.add_child(label)
        inventory_container.add_child(slot)