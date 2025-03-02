extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_force: float = 10.0
@export var gravity: float = 20.0

func _physics_process(delta: float) -> void:
	var inp_dir = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		inp_dir.z -= 1
		print("elore")
	if Input.is_action_pressed("move_backward"):
		inp_dir.z += 1
		print("hatra")
	if Input.is_action_pressed("move_left"):
		inp_dir.x -= 1
		print("balra")
	if Input.is_action_pressed("move_right"):
		inp_dir.x += 1
		print("jobbra")

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
		print("jump")

	move_and_slide()
