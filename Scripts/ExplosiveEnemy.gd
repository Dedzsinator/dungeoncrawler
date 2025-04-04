extends Enemy
class_name ExplosiveEnemy

@export var throw_range: float = 10.0
@export var explosion_radius: float = 3.0
@export var explosion_damage: float = 30.0
@export var projectile_arc_height: float = 3.0
@export var fuse_time: float = 1.5

func _ready():
	super._ready()
	max_health = 70
	movement_speed = 2.2
	attack_damage = 15
	attack_radius = 8.0
	attack_cooldown = 3.0
	detection_radius = 12.0
	
	# Setup visuals for explosive enemy
	if has_node("MeshInstance3D"):
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.8, 0.4, 0) # Orange for explosives
		$MeshInstance3D.material_override = material

func chase_behavior(delta):
	if not player:
		return
		
	# Calculate distance to player
	var distance = global_position.distance_to(player.global_position)
	
	# Try to maintain a medium distance
	if distance < throw_range * 0.5:
		var direction = (global_position - player.global_position).normalized()
		velocity = direction * movement_speed
	elif distance > throw_range * 0.8:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * movement_speed
	else:
		velocity = velocity.lerp(Vector3.ZERO, 0.1)
	
	# Look at player (only Y-axis)
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

func perform_attack():
	if not player:
		return
		
	# Create and throw explosive
	var explosive = Area3D.new()
	explosive.name = "Explosive"
	
	# Add collision
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.3
	collision.shape = shape
	explosive.add_child(collision)
	
	# Add visual
	var mesh_instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	mesh_instance.mesh = mesh
	
	# Apply material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.2, 0)
	mesh_instance.material_override = material
	
	explosive.add_child(mesh_instance)
	
	# Add script with _init function
	var script = GDScript.new()
	script.source_code = """
	extends Area3D

	var start_pos = Vector3.ZERO
	var target_pos = Vector3.ZERO
	var arc_height = 3.0
	var throw_duration = 1.0
	var damage = 30.0
	var blast_radius = 3.0
	var has_exploded = false
	var elapsed_time = 0.0
	
	# For blinking effect
	var blink_interval = 0.2
	var next_blink = 0.0
	
	func _init(p_start_pos, p_target_pos, p_arc_height, p_duration, p_damage, p_radius):
		start_pos = p_start_pos
		target_pos = p_target_pos
		arc_height = p_arc_height
		throw_duration = p_duration
		damage = p_damage
		blast_radius = p_radius

	func _ready():
		# Connect signal to self for early detonation
		body_entered.connect(_on_body_entered)
		
		# Start blink effect
		next_blink = throw_duration * 0.5
		
		# Add light for visual effect
		var light = OmniLight3D.new()
		light.name = "ExplosiveLight"
		light.light_color = Color(1, 0.5, 0)
		light.light_energy = 0.5
		light.omni_range = 3.0
		add_child(light)

	func _physics_process(delta):
		elapsed_time += delta
		
		if elapsed_time >= throw_duration and not has_exploded:
			explode()
		else:
			# Calculate arc trajectory
			var t = elapsed_time / throw_duration
			var pos = start_pos.lerp(target_pos, t)
			pos.y += arc_height * sin(PI * t)
			position = pos
			
			# Blinking effect as it's about to explode
			if elapsed_time >= next_blink:
				next_blink = elapsed_time + blink_interval * (1.0 - t)
				if has_node("MeshInstance3D"):
					var mesh = get_node("MeshInstance3D")
					if mesh.visible:
						mesh.visible = false
					else:
						mesh.visible = true
				
				# Increase light intensity
				if has_node("ExplosiveLight"):
					var light = get_node("ExplosiveLight")
					light.light_energy = 0.5 + t * 2.0

	func _on_body_entered(body):
		if not has_exploded and elapsed_time > 0.2:  # Small delay to prevent immediate explosion
			explode()

	func explode():
		has_exploded = true
		
		# Create explosion effect
		var explosion = GPUParticles3D.new()
		explosion.emitting = true
		explosion.one_shot = true
		explosion.explosiveness = 0.9
		explosion.amount = 50
		explosion.lifetime = 0.8
		
		# Add to scene
		get_parent().add_child(explosion)
		explosion.global_position = global_position
		
		# Explosion light
		var light = OmniLight3D.new()
		light.light_color = Color(1, 0.7, 0.2)
		light.light_energy = 8.0
		light.omni_range = blast_radius * 2
		explosion.add_child(light)
		
		# Fade out light
		var tween = create_tween()
		tween.tween_property(light, "light_energy", 0, 0.5)
		
		# Damage everything in radius
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		var shape = SphereShape3D.new()
		shape.radius = blast_radius
		query.shape = shape
		query.transform = global_transform
		
		var results = space_state.intersect_shape(query)
		for result in results:
			var collider = result["collider"]
			if collider.has_method("take_damage"):
				# Scale damage by distance
				var distance = global_position.distance_to(collider.global_position)
				var damage_scale = 1.0 - min(distance / blast_radius, 1.0)
				collider.take_damage(damage * damage_scale)
			elif collider.is_in_group("player"):
				# Direct damage to player
				var distance = global_position.distance_to(collider.global_position)
				var damage_scale = 1.0 - min(distance / blast_radius, 1.0)
				collider.change_health(-damage * damage_scale)
		
		# Remove original explosive
		queue_free()
		
		# Remove explosion after effect finishes
		await get_tree().create_timer(1.5).timeout
		explosion.queue_free()
	"""
	
	# Set the script first
	explosive.set_script(script)

	# Add to scene
	get_tree().root.add_child(explosive)

	# Set properties directly instead of using _init()
	explosive.start_pos = global_position + Vector3(0, 1.0, 0)
	explosive.target_pos = player.global_position
	explosive.arc_height = projectile_arc_height
	explosive.throw_duration = fuse_time
	explosive.damage = explosion_damage
	explosive.blast_radius = explosion_radius
	
	# Play animation if possible
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("throw")
