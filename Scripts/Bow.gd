extends Weapon

@export var projectile_speed: float = 15.0
@export var max_ammo: int = 10
@export var reload_time: float = 2.0

var current_ammo: int
var is_reloading: bool = false

func _ready():
	# Set model and texture paths
	model_path = "res://Assets/Items/Bow_And_Arrow.fbx"
	texture_path = "res://Assets/textures/Bow_basecolor.png"
	
	# Call parent ready which will load the model
	super._ready()
	
	# Set weapon properties
	item_name = "Bow"
	description = "Fires arrows at enemies from a distance"
	damage = 12.0
	cooldown = 1.0
	range = 20.0
	
	# Initialize ammo
	current_ammo = max_ammo
	
	# Create weapon mesh if model loading fails
	var weapon_mesh: MeshInstance3D
	
	if not model_instance:
		# Fallback mesh if model loading fails
		weapon_mesh = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.05
		mesh.bottom_radius = 0.05
		mesh.height = 1.2
		weapon_mesh.mesh = mesh
		
		# Rotate to align with bow orientation
		weapon_mesh.rotation_degrees.x = 90
		
		# Apply material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.4, 0.2, 0.1)
		weapon_mesh.material_override = material
		
		# Add the mesh to the scene
		add_child(weapon_mesh)
	else:
		# Scale and position the model properly
		model_instance.scale = Vector3(0.01, 0.01, 0.01) # Adjust scale as needed
		model_instance.rotation_degrees = Vector3(0, 0, 0) # Adjust rotation as needed

func use():
	if is_reloading:
		print("Reloading...")
		return false
		
	if current_ammo <= 0:
		start_reload()
		return false
		
	return super.use()

func _weapon_effect():
	# Decrement ammo
	current_ammo -= 1
	
	# Get player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Create arrow
	var arrow = Area3D.new()
	arrow.name = "Arrow"
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.1, 0.1, 0.8)
	collision.shape = shape
	arrow.add_child(collision)
	
	# Add visual
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.8)
	mesh_instance.mesh = mesh
	
	# Apply material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.3)
	mesh_instance.material_override = material
	
	arrow.add_child(mesh_instance)
	
	# Modify the script to accept parameters in _init
	var script = GDScript.new()
	script.source_code = """
	extends Area3D

	var speed = 15.0
	var damage = 12.0
	var lifetime = 5.0
	var elapsed_time = 0.0
	var direction = Vector3.FORWARD

	func _ready():
		# Connect signal
		body_entered.connect(_on_body_entered)
		
	func _physics_process(delta):
		elapsed_time += delta
		
		# Move forward
		position += direction * speed * delta
		
		# Look in the direction of movement
		if direction.length() > 0.1:
			look_at(position + direction, Vector3.UP)
		
		# Self-destruct after lifetime
		if elapsed_time > lifetime:
			queue_free()
	
	func _on_body_entered(body):
		# Check if body is an Enemy using is_in_group instead of 'is' operator
		if body.is_in_group("enemies"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			queue_free()
		elif not body.is_in_group("player"):
			# Hit something else
			queue_free()
	"""
	
	# Get the direction the player is facing
	var direction = - player.global_transform.basis.z.normalized()

	# First set the script with initial parameters
	var script_instance = GDScript.new()
	script_instance.source_code = script.source_code
	arrow.set_script(script_instance)

	# Add to scene and position properly
	get_tree().root.add_child(arrow)
	arrow.global_position = player.global_position + Vector3(0, 1.5, 0)
	arrow.global_position += direction * 0.5 # Offset to avoid hitting player

	# Set properties directly instead of using _init()
	arrow.speed = projectile_speed
	arrow.damage = damage
	arrow.direction = direction
	
	# Check if we need to reload
	if current_ammo <= 0:
		start_reload()

func start_reload():
	is_reloading = true
	print("Reloading...")
	
	# Wait for reload time
	await get_tree().create_timer(reload_time).timeout
	
	current_ammo = max_ammo
	is_reloading = false
	print("Reloaded!")
