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
var camera_first_position = Vector3(0, 0.5, 0)  # Adjust based on your model
var camera_third_position = Vector3(0, 2, 4)    # Behind and above player

var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("health_changed", health, max_health)
	# Set initial camera position
	$Camera3D.position = camera_first_position if camera_first_person else camera_third_position

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity

		pitch = clamp(pitch, min_pitch, max_pitch)

		rotation_degrees.y = yaw
	
	$Camera3D.rotation_degrees.x = pitch

func _physics_process(delta: float) -> void:
	var inp_dir = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		inp_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		inp_dir.z += 1
	if Input.is_action_pressed("move_left"):
		inp_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		inp_dir.x += 1

	# Normalize input direction to prevent faster diagonal movement
	inp_dir = inp_dir.normalized() * speed

	velocity.x = inp_dir.x
	velocity.z = inp_dir.z

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	# Debug health controls
	if Input.is_action_just_pressed("ui_page_up"):
		change_health(0.5)  # Heal half a heart
	if Input.is_action_just_pressed("ui_page_down"):
		change_health(-0.5)  # Damage half a heart

	# Weapon controls
	if Input.is_action_just_pressed("switch_weapon"):  # C key
		switch_weapon()
	if Input.is_action_just_pressed("use_weapon"):     # Ctrl key
		use_active_weapon()

	# Camera view toggle
	if Input.is_action_just_pressed("toggle_camera"):  # V key
		toggle_camera_view()
	
	# Update camera position if transitioning between views
	update_camera_position(delta)

	move_and_slide()

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
	print("Camera view: " + ("First-person" if camera_first_person else "Third-person"))

func update_camera_position(delta: float) -> void:
	var target_position = camera_first_position if camera_first_person else camera_third_position
	$Camera3D.position = $Camera3D.position.lerp(target_position, camera_transition_speed * delta)
