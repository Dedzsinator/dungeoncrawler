extends GPUParticles3D

func _ready():
    # Fall particles - falling leaves
    amount = 40
    lifetime = 6.0
    explosiveness = 0.0
    randomness = 0.8
    emitting = true
    
    # Set particle material
    var mat = ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(10, 0.1, 10)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 20.0
    mat.gravity = Vector3(0, -0.8, 0)
    mat.initial_velocity_min = 0.5
    mat.initial_velocity_max = 1.2
    
    # Create gradient for fall leaves
    var gradient = Gradient.new()
    gradient.colors = [
        Color(0.9, 0.3, 0.1, 0.8), # Red-orange
        Color(0.8, 0.5, 0.1, 0.8), # Orange-yellow
        Color(0.7, 0.4, 0.0, 0.8) # Brown-orange
    ]
    
    var ramp = GradientTexture1D.new()
    ramp.gradient = gradient
    mat.color_ramp = ramp
    
    process_material = mat
    
    # Create mesh for particles (falling leaves)
    var mesh = QuadMesh.new()
    mesh.size = Vector2(0.15, 0.15)
    draw_pass_1 = mesh
    
    # Add gentle swaying motion
    var tween = create_tween()
    tween.set_loops()
    tween.tween_property(process_material, "tangential_accel", 1.0, 3.0)
    tween.tween_property(process_material, "tangential_accel", -1.0, 3.0)
