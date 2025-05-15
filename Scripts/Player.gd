extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_force: float = 10.0
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.1
@export var max_pitch: float = 90.0
@export var min_pitch: float = -90.0
@export var max_hearts: int = 3
@export var invincibility_time: float = 1.0

# Health system
var hearts: int = max_hearts
var half_hearts: int = hearts * 2
signal health_changed(current_half_hearts, max_half_hearts)
signal player_died

# Room tracking
var current_room = null

var damage_cooldown: float = 0.5
var can_take_damage: bool = true
var invincibility_timer: float = 0.0

# Inventory system
var inventory = null
signal weapon_switched(weapon_index)
signal weapon_used(weapon)
signal passive_item_added(item)

# Camera settings
var camera_first_person = true
var camera_transition_speed = 5.0
var camera_head_position = Vector3(0, 1.2, 0.15) # Lower and slightly forward position
var camera_third_position = Vector3(0, 2.0, 3.0) # Adjusted third-person view
var head_bob_enabled = true
var head_bob_amount = 0.05
var head_bob_speed = 14.0
var head_bob_timer = 0.0

# Weapon positions
var weapon_mount_position = Vector3(0.5, -0.3, -0.7)
var weapon_offset = Vector3.ZERO

var yaw: float = 0.0
var pitch: float = 0.0

# Player model reference
var player_model: Node3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Hide the capsule mesh
	if has_node("MeshInstance3D"):
		$MeshInstance3D.visible = false
	
	# Adjust collision shape to make player shorter
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule_shape = collision_shape.shape as CapsuleShape3D
		capsule_shape.height = 1.5 # Shorter character height (default was 1.8)
		capsule_shape.radius = 0.35 # Slightly thinner character
		# Adjust the position of the collision shape
		collision_shape.position.y = capsule_shape.height / 2
		
	# Adjust camera position
	camera_head_position = Vector3(0, 1.5, 0.2) # Adjusted head position for visibility
	camera_third_position = Vector3(0, 2.5, 3.0) # Adjusted third-person camera position
	
	# Create and set up the Adventurer player model
	create_adventurer_player_model()
	
	add_to_group("player")
	
	# Connect to room entered signals
	get_tree().call_group("rooms", "connect", "player_entered", _on_enter_room)
	
	var skeleton = Skeleton3D.new()
	skeleton.name = "PlayerSkeleton"
	add_child(skeleton)
	
	var hand_bone = BoneAttachment3D.new()
	hand_bone.name = "RightHand"
	skeleton.add_child(hand_bone)
	hand_bone.position = Vector3(0.4, 0.85, -0.3)
	
	# Initialize weapon mount point attached to hand bone
	var weapon_mount = Node3D.new()
	weapon_mount.name = "WeaponMount"
	hand_bone.add_child(weapon_mount)
	
	var third_person_weapon = Node3D.new()
	third_person_weapon.name = "ThirdPersonWeapon"
	hand_bone.add_child(third_person_weapon)
	
	# Initialize inventory
	inventory = preload("res://Scripts/PlayerInventory.gd").new()
	add_child(inventory)
	
	# Connect signals
	if inventory.has_signal("active_weapon_changed"):
		inventory.connect("active_weapon_changed", _update_visible_weapon)
	
	if inventory.has_signal("weapon_added"):
		inventory.connect("weapon_added", _on_weapon_added)
	
	# Ensure camera is properly positioned
	camera_head_position = Vector3(0, 1.5, 0.2) # Adjusted head position
	camera_third_position = Vector3(0, 2.5, 3.0) # Adjusted third-person view
	$Camera3D.position = camera_head_position
	
	# Start with base health
	hearts = max_hearts
	half_hearts = hearts * 2
	emit_signal("health_changed", half_hearts, max_hearts * 2)
	
	# Apply camera position from ready function
	$Camera3D.position = camera_head_position
	
	# Set up initial weapons
	_create_initial_weapons()

func create_adventurer_player_model():
	# Create the player model node
	player_model = Node3D.new()
	player_model.name = "PlayerModel"
	add_child(player_model)
	
	# Create an AnimationPlayer to control all animations
	var animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	player_model.add_child(animation_player)
	
	# Create a structure that matches the expected animation skeleton structure
	var character_armature = Node3D.new()
	character_armature.name = "CharacterArmature"
	player_model.add_child(character_armature)
	
	# Create a Skeleton3D that will be referenced in animations
	var skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	character_armature.add_child(skeleton)
	
	# Position the model to correct height
	player_model.position.y = -0.9 # Lower the model to align properly with collision shape
	
	print("Created player model structure with skeleton")
	
	# Add basic bones that are likely used in the animations
	# This matches naming conventions often used in 3D models
	var bone_names = ["root", "Body", "Spine", "Chest", "Neck", "Head",
					"Shoulder.L", "UpperArm.L", "LowerArm.L", "Hand.L",
					"Shoulder.R", "UpperArm.R", "LowerArm.R", "Hand.R",
					"Hip", "UpperLeg.L", "LowerLeg.L", "Foot.L",
					"UpperLeg.R", "LowerLeg.R", "Foot.R",
					# Alternative bone names
					"Hips", "Spine1", "Spine2", "Neck1",
					"Head1", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
					"RightShoulder", "RightArm", "RightForeArm", "RightHand",
					"LeftUpLeg", "LeftLeg", "LeftFoot",
					"RightUpLeg", "RightLeg", "RightFoot"]
	
	# Add the bones to the skeleton
	var bone_parents = {}
	bone_parents["root"] = -1
	bone_parents["Body"] = 0
	bone_parents["Hips"] = 0
	bone_parents["Spine"] = 1
	bone_parents["Spine1"] = 1
	bone_parents["Chest"] = 2
	bone_parents["Spine2"] = 2
	bone_parents["Neck"] = 3
	bone_parents["Neck1"] = 3
	bone_parents["Head"] = 4
	bone_parents["Head1"] = 4
	
	# Left arm chain
	bone_parents["Shoulder.L"] = 3
	bone_parents["LeftShoulder"] = 3
	bone_parents["UpperArm.L"] = 6
	bone_parents["LeftArm"] = 6
	bone_parents["LowerArm.L"] = 7
	bone_parents["LeftForeArm"] = 7
	bone_parents["Hand.L"] = 8
	bone_parents["LeftHand"] = 8
	
	# Right arm chain
	bone_parents["Shoulder.R"] = 3
	bone_parents["RightShoulder"] = 3
	bone_parents["UpperArm.R"] = 9
	bone_parents["RightArm"] = 9
	bone_parents["LowerArm.R"] = 10
	bone_parents["RightForeArm"] = 10
	bone_parents["Hand.R"] = 11
	bone_parents["RightHand"] = 11
	
	# Leg chains
	bone_parents["Hip"] = 1
	bone_parents["UpperLeg.L"] = 14
	bone_parents["LeftUpLeg"] = 14
	bone_parents["LowerLeg.L"] = 15
	bone_parents["LeftLeg"] = 15
	bone_parents["Foot.L"] = 16
	bone_parents["LeftFoot"] = 16
	
	bone_parents["UpperLeg.R"] = 14
	bone_parents["RightUpLeg"] = 14
	bone_parents["LowerLeg.R"] = 17
	bone_parents["RightLeg"] = 17
	bone_parents["Foot.R"] = 18
	bone_parents["RightFoot"] = 18
	
	# Add all bones to the skeleton
	var bone_indices = {}
	for i in range(bone_names.size()):
		var bone_name = bone_names[i]
		var bone_index = skeleton.get_bone_count()
		skeleton.add_bone(bone_name)
		bone_indices[bone_name] = bone_index
	
	# Set parents after all bones are created
	for bone_name in bone_indices:
		if bone_name in bone_parents:
			var parent_idx = bone_parents[bone_name]
			if parent_idx >= 0 and parent_idx < skeleton.get_bone_count():
				skeleton.set_bone_parent(bone_indices[bone_name], parent_idx)
	
	# Now create the actual visible model
	var model_path = "res://Assets/Player/Adventurer/Adventurer_Idle.fbx"
	var model_resource = load(model_path)
	if model_resource:
		var model_instance = model_resource.instantiate()
		
		# Add model as a direct child under the CharacterArmature node
		character_armature.add_child(model_instance)
		
		# Find the mesh instance(s) in the model and make sure they have the skeleton path set
		_setup_mesh_skeleton(model_instance, skeleton)
		
		# Ensure meshes are also connected to the skeleton inside the armature
		for child in model_instance.get_children():
			if child is MeshInstance3D:
				# Make sure mesh is visible
				child.visible = true
				
				if child.get_surface_override_material_count() > 0:
					for i in range(child.get_surface_override_material_count()):
						var material = child.get_surface_override_material(i)
						if material:
							if material is StandardMaterial3D:
								# Make sure material isn't transparent unless needed
								material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
							
				# Set the skeleton path
				var skeleton_path = child.get_path_to(skeleton)
				child.skeleton = skeleton_path
		
		# Setup animations
		setup_animations(model_instance, animation_player)
		
		# Set up animation tree for more sophisticated animation control
		setup_animation_tree(model_instance, animation_player)
	else:
		push_error("Failed to load Adventurer model from: " + model_path)
	
	# Position and rotate the model properly
	player_model.rotation_degrees.y = 180
	player_model.position.y = -0.9
	player_model.visible = !camera_first_person
	
	await get_tree().create_timer(0.1).timeout
	
	# Play idle animation
	force_animation_play("Idle", 0.5)
	
	# Final setup: ensure player model is visible in third-person mode
	if !camera_first_person:
		if get_node_or_null("PlayerModel"):
			player_model.visible = true
			
			# Make sure everything in the hierarchy is visible
			for child in player_model.get_children():
				child.visible = true
				
				for grandchild in child.get_children():
					grandchild.visible = true

func print_node_structure(node, indent = 0):
	for child in node.get_children():
		print_node_structure(child, indent + 1)

# Function to set up animations from the Adventurer FBX files
func setup_animations(model_instance, animation_player):
	# Define the animation mapping
	var animation_files = {
		"Idle": "res://Assets/Player/Adventurer/Adventurer_Idle.glb",
		"Walk": "res://Assets/Player/Adventurer/Adventurer_RunForward.glb",
		"RunLeft": "res://Assets/Player/Adventurer/Adventurer_RunLeft.glb",
		"RunRight": "res://Assets/Player/Adventurer/Adventurer_RunRight.glb",
		"Attack": "res://Assets/Player/Adventurer/Adventurer_Attack.glb",
		"IdleWithWeapon": "res://Assets/Player/Adventurer/Adventurer_IdleWithWeapon.glb",
		"Death": "res://Assets/Player/Adventurer/Adventurer_Death.glb",
		"Hit": "res://Assets/Player/Adventurer/Adventurer_Hit.glb",
		"Interact": "res://Assets/Player/Adventurer/Adventurer_Interact.glb",
		"jump_falling": "res://Assets/Player/Adventurer/Adventurer_Jump.glb", # Using jump animation for falling
		"jump_end": "res://Assets/Player/Adventurer/Adventurer_Land.glb" # Using landing animation
	}
	
	# Find the actual skeleton path in our model
	var skeleton_path = ""
	var skeleton_node = find_skeleton_in_model(model_instance)
	if skeleton_node:
		skeleton_path = model_instance.get_path_to(skeleton_node)
		
	# Create animation library
	var library_name = "PlayerAnimations"
	if not animation_player.has_animation_library(library_name):
		var new_anim_library = AnimationLibrary.new()
		animation_player.add_animation_library(library_name, new_anim_library)
	
	var anim_library = animation_player.get_animation_library(library_name)
	
	# Load each animation directly from files
	for anim_name in animation_files.keys():
		var anim_path = animation_files[anim_name]
		
		# Get the source animation
		var source_anim = get_animation_from_file(anim_path)
		if source_anim:
			var has_skeleton_tracks = false
			for i in range(source_anim.get_track_count()):
				var track_path = source_anim.track_get_path(i)
				if "Skeleton" in str(track_path):
					has_skeleton_tracks = true
					break
			
			if str(skeleton_path) != "" and has_skeleton_tracks:
				fix_animation_paths(source_anim, skeleton_path)
			
			# Add the animation to our animation library
			anim_library.add_animation(anim_name, source_anim)

# Function to find the Skeleton3D node in the model
func find_skeleton_in_model(model_node):
	if model_node is Skeleton3D:
		return model_node
	
	# Check children recursively
	for child in model_node.get_children():
		var found = find_skeleton_in_model(child)
		if found:
			return found
	
	return null

# Function to fix animation track paths to match our skeleton
func fix_animation_paths(animation, skeleton_path):
	# Get a list of all available bones from the skeleton
	var available_bones = []
	var skeleton_node = null
	
	# This might be either a NodePath or a Skeleton3D object
	if skeleton_path is NodePath:
		skeleton_node = get_node_or_null(skeleton_path)
	elif skeleton_path is Skeleton3D:
		skeleton_node = skeleton_path
		
	if skeleton_node and skeleton_node is Skeleton3D:
		for i in range(skeleton_node.get_bone_count()):
			available_bones.append(skeleton_node.get_bone_name(i))
	
	# Fix each animation track
	for track_idx in range(animation.get_track_count()):
		var track_path = animation.track_get_path(track_idx)
		var path_string = str(track_path)
		
		# Try to extract the bone name
		var bone_name = ""
		var path_parts = []
		
		if ":" in path_string:
			path_parts = path_string.split(":")
			if path_parts.size() > 1:
				bone_name = path_parts[1]
		else:
			path_parts = path_string.split("/")
			if path_parts.size() > 0:
				bone_name = path_parts[path_parts.size() - 1]
		
		# If we found a bone name and it exists in our skeleton
		if bone_name != "" and (available_bones.size() == 0 or bone_name in available_bones):
			# Create the correct path to our skeleton's bone
			var new_path = NodePath("CharacterArmature/Skeleton3D:"+ bone_name)
			animation.track_set_path(track_idx, new_path)
		# If we couldn't find the bone but the track has "Skeleton" in its path
		elif "Skeleton" in path_string:
			var new_path = NodePath("CharacterArmature/Skeleton3D:"+ bone_name)
			animation.track_set_path(track_idx, new_path)
		else:
			if "Armature" in path_string:
				var new_path = NodePath("CharacterArmature")
				animation.track_set_path(track_idx, new_path)

func get_animation_from_file(file_path):
	var model_resource = load(file_path)
	if not model_resource:
		push_error("Failed to load animation model: " + file_path)
		return null
		
	var model_scene = model_resource.instantiate()
	if not model_scene:
		push_error("Failed to instantiate model scene: " + file_path)
		return null
	
	# Find AnimationPlayer in the model (recursive search)
	var source_anim_player = find_animation_player_in_node(model_scene)
	
	if not source_anim_player:
		push_error("No AnimationPlayer found in: " + file_path)
		model_scene.queue_free()
		return null
	
	# Get the animation
	var animation = null
	var animation_list = []
	
	var default_anims = source_anim_player.get_animation_list()
	for anim_name in default_anims:
		animation_list.append(anim_name)
	
	# Check all animation libraries
	for lib_name in source_anim_player.get_animation_library_list():
		var lib = source_anim_player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			animation_list.append(lib_name + "/" + anim_name)
	
	if animation_list.size() > 0:
		var anim_name = animation_list[0]
		
		if "/" in anim_name:
			var parts = anim_name.split("/")
			var lib_name = parts[0]
			var actual_anim_name = parts[1]
			animation = source_anim_player.get_animation_library(lib_name).get_animation(actual_anim_name)
		else:
			animation = source_anim_player.get_animation(anim_name)
	
	model_scene.queue_free()
	return animation

# Helper to find AnimationPlayer node recursively
func find_animation_player_in_node(node):
	if node is AnimationPlayer:
		return node
	
	# Check children recursively
	for child in node.get_children():
		var found = find_animation_player_in_node(child)
		if found:
			return found
	
	return null

func play_animation(anim_name):
	# Use the class variable instead of local one
	if player_model:
		var animation_player = player_model.get_node_or_null("AnimationPlayer")
		if animation_player:
			# First check all animation libraries
			var library_name = "PlayerAnimations" # Our custom library name
			var found = false
			
			# Try with our custom library first
			if animation_player.has_animation_library(library_name) and animation_player.get_animation_library(library_name).has_animation(anim_name):
				var full_anim_name = library_name + "/" + anim_name
				if animation_player.current_animation != full_anim_name:
					animation_player.play(full_anim_name)
					print("Playing animation: " + full_anim_name)
					return true
				found = true
			
			# If not found in our library, check the default library
			if not found and animation_player.has_animation(anim_name):
				if animation_player.current_animation != anim_name:
					animation_player.play(anim_name)
					print("Playing animation: " + anim_name + " from default library")
					return true
				found = true
				
			# Try all other libraries as a last resort
			if not found:
				for lib_name in animation_player.get_animation_library_list():
					var lib = animation_player.get_animation_library(lib_name)
					if lib.has_animation(anim_name):
						var full_anim_name = lib_name + "/" + anim_name
						if animation_player.current_animation != full_anim_name:
							animation_player.play(full_anim_name)
							print("Playing animation: " + full_anim_name)
							return true
						found = true
						break
			
			if not found:
				print("Animation not found: " + anim_name + " in any animation library")
	return false

func force_animation_play(anim_name, blend_time = 0.2):
	# Use the class variable instead of a local one
	if player_model:
		var animation_player = player_model.get_node_or_null("AnimationPlayer")
		if animation_player:
			# First check all animation libraries
			var library_name = "PlayerAnimations" # Our custom library name
			var found = false
			
			# Try with our custom library first
			if animation_player.has_animation_library(library_name) and animation_player.get_animation_library(library_name).has_animation(anim_name):
				var full_anim_name = library_name + "/" + anim_name
				if animation_player.current_animation != full_anim_name:
					print("Force playing animation: " + full_anim_name + " with blend time " + str(blend_time))
					
					# Try setting animation update mode to ensure it plays in the physics process
					animation_player.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_PHYSICS
					
					# Play the animation with blend time
					animation_player.play(full_anim_name, blend_time)
					
					return true
				found = true
			
			# If not found in our library, check the default library
			if not found and animation_player.has_animation(anim_name):
				print("Force playing animation: " + anim_name + " from default library")
				animation_player.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_PHYSICS
				animation_player.play(anim_name, blend_time)
				return true
			
			# Try all other libraries as a last resort
			if not found:
				for lib_name in animation_player.get_animation_library_list():
					var lib = animation_player.get_animation_library(lib_name)
					if lib.has_animation(anim_name):
						var full_anim_name = lib_name + "/" + anim_name
						print("Force playing animation: " + full_anim_name)
						animation_player.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_PHYSICS
						animation_player.play(full_anim_name, blend_time)
						return true
			
			if not found:
				print("Animation not found for force play: " + anim_name)
	return false

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	# Handle mouse look
	if event is InputEventMouseMotion:
		# Horizontal rotation (player body)
		yaw -= event.relative.x * mouse_sensitivity
		# Vertical rotation (camera only)
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)
		
		# Rotate the entire player body horizontally
		rotation_degrees.y = yaw
		
		# Only pitch the camera up/down
		$Camera3D.rotation_degrees.x = pitch
	
	# Handle weapon switching
	if event.is_action_pressed("switch_weapon"):
		inventory.handle_input_action("switch_weapon")
	
	# Handle weapon using
	if event.is_action_pressed("use_weapon"):
		inventory.handle_input_action("use_weapon")
	
	# Handle camera toggle
	if event.is_action_pressed("toggle_camera"):
		toggle_camera_view()

func _physics_process(delta: float) -> void:
	# Get movement input relative to camera direction
	var inp_dir = Vector3.ZERO
	
	# Forward/backward is in the camera's Z direction
	if Input.is_action_pressed("move_forward"):
		inp_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		inp_dir.z += 1
	
	# Left/right is in the camera's X direction
	if Input.is_action_pressed("move_left"):
		inp_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		inp_dir.x += 1

	# Normalize input direction to prevent faster diagonal movement
	inp_dir = inp_dir.normalized()
	
	var global_dir = (transform.basis * Vector3(inp_dir.x, 0, inp_dir.z)).normalized()
	
	# Set horizontal movement
	if global_dir:
		velocity.x = global_dir.x * speed
		velocity.z = global_dir.z * speed
		
		# Determine animation based on movement direction
		var forward_dot = global_dir.dot(-transform.basis.z)
		var right_dot = global_dir.dot(transform.basis.x)
		
		# Use directional animations based on movement direction
		if abs(right_dot) > abs(forward_dot) * 1.5:
			if right_dot > 0:
				play_animation("RunRight")
			elif right_dot < 0:
				play_animation("RunLeft")
			else:
				play_animation("Walk")
		else:
			play_animation("Walk")
	else:
		# Apply friction when no input
		velocity.x = lerp(velocity.x, 0.0, 0.2)
		velocity.z = lerp(velocity.z, 0.0, 0.2)
		
		# Play appropriate idle animation based on weapon state
		var has_active_weapon = inventory and inventory.get_active_weapon()
		
		if has_active_weapon:
			play_animation("IdleWithWeapon")
		else:
			play_animation("Idle")
	
	# Apply gravity
	if not is_on_floor():
		# Store previous y velocity to detect transitions
		var prev_y_velocity = velocity.y
		
		velocity.y -= gravity * delta
		
		# Play falling animation if moving downward significantly
		if velocity.y < -4.0: # Falling threshold
			play_animation("jump_falling")
		# Started falling (transition from rising to falling)
		elif prev_y_velocity >= 0 and velocity.y < 0:
			play_animation("jump_falling")
	else:
		# Store if we were falling before hitting the ground
		var was_falling = velocity.y < -4.0
		
		# Reset downward velocity when on floor
		velocity.y = -0.1 # Small downward force to keep grounded
		
		# Handle landing from a jump/fall
		if was_falling:
			play_animation("jump_end")
			# Create a small camera shake effect for landing
			var shake_amount = min(abs(velocity.y) * 0.01, 0.05)
			var original_pos = $Camera3D.position
			var tween = create_tween()
			tween.tween_property($Camera3D, "position", original_pos + Vector3(0, -shake_amount, 0), 0.1)
			tween.tween_property($Camera3D, "position", original_pos, 0.1)

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		
		# Play jump animation
		if player_model:
			play_animation("jump_falling")
	
	# Apply head bobbing when walking - only in first person mode
	if camera_first_person and head_bob_enabled and is_on_floor() and (velocity.x != 0 or velocity.z != 0):
		head_bob_timer += delta * head_bob_speed * velocity.length() / speed
		
		# Calculate bobbing offset
		var bob_offset = Vector3(
			sin(head_bob_timer * 0.5) * head_bob_amount * 0.5,
			sin(head_bob_timer) * head_bob_amount,
			0
		)
		
		# Apply to camera position
		$Camera3D.position = camera_head_position + bob_offset
	elif camera_first_person:
		# Reset camera position when not moving or in air (first-person only)
		$Camera3D.position = camera_head_position
	
	# Update player model position and rotation in third-person mode
	if !camera_first_person:
		# Use class variable instead of local one
		if player_model:
			player_model.rotation_degrees.y = 180
			
			# Make sure animation player is running on physics process
			var animation_player = player_model.get_node_or_null("AnimationPlayer")
			if animation_player:
				animation_player.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_PHYSICS

	move_and_slide()

# Health system methods
func change_health(amount: int) -> void:
	# Handle damage cooldown
	if amount < 0 and not can_take_damage:
		return
	
	# Convert amount to half-hearts
	var half_heart_amount = amount
	
	# Update half hearts
	half_hearts = clamp(half_hearts + half_heart_amount, 0, max_hearts * 2)
	
	# Update hearts (integer division)
	hearts = int(half_hearts / 2.0)
	
	# Emit signal with half_hearts
	emit_signal("health_changed", half_hearts, max_hearts * 2)
	
	if amount < 0:
		# Hit effect
		print("Player took " + str(-amount) + " damage. Half hearts: " + str(half_hearts))
		_damage_feedback()
	
	# Death condition
	if half_hearts <= 0:
		die()

func _damage_feedback():
	# Visual feedback
	var tween = create_tween()
	tween.tween_property($Camera3D, "position:y", camera_head_position.y - 0.2, 0.1)
	tween.tween_property($Camera3D, "position:y", camera_head_position.y, 0.1)
	
	# Start invincibility frames
	can_take_damage = false
	
	# Play hit animation
	if player_model:
		var animation_player = player_model.get_node_or_null("AnimationPlayer")
		if animation_player and animation_player.has_animation("Hit"):
			animation_player.play("Hit")
	
	# Visual indicator of invincibility - flash the player
	# Find all mesh instances to flash
	var meshes = []
	for child in get_children():
		if child is MeshInstance3D:
			meshes.append(child)
	
	var flash_tween = create_tween()
	flash_tween.set_loops(5)
	
	for i in range(5):
		flash_tween.tween_callback(func(): _set_meshes_visibility(meshes, 0.5))
		flash_tween.tween_interval(0.1)
		flash_tween.tween_callback(func(): _set_meshes_visibility(meshes, 1.0))
		flash_tween.tween_interval(0.1)
	
	# Reset after invincibility time
	await get_tree().create_timer(invincibility_time).timeout
	can_take_damage = true
	_set_meshes_visibility(meshes, 1.0)

func change_max_health(amount: int) -> void:
	max_hearts += amount
	if amount > 0:
		# If increasing max hearts, also heal by that amount
		half_hearts += amount * 2
	half_hearts = clamp(half_hearts, 0, max_hearts * 2)
	hearts = int(half_hearts / 2.0)
	emit_signal("health_changed", half_hearts, max_hearts * 2)

func die() -> void:
	print("Player died!")
	emit_signal("player_died")
	
	# Use class variable instead of local one
	if player_model:
		var animation_player = player_model.get_node_or_null("AnimationPlayer")
		if animation_player and animation_player.has_animation("Death"):
			animation_player.play("Death")
		else:
			# Fallback death animation
			var tween = create_tween()
			tween.tween_property(self, "rotation_degrees:z", 90, 1.0)
	else:
		var tween = create_tween()
		tween.tween_property(self, "rotation_degrees:z", 90, 1.0)
	
	# Disable controls
	set_physics_process(false)
	set_process_input(false)
	
	# Wait a moment then restart
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

# Inventory system methods
func add_passive_item(item) -> void:
	inventory.add_passive_item(item)

func _on_item_added(item):
	print("Added " + item.item_name + " to inventory")
	emit_signal("passive_item_added", item)

func _on_item_removed(item):
	# Handle removing the item
	print("Removed " + item.item_name + " from inventory")

func _on_weapon_switched(index):
	print("Switched to weapon slot " + str(index + 1))
	_update_visible_weapon()
	emit_signal("weapon_switched", index)

func _on_weapon_used(weapon):
	emit_signal("weapon_used", weapon)

func equip_weapon(weapon, slot: int = -1) -> void:
	inventory.add_weapon(weapon, slot)
	_update_visible_weapon()

func switch_weapon():
	inventory.cycle_active_weapon()
	emit_signal("weapon_switched", inventory.current_active_slot)

func use_weapon() -> void:
	var current_weapon = inventory.get_active_weapon()
	if current_weapon:
		# Play attack animation
		if play_animation("Attack"):
			# Use class variable instead of local one
			if player_model:
				var animation_player = player_model.get_node_or_null("AnimationPlayer")
				if animation_player:
					if animation_player.is_connected("animation_finished", _on_attack_animation_finished):
						animation_player.disconnect("animation_finished", _on_attack_animation_finished)
					
					# Connect to the signal
					animation_player.connect("animation_finished", _on_attack_animation_finished)
					print("Connected to animation_finished signal")
		
		await current_weapon.use()
	else:
		print("No weapon equipped")

func _on_attack_animation_finished(anim_name):
	if anim_name == "Attack" or anim_name == "PlayerAnimations/Attack" or anim_name.ends_with("/Attack"):
		# Return to appropriate idle animation
		var has_active_weapon = inventory and inventory.get_active_weapon()
		
		if has_active_weapon:
			play_animation("IdleWithWeapon")
		else:
			play_animation("Idle")

# Camera view methods
func toggle_camera_view() -> void:
	camera_first_person = !camera_first_person
	
	# Update active weapon to appear in correct mount
	var active_weapon = null
	if inventory:
		active_weapon = inventory.get_active_weapon()
	
	# Update camera position based on view mode
	if camera_first_person:
		# Switch to first-person view
		$Camera3D.position = camera_head_position
		
		if player_model:
			print("Switching to first-person - hiding player model")
			player_model.visible = false
			
		# If we have a weapon, move it to first-person mount
		if active_weapon and active_weapon.get_parent():
			active_weapon.get_parent().remove_child(active_weapon)
			$PlayerSkeleton/RightHand/WeaponMount.add_child(active_weapon)
			active_weapon.position = weapon_offset
	else:
		# Switch to third-person view
		$Camera3D.position = camera_third_position
		
		if player_model:
			print("Switching to third-person - showing player model")
			player_model.visible = true
			
			# Make sure all child nodes are visible too
			for child in player_model.get_children():
				# Skip non-visual nodes like AnimationPlayer
				if !(child is AnimationPlayer):
					child.visible = true
				
				# If this is CharacterArmature, make its children visible too
				if child.name == "CharacterArmature":
					for armature_child in child.get_children():
						# Only set visibility on visual nodes
						if !(armature_child is AnimationPlayer):
							armature_child.visible = true
						armature_child.visible = true
			
		# If we have a weapon, move it to third-person mount
		if active_weapon and active_weapon.get_parent():
			active_weapon.get_parent().remove_child(active_weapon)
			$PlayerSkeleton/RightHand/ThirdPersonWeapon.add_child(active_weapon)
			active_weapon.position = weapon_offset
	
	print("Camera view: " + ("First-person" if camera_first_person else "Third-person"))
	
# Interaction methods
func _on_interaction_area_body_entered(body):
	if body.is_in_group("item_pickup"):
		body.interact(self)

func _on_weapon_added(weapon, slot: int):
	# Handle the event when a weapon is added to the inventory
	print("Added " + weapon.name + " to inventory slot " + str(slot))
	
	# If this is the active weapon slot, update the visible weapon
	if slot == inventory.current_active_slot:
		_update_visible_weapon()

# Room transition handling
func _on_enter_room(room):
	# Store the current room
	current_room = room
	
	# Apply seasonal effects from the room
	get_tree().call_group("room_manager", "process_season_effects", self, room)

func get_current_room():
	return current_room
	
func _set_meshes_visibility(meshes: Array, alpha: float) -> void:
	for mesh in meshes:
		if mesh is MeshInstance3D and mesh.material_override:
			mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			# Set the alpha value
			mesh.material_override.albedo_color.a = alpha

func _create_initial_weapons():
	var SwordClass = load("res://Scripts/Sword.gd")
	var BowClass = load("res://Scripts/Bow.gd")
	
	if SwordClass and BowClass:
		# Create weapon instances
		var sword = SwordClass.new()
		var bow = BowClass.new()
		
		# Add to inventory
		inventory.add_weapon(sword, 0)
		inventory.add_weapon(bow, 1)
		
		# Mount the active weapon
		_update_visible_weapon()
	else:
		push_error("Failed to load weapon scripts")

func _update_visible_weapon():
	# Find weapon mounts in new skeleton structure
	var weapon_mount = $PlayerSkeleton/RightHand/WeaponMount
	var third_person_mount = $PlayerSkeleton/RightHand/ThirdPersonWeapon
	
	if !weapon_mount or !third_person_mount:
		print("Warning: Weapon mounts not found")
		return
	
	# Remove all current weapons from mount
	for child in weapon_mount.get_children():
		weapon_mount.remove_child(child)
		child.queue_free()
		
	# Clear third-person weapon model
	for child in third_person_mount.get_children():
		third_person_mount.remove_child(child)
		child.queue_free()
	
	# Get active weapon
	var active_weapon = inventory.get_active_weapon()
	
	if active_weapon:
		if camera_first_person:
			# Mount weapon to first-person mount
			weapon_mount.add_child(active_weapon)
			active_weapon.position = weapon_offset
		else:
			# Mount weapon to third-person mount
			third_person_mount.add_child(active_weapon)
			active_weapon.position = weapon_offset
		
		# Update player animation to show weapon
		play_animation("IdleWithWeapon")

func _setup_mesh_skeleton(model_node, skeleton_node):
	if model_node is MeshInstance3D:
		var skeleton_path = model_node.get_path_to(skeleton_node)
		
		if model_node.skeleton != skeleton_path:
			model_node.skeleton = skeleton_path
		
		if model_node.skin:
			pass
	
	# Recursively check all children
	for child in model_node.get_children():
		_setup_mesh_skeleton(child, skeleton_node)

# Set up animation tree for more sophisticated animation control
func setup_animation_tree(model_instance, animation_player):
	# Create animation tree
	var anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	model_instance.add_child(anim_tree)
	
	# Set the animation player for the tree
	anim_tree.anim_player = animation_player.get_path()
	
	# Create a state machine
	var state_machine = AnimationNodeStateMachine.new()
	
	# Create animation nodes for our states
	var idle_node = AnimationNodeAnimation.new()
	idle_node.animation = "PlayerAnimations/Idle"
	
	var walk_node = AnimationNodeAnimation.new()
	walk_node.animation = "PlayerAnimations/Walk"
	
	var jump_falling_node = AnimationNodeAnimation.new()
	jump_falling_node.animation = "PlayerAnimations/jump_falling"
	
	var jump_end_node = AnimationNodeAnimation.new()
	jump_end_node.animation = "PlayerAnimations/jump_end"
	
	var idle_weapon_node = AnimationNodeAnimation.new()
	idle_weapon_node.animation = "PlayerAnimations/IdleWithWeapon"
	
	# Add states to the state machine
	state_machine.add_node("idle", idle_node)
	state_machine.add_node("walk", walk_node)
	state_machine.add_node("jump_falling", jump_falling_node)
	state_machine.add_node("jump_end", jump_end_node)
	state_machine.add_node("idle_weapon", idle_weapon_node)
	
	# Create transitions
	var idle_to_walk = AnimationNodeStateMachineTransition.new()
	var walk_to_idle = AnimationNodeStateMachineTransition.new()
	var walk_to_jump = AnimationNodeStateMachineTransition.new()
	var idle_to_jump = AnimationNodeStateMachineTransition.new()
	var jump_to_land = AnimationNodeStateMachineTransition.new()
	var land_to_idle = AnimationNodeStateMachineTransition.new()
	var idle_to_weapon = AnimationNodeStateMachineTransition.new()
	var weapon_to_idle = AnimationNodeStateMachineTransition.new()
	var weapon_to_walk = AnimationNodeStateMachineTransition.new()
	
	# Configure transitions - set blend times
	idle_to_walk.xfade_time = 0.2
	walk_to_idle.xfade_time = 0.2
	walk_to_jump.xfade_time = 0.1
	idle_to_jump.xfade_time = 0.1
	jump_to_land.xfade_time = 0.1
	land_to_idle.xfade_time = 0.2
	idle_to_weapon.xfade_time = 0.2
	weapon_to_idle.xfade_time = 0.2
	weapon_to_walk.xfade_time = 0.2
	
	# Add transitions to state machine
	state_machine.add_transition("idle", "walk", idle_to_walk)
	state_machine.add_transition("walk", "idle", walk_to_idle)
	state_machine.add_transition("walk", "jump_falling", walk_to_jump)
	state_machine.add_transition("idle", "jump_falling", idle_to_jump)
	state_machine.add_transition("jump_falling", "jump_end", jump_to_land)
	state_machine.add_transition("jump_end", "idle", land_to_idle)
	state_machine.add_transition("idle", "idle_weapon", idle_to_weapon)
	state_machine.add_transition("idle_weapon", "idle", weapon_to_idle)
	state_machine.add_transition("idle_weapon", "walk", weapon_to_walk)
	
	# Set default state
	state_machine.set_start_node("idle")
	
	# Connect animation tree to state machine
	anim_tree.tree_root = state_machine
	
	# Enable the animation tree
	anim_tree.active = true
	
	# Store animation tree reference for later use
	return anim_tree
