extends Node3D


@onready var warrior_scene: PackedScene = preload("res://Scenes/Monsters/SkeletonWarrior/skeleton_warrior.tscn")
@onready var walls_gridmap: GridMap = get_node("Walls")
@onready var walls2_gridmap: GridMap = get_node("Walls2")


func _ready() -> void:
	create_monsters(3, -36, -28, -38, 0)
	create_monsters(2, -24, -11, 6, 24)
	create_monsters(5, -24, 0, -38, 0)
	create_monsters(10, 0, 30, -38, 22)
	
	# Initialize RTX effects - using a call_deferred to avoid shader compilation issues
	call_deferred("setup_rtx")

func setup_rtx() -> void:
	# Get the existing environment or create a new one
	var world_env = get_node_or_null("WorldEnvironment")
	if not world_env:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		add_child(world_env)
		
		var env = Environment.new()
		world_env.environment = env
	
	# Configure minimal RTX-like effects with performance optimization
	var env = world_env.environment
	
	# SSAO (Ambient Occlusion) - cheaper than SSIL
	env.ssao_enabled = true
	env.ssao_radius = 1.0 # Lower radius for better performance
	env.ssao_intensity = 1.5
	
	# SSR (Screen Space Reflections) - for puddle reflections
	env.ssr_enabled = true
	env.ssr_max_steps = 32 # Reduced from 64 for performance
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.2
	
	# Glow - for highlighting effects
	env.glow_enabled = true
	env.glow_intensity = 0.5 # Reduced intensity for better performance
	
	# Setup skybox
	setup_skybox(env)
	
	# Add single, optimized reflection probe
	var rtx_setup = Node3D.new()
	rtx_setup.name = "RTXSetup"
	add_child(rtx_setup)
	
	var reflection_probe = ReflectionProbe.new()
	reflection_probe.name = "RTXReflectionProbe"
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	reflection_probe.size = Vector3(50, 20, 50)
	reflection_probe.origin_offset = Vector3(0, 0, 0)
	reflection_probe.interior = true
	reflection_probe.max_distance = 50.0
	rtx_setup.add_child(reflection_probe)
	
	# Create water puddles throughout the dungeon
	create_water_puddles(10) # Create 10 puddles

func setup_skybox(env: Environment) -> void:
	# Set background mode to sky
	env.background_mode = Environment.BG_SKY
	
	# Create a procedural sky
	var sky = ProceduralSky.new()
	
	# Configure sky colors for a dungeon-appropriate mood
	sky.sky_top_color = Color(0.05, 0.05, 0.1) # Dark blue-black at top
	sky.sky_horizon_color = Color(0.15, 0.15, 0.2) # Slightly lighter at horizon
	sky.sky_curve = 0.15 # Sharper transition to create more contrast
	
	# Ground colors (will be mostly invisible but affects reflections)
	sky.ground_bottom_color = Color(0.02, 0.02, 0.05) # Almost black
	sky.ground_horizon_color = Color(0.1, 0.1, 0.15) # Dark bluish
	sky.ground_curve = 0.05
	
	# Sun settings - minimal as we're in a dungeon
	sky.sun_color = Color(0.8, 0.7, 0.5, 0.2) # Warm but faint light
	sky.sun_latitude = 35.0
	sky.sun_longitude = 45.0
	sky.sun_angle_max = 30.0
	sky.sun_curve = 0.15
	
	# Apply sky to environment
	env.sky = sky
	
	# Add cubemap for enhanced reflections
	create_cubemap(env)

func create_cubemap(env: Environment) -> void:
	# Add a custom reflection cube map for water reflections
	# This gives a hint of ambient lighting even without direct skybox visibility
	# Ideally you would create/add a specific cubemap texture here
	# For now we'll rely on the procedural sky
	# Optional: Ambient light adjustment to enhance reflections
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.2, 0.3, 0.4) # Slightly blue tint
	env.ambient_light_energy = 0.5 # Subtle, not overpowering
	
	# Adjust reflection settings
	env.sky_custom_fov = 90.0
	env.reflected_light_source = Environment.REFLECTED_LIGHT_SOURCE_SKY

func create_water_puddles(count: int) -> void:
	var puddles_node = Node3D.new()
	puddles_node.name = "WaterPuddles"
	add_child(puddles_node)
	
	# Create a simple water material
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.1, 0.2, 0.3, 0.7)
	water_material.metallic = 0.9
	water_material.metallic_specular = 0.9
	water_material.roughness = 0.1
	water_material.refraction_enabled = true
	water_material.refraction_scale = 0.05
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var created_puddles = 0
	var attempts = 0
	var max_attempts = 100
	
	# Create a noise texture for random puddle shapes
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.fractal_octaves = 2
	noise.frequency = 0.1
	
	while created_puddles < count and attempts < max_attempts:
		attempts += 1
		
		# Find a suitable floor position
		var x_pos = randi_range(-30, 30)
		var z_pos = randi_range(-30, 30)
		
		if is_empty_cell(x_pos, z_pos):
			# Create puddle mesh with custom geometry for organic shape
			var puddle = MeshInstance3D.new()
			
			# Use ArrayMesh for custom puddle shape
			var arr_mesh = ArrayMesh.new()
			var surface_tool = SurfaceTool.new()
			surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			
			# Random puddle parameters
			var base_size = randf_range(2.0, 4.0) # Larger puddles
			var segments = 24 # Higher number gives smoother edges
			var center = Vector3.ZERO
			var min_radius = base_size * 0.4
			
			# Generate the puddle vertices with noise-based distortion
			for i in range(segments):
				var angle_1 = i * TAU / segments
				var angle_2 = (i + 1) * TAU / segments
				
				# Use noise to create irregular edges
				var noise_val_1 = (noise.get_noise_2d(cos(angle_1) * 2, sin(angle_1) * 2) * 0.5 + 0.5) * base_size
				var noise_val_2 = (noise.get_noise_2d(cos(angle_2) * 2, sin(angle_2) * 2) * 0.5 + 0.5) * base_size
				var radius_1 = max(min_radius, noise_val_1)
				var radius_2 = max(min_radius, noise_val_2)
				
				# Create vertices for triangles
				var v1 = center
				var v2 = Vector3(cos(angle_1) * radius_1, 0, sin(angle_1) * radius_1)
				var v3 = Vector3(cos(angle_2) * radius_2, 0, sin(angle_2) * radius_2)
				
				# Add normal and UV data
				surface_tool.set_normal(Vector3.UP)
				surface_tool.set_uv(Vector2(0.5, 0.5))
				surface_tool.add_vertex(v1)
				
				surface_tool.set_normal(Vector3.UP)
				surface_tool.set_uv(Vector2(cos(angle_1) * 0.5 + 0.5, sin(angle_1) * 0.5 + 0.5))
				surface_tool.add_vertex(v2)
				
				surface_tool.set_normal(Vector3.UP)
				surface_tool.set_uv(Vector2(cos(angle_2) * 0.5 + 0.5, sin(angle_2) * 0.5 + 0.5))
				surface_tool.add_vertex(v3)
			
			surface_tool.set_material(water_material)
			arr_mesh = surface_tool.commit()
			puddle.mesh = arr_mesh
			
			# Position slightly above floor to avoid z-fighting
			puddle.position = Vector3(x_pos, -1.99, z_pos)
			# Random rotation
			puddle.rotation.y = randf_range(0, TAU)
			
			puddles_node.add_child(puddle)
			created_puddles += 1
	
	# Add reflective wall highlights in a few spots
	add_reflective_wall_highlights()

func add_reflective_wall_highlights() -> void:
	var highlights_node = Node3D.new()
	highlights_node.name = "WallHighlights"
	add_child(highlights_node)
	
	# Create a reflective material for highlights
	var highlight_material = StandardMaterial3D.new()
	highlight_material.albedo_color = Color(0.8, 0.8, 0.9, 0.6)
	highlight_material.metallic = 1.0
	highlight_material.metallic_specular = 1.0
	highlight_material.roughness = 0.05
	highlight_material.emission_enabled = true
	highlight_material.emission = Color(0.1, 0.1, 0.2)
	highlight_material.emission_energy = 0.2
	
	# Find some walls to add highlights to
	var wall_positions = []
	
	# Scan for wall cells in the grid maps
	for x in range(-30, 30):
		for z in range(-30, 30):
			if not is_empty_cell(x, z):
				# Check if there's empty space adjacent to this wall
				if is_empty_cell(x + 1, z) or is_empty_cell(x - 1, z) or is_empty_cell(x, z + 1) or is_empty_cell(x, z - 1):
					wall_positions.append(Vector3(x, -1, z))
	
	# Add highlights to a selection of walls
	var highlight_count = min(5, wall_positions.size())
	for i in range(highlight_count):
		var pos_index = randi() % wall_positions.size()
		var wall_pos = wall_positions[pos_index]
		wall_positions.remove_at(pos_index)
		
		# Create a small glowing panel
		var highlight = MeshInstance3D.new()
		var highlight_mesh = QuadMesh.new()
		highlight_mesh.size = Vector2(randf_range(0.5, 1.0), randf_range(0.5, 1.0))
		
		highlight.mesh = highlight_mesh
		highlight.material_override = highlight_material
		
		# Position on the wall
		highlight.position = wall_pos + Vector3(0, randf_range(0, 1.0), 0)
		
		# Orient facing into the room
		if is_empty_cell(wall_pos.x + 1, wall_pos.z):
			highlight.rotation.y = deg_to_rad(90)
			highlight.position.x += 0.51
		elif is_empty_cell(wall_pos.x - 1, wall_pos.z):
			highlight.rotation.y = deg_to_rad(270)
			highlight.position.x -= 0.51
		elif is_empty_cell(wall_pos.x, wall_pos.z + 1):
			highlight.rotation.y = deg_to_rad(0)
			highlight.position.z += 0.51
		elif is_empty_cell(wall_pos.x, wall_pos.z - 1):
			highlight.rotation.y = deg_to_rad(180)
			highlight.position.z -= 0.51
		
		highlights_node.add_child(highlight)

func is_empty_cell(x_pos: int, z_pos: int) -> bool:
	var is_not_wall_tile := walls_gridmap.get_cell_item(Vector3i(x_pos, -1, z_pos)) == GridMap.INVALID_CELL_ITEM
	var is_not_wall_tile2 := walls2_gridmap.get_cell_item(Vector3i(x_pos, -1, z_pos)) == GridMap.INVALID_CELL_ITEM
	return is_not_wall_tile and is_not_wall_tile2

func create_monster(x_pos: int, z_pos: int) -> bool:
	is_empty_cell(x_pos, z_pos)
	var monster := warrior_scene.instantiate()
	if is_empty_cell(x_pos, z_pos):
		monster.position = Vector3i(x_pos, -2, z_pos)
		monster.player = get_node("Player")
		get_node("Monsters").add_child(monster)
		return true
	return false

func create_monsters(count: int, min_x_pos: int, max_x_pos: int, min_z_pos: int, max_z_pos: int) -> void:
	while true:
		var x_pos := randi_range(min_x_pos, max_x_pos)
		var z_pos := randi_range(min_z_pos, max_z_pos)
		if create_monster(x_pos, z_pos):
			count -= 1
			if count == 0:
				break
