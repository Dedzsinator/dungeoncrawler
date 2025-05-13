extends GPUParticles3D

func _ready():
    # Summer particles - sun rays or heat waves
    amount = 20
    lifetime = 4.0
    explosiveness = 0.0
    randomness = 0.7
    emitting = true
    
    # Set particle material
    var mat = ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(10, 0.1, 10)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 15.0
    mat.gravity = Vector3(0, -1.0, 0)
    mat.initial_velocity_min = 0.3
    mat.initial_velocity_max = 0.7
    mat.color = Color(1, 0.9, 0.2, 0.7) # Yellow/gold for summer sun
    process_material = mat
    
    # Create mesh for particles
    var mesh = QuadMesh.new()
    mesh.size = Vector2(0.2, 0.2)
    draw_pass_1 = mesh
    
    # Add subtle pulsing effect
    var tween = create_tween()
    tween.set_loops()
    tween.tween_property(self, "speed_scale", 1.5, 2.0)
    tween.tween_property(self, "speed_scale", 1.0, 2.0)
