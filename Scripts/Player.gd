extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_force: float = 10.0
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.1
@export var max_pitch: float = 90.0
@export var min_pitch: float = -90.0
@export var max_health: float = 6.0  # 6 half-hearts = 3 full hearts

# Health system
var health: float = max_health
signal health_changed(current_health, max_health)

# Inventory system
var active_weapons = [null, null]  # Holds two weapon references
var active_weapon_index = 0  # Currently selected weapon (0 or 1)
var passive_items = []  # "Infinite" inventory for passive items

# Camera settings
var camera_first_person = true
var camera_transition_speed = 5.0
var camera_head_position = Vector3(0, 1.7, 0)  # Eye level for a standard character
var camera_third_position = Vector3(0, 3, 4)    # Behind and above player
var head_bob_enabled = true
var head_bob_amount = 0.05
var head_bob_speed = 14.0
var head_bob_timer = 0.0

var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("health_changed", health, max_health)
	
	# Set up camera properly
	$Camera3D.position = camera_head_position
	
	# Print debug info
	print("Player initialized at: " + str(global_position))
	print("Camera positioned at (local): " + str($Camera3D.position))
	print("Camera positioned at (global): " + str($Camera3D.global_position))
	print("Player collision shape: " + str(has_node("CollisionShape3D")))

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
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
		velocity.y = -0.1  # Small downward force to keep grounded

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

	# Debug physics info every 60 frames
	if Engine.get_physics_frames() % 60 == 0:
		if not is_on_floor():
			print("Player not on floor! Position: " + str(global_position) + " Velocity: " + str(velocity))
		else:
			print("Player on floor. Position: " + str(global_position))

# Health system methods
func change_health(amount: float) -> void:
	health = clamp(health + amount, 0, max_health)
	emit_signal("health_changed", health, max_health)
	
	if health <= 0:
		die()

func die() -> void:
	print("Player died!")
	# Implement death logic here

# Inventory system methods
func add_passive_item(item) -> void:
	passive_items.append(item)

func equip_weapon(weapon, slot: int) -> void:
	if slot >= 0 and slot < active_weapons.size():
		active_weapons[slot] = weapon

func switch_weapon() -> void:
	active_weapon_index = (active_weapon_index + 1) % active_weapons.size()
	print("Switched to weapon " + str(active_weapon_index + 1))

func use_active_weapon() -> void:
	var current_weapon = active_weapons[active_weapon_index]
	if current_weapon != null:
		# Assume each weapon has a use() method
		current_weapon.use()
		print("Used weapon " + str(active_weapon_index + 1))
	else:
		print("No weapon equipped in slot " + str(active_weapon_index + 1))

# Camera view methods
func toggle_camera_view() -> void:
	camera_first_person = !camera_first_person
	
	# Update camera immediately
	if camera_first_person:
		$Camera3D.position = camera_head_position
		# Hide player model in first person if needed
		# $Model.visible = false
	else:
		$Camera3D.position = camera_third_position
		# $Model.visible = true
		
	print("Camera view: " + ("First-person" if camera_first_person else "Third-person"))
