extends Enemy
class_name SwarmEnemy

@export var swarm_count: int = 5
@export var swarm_radius: float = 1.5
@export var rotation_speed: float = 2.0

var swarm_members = []
var time_offset = 0

func _ready():
    super._ready()
    max_health = 120 # Total swarm health
    movement_speed = 1.8
    attack_damage = 5 # Per swarm member
    attack_radius = 1.2
    detection_radius = 10.0
    
    time_offset = randf() * 10.0
    
    # Create swarm members
    for i in range(swarm_count):
        var swarm_member = create_swarm_member(i)
        swarm_members.append(swarm_member)
        add_child(swarm_member)

func create_swarm_member(index: int) -> Node3D:
    var member = Node3D.new()
    member.name = "SwarmMember" + str(index)
    
    # Add visual mesh
    var mesh_instance = MeshInstance3D.new()
    var mesh = SphereMesh.new()
    mesh.radius = 0.3
    mesh.height = 0.6
    mesh_instance.mesh = mesh
    
    # Apply material
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.8, 0.8, 0.2) # Yellow for swarm
    mesh_instance.material_override = material
    
    member.add_child(mesh_instance)
    
    # Add area for damage detection
    var area = Area3D.new()
    var collision = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 0.3
    collision.shape = shape
    area.add_child(collision)
    member.add_child(area)
    
    # Connect damage signal
    area.body_entered.connect(func(body):
        if body.is_in_group("player") and state == "attack":
            body.change_health(-attack_damage)
    )
    
    return member

func _physics_process(delta):
    super._physics_process(delta)
    update_swarm_positions(delta)

func update_swarm_positions(delta):
    var time = Time.get_ticks_msec() / 1000.0 + time_offset
    
    # Update each swarm member's position in a circular pattern
    for i in range(swarm_members.size()):
        var member = swarm_members[i]
        if member:
            # Calculate position in circular pattern around center
            var angle = time * rotation_speed + (i * 2 * PI / swarm_count)
            var radius = swarm_radius * (0.8 + 0.2 * sin(time * 2 + i))
            var offset = Vector3(cos(angle) * radius, 0.5 * sin(time * 3 + i), sin(angle) * radius)
            
            # Set position relative to swarm center
            member.position = offset

func take_damage(amount):
    health -= amount
    
    # Remove a swarm member when damaged enough
    var health_per_member = max_health / swarm_count
    var remaining_members = ceil(health / health_per_member)
    
    # Remove excess members
    while swarm_members.size() > remaining_members and swarm_members.size() > 0:
        var member = swarm_members.pop_back()
        if member:
            member.queue_free()
    
    # Check if dead (all members gone)
    if health <= 0 or swarm_members.size() == 0:
        die()
    else:
        # Visual feedback
        for member in swarm_members:
            if member and member.get_child(0) is MeshInstance3D:
                var mesh = member.get_child(0) as MeshInstance3D
                var original_color = mesh.material_override.albedo_color
                mesh.material_override.albedo_color = Color(1, 0, 0)
                
                # Return to original color after 0.1 seconds
                await get_tree().create_timer(0.1).timeout
                if is_instance_valid(mesh):
                    mesh.material_override.albedo_color = original_color