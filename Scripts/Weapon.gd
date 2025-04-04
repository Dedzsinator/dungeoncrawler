extends Node3D

class_name Weapon

@export var item_name: String = "Weapon"
@export var description: String = "Base weapon"
@export var damage: float = 10.0
@export var cooldown: float = 1.0
@export var range: float = 5.0
@export var icon: Texture

var can_use: bool = true
var owner_node = null

signal weapon_used(weapon)

func _ready():
    if not icon:
        # Create default icon
        var img = Image.new()
        img.create(64, 64, false, Image.FORMAT_RGBA8)
        img.fill(Color(1, 0, 0))
        icon = ImageTexture.create_from_image(img)

func use():
    if not can_use:
        return false
    
    can_use = false
    
    # Actual weapon effect implemented in subclasses
    _weapon_effect()
    
    emit_signal("weapon_used", self)
    
    # Start cooldown without await
    var timer = get_tree().create_timer(cooldown)
    timer.timeout.connect(func(): can_use = true)
    
    return true

# Override in subclasses
func _weapon_effect():
    print("Base weapon effect")

func get_display_info() -> Dictionary:
    return {
        "name": item_name,
        "description": description,
        "damage": damage,
        "cooldown": cooldown,
        "icon": icon
    }