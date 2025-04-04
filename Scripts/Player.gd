extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_force: float = 10.0
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.1
@export var max_pitch: float = 90.0
@export var min_pitch: float = -90.0
@export var max_health: float = 100.0

# Health system
var health: float = max_health
signal health_changed(current_health, max_health)
signal player_died

# Combat variables
var damage_cooldown: float = 0.5
var can_take_damage: bool = true

# Inventory system
var inventory = null
signal weapon_switched(weapon_index)
signal weapon_used(weapon)
signal passive_item_added(item)

# Camera settings
var camera_first_person = true
var camera_transition_speed = 5.0
var camera_head_position = Vector3(0, 1.7, 0)
var camera_third_position = Vector3(0, 3, 4)
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
	
	# Initialize weapon mount point
	var weapon_mount = Node3D.new()
	weapon_mount.name = "WeaponMount"
	$Camera3D.add_child(weapon_mount)
	weapon_mount.position = weapon_mount_position
	
	# Create weapon holder for third-person view
	var third_person_weapon = Node3D.new()
	third_person_weapon.name = "ThirdPersonWeapon"
	add_child(third_person_weapon)
	
	# Initialize inventory
	inventory = preload("res://Scripts/PlayerInventory.gd").new()
	add_child(inventory)
	inventory.connect("item_added", _on_item_added)
	inventory.connect("item_removed", _on_item_removed)
	inventory.connect("active_weapon_changed", _on_weapon_switched)
	inventory.connect("active_weapon_used", _on_weapon_used)
	
	# Start with base health
	health = max_health
	emit_signal("health_changed", health, max_health)
	
	# Set up camera properly
	$Camera3D.position = camera_head_position
	
	# Set up initial weapons (for testing)
	_create_initial_weapons()
	
	print("Player initialized at: " + str(global_position))

func _create_initial_weapons():
	# Create a sword
	var sword = preload("res://Scripts/Sword.gd").new()
	var bow = preload("res://Scripts/Bow.gd").new()
	
	# Add to inventory
	inventory.add_weapon(sword, 0)
	inventory.add_weapon(bow, 1)
	
	# Mount the active weapon
	_update_visible_weapon()

func _update_visible_weapon():
	# Remove all current weapons from mount
	var weapon_mount = $Camera3D/WeaponMount
	for child in weapon_mount.get_children():
		weapon_mount.remove_child(child)
		child.queue_free()
	
	# Get active weapon
	var active_weapon = inventory.get_active_weapon()
	
	if active_weapon:
		# Mount weapon to camera
		weapon_mount.add_child(active_weapon)
		active_weapon.position = weapon_offset
		
		# Update third-person weapon model
		var third_person_mount = $ThirdPersonWeapon
		for child in third_person_mount.get_children():
			third_person_mount.remove_child(child)
			child.queue_free()
			
		if not camera_first_person:
			# Create weapon visual for third-person
			var weapon_visual = active_weapon.duplicate()
			third_person_mount.add_child(weapon_visual)
			weapon_visual.position = Vector3(0.4, 0, 0) # Adjust for third-person view
			weapon_visual.rotation = Vector3(0, 0, 0)

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
	else:
		# Apply friction when no input
		velocity.x = lerp(velocity.x, 0.0, 0.2)
		velocity.z = lerp(velocity.z, 0.0, 0.2)

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Reset downward velocity when on floor
		velocity.y = -0.1 # Small downward force to keep grounded

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	# Apply head bobbing when walking
	if head_bob_enabled and is_on_floor() and (velocity.x != 0 or velocity.z != 0):
		head_bob_timer += delta * head_bob_speed * velocity.length() / speed
		
		# Calculate bobbing offset
		var bob_offset = Vector3(
			sin(head_bob_timer * 0.5) * head_bob_amount * 0.5,
			sin(head_bob_timer) * head_bob_amount,
			0
		)
		
		# Apply to camera position
		$Camera3D.position = camera_head_position + bob_offset
	else:
		# Reset camera position when not moving or in air
		$Camera3D.position = camera_head_position

	move_and_slide()

# Health system methods
func change_health(amount: float) -> void:
	# Handle damage cooldown
	if amount < 0 and not can_take_damage:
		return
		
	health = clamp(health + amount, 0, max_health)
	emit_signal("health_changed", health, max_health)
	
	if amount < 0:
		# Hit effect
		print("Player took " + str(-amount) + " damage. Health: " + str(health))
		_damage_feedback()
	
	# Death condition
	if health <= 0:
		die()

func _damage_feedback():
	# Visual feedback
	var tween = create_tween()
	tween.tween_property($Camera3D, "position:y", camera_head_position.y - 0.2, 0.1)
	tween.tween_property($Camera3D, "position:y", camera_head_position.y, 0.1)
	
	# Damage cooldown
	can_take_damage = false
	await get_tree().create_timer(damage_cooldown).timeout
	can_take_damage = true

func change_max_health(amount: float) -> void:
	max_health += amount
	if amount > 0:
		# If increasing max health, also heal by that amount
		health += amount
	health = clamp(health, 0, max_health)
	emit_signal("health_changed", health, max_health)

func die() -> void:
	print("Player died!")
	emit_signal("player_died")
	
	# Animation or visual feedback
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
		await current_weapon.use()
	else:
		print("No weapon equipped")

# Camera view methods
func toggle_camera_view() -> void:
	camera_first_person = !camera_first_person
	
	# Update camera immediately
	if camera_first_person:
		$Camera3D.position = camera_head_position
		$MeshInstance3D.visible = false
	else:
		$Camera3D.position = camera_third_position
		$MeshInstance3D.visible = true
	
	# Update weapon visibility
	_update_visible_weapon()
	
	print("Camera view: " + ("First-person" if camera_first_person else "Third-person"))

# Interaction methods
func _on_interaction_area_body_entered(body):
	if body.is_in_group("item_pickup"):
		body.interact(self)
