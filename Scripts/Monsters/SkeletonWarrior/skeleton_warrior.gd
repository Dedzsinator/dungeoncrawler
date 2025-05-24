extends CharacterBody3D


@onready var item_object_scene: PackedScene = preload("res://Scenes/Objects/item_object.tscn")
@onready var state_controller = get_node("StateMachine")
@onready var skeleton_mesh = $Skeleton_Warrior
@onready var collision_shape = $CollisionShape3D

@export var player: CharacterBody3D

var speed: float = 1.0
var direction: Vector3
var health: int = 4
var damage: int = 3
var is_awakening: bool = false
var is_attacking: bool = false
var is_dying: bool = false
var just_hit: bool = false

# Ragdoll variables
var ragdoll_parts: Array[RigidBody3D] = []
var dissolution_timer: Timer


func _ready() -> void:
	state_controller.change_state("Idle")
	setup_dissolution_timer()

func setup_dissolution_timer() -> void:
	dissolution_timer = Timer.new()
	dissolution_timer.wait_time = 3.0 # Dissolve after 3 seconds
	dissolution_timer.one_shot = true
	dissolution_timer.timeout.connect(_start_dissolution)
	add_child(dissolution_timer)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if is_instance_valid(player):
		direction = (player.global_transform.origin - global_transform.origin).normalized()
	move_and_slide()

func _on_chase_player_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and !is_dying:
		state_controller.change_state("Run")

func _on_chase_player_detection_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and !is_dying:
		state_controller.change_state("Idle")
		
func _on_attack_player_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and !is_dying:
		state_controller.change_state("Attack")

func _on_attack_player_detection_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and !is_dying:
		state_controller.change_state("Run")

func die() -> void:
	$Skeleton_Warrior.hide()
	$VFX_Die/AnimationPlayer.play("hit")
	var rng := randi_range(2, 3)
	for i in range(rng):
		var item_object := item_object_scene.instantiate()
		item_object.position = global_position
		get_node("../../Items").add_child(item_object)
	GameManager.gain_exp(100)

func _on_die_animation_player_animation_finished(_anim_name: StringName) -> void:
	create_ragdoll()

func create_ragdoll() -> void:
	# Disable the main collision
	collision_shape.disabled = true
	
	# Create ragdoll parts (bones/limbs)
	var bone_positions = [
		Vector3(0, 1.5, 0), # Head
		Vector3(0, 1.0, 0), # Torso
		Vector3(-0.3, 0.8, 0), # Left arm
		Vector3(0.3, 0.8, 0), # Right arm
		Vector3(-0.2, 0.3, 0), # Left leg
		Vector3(0.2, 0.3, 0) # Right leg
	]
	
	var bone_sizes = [
		Vector3(0.2, 0.2, 0.2), # Head
		Vector3(0.4, 0.5, 0.2), # Torso
		Vector3(0.15, 0.4, 0.15), # Left arm
		Vector3(0.15, 0.4, 0.15), # Right arm
		Vector3(0.15, 0.5, 0.15), # Left leg
		Vector3(0.15, 0.5, 0.15) # Right leg
	]
	
	for i in range(bone_positions.size()):
		var bone_part = RigidBody3D.new()
		bone_part.position = global_position + bone_positions[i]
		
		# Create collision shape
		var collision = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = bone_sizes[i]
		collision.shape = box_shape
		bone_part.add_child(collision)
		
		# Create visual mesh
		var mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = bone_sizes[i]
		mesh_instance.mesh = box_mesh
		
		# Create skeleton-like material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.9, 0.9, 0.8) # Bone color
		material.roughness = 0.8
		mesh_instance.material_override = material
		bone_part.add_child(mesh_instance)
		
		# Add some random impulse for realistic ragdoll effect
		var impulse = Vector3(
			randf_range(-2.0, 2.0),
			randf_range(1.0, 3.0),
			randf_range(-2.0, 2.0)
		)
		
		get_parent().add_child(bone_part)
		bone_part.apply_impulse(impulse)
		ragdoll_parts.append(bone_part)
	
	# Start dissolution timer
	dissolution_timer.start()

func _start_dissolution() -> void:
	# Create dissolution effect
	var dissolution_tween = get_tree().create_tween()
	dissolution_tween.set_parallel(true)
	
	for part in ragdoll_parts:
		if is_instance_valid(part):
			var mesh_instance = part.get_child(1) as MeshInstance3D
			if mesh_instance and mesh_instance.material_override:
				var material = mesh_instance.material_override as StandardMaterial3D
				
				# Fade out the parts
				dissolution_tween.tween_property(material, "albedo_color:a", 0.0, 2.0)
				
				# Scale down the parts
				dissolution_tween.tween_property(part, "scale", Vector3.ZERO, 2.0)
	
	# Clean up after dissolution
	dissolution_tween.tween_callback(_cleanup_ragdoll).set_delay(2.0)

func _cleanup_ragdoll() -> void:
	for part in ragdoll_parts:
		if is_instance_valid(part):
			part.queue_free()
	ragdoll_parts.clear()
	queue_free()

func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if "Awake" in anim_name:
		is_awakening = false
	elif "Attack" in anim_name:
		if !is_dying and player in get_node("AttackPlayerDetection").get_overlapping_bodies():
			state_controller.change_state("Attack")
	elif "Death" in anim_name:
		# Call create_ragdoll directly instead of die()
		die()
		create_ragdoll()

func hit(amount: int) -> void:
	if !just_hit:
		just_hit = true
		get_node("HitTimer").start()
		health -= amount
		if health <= 0:
			is_dying = true
			state_controller.change_state("Death")
		else:
			var tween := get_tree().create_tween()
			tween.tween_property(self, "global_position", global_position - (direction / 1.5), 0.2)

func _on_hit_timer_timeout() -> void:
	just_hit = false

func _on_damage_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_attacking:
		body.hit(damage)
