extends CharacterBody3D
class_name Enemy

# Base enemy properties
@export var max_health: int = 40
@export var movement_speed: float = 2.0
@export var attack_damage: int = 1 # Damage in half-hearts (1 = half heart, 2 = full heart)
@export var attack_cooldown: float = 1.5
@export var detection_radius: float = 10.0
@export var attack_radius: float = 1.5
@export var knockback_force: float = 5.0
@export var knockback_duration: float = 0.3

# Current state
var health: int
var can_attack: bool = true
var player: CharacterBody3D = null
var state: String = "idle"
var nav_agent: NavigationAgent3D
var is_being_knocked_back: bool = false
var knockback_timer: float = 0.0
var knockback_direction: Vector3 = Vector3.ZERO

# Room and season tracking
var current_room = null
var movement_modifier: float = 1.0
var damage_modifier: float = 1.0
var knockback_modifier: float = 1.0

# Visual feedback
@onready var model: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var hit_particles = $HitParticles if has_node("HitParticles") else null

signal enemy_died(enemy)

func _ready():
	# Initialize variables - randomize health between 30-50
	max_health = randi_range(30, 50)
	health = max_health
	
	# Add enemy to group for easier reference
	add_to_group("enemies")
	
	# Get current room - check parent nodes
	var parent = get_parent()
	while parent and not parent.has_node("RoomDetector"):
		parent = parent.get_parent()
		
	if parent and parent.has_node("RoomDetector"):
		current_room = parent
		# Apply seasonal effects
		_on_enter_room(current_room)
	
	# Setup navigation
	nav_agent = NavigationAgent3D.new()
	add_child(nav_agent)
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 1.5
	
	# Setup collision
	if not has_node("CollisionShape3D"):
		var collision = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 2.0
		collision.shape = shape
		add_child(collision)
	
	# Create placeholder mesh if not present
	if not has_node("MeshInstance3D"):
		var mesh_instance = MeshInstance3D.new()
		var mesh = CapsuleMesh.new()
		mesh.radius = 0.5
		mesh.height = 2.0
		mesh_instance.mesh = mesh
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
		
		# Apply material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.8, 0.2, 0.2)
		mesh_instance.material_override = material
	  # Setup enhanced hit effect
	if not has_node("HitParticles"):
		var particles = GPUParticles3D.new()
		particles.name = "HitParticles"
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.amount = 15
		particles.lifetime = 0.6
		
		# Set up particle material
		var mat = ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 60.0
		mat.gravity = Vector3(0, -9.8, 0)
		mat.initial_velocity_min = 2.0
		mat.initial_velocity_max = 5.0
		mat.scale_min = 0.1
		mat.scale_max = 0.3
		mat.color = Color(0.9, 0.1, 0.1, 0.8)
		particles.process_material = mat
		
		# Create mesh for particles
		var mesh = SphereMesh.new()
		mesh.radius = 0.05
		mesh.height = 0.1
		particles.draw_pass_1 = mesh
		
		add_child(particles)
	
	# Start behavior tick - make sure we're in tree first
	call_deferred("setup_timers_and_player")

# Setup timers and find player after being added to scene tree
func setup_timers_and_player():
	# Wait until we're properly in the scene tree
	await get_tree().process_frame
	
	# Connect to room entered signals - safely
	if is_inside_tree():
		var tree = get_tree()
		if tree:
			tree.call_group("rooms", "connect", "player_entered", _on_room_player_entered)
	
	# First attempt to find player
	find_player()
	
	# Now set up the timer
	await get_tree().create_timer(0.2).timeout
	var update_timer = Timer.new()
	update_timer.wait_time = 0.1
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	update_timer.start()

# Helper method to find player with error handling
func find_player():
	# Make sure we have a valid tree reference
	if not is_inside_tree():
		print("Enemy not in tree yet, can't find player")
		return
		
	var tree = get_tree()
	if not tree:
		print("Enemy couldn't get scene tree")
		return
		
	player = tree.get_first_node_in_group("player")
	
	if player == null:
		# Schedule a retry after a short delay
		print("Enemy couldn't find player, will retry in 0.5 seconds")
		var retry_timer = Timer.new()
		retry_timer.wait_time = 0.5
		retry_timer.one_shot = true
		retry_timer.timeout.connect(func():
			player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
			if player == null:
				print("Enemy still couldn't find player after retry")
			retry_timer.queue_free()
		)
		add_child(retry_timer)
		retry_timer.start()

func _physics_process(delta):
	# Handle being knocked back
	if is_being_knocked_back:
		knockback_timer -= delta
		if knockback_timer <= 0:
			is_being_knocked_back = false
		else:
			# Apply knockback velocity
			velocity = knockback_direction * knockback_force
			move_and_slide()
			return
	
	# Regular state handling if not knocked back
	match state:
		"idle":
			# Just stand there
			pass
		"patrol":
			# Move around randomly
			patrol_behavior(delta)
		"chase":
			# Chase the player
			chase_behavior(delta)
		"attack":
			# Attack the player
			attack_behavior(delta)
		"stunned":
			# Cannot move or attack
			pass
		"dead":
			# Dead, do nothing
			return

	# Apply velocity
	move_and_slide()
	
func _on_update_timer_timeout():
	if state == "dead":
		return
		
	# Try to find player if not already found
	if player == null:
		find_player()
	
	# Only update state if player is found
	if player:
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= attack_radius:
			state = "attack"
		elif distance <= detection_radius:
			state = "chase"
		else:
			state = "patrol"
	else:
		state = "idle"

func patrol_behavior(_delta):
	# Simple random movement
	if randf() < 0.01: # Occasionally change direction
		var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		# Apply seasonal movement modifier
		velocity = random_dir * movement_speed * 0.5 * movement_modifier
	else:
		# Slow down gradually
		velocity = velocity.lerp(Vector3.ZERO, 0.1)

func chase_behavior(delta):
	# Make sure we have both player and navigation agent
	if not player or not is_instance_valid(player):
		find_player()
		return
		
	if nav_agent.is_navigation_finished():
		return
	
	# Set target destination
	nav_agent.set_target_position(player.global_position)
	
	# Follow navigation path
	var next_pos = nav_agent.get_next_position()
	var direction = (next_pos - global_position).normalized()
	
	# Apply seasonal movement modifier
	velocity = direction * movement_speed * movement_modifier
	
	# Look at player (only Y-axis)
	look_at(Vector3(player.global_position.x, player.global_position.y, player.global_position.z), Vector3.UP)

func attack_behavior(delta):
	if not player or not is_instance_valid(player):
		find_player()
		return
		
	# Face the player
	look_at(Vector3(player.global_position.x, player.global_position.y, player.global_position.z), Vector3.UP)
	
	# Stop moving
	velocity = Vector3.ZERO
	
	# Attack if cooled down
	if can_attack:
		perform_attack()
		can_attack = false
		
		# Start cooldown
		var timer = get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func(): can_attack = true)

# Override this in child classes
func perform_attack():
	# Base attack just deals damage if player is in range
	if player and global_position.distance_to(player.global_position) <= attack_radius:
		# Apply seasonal damage modifier
		var modified_damage = int(attack_damage * damage_modifier)
		player.change_health(-modified_damage)
		
		# Play attack animation if available
		if has_node("AnimationPlayer"):
			var anim_player = $AnimationPlayer
			if anim_player.has_animation("attack"):
				anim_player.play("attack")

func take_damage(amount):
	health -= amount
	
	# Apply knockback effect
	if player:
		is_being_knocked_back = true
		knockback_timer = knockback_duration
		knockback_direction = (global_position - player.global_position).normalized()
		knockback_direction.y = 0.3 # Add slight upward component
		
		# Apply seasonal knockback modifier
		velocity = knockback_direction * knockback_force * knockback_modifier
	
	# Visual feedback - particles
	if has_node("HitParticles"):
		$HitParticles.restart()
		$HitParticles.emitting = true
		
		# Create impact flash
		var flash = OmniLight3D.new()
		flash.light_color = Color(1.0, 0.3, 0.3)
		flash.light_energy = 2.0
		flash.omni_range = 3.0
		add_child(flash)
		
		# Remove flash after short duration
		var flash_tween = create_tween()
		flash_tween.tween_property(flash, "light_energy", 0.0, 0.3)
		flash_tween.tween_callback(func(): flash.queue_free())
	  # Visual feedback - mesh flash
	if has_node("MeshInstance3D"):
		var mesh_instance = $MeshInstance3D
		var original_color = Color(0.8, 0.2, 0.2) # Default red as fallback
		var material = null
		
		# Check if we have material_override or surface_override_material
		if mesh_instance.material_override:
			material = mesh_instance.material_override
			original_color = material.albedo_color
			material.albedo_color = Color(1, 0, 0)
		elif mesh_instance.get_surface_override_material_count() > 0:
			material = mesh_instance.get_surface_override_material(0)
			if material:
				original_color = material.albedo_color
				material.albedo_color = Color(1, 0, 0)
		
		if material:
			# Add hit animation
			var tween = create_tween()
			tween.tween_property(self, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
			tween.tween_property(self, "scale", Vector3(1, 1, 1), 0.1)
			
			# Return to original color after animation
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(self) and has_node("MeshInstance3D"):
				material.albedo_color = original_color
	
	# Check if dead
	if health <= 0:
		die()

func die():
	state = "dead"
	
	# Death animation or effect
	if has_node("AnimationPlayer"):
		var anim_player = $AnimationPlayer
		if anim_player.has_animation("death"):
			anim_player.play("death")
			await anim_player.animation_finished
	
	# Emit signal before removal
	emit_signal("enemy_died", self)
	
	# Remove from scene
	queue_free()

# Room transition handling
func _on_enter_room(room):
	# Store the current room
	current_room = room
	
	# Apply seasonal effects from the room
	get_tree().call_group("room_manager", "process_season_effects", self, room)
	
	# Check if it's a boss room - if so, this enemy is part of the boss room
	if room.has_meta("is_boss_room") and room.get_meta("is_boss_room"):
		if not get_meta("is_boss", false): # Only for non-boss enemies
			# Reduce health for minions in boss room
			max_health = int(max_health * 0.7)
			health = max_health

# Called when player enters a room - enemies should react
func _on_room_player_entered(room):
	# Only react if we're in the same room as the player now
	if current_room == room:
		# Player entered our room, become active
		state = "chase"
	else:
		# Player left our room, go back to idle
		state = "idle"

# Apply a movement speed modifier from seasonal effects
func set_movement_modifier(modifier):
	movement_modifier = modifier
	
# Apply a damage modifier from seasonal effects
func set_damage_modifier(modifier):
	damage_modifier = modifier
	
# Apply a knockback modifier from seasonal effects
func set_knockback_modifier(modifier):
	knockback_modifier = modifier
