extends Enemy
class_name TrailEnemy

@export var trail_damage_per_second: float = 15.0
@export var trail_lifetime: float = 3.0
@export var trail_interval: float = 0.2

var last_trail_pos = Vector3.ZERO
var trail_timer: float = 0.0
var trail_nodes = []

func _ready():
    super._ready()
    max_health = 90
    movement_speed = 3.2
    attack_damage = 8
    attack_radius = 1.5
    detection_radius = 12.0
    
    # Setup visuals for trail enemy
    if has_node("MeshInstance3D"):
        var material = StandardMaterial3D.new()
        material.albedo_color = Color(0.2, 0.8, 0.6) # Teal for trail
        material.emission_enabled = true
        material.emission = Color(0.0, 0.6, 0.4)
        material.emission_energy = 0.5
        $MeshInstance3D.material_override = material
    
    # Initialize last position
    last_trail_pos = global_position

func _physics_process(delta):
    super._physics_process(delta)
    
    # Update trail
    trail_timer += delta
    if trail_timer >= trail_interval and velocity.length() > 0.5:
        trail_timer = 0.0
        create_trail_node()

func create_trail_node():
    # Skip if too close to last trail
    if global_position.distance_to(last_trail_pos) < 0.5:
        return
        
    last_trail_pos = global_position
    
    # Create trail point
    var trail = Area3D.new()
    trail.name = "PoisonTrail"
    
    # Add collision shape
    var collision = CollisionShape3D.new()
    var shape = CylinderShape3D.new()
    shape.height = 0.1
    shape.radius = 0.4
    collision.shape = shape
    trail.add_child(collision)
    
    # Add visual
    var mesh_instance = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = 0.4
    mesh.bottom_radius = 0.4
    mesh.height = 0.1
    mesh_instance.mesh = mesh
    
    # Apply material
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.2, 0.8, 0.6, 0.7)
    material.emission_enabled = true
    material.emission = Color(0.0, 0.6, 0.4)
    material.emission_energy = 1.0
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mesh_instance.material_override = material
    
    trail.add_child(mesh_instance)
    
    # Add script with _init function
    var script = GDScript.new()
    script.source_code = """
    extends Area3D

    var damage_per_second = 15.0
    var lifetime = 3.0
    var elapsed_time = 0.0
    var damaging_bodies = {}
    
    func _init(p_damage = 15.0, p_lifetime = 3.0):
        damage_per_second = p_damage
        lifetime = p_lifetime
    
    func _ready():
        # Connect signals
        body_entered.connect(_on_body_entered)
        body_exited.connect(_on_body_exited)

    # Rest of script unchanged
    """
    
    # Set the script
    trail.set_script(script)

    # Add to scene
    get_tree().root.add_child(trail)
    trail.global_position = global_position
    trail.global_position.y = 0.05 # Slightly above ground

    # Set properties directly instead of calling _init()
    trail.damage_per_second = trail_damage_per_second
    trail.lifetime = trail_lifetime
    
    # Track trail nodes and when we spawned last
    trail_nodes.append(trail)
    trail_timer = 0.0
    
    # Limit number of trail nodes
    if trail_nodes.size() > 30:
        var oldest = trail_nodes.pop_front()
        if is_instance_valid(oldest):
            oldest.queue_free()

func die():
    # Remove all trail nodes
    for trail in trail_nodes:
        if is_instance_valid(trail):
            trail.queue_free()
            
    trail_nodes.clear()
    super.die()