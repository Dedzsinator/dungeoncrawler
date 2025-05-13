extends GPUParticles3D

func _ready():
    # Spring particles - pollen or butterflies
    amount = 30
    lifetime = 8.0
    explosiveness = 0.0
    randomness = 0.5
    emitting = true
    
    # Set particle material
    var mat = ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(10, 0.1, 10)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 10.0
    mat.gravity = Vector3(0, -0.5, 0)
    mat.initial_velocity_min = 0.5
    mat.initial_velocity_max = 1.0
    mat.color = Color(1.0, 1.0, 0.8, 0.5) # Light yellow for pollen
    process_material = mat
    
    # Create mesh for particles
    var mesh = QuadMesh.new()
    mesh.size = Vector2(0.1, 0.1)
    draw_pass_1 = mesh
