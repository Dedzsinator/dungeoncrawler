extends Node

class_name SeasonManager

enum Season {SPRING, SUMMER, FALL, WINTER}

# Season properties
var current_season = Season.SPRING
var season_names = ["Spring", "Summer", "Fall", "Winter"]

# Season effect parameters
var spring_movement_modifier = 1.2 # Faster movement in spring
var summer_damage_modifier = 1.3 # More damage in summer
var fall_knockback_modifier = 1.5 # Stronger knockback in fall
var winter_slow_modifier = 0.7 # Slower movement in winter

# Visual effects for each season
var season_colors = {
    Season.SPRING: Color(0.5, 0.8, 0.5), # Green for spring
    Season.SUMMER: Color(0.9, 0.7, 0.4), # Yellow/orange for summer
    Season.FALL: Color(0.8, 0.4, 0.2), # Orange/red for fall
    Season.WINTER: Color(0.7, 0.8, 1.0) # Light blue for winter
}

var season_particles = {
    Season.SPRING: preload("res://Scripts/SpringParticles.gd"),
    Season.SUMMER: preload("res://Scripts/SummerParticles.gd"),
    Season.FALL: preload("res://Scripts/FallParticles.gd"),
    Season.WINTER: preload("res://Scripts/WinterParticles.gd")
}

# Select a random season
func select_random_season() -> int:
    var season = randi() % 4
    current_season = season
    print("Room season set to: " + season_names[season])
    return season

# Apply season effects to a room
func apply_season_to_room(room: Node3D) -> void:
    # Store the season in the room's metadata
    room.set_meta("season", current_season)
    
    # Apply visual effects
    apply_visual_effects(room)
    
    # Apply gameplay effects - these will be picked up by enemies and players
    room.set_meta("movement_modifier", get_movement_modifier())
    room.set_meta("damage_modifier", get_damage_modifier())
    room.set_meta("knockback_modifier", get_knockback_modifier())
    
    print("Applied " + season_names[current_season] + " effects to room")

# Get the current movement speed modifier based on season
func get_movement_modifier() -> float:
    match current_season:
        Season.SPRING:
            return spring_movement_modifier
        Season.WINTER:
            return winter_slow_modifier
        _:
            return 1.0

# Get the current damage modifier based on season
func get_damage_modifier() -> float:
    match current_season:
        Season.SUMMER:
            return summer_damage_modifier
        _:
            return 1.0

# Get the current knockback modifier based on season
func get_knockback_modifier() -> float:
    match current_season:
        Season.FALL:
            return fall_knockback_modifier
        _:
            return 1.0

# Apply visual effects to the room based on season
func apply_visual_effects(room: Node3D) -> void:
    # Change lighting based on season
    var light = DirectionalLight3D.new()
    light.name = "SeasonLight"
    light.light_color = season_colors[current_season]
    
    # Adjust light intensity based on season
    match current_season:
        Season.SUMMER:
            light.light_energy = 1.5
        Season.WINTER:
            light.light_energy = 0.8
        _:
            light.light_energy = 1.0
    
    # Add season-specific particles
    add_season_particles(room)
    
    # Add the light to the room
    room.add_child(light)

# Add season-specific particle effects
func add_season_particles(room: Node3D) -> void:
    # Create appropriate particle effect based on season
    var particles = GPUParticles3D.new()
    particles.name = "SeasonParticles"
    
    match current_season:
        Season.SPRING:
            setup_spring_particles(particles)
        Season.SUMMER:
            setup_summer_particles(particles)
        Season.FALL:
            setup_fall_particles(particles)
        Season.WINTER:
            setup_winter_particles(particles)
    
    # Position particles in the center of the room, near the ceiling
    var bounds = get_room_bounds(room)
    if bounds:
        particles.position = Vector3(
            (bounds.min_pos.x + bounds.max_pos.x) / 2,
            bounds.max_pos.y - 1.0,
            (bounds.min_pos.z + bounds.max_pos.z) / 2
        )
    else:
        # Default position if can't determine bounds
        particles.position = Vector3(0, 4, 0)
    
    room.add_child(particles)

# Helper function to get room bounds
func get_room_bounds(room: Node3D) -> Dictionary:
    var result = {}
    
    # Check if room has a detector with collision shape
    var detector = room.get_node_or_null("RoomDetector")
    if detector and detector.get_child_count() > 0:
        var shape = detector.get_child(0)
        if shape is CollisionShape3D:
            var collision_shape = shape.shape
            if collision_shape is BoxShape3D:
                var size = collision_shape.size
                var position = shape.global_position
                
                result = {
                    "min_pos": position - size / 2,
                    "max_pos": position + size / 2
                }
    
    return result

# Setup particle effects for Spring
func setup_spring_particles(particles: GPUParticles3D) -> void:
    particles.amount = 30
    particles.lifetime = 8.0
    particles.explosiveness = 0.0
    particles.randomness = 0.5
    particles.emitting = true
    
    # Set particle material
    var mat = ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(10, 0.1, 10)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 10.0
    mat.gravity = Vector3(0, -0.5, 0)
    mat.initial_velocity_min = 0.5
    mat.initial_velocity_max = 1.0
    mat.color = Color(1, 1, 1, 0.5)
    particles.process_material = mat
    
    # Create mesh for particles (butterflies or pollen)
    var mesh = QuadMesh.new()
    mesh.size = Vector2(0.1, 0.1)
    particles.draw_pass_1 = mesh

# Setup particle effects for Summer
func setup_summer_particles(particles: GPUParticles3D) -> void:
    particles.amount = 20
    particles.lifetime = 4.0
    particles.explosiveness = 0.0
    particles.randomness = 0.7
    particles.emitting = true
    
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
    particles.process_material = mat
    
    # Create mesh for particles (sun rays or heat waves)
    var mesh = QuadMesh.new()
    mesh.size = Vector2(0.2, 0.2)
    particles.draw_pass_1 = mesh

# Setup particle effects for Fall
func setup_fall_particles(particles: GPUParticles3D) -> void:
    particles.amount = 40
    particles.lifetime = 6.0
    particles.explosiveness = 0.0
    particles.randomness = 0.8
    particles.emitting = true
    
    # Set particle material
    var mat = ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(10, 0.1, 10)
    mat.direction = Vector3(0, -1, 0)
    mat.spread = 20.0
    mat.gravity = Vector3(0, -0.8, 0)
    mat.initial_velocity_min = 0.5
    mat.initial_velocity_max = 1.2
    mat.color_ramp = create_fall_color_ramp()
    particles.process_material = mat
    
    # Create mesh for particles (falling leaves)
    var mesh = QuadMesh.new()
    mesh.size = Vector2(0.15, 0.15)
    particles.draw_pass_1 = mesh

# Setup particle effects for Winter
func setup_winter_particles(particles: GPUParticles3D) -> void:
    particles.amount = 50
    particles.lifetime = 7.0
    particles.explosiveness = 0.0
    particles.randomness = 0.5
    particles.emitting = true
    
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
    particles.process_material = mat
    
    # Create mesh for particles (snowflakes)
    var mesh = QuadMesh.new()
    mesh.size = Vector2(0.08, 0.08)
    particles.draw_pass_1 = mesh

# Create a color gradient for fall leaves
func create_fall_color_ramp() -> Gradient:
    var gradient = Gradient.new()
    gradient.colors = [
        Color(0.9, 0.3, 0.1, 0.8), # Red-orange
        Color(0.8, 0.5, 0.1, 0.8), # Orange-yellow
        Color(0.7, 0.4, 0.0, 0.8) # Brown-orange
    ]
    return gradient
