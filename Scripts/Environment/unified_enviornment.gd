# Scripts/Environment/unified_enviornment.gd
extends WorldEnvironment
class_name UnifiedEnvironment

# Time settings
@export var day_duration: float = 300.0 # 5 minutes per full day/night cycle
@export var start_time: float = 0.25 # Start at dawn (0.0 = midnight, 0.5 = noon)
@export var time_speed_multiplier: float = 1.0
@export var auto_start: bool = true

# Sky gradient colors for different times
@export_group("Dawn Colors (5-7 AM)")
@export var dawn_sky_top: Color = Color(0.4, 0.6, 0.9, 1.0)
@export var dawn_sky_horizon: Color = Color(1.0, 0.7, 0.4, 1.0)
@export var dawn_ground_bottom: Color = Color(0.1, 0.1, 0.2, 1.0)
@export var dawn_ground_horizon: Color = Color(0.8, 0.6, 0.4, 1.0)

@export_group("Morning Colors (7-10 AM)")
@export var morning_sky_top: Color = Color(0.5, 0.8, 1.0, 1.0)
@export var morning_sky_horizon: Color = Color(0.8, 0.9, 1.0, 1.0)
@export var morning_ground_bottom: Color = Color(0.2, 0.3, 0.4, 1.0)
@export var morning_ground_horizon: Color = Color(0.6, 0.7, 0.8, 1.0)

@export_group("Day Colors (10 AM - 4 PM)")
@export var day_sky_top: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var day_sky_horizon: Color = Color(0.6, 0.8, 1.0, 1.0)
@export var day_ground_bottom: Color = Color(0.3, 0.4, 0.5, 1.0)
@export var day_ground_horizon: Color = Color(0.7, 0.8, 0.9, 1.0)

@export_group("Evening Colors (4-7 PM)")
@export var evening_sky_top: Color = Color(0.3, 0.4, 0.7, 1.0)
@export var evening_sky_horizon: Color = Color(1.0, 0.6, 0.3, 1.0)
@export var evening_ground_bottom: Color = Color(0.2, 0.2, 0.3, 1.0)
@export var evening_ground_horizon: Color = Color(0.9, 0.5, 0.3, 1.0)

@export_group("Sunset Colors (7-8 PM)")
@export var sunset_sky_top: Color = Color(0.2, 0.3, 0.6, 1.0)
@export var sunset_sky_horizon: Color = Color(1.0, 0.4, 0.2, 1.0)
@export var sunset_ground_bottom: Color = Color(0.1, 0.1, 0.2, 1.0)
@export var sunset_ground_horizon: Color = Color(1.0, 0.3, 0.2, 1.0)

@export_group("Night Colors (8 PM - 5 AM)")
@export var night_sky_top: Color = Color(0.05, 0.05, 0.2, 1.0)
@export var night_sky_horizon: Color = Color(0.1, 0.1, 0.3, 1.0)
@export var night_ground_bottom: Color = Color(0.02, 0.02, 0.05, 1.0)
@export var night_ground_horizon: Color = Color(0.05, 0.05, 0.1, 1.0)

@export_group("Sun Settings")
@export var sun_color_day: Color = Color(1.0, 0.95, 0.8, 1.0)
@export var sun_color_dawn: Color = Color(1.0, 0.7, 0.4, 1.0)
@export var sun_color_sunset: Color = Color(1.0, 0.5, 0.2, 1.0)
@export var sun_energy_max: float = 1.5

@export_group("Ambient Settings")
@export var ambient_energy_day: float = 0.4
@export var ambient_energy_night: float = 0.1

@export_group("Fog Settings")
@export var fog_density_day: float = 0.01
@export var fog_density_night: float = 0.03
@export var fog_color_day: Color = Color(0.7, 0.8, 0.9, 1.0)
@export var fog_color_night: Color = Color(0.2, 0.2, 0.4, 1.0)

# Current time and references
var current_time: float = 0.25
var time_of_day_text: String = "Dawn"
var sky_material: ProceduralSkyMaterial
var directional_light: DirectionalLight3D
var star_particles: GPUParticles3D
var star_material: ParticleProcessMaterial

# Signals
signal time_changed(new_time: float, time_text: String)
signal day_phase_changed(phase: String)

func _ready():
    add_to_group("unified_environment")
    
    if auto_start:
        setup_unified_environment()
    
    print("Unified environment initialized")

func setup_unified_environment():
    current_time = start_time
    
    # Get references to materials from existing environment
    if environment and environment.sky and environment.sky.sky_material:
        sky_material = environment.sky.sky_material as ProceduralSkyMaterial
        print("Found existing sky material")
    else:
        print("Warning: No sky material found in environment")
        return
    
    # Setup directional light
    setup_directional_light()
    
    # Setup star field
    setup_star_field()
    
    # Initial update
    update_all_effects()
    
    print("Unified environment setup complete")

func _process(delta):
    if not auto_start:
        return
    
    # Update time
    current_time += (delta * time_speed_multiplier) / day_duration
    if current_time >= 1.0:
        current_time -= 1.0
    
    # Update all visual elements
    update_all_effects()
    
    # Emit signals
    emit_signal("time_changed", current_time, time_of_day_text)

func update_all_effects():
    update_skybox()
    update_sun_moon()
    update_lighting()
    update_fog()
    update_stars()
    update_time_text()

func setup_directional_light():
    # Find existing directional light
    directional_light = find_directional_light_in_scene()
    
    if directional_light:
        print("Using existing DirectionalLight3D for unified environment")
    else:
        # Create new directional light
        directional_light = DirectionalLight3D.new()
        directional_light.name = "UnifiedSun"
        get_parent().add_child(directional_light)
        print("Created new DirectionalLight3D for unified environment")
    
    # Configure shadows
    directional_light.shadow_enabled = true
    directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    directional_light.directional_shadow_max_distance = 25.0
    directional_light.shadow_bias = 0.1
    directional_light.shadow_normal_bias = 1.0

func find_directional_light_in_scene() -> DirectionalLight3D:
    var scene_root = get_tree().current_scene
    return find_directional_light_recursive(scene_root)

func find_directional_light_recursive(node: Node) -> DirectionalLight3D:
    if node is DirectionalLight3D:
        return node as DirectionalLight3D
    
    for child in node.get_children():
        var result = find_directional_light_recursive(child)
        if result:
            return result
    
    return null

func setup_star_field():
    # Create star particle system
    star_particles = GPUParticles3D.new()
    star_particles.name = "UnifiedStarField"
    star_particles.emitting = true
    star_particles.amount = 1000
    star_particles.lifetime = 60.0
    star_particles.visibility_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 50, 200))
    
    # Create star material
    star_material = ParticleProcessMaterial.new()
    star_material.direction = Vector3(0, 0, 0)
    star_material.initial_velocity_min = 0.0
    star_material.initial_velocity_max = 0.0
    star_material.gravity = Vector3(0, 0, 0)
    star_material.scale_min = 0.1
    star_material.scale_max = 0.3
    star_material.color = Color(1.0, 1.0, 1.0, 1.0)
    
    # Star gradient
    var star_gradient = Gradient.new()
    star_gradient.add_point(0.0, Color.WHITE)
    star_gradient.add_point(0.3, Color(0.8, 0.9, 1.0))
    star_gradient.add_point(0.6, Color(1.0, 0.9, 0.7))
    star_gradient.add_point(1.0, Color(0.9, 0.8, 1.0))
    
    var star_gradient_texture = GradientTexture1D.new()
    star_gradient_texture.gradient = star_gradient
    star_material.color_ramp = star_gradient_texture
    
    # Emission setup
    star_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    star_material.emission_sphere_radius = 80.0
    
    star_particles.process_material = star_material
    
    # Star mesh
    var star_mesh = QuadMesh.new()
    star_mesh.size = Vector2(0.5, 0.5)
    star_particles.draw_pass_1 = star_mesh
    
    add_child(star_particles)

func update_skybox():
    if not sky_material:
        print("Warning: No sky material available")
        return
    
    var sky_colors = get_sky_colors_for_time(current_time)
    
    sky_material.sky_top_color = sky_colors.sky_top
    sky_material.sky_horizon_color = sky_colors.sky_horizon
    sky_material.ground_bottom_color = sky_colors.ground_bottom
    sky_material.ground_horizon_color = sky_colors.ground_horizon

func get_sky_colors_for_time(time: float) -> Dictionary:
    if time >= 0.0 and time < 0.2: # Night
        return interpolate_colors(night_sky_top, night_sky_horizon, night_ground_bottom, night_ground_horizon)
    elif time >= 0.2 and time < 0.29: # Dawn
        var factor = (time - 0.2) / 0.09
        return lerp_sky_colors(get_night_colors(), get_dawn_colors(), factor)
    elif time >= 0.29 and time < 0.42: # Morning
        var factor = (time - 0.29) / 0.13
        return lerp_sky_colors(get_dawn_colors(), get_morning_colors(), factor)
    elif time >= 0.42 and time < 0.67: # Day
        var factor = (time - 0.42) / 0.25
        return lerp_sky_colors(get_morning_colors(), get_day_colors(), factor)
    elif time >= 0.67 and time < 0.79: # Evening
        var factor = (time - 0.67) / 0.12
        return lerp_sky_colors(get_day_colors(), get_evening_colors(), factor)
    elif time >= 0.79 and time < 0.83: # Sunset
        var factor = (time - 0.79) / 0.04
        return lerp_sky_colors(get_evening_colors(), get_sunset_colors(), factor)
    else: # Night
        var factor = (time - 0.83) / 0.17
        return lerp_sky_colors(get_sunset_colors(), get_night_colors(), factor)

func get_night_colors() -> Dictionary:
    return interpolate_colors(night_sky_top, night_sky_horizon, night_ground_bottom, night_ground_horizon)

func get_dawn_colors() -> Dictionary:
    return interpolate_colors(dawn_sky_top, dawn_sky_horizon, dawn_ground_bottom, dawn_ground_horizon)

func get_morning_colors() -> Dictionary:
    return interpolate_colors(morning_sky_top, morning_sky_horizon, morning_ground_bottom, morning_ground_horizon)

func get_day_colors() -> Dictionary:
    return interpolate_colors(day_sky_top, day_sky_horizon, day_ground_bottom, day_ground_horizon)

func get_evening_colors() -> Dictionary:
    return interpolate_colors(evening_sky_top, evening_sky_horizon, evening_ground_bottom, evening_ground_horizon)

func get_sunset_colors() -> Dictionary:
    return interpolate_colors(sunset_sky_top, sunset_sky_horizon, sunset_ground_bottom, sunset_ground_horizon)

func interpolate_colors(sky_top: Color, sky_horizon: Color, ground_bottom: Color, ground_horizon: Color) -> Dictionary:
    return {
        "sky_top": sky_top,
        "sky_horizon": sky_horizon,
        "ground_bottom": ground_bottom,
        "ground_horizon": ground_horizon
    }

func lerp_sky_colors(colors1: Dictionary, colors2: Dictionary, factor: float) -> Dictionary:
    return {
        "sky_top": colors1.sky_top.lerp(colors2.sky_top, factor),
        "sky_horizon": colors1.sky_horizon.lerp(colors2.sky_horizon, factor),
        "ground_bottom": colors1.ground_bottom.lerp(colors2.ground_bottom, factor),
        "ground_horizon": colors1.ground_horizon.lerp(colors2.ground_horizon, factor)
    }

func update_sun_moon():
    if not directional_light:
        print("Warning: No directional light found")
        return
    
    # Calculate sun position
    var sun_angle = (current_time - 0.5) * PI
    var sun_height = sin(sun_angle * 2)
    
    var sun_direction = Vector3(
        cos(sun_angle * 2) * 0.5,
        -sun_height,
        sin(sun_angle * 2) * 0.3
    ).normalized()
    
    directional_light.transform.basis = Basis.looking_at(sun_direction, Vector3.UP)
    
    # Sun energy and color
    var sun_energy = 0.0
    if sun_height > 0:
        sun_energy = sun_height * sun_energy_max
    
    directional_light.light_energy = sun_energy
    directional_light.light_color = get_sun_color_for_time(current_time)
    directional_light.visible = sun_height > -0.1
    
    # Debug print for sun
    if fmod(Time.get_time_dict_from_system()["second"], 5) == 0:
        print("Sun height: ", sun_height, " Energy: ", sun_energy, " Visible: ", directional_light.visible)

func get_sun_color_for_time(time: float) -> Color:
    if time >= 0.2 and time < 0.35: # Dawn
        var factor = (time - 0.2) / 0.15
        return sun_color_dawn.lerp(sun_color_day, factor)
    elif time >= 0.35 and time < 0.75: # Day
        return sun_color_day
    elif time >= 0.75 and time < 0.85: # Sunset
        var factor = (time - 0.75) / 0.1
        return sun_color_day.lerp(sun_color_sunset, factor)
    else:
        return sun_color_sunset

func update_lighting():
    if not environment:
        return
    
    var is_day = current_time > 0.25 and current_time < 0.75
    var ambient_factor = 1.0 if is_day else 0.3
    
    environment.ambient_light_energy = lerp(ambient_energy_night, ambient_energy_day, ambient_factor)

func update_fog():
    if not environment:
        return
    
    var is_day = current_time > 0.3 and current_time < 0.7
    var fog_factor = 1.0 if is_day else 0.3
    
    environment.fog_density = lerp(fog_density_night, fog_density_day, fog_factor)
    environment.fog_light_color = fog_color_day.lerp(fog_color_night, 1.0 - fog_factor)

func update_stars():
    if not star_particles or not star_material:
        print("Warning: No star particles or material found")
        return
    
    var star_visibility = 0.0
    
    if current_time <= 0.25 or current_time >= 0.75:
        star_visibility = 1.0
    elif current_time <= 0.35:
        star_visibility = (0.35 - current_time) / 0.1
    elif current_time >= 0.65:
        star_visibility = (current_time - 0.65) / 0.1
    
    star_particles.emitting = star_visibility > 0.1
    
    var current_color = star_material.color
    var new_alpha = lerp(current_color.a, star_visibility, 0.02)
    star_material.color = Color(current_color.r, current_color.g, current_color.b, new_alpha)
    
    # Debug print for stars
    if fmod(Time.get_time_dict_from_system()["second"], 5) == 0:
        print("Star visibility: ", star_visibility, " Emitting: ", star_particles.emitting)

func update_time_text():
    var hour = int(current_time * 24)
    var minute = int((current_time * 24 - hour) * 60)
    var time_string = "%02d:%02d" % [hour, minute]
    
    if current_time >= 0.0 and current_time < 0.2:
        time_of_day_text = "Night (%s)" % time_string
    elif current_time >= 0.2 and current_time < 0.29:
        time_of_day_text = "Dawn (%s)" % time_string
    elif current_time >= 0.29 and current_time < 0.42:
        time_of_day_text = "Morning (%s)" % time_string
    elif current_time >= 0.42 and current_time < 0.67:
        time_of_day_text = "Day (%s)" % time_string
    elif current_time >= 0.67 and current_time < 0.79:
        time_of_day_text = "Evening (%s)" % time_string
    elif current_time >= 0.79 and current_time < 0.83:
        time_of_day_text = "Sunset (%s)" % time_string
    else:
        time_of_day_text = "Night (%s)" % time_string

# Public control methods
func set_time(new_time: float):
    current_time = clamp(new_time, 0.0, 1.0)
    update_all_effects()

func set_time_of_day(hour: int, minute: int = 0):
    var time_decimal = (hour + minute / 60.0) / 24.0
    set_time(time_decimal)

func is_day_time() -> bool:
    return current_time > 0.25 and current_time < 0.75

func is_night_time() -> bool:
    return not is_day_time()

func set_time_speed(multiplier: float):
    time_speed_multiplier = multiplier

func pause_time():
    time_speed_multiplier = 0.0

func resume_time():
    time_speed_multiplier = 1.0