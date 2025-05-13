extends Node3D

class_name Weapon

@export var item_name: String = "Weapon"
@export var description: String = "Base weapon"
@export var damage: float = 10.0
@export var cooldown: float = 1.0
@export var range: float = 5.0
@export var icon: Texture
@export var model_path: String = ""
@export var texture_path: String = ""

var can_use: bool = true
var owner_node = null
var model_instance: Node3D = null

signal weapon_used(weapon)

func _ready():
	# Load icon if not provided
	if not icon:
		# Create default icon
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 0))
		icon = ImageTexture.create_from_image(img)
	
	# Load model if path provided
	if model_path != "":
		_load_model()
		
func _load_model():
	# Try to load the model
	var model_resource = load(model_path)
	if model_resource:
		model_instance = model_resource.instantiate()
		add_child(model_instance)
		
		# Apply texture if specified
		if texture_path != "" and model_instance:
			_apply_texture_to_model()
	else:
		push_error("Failed to load model: " + model_path)

func _apply_texture_to_model():
	var texture = load(texture_path)
	if not texture:
		push_error("Failed to load texture: " + texture_path)
		return
		
	# Apply texture to all mesh instances in the model
	for child in model_instance.get_children():
		if child is MeshInstance3D:
			var material = StandardMaterial3D.new()
			material.albedo_texture = texture
			child.material_override = material

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
