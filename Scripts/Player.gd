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

# Combat variables
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
var camera_head_position = Vector3(0, 1.7, 0)
var camera_third_position = Vector3(0, 3, 4) # Positioned behind and above the player
var head_bob_enabled = true
var head_bob_amount = 0.05
var head_bob_speed = 14.0
var head_bob_timer = 0.0

# Weapon positions
var weapon_mount_position = Vector3(0.5, -0.3, -0.7) # Right side, slightly forward
var weapon_offset = Vector3.ZERO

var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Hide the capsule mesh - we don't want to see it
	if has_node("MeshInstance3D"):
		$MeshInstance3D.visible = false
	
	# Initialize player model with the new animated model
	var player_model_scene = load("res://Assets/Characters/PlayerAnimated.tscn")
	if not player_model_scene:
		# Try fallback paths for the animated model
		player_model_scene = load("res://Assets/PlayerAnimated.tscn")
		if not player_model_scene:
			player_model_scene = load("res://Assets/Models/PlayerAnimated.tscn")
	
	# Fallback to the regular model if none of the animated models exist
	if not player_model_scene:
		player_model_scene = load("res://Assets/Player.fbx")
		print("Using fallback player model")
	
	if player_model_scene:
		var player_model = player_model_scene.instantiate()
		if player_model:
			# Remove any existing player model
			for child in get_children():
				if child.name == "PlayerModel":
					child.queue_free()
					
			player_model.name = "PlayerModel"
			add_child(player_model)
			
			# Fix model orientation
			player_model.rotation_degrees.y = 180
			
			# Adjust model height/position
			player_model.position.y = -0.9
			
			# Setup animations
			var animation_player = player_model.get_node_or_null("AnimationPlayer")
			if animation_player:
				print("Found animation player in model")
				animation_player.play("Idle") # Start with idle animation
			else:
				# Try to find animation player deeper in the hierarchy
				for child in player_model.get_children():
					animation_player = child.get_node_or_null("AnimationPlayer")
					if animation_player:
						print("Found nested animation player")
						animation_player.play("Idle")
						break
			
			# Hide model in first-person mode
			player_model.visible = !camera_first_person
	else:
		push_error("Failed to load any player model")
	
	# Add player to group for easier reference - ensure consistent group name
	add_to_group("player")
	
	# Connect to room entered signals
	get_tree().call_group("rooms", "connect", "player_entered", _on_enter_room)
	
	# Create player skeleton with hand bone for proper weapon attachments
	var skeleton = Skeleton3D.new()
	skeleton.name = "PlayerSkeleton"
	add_child(skeleton)
	
	# Setup bones - simple skeleton with just a hand for weapon mounting
	# In a real implementation you'd synchronize this with your model's actual skeleton
	var hand_bone = BoneAttachment3D.new()
	hand_bone.name = "RightHand"
	skeleton.add_child(hand_bone)
	hand_bone.position = Vector3(0.4, 0.85, -0.3) # Position relative to player
	
	# Initialize weapon mount point attached to hand bone
	var weapon_mount = Node3D.new()
	weapon_mount.name = "WeaponMount"
	hand_bone.add_child(weapon_mount)
	
	# Create weapon holder for third-person view
	var third_person_weapon = Node3D.new()
	third_person_weapon.name = "ThirdPersonWeapon"
	hand_bone.add_child(third_person_weapon)
	
	# Initialize inventory
	inventory = preload("res://Scripts/PlayerInventory.gd").new()
	add_child(inventory)
	
	# Connect signals
	if inventory.has_signal("active_weapon_changed"):
		inventory.connect("active_weapon_changed", _update_visible_weapon)
	
	# Connect weapon_added signal if it exists
	if inventory.has_signal("weapon_added"):
		inventory.connect("weapon_added", _on_weapon_added)
	
	# Start with base health (3 hearts = 6 half hearts)
	hearts = max_hearts
	half_hearts = hearts * 2
	emit_signal("health_changed", half_hearts, max_hearts * 2)
	
	# Adjust camera position to be slightly behind the player's head
	camera_head_position = Vector3(0, 1.5, 0.2) # Moved slightly back to avoid seeing inside model
	camera_third_position = Vector3(0, 2.5, 3) # Positioned behind and above player
	$Camera3D.position = camera_head_position
	
	# Set up initial weapons (for testing)
	_create_initial_weapons()
	
	print("Player initialized at: " + str(global_position))

func _create_initial_weapons():
	# Create weapons using resource loading for better error handling
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
		# Handle weapon differently based on camera mode
		if camera_first_person:
			# Mount weapon to first-person mount
			weapon_mount.add_child(active_weapon)
			active_weapon.position = weapon_offset
		else:
			# Mount weapon to third-person mount
			third_person_mount.add_child(active_weapon)
			active_weapon.position = weapon_offset

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
	
	# Transform direction from local to global space
	var global_dir = (transform.basis * Vector3(inp_dir.x, 0, inp_dir.z)).normalized()
	
	# Set horizontal movement
	if global_dir:
		velocity.x = global_dir.x * speed
		velocity.z = global_dir.z * speed
		
		# Play walk/run animation when moving
		var player_model = get_node_or_null("PlayerModel")
		if player_model:
			var animation_player = find_animation_player(player_model)
			if animation_player and animation_player.has_animation("Walk"):
				if is_on_floor() and animation_player.current_animation != "Walk":
					animation_player.play("Walk")
	else:
		# Apply friction when no input
		velocity.x = lerp(velocity.x, 0.0, 0.2)
		velocity.z = lerp(velocity.z, 0.0, 0.2)
		
		# Play idle animation when not moving
		var player_model = get_node_or_null("PlayerModel")
		if player_model:
			var animation_player = find_animation_player(player_model)
			if animation_player and animation_player.has_animation("Idle"):
				if is_on_floor() and animation_player.current_animation != "Idle":
					animation_player.play("Idle")
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Reset downward velocity when on floor
		velocity.y = -0.1 # Small downward force to keep grounded

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		
		# Play jump animation
		var player_model = get_node_or_null("PlayerModel")
		if player_model:
			var animation_player = find_animation_player(player_model)
			if animation_player and animation_player.has_animation("Jump"):
				animation_player.play("Jump")
	
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
	hearts = half_hearts / 2
	
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
	
	# Visual indicator of invincibility - flash the player
	# Find all mesh instances to flash
	var meshes = []
	for child in get_children():
		if child is MeshInstance3D:
			meshes.append(child)
	
	# Create flash effect by modifying mesh visibility
	var flash_tween = create_tween()
	flash_tween.set_loops(5)
	
	# Alternate visibility for flash effect
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
	hearts = half_hearts / 2
	emit_signal("health_changed", half_hearts, max_hearts * 2)

func die() -> void:
	print("Player died!")
	emit_signal("player_died")
	
	# Play death animation if available
	var player_model = get_node_or_null("PlayerModel")
	if player_model:
		var animation_player = find_animation_player(player_model)
		if animation_player and animation_player.has_animation("Death"):
			animation_player.play("Death")
		else:
			# Fallback death animation
			var tween = create_tween()
			tween.tween_property(self, "rotation_degrees:z", 90, 1.0)
	else:
		# Fallback death animation if no model
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
	# Handle adding the item (visual notification, etc)
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
		# Play attack animation if available
		var player_model = get_node_or_null("PlayerModel")
		if player_model:
			var animation_player = find_animation_player(player_model)
			if animation_player and animation_player.has_animation("Attack"):
				animation_player.play("Attack")
		
		await current_weapon.use()
	else:
		print("No weapon equipped")

# Camera view methods
func toggle_camera_view() -> void:
	camera_first_person = !camera_first_person
	
	# Update active weapon to appear in correct mount
	var active_weapon = null
	if inventory:
		active_weapon = inventory.get_active_weapon()
	
	# Find player model
	var player_model = get_node_or_null("PlayerModel")
	
	# Update camera position based on view mode
	if camera_first_person:
		# Switch to first-person view
		$Camera3D.position = camera_head_position
		
		if player_model:
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
			player_model.visible = true
			
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
	
	# Display season info if available
	if room.has_meta("season"):
		var season_id = room.get_meta("season")
		var season_manager = get_tree().get_first_node_in_group("room_manager").season_manager
		if season_manager:
			var season_name = season_manager.season_names[season_id]
			print("Entered " + season_name + " room")
	
	# Check if it's a boss room
	if room.has_meta("is_boss_room") and room.get_meta("is_boss_room"):
		print("Entered boss room!")

# Get the current room for other objects to access
func get_current_room():
	return current_room
	
# Helper function to set mesh visibility/transparency
func _set_meshes_visibility(meshes: Array, alpha: float) -> void:
	for mesh in meshes:
		if mesh is MeshInstance3D and mesh.material_override:
			# Make sure the material is ready for transparency
			mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			# Set the alpha value
			mesh.material_override.albedo_color.a = alpha

# Helper function to find animation player in model hierarchy
func find_animation_player(model_node):
	# First check direct child
	var animation_player = model_node.get_node_or_null("AnimationPlayer")
	if animation_player:
		return animation_player
		
	# Then search in children
	for child in model_node.get_children():
		animation_player = child.get_node_or_null("AnimationPlayer")
		if animation_player:
			return animation_player
			
	return null
