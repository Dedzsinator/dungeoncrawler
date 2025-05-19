extends Node3D

@export var enable_rtx: bool = true
@export var enable_water_puddles: bool = true
@export var puddle_density: float = 0.2
@export var max_puddles: int = 10

@onready var environment = $WorldEnvironment.environment if has_node("WorldEnvironment") else null
@onready var wall_materials = []

# Preloaded resources
var puddle_scene = preload("res://Scenes/water_puddle.tscn")
var noise_texture = preload("res://Assets/VFX/Textures/T_PerlinNoise_Tiled.png")
var water_material = preload("res://Materials/water_puddle_material.tres")
var rtx_wall_material = preload("res://Materials/rtx_wall_material.tres")

func _ready():
	if not enable_rtx:
		return
		
	setup_environment()
	apply_rtx_to_walls()
	
	if enable_water_puddles:
		generate_water_puddles()

func setup_environment():
	if environment == null:
		print("No environment found. Creating one...")
		var world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		var env = Environment.new()
		world_env.environment = env
		add_child(world_env)
		environment = env
	
	# Configure environment for RTX
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 2.0
	
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	environment.ssr_fade_in = 0.15
	environment.ssr_fade_out = 2.0
	environment.ssr_depth_tolerance = 0.2
	
	environment.ssil_enabled = true
	environment.ssil_intensity = 1.0
	environment.ssil_radius = 5.0
	
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	
	# Add reflection probe
	var reflection_probe = ReflectionProbe.new()
	reflection_probe.name = "RTXReflectionProbe"
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	reflection_probe.interior_enable = true
	reflection_probe.box_projection = true
	reflection_probe.enable_shadows = true
	reflection_probe.size = Vector3(50, 20, 50)
	reflection_probe.origin_offset = Vector3(0, 0, 0)
	add_child(reflection_probe)
	
	# Add reflection manager
	var reflection_manager = Node3D.new()
	reflection_manager.name = "ReflectionManager"
	reflection_manager.set_script(load("res://Scripts/rtx_reflection_manager.gd"))
	reflection_manager.reflection_probe = reflection_probe
	add_child(reflection_manager)

func apply_rtx_to_walls():
	var walls = get_tree().get_nodes_in_group("walls")
	if walls.size() == 0:
		# If no walls are defined in a group, try to find them by type
		walls = get_dungeon_walls()
	
	for wall in walls:
		if wall is MeshInstance3D:
			apply_rtx_material_to_mesh(wall)

func get_dungeon_walls():
	var result = []
	var meshes = get_tree().get_nodes_in_group("MeshInstance3D")
	
	for mesh in meshes:
		var name_lower = mesh.name.to_lower()
		if "wall" in name_lower:
			result.append(mesh)
	
	return result

func apply_rtx_material_to_mesh(mesh_instance):
	var material = rtx_wall_material.duplicate()
	
	# Try to preserve original texture
	if mesh_instance.get_surface_override_material(0) != null:
		var original_material = mesh_instance.get_surface_override_material(0)
		if original_material is StandardMaterial3D:
			if original_material.albedo_texture != null:
				material.set_shader_parameter("albedo_texture", original_material.albedo_texture)
			if original_material.normal_texture != null:
				material.set_shader_parameter("normal_texture", original_material.normal_texture)
	
	mesh_instance.set_surface_override_material(0, material)
	wall_materials.append(material)

func generate_water_puddles():
	var floor_meshes = get_tree().get_nodes_in_group("floors")
	if floor_meshes.size() == 0:
		floor_meshes = get_dungeon_floors()
	
	var puddle_count = min(max_puddles, int(floor_meshes.size() * puddle_density))
	var used_floors = []
	
	for i in range(puddle_count):
		var available_floors = []
		for floor_mesh in floor_meshes:
			if not floor_mesh in used_floors:
				available_floors.append(floor_mesh)
		
		if available_floors.size() == 0:
			break
		
		var selected_floor = available_floors[randi() % available_floors.size()]
		used_floors.append(selected_floor)
		
		var aabb = selected_floor.get_aabb()
		var floor_pos = selected_floor.global_transform.origin
		
		# Create puddle instance
		var puddle = puddle_scene.instantiate()
		puddle.transform.origin = floor_pos + Vector3(0, 0.01, 0) # Slightly above floor
		
		# Adjust puddle size based on floor size
		var puddle_size = randf_range(0.5, 1.0)
		puddle.scale = Vector3(puddle_size, 0.01, puddle_size) * min(aabb.size.x, aabb.size.z) * 0.5
		
		add_child(puddle)

func get_dungeon_floors():
	var result = []
	var meshes = get_tree().get_nodes_in_group("MeshInstance3D")
	
	for mesh in meshes:
		var name_lower = mesh.name.to_lower()
		if "floor" in name_lower:
			result.append(mesh)
	
	return result
