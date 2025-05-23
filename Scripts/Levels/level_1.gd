extends Node3D

@onready var warrior_scene: PackedScene = preload("res://Scenes/Monsters/SkeletonWarrior/skeleton_warrior.tscn")
@onready var walls_gridmap: GridMap = get_node("Walls")
@onready var walls2_gridmap: GridMap = get_node("Walls2")

# RTX Settings
@export var enable_rtx: bool = true
@export var enable_water_puddles: bool = true
@export var enable_compute_rtx: bool = true # Disable for now to troubleshoot
@export var puddle_density: float = 0.3
@export var max_puddles: int = 15

# RTX Resources
var puddle_scene: PackedScene
var rtx_wall_material: Material
var rtx_manager: Node3D
var wall_materials = []

func _ready() -> void:
	# Load RTX resources
	if enable_rtx:
		load_rtx_resources()
	
	# Existing monster creation
	create_monsters(3, -36, -28, -38, 0)
	create_monsters(2, -24, -11, 6, 24)
	create_monsters(5, -24, 0, -38, 0)
	create_monsters(10, 0, 30, -38, 22)
	
	# Initialize RTX after everything is loaded
	if enable_rtx:
		setup_rtx()

func load_rtx_resources():
	# Load resources with error handling
	if ResourceLoader.exists("res://Scenes/water_puddle.tscn"):
		puddle_scene = load("res://Scenes/water_puddle.tscn")
	else:
		print("Warning: water_puddle.tscn not found")
	
	if ResourceLoader.exists("res://Materials/rtx_wall_material.tres"):
		rtx_wall_material = load("res://Materials/rtx_wall_material.tres")
	else:
		print("Warning: rtx_wall_material.tres not found")

func setup_rtx():
	print("Setting up enhanced RTX showcase for Level1...")
	
	# First create the RTX manager script if it doesn't exist
	create_minimal_rtx_manager()
	
	# Setup enhanced environment
	setup_rtx_environment()
	
	# Apply RTX materials to walls
	apply_rtx_to_walls()
	
	# Generate lots of water puddles for RTX showcase
	if enable_water_puddles:
		generate_water_puddles()
	
	# Add dynamic lighting for dramatic effect
	add_dynamic_lighting()
	
	# Test compute RTX (optional)
	if enable_compute_rtx:
		setup_compute_rtx()
	
	print("RTX showcase setup complete!")

# Simplify VoxelGI setup as well to ensure no errors
func add_voxel_gi():
	var voxel_gi = VoxelGI.new()
	voxel_gi.name = "RTXVoxelGI"
	
	# Configure VoxelGI for dungeon with ONLY correct Godot 4 properties
	voxel_gi.size = Vector3(50, 20, 50) # Size of the GI volume
	voxel_gi.position = Vector3(0, 5, 0) # Center it better
	
	# These are the ONLY valid VoxelGI properties in Godot 4:
	voxel_gi.subdiv = VoxelGI.SUBDIV_256 # Subdivision level
	
	add_child(voxel_gi)
	
	# Bake the VoxelGI after geometry is ready
	await get_tree().process_frame
	await get_tree().process_frame # Wait an extra frame
	
	print("Baking VoxelGI...")
	voxel_gi.bake()
	print("VoxelGI added and baked")

func setup_rtx_environment():
	var world_env = get_node("WorldEnvironment")
	if not world_env:
		print("WorldEnvironment not found!")
		return
		
	if not world_env.environment:
		print("Environment not found in WorldEnvironment!")
		return
		
	var environment = world_env.environment
	
	# Enhanced environment setup for RTX showcase
	environment.background_mode = Environment.BG_SKY
	
	# Ambient light settings
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.3
	
	# Enable SSAO for better depth perception
	environment.ssao_enabled = true
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 0.8
	
	# Enable SSR for water reflections
	environment.ssr_enabled = true
	environment.ssr_max_steps = 32
	environment.ssr_fade_in = 0.15
	environment.ssr_fade_out = 2.0
	environment.ssr_depth_tolerance = 0.2
	
	# Enable SSIL for better indirect lighting
	environment.ssil_enabled = true
	environment.ssil_intensity = 0.4
	environment.ssil_radius = 2.0
	
	# Enable glow for emission effects
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.1
	
	# Tone mapping for better color reproduction
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	
	# Color adjustments for better visuals
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 1.2
	
	print("Enhanced RTX environment configured")
	
	# Add reflection probe for accurate reflections
	add_reflection_probe()
	
	# Add VoxelGI for global illumination
	add_voxel_gi()

func add_dynamic_lighting():
	# Add a torch-like light that will be reflected in puddles
	var torch_light = OmniLight3D.new()
	torch_light.name = "TorchLight"
	torch_light.light_energy = 2.0
	torch_light.light_color = Color(1.0, 0.7, 0.4) # Warm torch color
	torch_light.omni_range = 15.0
	torch_light.position = Vector3(0, 3, 0) # Center of dungeon
	
	# Enable shadows for dramatic effect
	torch_light.shadow_enabled = true
	torch_light.shadow_bias = 0.1
	
	add_child(torch_light)
	print("Added torch light for RTX showcase")
	
	# Add some moving lights for dynamic reflections
	create_moving_lights()

func create_moving_lights():
	for i in range(3):
		var moving_light = OmniLight3D.new()
		moving_light.name = "MovingLight" + str(i)
		moving_light.light_energy = 1.5
		moving_light.light_color = Color(0.5, 0.8, 1.0) # Cool blue light
		moving_light.omni_range = 8.0
		moving_light.position = Vector3(randf_range(-20, 20), 2, randf_range(-20, 20))
		
		add_child(moving_light)
		
		# Add simple animation
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(moving_light, "position:y", 4.0, 2.0)
		tween.tween_property(moving_light, "position:y", 1.0, 2.0)

func add_reflection_probe():
	var reflection_probe = ReflectionProbe.new()
	reflection_probe.name = "RTXReflectionProbe"
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	reflection_probe.intensity = 0.8 # Higher intensity for better reflections
	reflection_probe.max_distance = 25.0
	reflection_probe.size = Vector3(60, 20, 60) # Cover more area
	reflection_probe.origin_offset = Vector3(0, 5, 0)
	
	# Enable box projection for interior spaces
	reflection_probe.box_projection = true
	
	# Set cull mask to capture all geometry
	reflection_probe.cull_mask = 0xFFFFF # All layers
	
	add_child(reflection_probe)
	print("Enhanced reflection probe added")

func create_enhanced_material() -> Material:
	if rtx_wall_material:
		var material = rtx_wall_material.duplicate()
		print("Using enhanced RTX wall material")
		return material
	else:
		# Create enhanced fallback material
		var material = StandardMaterial3D.new()
		
		# PBR properties optimized for RTX
		material.metallic = 0.1 # Slight metallic for subtle reflections
		material.roughness = 0.6 # Balanced roughness
		material.albedo_color = Color(0.7, 0.6, 0.5) # Warmer stone color
		
		# Enable clearcoat for subtle reflections
		material.clearcoat_enabled = true
		material.clearcoat = 0.2
		material.clearcoat_roughness = 0.3
		
		# Enhanced normal mapping
		material.normal_enabled = true
		material.normal_scale = 1.0
		
		# Proper RTX settings
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		
		return material

func apply_rtx_to_walls():
	# Get wall GridMaps and apply RTX materials
	var wall_gridmaps = [get_node("Walls"), get_node("Walls2")]
	
	for gridmap in wall_gridmaps:
		if gridmap:
			gridmap.add_to_group("rtx_geometry")
			apply_rtx_to_gridmap(gridmap)
			print("Applied RTX to gridmap: ", gridmap.name)

func apply_rtx_to_gridmap(gridmap: GridMap):
	var mesh_library = gridmap.mesh_library
	if not mesh_library:
		print("No mesh library found for: ", gridmap.name)
		return
	
	# Apply RTX material to all items in the mesh library
	var item_list = mesh_library.get_item_list()
	print("Processing ", item_list.size(), " items in mesh library")
	
	for item_id in item_list:
		var mesh = mesh_library.get_item_mesh(item_id)
		
		if mesh:
			# Create RTX material
			var material = create_enhanced_material()
			if material:
				# For GridMap items, we need to create a new mesh with the material applied
				var new_mesh = mesh.duplicate()
				
				# Apply material to all surfaces of the mesh
				for surface_idx in range(new_mesh.get_surface_count()):
					new_mesh.surface_set_material(surface_idx, material)
				
				# Set the updated mesh back to the library
				mesh_library.set_item_mesh(item_id, new_mesh)
				wall_materials.append(material)
				
				print("Applied RTX material to item ", item_id)

func generate_water_puddles():
	# Get floor GridMap
	var floor_gridmap = get_node("Floor")
	if not floor_gridmap:
		print("No Floor GridMap found")
		return
	
	var used_cells = floor_gridmap.get_used_cells()
	if used_cells.is_empty():
		print("No floor cells found")
		return
	
	var puddle_count = min(max_puddles, int(used_cells.size() * puddle_density))
	var used_positions = []
	
	print("Generating ", puddle_count, " water puddles for RTX showcase")
	
	for i in range(puddle_count):
		if used_cells.is_empty():
			break
			
		var available_cells = []
		for cell in used_cells:
			if not cell in used_positions:
				available_cells.append(cell)
		
		if available_cells.is_empty():
			break
		
		var selected_cell = available_cells[randi() % available_cells.size()]
		used_positions.append(selected_cell)
		
		# Convert grid position to world position
		var world_pos = floor_gridmap.map_to_local(selected_cell)
		
		# Create puddle instance with enhanced properties
		create_enhanced_water_puddle(world_pos)

func create_enhanced_water_puddle(position: Vector3):
	var puddle: Node3D
	
	if puddle_scene:
		puddle = puddle_scene.instantiate()
		print("Using water_puddle.tscn for enhanced reflections")
	else:
		# Create enhanced puddle mesh with RTX-optimized material
		puddle = create_rtx_puddle()
		print("Created RTX-optimized water puddle")
	
	puddle.transform.origin = position + Vector3(0, 0.01, 0)
	
	# Varied puddle sizes for visual interest
	var puddle_size = randf_range(0.5, 1.2)
	puddle.scale = Vector3(puddle_size, 0.02, puddle_size) # Slightly thicker
	
	# Add some random rotation for natural look
	puddle.rotation.y = randf() * PI * 2
	
	add_child(puddle)

func create_rtx_puddle() -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(2.0, 2.0)
	plane_mesh.subdivide_width = 4 # More subdivisions for better reflections
	plane_mesh.subdivide_depth = 4
	mesh_instance.mesh = plane_mesh
	
	# Enhanced water material for RTX
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.4, 0.8, 0.85) # More transparent
	material.metallic = 0.95 # Very metallic for reflections
	material.roughness = 0.05 # Very smooth for clear reflections
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Enhanced clearcoat for realistic water surface
	material.clearcoat_enabled = true
	material.clearcoat = 1.0 # Maximum clearcoat
	material.clearcoat_roughness = 0.01 # Very smooth clearcoat
	
	# Enable normal mapping if you have water normal textures
	material.normal_enabled = true
	
	# Enhanced reflection properties
	material.rim_enabled = true
	material.rim = 0.3
	material.rim_tint = 0.5
	
	# Set proper shading for RTX
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # Water doesn't cast shadows
	
	return mesh_instance

func create_simple_puddle() -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(2.0, 2.0)
	mesh_instance.mesh = plane_mesh
	
	# Create realistic water material - less reflective to avoid overexposure
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.4, 0.6, 0.7) # Less saturated
	material.metallic = 0.6 # Less metallic
	material.roughness = 0.2 # Slightly rougher
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Reduce clearcoat to prevent overexposure
	material.clearcoat_enabled = true
	material.clearcoat = 0.3
	material.clearcoat_roughness = 0.1
	
	mesh_instance.material_override = material
	
	return mesh_instance

func setup_compute_rtx():
	# Check if rtx_manager script exists
	if not ResourceLoader.exists("res://Scripts/rtx_manager.gd"):
		print("rtx_manager.gd not found, skipping compute RTX setup")
		return
	
	# Check if the compute shader exists
	if not ResourceLoader.exists("res://Materials/rtx.glsl"):
		print("rtx.glsl not found, skipping compute RTX setup")
		return
	
	print("Setting up compute RTX...")
	
	# Create RTX manager
	rtx_manager = Node3D.new()
	rtx_manager.name = "RTXManager"
	
	# Load and attach the script
	var rtx_script = load("res://Scripts/rtx_manager.gd")
	rtx_manager.set_script(rtx_script)
	add_child(rtx_manager)
	
	print("RTX Manager created")
	
	# Tag geometry for RTX
	tag_geometry_for_rtx()
	
	# Test if the compute shader can be loaded
	test_compute_shader()

func test_compute_shader():
	print("Testing compute shader...")
	
	# Try to create a basic compute shader to test functionality
	var rd = RenderingServer.create_local_rendering_device()
	if not rd:
		print("Failed to create rendering device for compute shader")
		return
	
	# Try to load the shader
	var shader_file = FileAccess.open("res://Materials/rtx.glsl", FileAccess.READ)
	if not shader_file:
		print("Failed to open rtx.glsl")
		return
	
	var shader_source = shader_file.get_as_text()
	shader_file.close()
	
	# Create RDShaderSource object (Godot 4 way)
	var shader_source_rd = RDShaderSource.new()
	shader_source_rd.source_compute = shader_source
	shader_source_rd.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	
	# Compile the shader
	var shader_spirv = rd.shader_compile_spirv_from_source(shader_source_rd)
	if shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE) != "":
		print("Compute shader compilation error: ", shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
		return
	
	var compute_shader = rd.shader_create_from_spirv(shader_spirv)
	if not compute_shader.is_valid():
		print("Failed to create compute shader")
		return
	
	print("Compute shader loaded successfully!")
	
	# Clean up
	rd.free()

# Let's also create a more complete RTX manager that can actually use the compute shader
func create_minimal_rtx_manager():
	var rtx_manager_script = """
extends Node3D

var rd: RenderingDevice
var compute_shader: RID
var output_texture: RID
var camera_buffer: RID
var scene_buffer: RID

func _ready():
	print("RTX Manager initialized")
	setup_compute_pipeline()

func setup_compute_pipeline():
	print("Setting up compute pipeline...")
	
	# Create local rendering device
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		print("Failed to create rendering device")
		return
	
	# Load and compile shader
	if not load_compute_shader():
		return
	
	# Create buffers and textures
	setup_buffers()
	
	print("Compute pipeline setup complete")

func load_compute_shader() -> bool:
	var shader_file = FileAccess.open("res://Materials/rtx.glsl", FileAccess.READ)
	if not shader_file:
		print("Failed to open rtx.glsl")
		return false
	
	var shader_source = shader_file.get_as_text()
	shader_file.close()
	
	# Create shader source
	var shader_source_rd = RDShaderSource.new()
	shader_source_rd.source_compute = shader_source
	shader_source_rd.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	
	# Compile shader
	var shader_spirv = rd.shader_compile_spirv_from_source(shader_source_rd)
	if shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE) != "":
		print("Shader compilation error: ", shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
		return false
	
	compute_shader = rd.shader_create_from_spirv(shader_spirv)
	if not compute_shader.is_valid():
		print("Failed to create compute shader")
		return false
	
	print("Compute shader compiled successfully")
	return true

func setup_buffers():
	# Create output texture (basic setup)
	var output_format = RDTextureFormat.new()
	output_format.width = 1024
	output_format.height = 768
	output_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	output_format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	output_texture = rd.texture_create(output_format, RDTextureView.new(), [])
	
	# Create camera buffer with proper Godot 4 API
	var camera_data = PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0])
	camera_buffer = rd.storage_buffer_create(camera_data.to_byte_array().size())
	
	print("Buffers created")

func update_camera_buffer(camera_transform: Transform3D):
	if not rd or not camera_buffer.is_valid():
		return
	
	# Convert transform to float array
	var transform_data = PackedFloat32Array()
	var basis = camera_transform.basis
	var origin = camera_transform.origin
	
	# Add basis vectors and origin
	transform_data.append_array([basis.x.x, basis.x.y, basis.x.z, 0.0])
	transform_data.append_array([basis.y.x, basis.y.y, basis.y.z, 0.0])
	transform_data.append_array([basis.z.x, basis.z.y, basis.z.z, 0.0])
	transform_data.append_array([origin.x, origin.y, origin.z, 1.0])
	
	# Update buffer with correct Godot 4 API (4 parameters required)
	rd.buffer_update(camera_buffer, 0, transform_data.to_byte_array(), RenderingDevice.BARRIER_MASK_COMPUTE)

func dispatch_compute():
	if not rd or not compute_shader.is_valid():
		return
	
	# Basic dispatch (this would need proper uniform sets in a real implementation)
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, compute_shader)
	rd.compute_list_dispatch(compute_list, 128, 96, 1)  # 1024/8, 768/8
	rd.compute_list_end()
	rd.submit()
	rd.wait()

func _exit_tree():
	if rd:
		rd.free()
"""
	
	# Save the script if it doesn't exist
	if not ResourceLoader.exists("res://Scripts/rtx_manager.gd"):
		var file = FileAccess.open("res://Scripts/rtx_manager.gd", FileAccess.WRITE)
		if file:
			file.store_string(rtx_manager_script)
			file.close()
			print("Created minimal rtx_manager.gd")

func tag_geometry_for_rtx():
	# Add all relevant nodes to the rtx_geometry group
	var nodes_to_tag = [
		get_node("Floor"),
		get_node("Walls"),
		get_node("Walls2")
	]
	
	# Add Objects node if it exists
	if has_node("Objects"):
		nodes_to_tag.append(get_node("Objects"))
	
	for node in nodes_to_tag:
		if node:
			node.add_to_group("rtx_geometry")
			print("Tagged for RTX: ", node.name)
	
	# Also tag any mesh instances
	var all_meshes = find_all_mesh_instances(self)
	for mesh in all_meshes:
		if not mesh.is_in_group("rtx_geometry"):
			mesh.add_to_group("rtx_geometry")

func find_all_mesh_instances(node: Node) -> Array:
	var result = []
	
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		result.append_array(find_all_mesh_instances(child))
	
	return result

# Existing functions remain the same
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
