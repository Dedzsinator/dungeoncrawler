extends Weapon

@export var swing_angle: float = 90.0
@export var knockback_force: float = 5.0

var swing_mesh: MeshInstance3D
var swing_particles: GPUParticles3D

func _ready():
	# Set model and texture paths
	model_path = "res://Assets/Items/Longsword.fbx"
	texture_path = "res://Assets/textures/Longsword_basecolor.png"
	
	# Call parent ready which will load the model
	super._ready()
	
	# Set weapon properties
	item_name = "Sword"
	description = "A basic sword that deals damage in a wide arc"
	damage = 15.0
	cooldown = 0.8
	range = 2.0
	
	# Create swing effect mesh if model wasn't loaded
	if not model_instance:
		swing_mesh = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.1, 0.5, 1.5)
		swing_mesh.mesh = mesh
		
		# Apply material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.7, 0.7, 0.8)
		material.metallic = 0.8
		material.roughness = 0.2
		swing_mesh.material_override = material
		add_child(swing_mesh)
	else:
		# Scale and position the model properly
		model_instance.scale = Vector3(0.01, 0.01, 0.01) # Adjust scale as needed
		model_instance.rotation_degrees = Vector3(-90, 0, 0) # Adjust rotation as needed
	
	add_child(swing_mesh)
	
	# Create swing particles
	swing_particles = GPUParticles3D.new()
	swing_particles.name = "SwingParticles"
	swing_particles.emitting = false
	swing_particles.one_shot = true
	swing_particles.explosiveness = 0.8
	swing_particles.lifetime = 0.5
	swing_particles.amount = 20
	swing_particles.process_material = create_swing_particle_material()
	swing_particles.draw_pass_1 = create_swing_particle_mesh()
	swing_particles.position = Vector3(0, 0, -0.8) # Position at the tip of the sword
	add_child(swing_particles)

func create_swing_particle_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, -1)
	material.spread = 50.0
	material.gravity = Vector3(0, -1, 0)
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(0.9, 0.9, 1.0, 0.7)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.2
	return material
	
func create_swing_particle_mesh() -> Mesh:
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	return mesh

func _weapon_effect():
	# Get player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Play swing animation
	var tween = create_tween()
	tween.tween_property(swing_mesh, "rotation_degrees:y", swing_angle / 2, 0.2)
	tween.tween_property(swing_mesh, "rotation_degrees:y", -swing_angle / 2, 0.2)
	tween.tween_property(swing_mesh, "rotation_degrees:y", 0, 0.1)
	
	# Emit particles
	swing_particles.restart()
	swing_particles.emitting = true
	
	# Create damage area
	var attack_area = Area3D.new()
	attack_area.name = "SwordSwing"
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 1.0, 2.0)
	collision.shape = shape
	attack_area.add_child(collision)
	
	# Get seasonal modifiers from current room
	var damage_modifier = 1.0
	var knockback_modifier = 1.0
	
	if player.has_method("get_current_room") and player.get_current_room() != null:
		var current_room = player.get_current_room()
		if current_room.has_meta("damage_modifier"):
			damage_modifier = current_room.get_meta("damage_modifier")
		if current_room.has_meta("knockback_modifier"):
			knockback_modifier = current_room.get_meta("knockback_modifier")
	
	# Apply modifiers
	var modified_damage = damage * damage_modifier
	var modified_knockback = knockback_force * knockback_modifier
	
	# Create script for damage with values directly in the source
	var script_text = """
	extends Area3D
	
	var damage_amount = %.1f
	var knockback_amount = %.1f
	var already_hit = []
	
	func _ready():
		# Connect signal
		body_entered.connect(_on_body_entered)
		
		# Remove after short duration
		await get_tree().create_timer(0.3).timeout
		queue_free()
	
	func _on_body_entered(body):
		# Don't hit same enemy twice
		if already_hit.has(body):
			return
			
		if body.is_in_group("enemies"):
			body.take_damage(damage_amount)
			already_hit.append(body)
			
			# Apply knockback
			var knockback_dir = (body.global_position - get_parent().global_position).normalized()
			body.velocity = knockback_dir * knockback_amount
	"""
	
	# Format the script with the actual values
	script_text = script_text % [modified_damage, modified_knockback]
	
	var script = GDScript.new()
	script.source_code = script_text
	
	# Set the script
	attack_area.set_script(script)
	
	# Add to scene in front of player
	player.add_child(attack_area)
	attack_area.position = Vector3(0, 0, -1.5)
