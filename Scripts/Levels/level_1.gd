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
	
	# Setup basic environment effects as a fallback
	var env = world_env.environment
	env.ssao_enabled = true
	env.ssr_enabled = true
	env.glow_enabled = true
	
	# Setup skybox
	setup_skybox(env)
	
	# Add proper ray tracing using the addon
	setup_raytracing_addon()
	
	# Apply RTX materials to walls
	apply_rtx_materials_to_walls()
	
	# Create water puddles for additional reflection effects
	create_water_puddles(10)

func apply_rtx_materials_to_walls() -> void:
	# Load the RTX wall material
	var rtx_wall_material = load("res://Materials/rtx_wall_material.tres")
	
	if not rtx_wall_material:
		print("ERROR: Could not load RTX wall material")
		return
	
	# Apply to GridMap cells - this approach gets the internal MeshInstances of the GridMap
	# Process first wall grid
	if walls_gridmap:
		# Get meshes using the correct approach for Godot 4
		var mesh_instances = walls_gridmap.get_meshes()
		
		# Debug to understand the structure
		if mesh_instances.size() > 0:
			print("First mesh_data type: ", typeof(mesh_instances[0]))
			
		for mesh_data in mesh_instances:
			# Check if mesh_data is an array or a Transform3D
			if typeof(mesh_data) == TYPE_ARRAY and mesh_data.size() >= 2:
				if mesh_data[1] is MeshInstance3D:
					var mesh_instance = mesh_data[1]
					mesh_instance.material_override = rtx_wall_material
			elif mesh_data is MeshInstance3D:
				# If mesh_data is directly a MeshInstance3D
				mesh_data.material_override = rtx_wall_material
	
	# Similar change for the second wall grid
	if walls2_gridmap:
		# Get meshes using the correct approach for Godot 4
		var mesh_instances = walls2_gridmap.get_meshes()
		for mesh_data in mesh_instances:
			if typeof(mesh_data) == TYPE_ARRAY and mesh_data.size() >= 2:
				if mesh_data[1] is MeshInstance3D:
					var mesh_instance = mesh_data[1]
					mesh_instance.material_override = rtx_wall_material
			elif mesh_data is MeshInstance3D:
				mesh_data.material_override = rtx_wall_material
	
	# Alternative approach to find all wall-like objects in the scene
	var all_meshes = get_tree().get_nodes_in_group("MeshInstance3D")
	for mesh in all_meshes:
		if mesh is MeshInstance3D:
			var name_lower = mesh.name.to_lower()
			if "wall" in name_lower or "pillar" in name_lower or "column" in name_lower:
				mesh.material_override = rtx_wall_material

func setup_raytracing_addon() -> void:
	# Create container for RTX components
	var rtx_node = Node3D.new()
	rtx_node.name = "RTXSetup"
	add_child(rtx_node)
	
	# Load the ray tracing main panel scene from the addon with correct path
	# The path shown in your project structure is different from what you were using
	var rtx_scene_path = "res://addons/RayTracing/godot/addons/RayTracing/main_panel.tscn"
	var rtx_scene = load(rtx_scene_path)
	
	# Try alternative paths if the first one fails
	if not rtx_scene:
		rtx_scene_path = "res://addons/RayTracing/main_panel.tscn"
		rtx_scene = load(rtx_scene_path)
	
	if rtx_scene:
		print("RTX scene loaded successfully from: " + rtx_scene_path)
		var rtx_instance = rtx_scene.instantiate()
		rtx_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		
		# Add the instance first so we can find its children
		rtx_node.add_child(rtx_instance)
		
		# Configure RTX parameters - modified to use correct path structure
		# Wait one frame to ensure the node structure is fully initialized
		await get_tree().process_frame
		
		# Look for shader rect in various possible paths based on the addon structure
		var shader_rect = rtx_instance.find_child("ShaderRect", true)
		if shader_rect and shader_rect.material:
			print("Found ShaderRect, configuring RTX parameters")
			var material = shader_rect.material
			material.set_shader_parameter("camera_gamma", 2.2)
			material.set_shader_parameter("camera_exposure", 1.6)
			material.set_shader_parameter("light_quality", 0.2)
			material.set_shader_parameter("camera_aperture", 0.01)
			material.set_shader_parameter("denoise", true)
		
		# Setup reflection probe for non-raytraced reflections as fallback
		var reflection_probe = ReflectionProbe.new()
		reflection_probe.name = "RTXReflectionProbe"
		reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
		reflection_probe.size = Vector3(50, 20, 50)
		reflection_probe.interior = true
		reflection_probe.max_distance = 50.0
		rtx_node.add_child(reflection_probe)
	else:
		# Fallback if addon can't be loaded
		print("ERROR: Could not load RTX addon scene. Tried paths:")
		print("  - res://addons/RayTracing/godot/addons/RayTracing/main_panel.tscn")
		print("  - res://addons/RayTracing/main_panel.tscn")
		
		# Add a standard reflection probe
		var reflection_probe = ReflectionProbe.new()
		reflection_probe.name = "RTXReflectionProbe"
		reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
		reflection_probe.size = Vector3(50, 20, 50)
		reflection_probe.interior = true
		reflection_probe.max_distance = 50.0
		rtx_node.add_child(reflection_probe)
		
		# Use enhanced lighting and reflection settings as fallback
		enhance_environment_fallback()
		
func enhance_environment_fallback() -> void:
	# Get environment and enhance it as fallback when RTX fails
	var world_env = get_node_or_null("WorldEnvironment")
	if world_env and world_env.environment:
		var env = world_env.environment
		
		# More intense SSR for better reflections without RTX
		env.ssr_enabled = true
		env.ssr_max_steps = 128
		env.ssr_fade_in = 0.15
		env.ssr_fade_out = 2.0
		env.ssr_depth_tolerance = 0.1
		
		# Enhance SSAO for better ambient shadows
		env.ssao_enabled = true
		env.ssao_radius = 3.0
		env.ssao_intensity = 3.0
		env.ssao_detail = 3.0
		
		# Add glow with better settings
		env.glow_enabled = true
		env.glow_intensity = 0.8
		env.glow_bloom = 0.1

func setup_skybox(env: Environment) -> void:
	# Set background mode to sky
	env.background_mode = Environment.BG_SKY
	
	# Create a sky using the Sky class
	var sky = Sky.new()
	var sky_material = PhysicalSkyMaterial.new()
	
	# Configure sky colors for a dungeon-appropriate mood
	sky_material.rayleigh_color = Color(0.05, 0.05, 0.1) # Dark blue-black for atmosphere
	sky_material.ground_color = Color(0.02, 0.02, 0.05) # Almost black ground
	
	# Adjust sun properties
	sky_material.sun_disk_scale = 0.5 # Smaller sun
	sky_material.energy_multiplier = 0.2 # Lower energy for dungeon feeling
	
	# Apply material to sky
	sky.sky_material = sky_material
	
	# Set sky in environment
	env.sky = sky
	
	# Add ambient and reflection settings
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.2, 0.3, 0.4) # Slightly blue tint
	env.ambient_light_energy = 0.5 # Subtle, not overpowering
	
	# Adjust reflection settings using available constants
	env.sky_custom_fov = 90.0
	
	# Remove this line that's causing the error
	# env.background_energy = 0.5

func create_cubemap(env: Environment) -> void:
	# Add a custom reflection cube map for water reflections
	# This gives a hint of ambient lighting even without direct skybox visibility
	# Optional: Ambient light adjustment to enhance reflections
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.2, 0.3, 0.4) # Slightly blue tint
	env.ambient_light_energy = 0.5 # Subtle, not overpowering
	
	# Adjust reflection settings
	env.sky_custom_fov = 90.0
	
func create_water_puddles(count: int) -> void:
	var puddles_node = Node3D.new()
	puddles_node.name = "WaterPuddles"
	add_child(puddles_node)
	
	# Reference the preloaded water puddle scene
	var puddle_scene = preload("res://Scenes/water_puddle.tscn")
	
	# Create a fallback material in case the scene doesn't use it
	var water_material = load("res://Materials/water_puddle_material.tres")
	
	var created_puddles = 0
	var attempts = 0
	var max_attempts = 100
	
	while created_puddles < count and attempts < max_attempts:
		attempts += 1
		
		# Find a suitable floor position
		var x_pos = randi_range(-30, 30)
		var z_pos = randi_range(-30, 30)
		
		if is_empty_cell(x_pos, z_pos):
			# Instantiate the puddle model
			var puddle = puddle_scene.instantiate()
			
			# Disable any lights or cameras that might be in the scene
			for child in puddle.get_children():
				if child is Light3D:
					child.visible = false
				elif child is Camera3D:
					child.current = false
				
				# Make sure the mesh has our water material
				if child is MeshInstance3D:
					child.material_override = water_material
			
			# Randomize puddle size for variety while keeping it flat
			var puddle_scale_x = randf_range(2.5, 5.0)
			var puddle_scale_z = randf_range(2.5, 5.0)
			
			# Apply non-uniform scaling for organic shape but keep Y flattened
			puddle.scale = Vector3(puddle_scale_x, 0.1, puddle_scale_z)
			
			# Position slightly above floor to avoid z-fighting
			puddle.position = Vector3(x_pos, -1.995, z_pos)
			
			# Random rotation for variety
			puddle.rotation.y = randf_range(0, TAU)
			
			# Add a small random offset to position for less grid-like placement
			puddle.position.x += randf_range(-0.5, 0.5)
			puddle.position.z += randf_range(-0.5, 0.5)
			
			puddles_node.add_child(puddle)
			created_puddles += 1
			
			# Debug first puddle
			if created_puddles == 1:
				print("Water puddle created at: ", puddle.position)
				print("Water puddle has children: ", puddle.get_child_count())
				for child in puddle.get_children():
					print("- Child: ", child.name, " (", child.get_class(), ")")
	
	# Add wall highlights for additional reflective surfaces
	add_reflective_wall_highlights()

func add_reflective_wall_highlights() -> void:
	var highlights_node = Node3D.new()
	highlights_node.name = "WallHighlights"
	add_child(highlights_node)
	
	# Load the RTX wall material as base
	var rtx_wall_material = load("res://Materials/rtx_wall_material.tres")
	
	# Create a modified version of the RTX material for highlights
	var highlight_material = StandardMaterial3D.new()
	if rtx_wall_material:
		# Try to copy properties if possible
		highlight_material.albedo_color = Color(0.8, 0.8, 0.9, 0.6)
		highlight_material.metallic = 1.0
		highlight_material.metallic_specular = 1.0
		highlight_material.roughness = 0.05
	else:
		# Fallback if RTX material not found
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
