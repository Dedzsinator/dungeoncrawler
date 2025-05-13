extends GPUParticles3D

func _ready():
    # Winter particles - snowflakes
    amount = 50
    lifetime = 7.0
    explosiveness = 0.0
    randomness = 0.5
    emitting = true
    
    # Set particle material
    var mat = ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(10, 0.1, 10)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 10.0
    mat.gravity = Vector3(0, -0.4, 0)
    mat.initial_velocity_min = 0.3
    mat.initial_velocity_max = 0.8
    mat.color = Color(0.9, 0.95, 1.0, 0.7) # Almost white for snow
    
    # Add gentle drift to snowflakes
    mat.tangential_accel_min = -0.5
    mat.tangential_accel_max = 0.5
    mat.damping_min = 0.1
    mat.damping_max = 0.3
    mat.angle_min = 0.0
    mat.angle_max = 360.0
    mat.scale_min = 0.05
    mat.scale_max = 0.12
    
    process_material = mat
    
    # Create mesh for particles (snowflakes)
    var mesh = QuadMesh.new()
    mesh.size = Vector2(0.08, 0.08)
    draw_pass_1 = mesh
