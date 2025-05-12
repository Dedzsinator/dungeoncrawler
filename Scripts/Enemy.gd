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

# Visual feedback
@onready var model: MeshInstance3D = $MeshInstance3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_particles = $HitParticles

signal enemy_died(enemy)

func _ready():
    # Initialize variables - randomize health between 30-50
    max_health = randi_range(30, 50)
    health = max_health
    
    # Setup navigation
    nav_agent = NavigationAgent3D.new()
    add_child(nav_agent)
    nav_agent.path_desired_distance = 0.5
    nav_agent.target_desired_distance = 1.5
    
    # Find player
    player = get_tree().get_first_node_in_group("player")
    
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
    
    # Setup hit effect
    if not has_node("HitParticles"):
        var particles = GPUParticles3D.new()
        particles.name = "HitParticles"
        particles.emitting = false
        particles.one_shot = true
        particles.explosiveness = 1.0
        particles.amount = 10
        add_child(particles)
    
    # Start behavior tick
    var update_timer = Timer.new()
    update_timer.wait_time = 0.1
    update_timer.timeout.connect(_on_update_timer_timeout)
    add_child(update_timer)
    update_timer.start()

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
        
    # Update state based on player distance
    if player:
        var distance = global_position.distance_to(player.global_position)
        
        if distance <= attack_radius:
            state = "attack"
        elif distance <= detection_radius:
            state = "chase"
        else:
            state = "patrol"
    else:
        # Try to find player again
        player = get_tree().get_first_node_in_group("player")
        state = "idle"

func patrol_behavior(delta):
    # Simple random movement
    if randf() < 0.01: # Occasionally change direction
        var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
        velocity = random_dir * movement_speed * 0.5
    else:
        # Slow down gradually
        velocity = velocity.lerp(Vector3.ZERO, 0.1)

func chase_behavior(delta):
    if not player or not nav_agent.is_navigation_finished():
        return
        
    # Set target destination
    nav_agent.set_target_position(player.global_position)
    
    # Follow navigation path
    var next_pos = nav_agent.get_next_position()
    var direction = (next_pos - global_position).normalized()
    velocity = direction * movement_speed
    
    # Look at player (only Y-axis)
    look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

func attack_behavior(delta):
    if not player:
        return
        
    # Face the player
    look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
    
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
        player.change_health(-attack_damage)
        
        if has_node("AnimationPlayer"):
            $AnimationPlayer.play("attack")

func take_damage(amount):
    health -= amount
    
    # Apply knockback effect
    if player:
        is_being_knocked_back = true
        knockback_timer = knockback_duration
        knockback_direction = (global_position - player.global_position).normalized()
        knockback_direction.y = 0.3 # Add slight upward component
        velocity = knockback_direction * knockback_force
    
    # Visual feedback
    if has_node("HitParticles"):
        $HitParticles.restart()
        $HitParticles.emitting = true
    
    if has_node("MeshInstance3D"):
        # Flash red
        var original_color = $MeshInstance3D.get_surface_override_material(0).albedo_color
        $MeshInstance3D.get_surface_override_material(0).albedo_color = Color(1, 0, 0)
        
        # Return to original color after 0.1 seconds
        await get_tree().create_timer(0.1).timeout
        if is_instance_valid(self) and has_node("MeshInstance3D"):
            $MeshInstance3D.get_surface_override_material(0).albedo_color = original_color
    
    # Check if dead
    if health <= 0:
        die()

func die():
    state = "dead"
    
    # Death animation or effect
    if has_node("AnimationPlayer") and $AnimationPlayer.has_animation("death"):
        $AnimationPlayer.play("death")
        await $AnimationPlayer.animation_finished
    
    # Emit signal before removal
    emit_signal("enemy_died", self)
    
    # Remove from scene
    queue_free()