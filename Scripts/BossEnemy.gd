extends Enemy
class_name BossEnemy

enum AttackType {SLAM, SWEEP, CHARGE}
enum BossState {NORMAL, CHARGING}

@export var current_phase: int = 1
@export var phase_thresholds: Array = [0.7, 0.4] # At 70% and 40% health, change phase

var attack_patterns = []
var current_attack = 0
var current_state = BossState.NORMAL

# Charge attack variables
var charge_duration = 1.0
var charge_elapsed_time = 0.0
var charge_damage = 40.0
var charge_direction = Vector3.ZERO
var charging = false

func _ready():
	super._ready()
	max_health = 300
	movement_speed = 2.0
	attack_damage = 25
	attack_radius = 3.0
	attack_cooldown = 2.5
	detection_radius = 15.0
	
	# Setup boss visuals - larger model
	if has_node("MeshInstance3D"):
		var mesh_instance = $MeshInstance3D
		var capsule = CapsuleMesh.new()
		capsule.radius = 1.0
		capsule.height = 4.0
		mesh_instance.mesh = capsule
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.0, 0.5) # Purple for boss
		material.emission_enabled = true
		material.emission = Color(0.3, 0.0, 0.3)
		material.emission_energy = 0.8
		mesh_instance.material_override = material
		
	# Create larger collision
	if has_node("CollisionShape3D"):
		var collision = $CollisionShape3D
		var shape = CapsuleShape3D.new()
		shape.radius = 1.0
		shape.height = 4.0
		collision.shape = shape
	
	# Setup attack patterns
	attack_patterns = [
		AttackType.SLAM,
		AttackType.SWEEP,
		AttackType.CHARGE,
		AttackType.SLAM
	]
	
	# Connect health changed signal
	connect("health_changed", _on_health_changed)

func _physics_process(delta):
	# Override default behavior when charging
	if current_state == BossState.CHARGING:
		process_charging(delta)
	else:
		super._physics_process(delta)

func process_charging(delta):
	if not charging:
		return
		
	charge_elapsed_time += delta
	
	# Apply velocity and move
	move_and_slide()
	
	# Check for collision with player
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider.is_in_group("player"):
			# Deal damage to player
			collider.change_health(-charge_damage)
			
			# Knockback player
			var knockback_dir = (collider.global_position - global_position).normalized()
			collider.velocity = knockback_dir * 15.0
			collider.velocity.y = 5.0 # Add upward component
			
			# End charge
			end_charge()
			return
	
	# End charge after duration
	if charge_elapsed_time >= charge_duration:
		end_charge()

func _on_health_changed(current_health, max_health):
	# Check for phase transitions
	var health_percent = current_health / max_health
	
	for i in range(phase_thresholds.size()):
		if health_percent <= phase_thresholds[i] and current_phase == i + 1:
			current_phase += 1
			begin_new_phase(current_phase)

func begin_new_phase(phase: int):
	# Phase transition effect/animation
	var phase_transition = GPUParticles3D.new()
	phase_transition.emitting = true
	phase_transition.one_shot = true
	phase_transition.amount = 100
	phase_transition.explosiveness = 1.0
	add_child(phase_transition)
	
	match phase:
		2:
			# Speed and damage increase
			movement_speed *= 1.3
			attack_damage *= 1.2
			attack_cooldown *= 0.8
			
			# Visual change
			if has_node("MeshInstance3D"):
				var material = $MeshInstance3D.material_override
				material.emission_energy = 1.5
				material.albedo_color = Color(0.7, 0.0, 0.7)
		3:
			# Further increase
			movement_speed *= 1.5
			attack_damage *= 1.5
			attack_cooldown *= 0.7
			
			# Visual change
			if has_node("MeshInstance3D"):
				var material = $MeshInstance3D.material_override
				material.emission_energy = 2.5
				material.albedo_color = Color(0.9, 0.0, 0.9)

func perform_attack():
	if not player:
		return
		
	# Get next attack in pattern
	var attack_type = attack_patterns[current_attack]
	current_attack = (current_attack + 1) % attack_patterns.size()
	
	match attack_type:
		AttackType.SLAM:
			perform_slam_attack()
		AttackType.SWEEP:
			perform_sweep_attack()
		AttackType.CHARGE:
			perform_charge_attack()

func perform_slam_attack():
	# Area of effect slam attack
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("slam")
	
	# Create shockwave effect
	var shockwave = Area3D.new()
	shockwave.name = "Shockwave"
	
	# Add collision
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 0.5
	collision.shape = shape
	shockwave.add_child(collision)
	
	# Add visual
	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 3.0
	mesh.bottom_radius = 3.0
	mesh.height = 0.2
	mesh_instance.mesh = mesh
	
	# Apply material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.2, 0.9, 0.7)
	material.emission_enabled = true
	material.emission = Color(0.7, 0.0, 0.7)
	material.emission_energy = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	
	shockwave.add_child(mesh_instance)
	
	# Add script
	var script = GDScript.new()
	script.source_code = """
	extends Area3D

	var damage = 30.0
	var lifetime = 0.8
	var elapsed_time = 0.0
	
	func _ready():
		# Connect signals
		body_entered.connect(_on_body_entered)
	
	func _physics_process(delta):
		elapsed_time += delta
		
		# Scale up the shockwave
		var scale_factor = 1.0 + elapsed_time * 3.0
		$MeshInstance3D.scale.x = scale_factor
		$MeshInstance3D.scale.z = scale_factor
		$CollisionShape3D.scale.x = scale_factor
		$CollisionShape3D.scale.z = scale_factor
		
		# Fade out
		if has_node("MeshInstance3D"):
			var alpha = 0.7 * (1.0 - elapsed_time / lifetime)
			$MeshInstance3D.material_override.albedo_color.a = alpha
			$MeshInstance3D.material_override.emission_energy = 2.0 * (1.0 - elapsed_time / lifetime)
			
		if elapsed_time >= lifetime:
			queue_free()
	
	func _on_body_entered(body):
		if body.is_in_group("player"):
			if body.has_method("change_health"):
				body.change_health(-damage)
	"""
	
	# Set the script
	shockwave.set_script(script)
	
	# Add to scene
	add_child(shockwave)
	shockwave.position = Vector3(0, 0.1, 0) # Slightly above ground
	
	# Set properties directly
	shockwave.damage = attack_damage * 1.2
	shockwave.lifetime = 0.8

func perform_sweep_attack():
	# Wide 180-degree attack
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("sweep")
	
	# Create sweep area
	var sweep = Area3D.new()
	sweep.name = "SweepAttack"
	
	# Add collision
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(5.0, 2.0, 2.0)
	collision.shape = shape
	sweep.add_child(collision)
	
	# Add script
	var script = GDScript.new()
	script.source_code = """
	extends Area3D

	var damage = 25.0
	var lifetime = 0.4
	var rotation_speed = 8.0  # radians per second
	var total_angle = 3.14159  # 180 degrees
	var start_angle = -total_angle / 2.0
	var elapsed_time = 0.0
	
	func _ready():
		# Start at beginning angle
		rotation.y = start_angle
		
		# Connect body entered signal
		body_entered.connect(_on_body_entered)

	func _physics_process(delta):
		elapsed_time += delta
		
		# Rotate through the sweep angle
		var t = elapsed_time / lifetime
		rotation.y = start_angle + total_angle * t
		
		if elapsed_time >= lifetime:
			queue_free()
	
	func _on_body_entered(body):
		if body.is_in_group("player"):
			if body.has_method("change_health"):
				body.change_health(-damage)
	"""
	
	# Set the script
	sweep.set_script(script)
	
	# Add to scene
	add_child(sweep)
	sweep.position = Vector3(0, 1.0, 1.0) # Position in front of boss
	
	# Set properties directly
	sweep.damage = attack_damage
	sweep.lifetime = 0.4

func perform_charge_attack():
	# Charge toward player
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("charge")
	
	if not player:
		return
		
	# Calculate charge direction
	charge_direction = (player.global_position - global_position).normalized()
	charge_direction.y = 0 # Keep on same Y level
	
	# Set velocity for charge
	velocity = charge_direction * movement_speed * 3.0
	
	# Set up charge state
	charge_elapsed_time = 0.0
	charge_damage = attack_damage * 1.5
	charging = true
	current_state = BossState.CHARGING
	
	# Visual feedback - maybe add a trail
	var trail = CPUParticles3D.new()
	trail.name = "ChargeTrail"
	trail.emitting = true
	trail.amount = 30
	trail.lifetime = 0.5
	trail.local_coords = false
	trail.gravity = Vector3(0, 0, 0)
	add_child(trail)
	
	# Schedule end of charge if nothing stops it
	get_tree().create_timer(charge_duration).timeout.connect(end_charge)

func end_charge():
	if not charging:
		return
	
	charging = false
	velocity = Vector3.ZERO
	current_state = BossState.NORMAL
	
	# Remove trail if it exists
	if has_node("ChargeTrail"):
		$ChargeTrail.queue_free()
		
	print("Boss charge ended")
