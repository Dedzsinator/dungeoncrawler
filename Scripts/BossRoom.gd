extends Node

class_name BossRoom

# Boss parameters
var hp_multiplier := 5.0
var size_multiplier := 1.5
var damage_multiplier := 1.5

# Reference to the room node
var room_node: Node3D
var boss_enemy: Node3D
var is_boss_defeated := false

# Next floor marker
var next_floor_marker: Node3D

func _init(room: Node3D):
	room_node = room
	room_node.set_meta("is_boss_room", true)

# Setup the boss room
func setup():
	if not room_node:
		push_error("BossRoom: No room node assigned")
		return
	
	# Add boss room visual indicators
	add_visual_indicators()
	
	# Spawn boss enemy
	spawn_boss_enemy()
	
	# Connect to boss defeated signal
	if boss_enemy:
		boss_enemy.connect("tree_exited", _on_boss_defeated)
		
	print("Boss room setup complete")

# Add visual indicators to show this is a boss room
func add_visual_indicators():
	# Create a special light effect for the boss room
	var ambient_light = OmniLight3D.new()
	ambient_light.name = "BossRoomLight"
	ambient_light.light_color = Color(0.9, 0.3, 0.3)
	ambient_light.light_energy = 1.5
	ambient_light.omni_range = 20.0
	
	# Position the light in the center of the room
	var room_size = Vector3(10, 5, 10) # Assume room is roughly this size
	ambient_light.position = Vector3(0, room_size.y / 2, 0)
	
	room_node.add_child(ambient_light)
	
	# Add pulsing animation to the light
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(ambient_light, "light_energy", 2.5, 1.5)
	tween.tween_property(ambient_light, "light_energy", 1.5, 1.5)
	
	# Add particle effect for boss room atmosphere
	var particles = GPUParticles3D.new()
	particles.name = "BossRoomParticles"
	particles.amount = 100
	particles.lifetime = 5.0
	particles.randomness = 0.7
	particles.emitting = true
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(5, 3, 5)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, -0.1, 0)
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.0
	mat.color = Color(0.7, 0.2, 0.2, 0.5)
	particles.process_material = mat
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh
	
	room_node.add_child(particles)

# Spawn a single powerful boss enemy
func spawn_boss_enemy():
	# Get the enemy scene - fallback to regular enemy if boss scene doesn't exist
	var enemy_resource = load("res://Scenes/BossEnemy.tscn")
	if not enemy_resource:
		print("BossRoom: BossEnemy.tscn not found, using Enemy script instead")
		# Create an enemy instance from script
		var EnemyClass = load("res://Scripts/Enemy.gd")
		if not EnemyClass:
			push_error("BossRoom: Failed to load enemy script")
			return
		
		boss_enemy = EnemyClass.new()
	else:
		# Instance a single enemy
		boss_enemy = enemy_resource.instantiate()
	
	# Enhance enemy stats to make it a boss
	boss_enemy.set_meta("is_boss", true)
	
	# Position at the center of the room
	boss_enemy.position = Vector3(0, 0, 0)
	
	# Scale up the boss size
	boss_enemy.scale = Vector3(size_multiplier, size_multiplier, size_multiplier)
	
	# Make sure the boss has initialized health and other properties
	if boss_enemy.has_method("_ready"):
		boss_enemy._ready()
	
	# Safely increase the boss HP
	if "max_health" in boss_enemy and "health" in boss_enemy:
		boss_enemy.max_health = int(boss_enemy.max_health * hp_multiplier)
		boss_enemy.health = boss_enemy.max_health
	
	# Safely increase the boss damage
	if "attack_damage" in boss_enemy:
		boss_enemy.attack_damage = int(boss_enemy.attack_damage * damage_multiplier)
	
	# Give the boss a distinct appearance
	if boss_enemy.has_node("MeshInstance3D"):
		var mesh_instance = boss_enemy.get_node("MeshInstance3D")
		var material = null
		
		# Check if we need to get surface material or material override
		if mesh_instance.get_surface_override_material_count() > 0:
			material = mesh_instance.get_surface_override_material(0)
		elif mesh_instance.material_override:
			material = mesh_instance.material_override
		
		# If we have a material, update its properties
		if material:
			material.albedo_color = Color(0.8, 0.2, 0.2) # Red color for boss
			material.emission_enabled = true
			material.emission = Color(0.5, 0.1, 0.1)
			material.emission_energy_multiplier = 1.5
	
	# Add the boss to the room
	room_node.add_child(boss_enemy)
	print("Boss enemy spawned")

# Called when the boss is defeated
func _on_boss_defeated():
	print("Boss defeated!")
	is_boss_defeated = true
	
	# Give player a temporary bonus for defeating the boss
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Apply a damage and speed bonus to the player
		player.set_meta("boss_defeat_bonus", true)
		
		# Display message to player about their victory
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_message"):
			hud.show_message("Boss defeated! You feel stronger now!")
	
	# Spawn next floor marker
	spawn_next_floor_marker()
	
	# Play victory effects
	play_victory_effects()

# Spawn the marker to proceed to the next floor
func spawn_next_floor_marker():
	# Create the next floor marker
	next_floor_marker = Node3D.new()
	next_floor_marker.name = "NextFloorMarker"
	
	# Add visual representation
	var marker_mesh = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.1
	marker_mesh.mesh = mesh
	
	# Create glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.8, 0.1) # Green color
	material.emission_enabled = true
	material.emission = Color(0.1, 0.8, 0.1)
	material.emission_energy_multiplier = 2.0
	marker_mesh.material_override = material
	
	# Add particles for the marker
	var particles = GPUParticles3D.new()
	particles.amount = 30
	particles.lifetime = 2.0
	particles.emitting = true
	
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 45.0
	particle_mat.gravity = Vector3(0, 0.5, 0)
	particle_mat.initial_velocity_min = 0.5
	particle_mat.initial_velocity_max = 1.0
	particle_mat.color = Color(0.3, 0.9, 0.3, 0.7)
	particles.process_material = particle_mat
	
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.03
	particle_mesh.height = 0.06
	particles.draw_pass_1 = particle_mesh
	
	# Add light to make marker more visible
	var light = OmniLight3D.new()
	light.light_color = Color(0.1, 0.9, 0.1)
	light.light_energy = 1.0
	light.omni_range = 3.0
	
	# Add an area to detect player interaction
	var area = Area3D.new()
	area.name = "InteractionArea"
	
	var collision_shape = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 1.5
	collision_shape.shape = shape
	area.add_child(collision_shape)
	
	# Set up interaction script
	var script = GDScript.new()
	script.source_code = """
	extends Area3D
	
	signal next_floor_activated
	
	func _ready():
		body_entered.connect(_on_body_entered)
		
	func _on_body_entered(body):
		if body.is_in_group("player"):
			# Player entered, emit signal to proceed to next floor
			print("Player activated next floor marker!")
			emit_signal("next_floor_activated")
	"""
	area.set_script(script)
	
	# Connect the signal to the next floor function
	area.connect("next_floor_activated", _on_next_floor_activated)
	
	# Assemble the marker
	next_floor_marker.add_child(marker_mesh)
	next_floor_marker.add_child(particles)
	next_floor_marker.add_child(light)
	next_floor_marker.add_child(area)
	
	# Position the marker in the center of the room
	next_floor_marker.position = Vector3(0, 0.05, 0) # Slightly above floor
	
	# Add floating animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(next_floor_marker, "position:y", 0.3, 1.5)
	tween.tween_property(next_floor_marker, "position:y", 0.05, 1.5)
	
	# Add rotating animation
	var rotate_script = GDScript.new()
	rotate_script.source_code = """
	extends Node3D
	
	func _process(delta):
		rotate_y(delta * 1.0)  # Rotate at 1 radian per second
	"""
	next_floor_marker.set_script(rotate_script)
	
	# Add marker to the room
	room_node.add_child(next_floor_marker)
	print("Next floor marker spawned")

# Play victory effects when boss is defeated
func play_victory_effects():
	# Create victory particles
	var particles = GPUParticles3D.new()
	particles.name = "VictoryParticles"
	particles.amount = 100
	particles.lifetime = 3.0
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.emitting = true
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, -1.0, 0)
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	
	# Create colorful particle effect
	var gradient = Gradient.new()
	gradient.colors = [
		Color(1, 0.8, 0.2, 1.0), # Gold
		Color(0.2, 0.8, 1.0, 1.0), # Blue
		Color(0.8, 0.2, 1.0, 1.0) # Purple
	]
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp
	
	particles.process_material = mat
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh
	
	# Position at the boss's last position
	particles.position = boss_enemy.position
	
	# Add to room
	room_node.add_child(particles)
	
	# Add victory sound
	var audio = AudioStreamPlayer3D.new()
	audio.name = "VictorySound"
	# Here you would normally set the stream to an audio file
	# audio.stream = load("res://Sounds/victory.wav")
	audio.unit_size = 20.0 # Make sound audible from far away
	audio.autoplay = true
	room_node.add_child(audio)
	
	# Auto-remove particles after they're done
	await get_tree().create_timer(4.0).timeout
	if particles.is_instance_valid():
		particles.queue_free()

# Called when player activates the next floor marker
func _on_next_floor_activated():
	# Here you would implement the logic to proceed to the next floor
	# For example:
	# get_tree().call_group("dungeon_generator", "generate_next_floor")
	print("Proceeding to next floor!")
	
	# This is a placeholder - you would call your dungeon generation system here
	var dungeon_generator = get_tree().get_first_node_in_group("dungeon_generator")
	if dungeon_generator and dungeon_generator.has_method("generate_next_floor"):
		dungeon_generator.generate_next_floor()
	else:
		# Try to use the room_manager's floor progression
		var room_manager = get_tree().get_first_node_in_group("room_manager")
		if room_manager:
			room_manager.start_new_floor()
			# Tell main game controller to regenerate the dungeon
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("regenerate_dungeon"):
				main.regenerate_dungeon()
		else:
			print("No dungeon generator found or it doesn't have generate_next_floor() method")
