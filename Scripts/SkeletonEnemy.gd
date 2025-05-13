extends Enemy
class_name SkeletonEnemy

func _ready():
	super._ready()
	max_health = randi_range(30, 50)
	health = max_health
	movement_speed = 2.5
	attack_damage = 2 # 2 half-hearts = 1 full heart of damage
	attack_radius = 1.5
	detection_radius = 10.0
	
	# Load and set the skeleton model
	var skeleton_model = preload("res://Assets/Skeleton.fbx").instantiate()
	skeleton_model.name = "SkeletonModel"
	add_child(skeleton_model)
	
	# Apply texture to the skeleton model - look for the mesh inside the imported model
	for child in skeleton_model.get_children():
		if child is MeshInstance3D:
			var material = StandardMaterial3D.new()
			material.albedo_texture = preload("res://Assets/textures/LPolyPallete.png")
			child.material_override = material
		
		# Look for nested mesh instances (common in imported models)
		for subchild in child.get_children():
			if subchild is MeshInstance3D:
				var material = StandardMaterial3D.new()
				material.albedo_texture = preload("res://Assets/textures/LPolyPallete.png")
				subchild.material_override = material
	
	# Set up proper collision
	var collision_shape = get_node_or_null("CollisionShape3D")
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)
	
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	collision_shape.shape = shape
	collision_shape.position.y = 0.9 # Center the collision shape with the model
	
	# Add to enemy group for targeting
	add_to_group("enemy")

func perform_attack():
	# Skeleton performs a lunging attack
	if player and global_position.distance_to(player.global_position) <= attack_radius:
		# Lunge toward player
		var lunge_dir = (player.global_position - global_position).normalized()
		velocity = lunge_dir * movement_speed * 1.5
		
		# Deal damage only if player can take damage (not in invincibility frames)
		if player.can_take_damage:
			player.change_health(-attack_damage)
		
		# Visual feedback - animate skeleton if possible
		if has_node("SkeletonModel"):
			# Simple animation: tilt forward slightly
			var tween = create_tween()
			tween.tween_property($SkeletonModel, "rotation_degrees:x", 30.0, 0.2)
			tween.tween_property($SkeletonModel, "rotation_degrees:x", 0.0, 0.2)

# Override to add death animation
func die():
	state = "dead"
	
	# Death animation
	if has_node("SkeletonModel"):
		var death_tween = create_tween()
		death_tween.tween_property($SkeletonModel, "rotation_degrees:z", 90, 0.5)
		death_tween.tween_property(self, "position:y", -0.5, 0.5)
	
	# Wait for animation then remove
	await get_tree().create_timer(1.0).timeout
	
	# Emit signal before removal
	emit_signal("enemy_died", self)
	
	# Remove from scene
	queue_free()
