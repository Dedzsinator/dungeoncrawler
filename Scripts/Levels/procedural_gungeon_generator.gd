# Scripts/Levels/procedural_dungeon_generator.gd
extends Node3D
class_name ProceduralDungeonGenerator

# Dungeon parameters
@export var dungeon_width: int = 15
@export var dungeon_height: int = 15
@export var room_min_size: int = 4
@export var room_max_size: int = 8
@export var max_rooms: int = 8
@export var corridor_width: int = 1
@export var wall_height: float = 4.0
@export var torch_height: float = 2.5

# Generation parameters
@export var puddle_chance: float = 0.15
@export var enemy_density: float = 0.3
@export var prop_density: float = 0.4

# RTX Materials
var rtx_wall_material: Material

# Asset paths - using your KayKit assets
var floor_assets = [
	"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/floor_tile_large.gltf.glb",
]

var puddle_assets = [
	"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/floor_tile_grate.gltf.glb",
]

# Enhanced wall assets with specific types
var wall_assets = {
	"straight": [
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall.gltf.glb",
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall_arched.gltf.glb"
	],
	"corner": [
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall_corner.gltf.glb"
	],
	"door": [
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall_doorway.gltf.glb"
	],
	"junction": [
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall_Tsplit.gltf.glb",
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall_crossing.gltf.glb"
	]
}

var prop_assets = {
	"containers": [
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/barrel.gltf.glb",
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/chest.gltf.glb",
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/crate.gltf.glb"
	],
	"furniture": [
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/table_medium.gltf.glb",
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/chair.gltf.glb"
	],
	"decorative": [
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/candle.gltf.glb",
		"res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/banner_patternA_blue.gltf.glb"
	]
}

# Enemy scenes
var enemy_scenes = [
	"res://Scenes/Enemies/slime.tscn",
	"res://Scenes/Enemies/skeleton.tscn",
	"res://Scenes/Enemies/goblin.tscn"
]

# Grid representation
enum CellType {
	EMPTY,
	FLOOR,
	WALL,
	CORRIDOR,
	DOOR
}

enum WallType {
	STRAIGHT_NS, # North-South wall (blocks east-west movement)
	STRAIGHT_EW, # East-West wall (blocks north-south movement)
	CORNER_NE, # Corner opening to North-East
	CORNER_SE, # Corner opening to South-East
	CORNER_SW, # Corner opening to South-West
	CORNER_NW, # Corner opening to North-West
	JUNCTION_T_N, # T-junction opening North
	JUNCTION_T_E, # T-junction opening East
	JUNCTION_T_S, # T-junction opening South
	JUNCTION_T_W, # T-junction opening West
	JUNCTION_CROSS, # 4-way crossing
	DOOR_NS, # Door in North-South wall
	DOOR_EW # Door in East-West wall
}

var grid: Array[Array]
var wall_types: Array[Array]
var rooms: Array[Rect2i]
var first_room_center: Vector2i
var doors: Array[Vector2i] # Track door positions

# Node references
var floor_container: Node3D
var wall_container: Node3D
var prop_container: Node3D
var torch_container: Node3D
var enemy_container: Node3D
var puddle_container: Node3D
var torch_scene: PackedScene
var rtx_floor_material: Material
var skybox_material: Material


# Track occupied positions
var occupied_positions: Array[Vector2i] = []

func _ready():
	setup_containers()
	load_scenes()
	load_rtx_materials()
	generate_dungeon()

func load_scenes():
	if ResourceLoader.exists("res://Scenes/Objects/torch.tscn"):
		torch_scene = preload("res://Scenes/Objects/torch.tscn")
	else:
		print("Warning: torch.tscn not found")

func setup_skybox_shader():
	print("Setting up skybox with sky shader...")
	
	# Get or create environment - use a more robust approach
	var environment: Environment
	var world_env = get_tree().get_first_node_in_group("world_environment")
	
	if not world_env:
		# Look for existing WorldEnvironment in the scene tree
		world_env = get_tree().get_nodes_in_group("world_environment")
		if world_env.size() > 0:
			world_env = world_env[0]
		else:
			world_env = null
	
	if not world_env:
		# Create new WorldEnvironment
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		world_env.add_to_group("world_environment")
		get_parent().add_child(world_env)
		print("Created new WorldEnvironment")
	
	# Get or create environment
	if world_env.environment:
		environment = world_env.environment
	else:
		environment = Environment.new()
		world_env.environment = environment
		print("Created new Environment")
	
	# Apply sky shader - use load() instead of preload()
	if ResourceLoader.exists("res://Shaders/sky.gdshader"):
		var sky_material = ShaderMaterial.new()
		var sky_shader = load("res://Shaders/sky.gdshader")
		sky_material.shader = sky_shader
		
		# Set sky shader parameters
		sky_material.set_shader_parameter("sky_color_top", Color(0.4, 0.6, 1.0))
		sky_material.set_shader_parameter("sky_color_bottom", Color(0.8, 0.9, 1.0))
		sky_material.set_shader_parameter("sun_color", Color(1.0, 0.9, 0.7))
		sky_material.set_shader_parameter("cloud_density", 0.3)
		sky_material.set_shader_parameter("sun_size", 0.05)
		sky_material.set_shader_parameter("time_of_day", 0.5)
		
		# Create and apply sky
		var sky = Sky.new()
		sky.sky_material = sky_material
		
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		
		print("Sky shader applied successfully")
	else:
		create_fallback_sky(environment)

func create_rtx_floor_material_from_shader() -> ShaderMaterial:
	var shader_material = ShaderMaterial.new()
	
	if ResourceLoader.exists("res://Shaders/rtx_floor.gdshader"):
		var shader = load("res://Shaders/rtx_floor.gdshader")
		shader_material.shader = shader
	else:
		# Use wall shader for floors with different parameters
		if ResourceLoader.exists("res://Shaders/rtx_wall.gdshader"):
			var shader = load("res://Shaders/rtx_wall.gdshader")
			shader_material.shader = shader
		else:
			print("Warning: No RTX shaders found!")
			return null
	
	# Set shader parameters for floors
	shader_material.set_shader_parameter("metallic", 0.0)
	shader_material.set_shader_parameter("roughness", 0.8)
	shader_material.set_shader_parameter("emission_strength", 0.0)
	shader_material.set_shader_parameter("normal_strength", 0.5)
	shader_material.set_shader_parameter("clearcoat", 0.1)
	shader_material.set_shader_parameter("clearcoat_roughness", 0.4)
	
	return shader_material

func create_rtx_wall_material_from_shader() -> ShaderMaterial:
	var shader_material = ShaderMaterial.new()
	
	# Use load() instead of preload() for dynamic paths
	if ResourceLoader.exists("res://Shaders/rtx_wall.gdshader"):
		var shader = load("res://Shaders/rtx_wall.gdshader")
		shader_material.shader = shader
	else:
		print("Warning: rtx_wall.gdshader not found!")
		return null
	
	# Set shader parameters for walls
	shader_material.set_shader_parameter("metallic", 0.1)
	shader_material.set_shader_parameter("roughness", 0.7)
	shader_material.set_shader_parameter("emission_strength", 0.0)
	shader_material.set_shader_parameter("normal_strength", 1.0)
	shader_material.set_shader_parameter("clearcoat", 0.3)
	shader_material.set_shader_parameter("clearcoat_roughness", 0.2)
	
	# Load textures if available - use load() for dynamic paths
	var wall_textures = [
		"res://Textures/wall_albedo.png",
		"res://Textures/stone_albedo.png",
		"res://Assets/Textures/wall_diffuse.png"
	]
	
	for texture_path in wall_textures:
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			shader_material.set_shader_parameter("albedo_texture", texture)
			break
	
	return shader_material

func load_rtx_materials():
	print("Loading RTX materials and shaders...")
	
	# Load RTX wall material/shader
	if ResourceLoader.exists("res://Materials/rtx_wall_material.tres"):
		rtx_wall_material = preload("res://Materials/rtx_wall_material.tres")
		print("RTX wall material loaded successfully")
	elif ResourceLoader.exists("res://Shaders/rtx_wall.gdshader"):
		rtx_wall_material = create_rtx_wall_material_from_shader()
		print("RTX wall material created from shader")
	else:
		print("Warning: RTX wall material/shader not found")
		create_fallback_rtx_wall_material()
	
	# Load RTX floor material/shader - FIX: Check for floor material, not wall material
	if ResourceLoader.exists("res://Materials/rtx_wall_material.tres"):
		rtx_floor_material = preload("res://Materials/rtx_wall_material.tres")
		print("RTX floor material loaded successfully")
	elif ResourceLoader.exists("res://Shaders/rtx_floor.gdshader"):
		rtx_floor_material = create_rtx_floor_material_from_shader()
		print("RTX floor material created from shader")
	else:
		rtx_floor_material = rtx_wall_material # Use wall material as fallback
	
	# Setup skybox
	setup_skybox_shader()

func create_fallback_sky(environment: Environment):
	print("Creating fallback procedural sky...")
	var sky = Sky.new()
	var procedural_sky = ProceduralSkyMaterial.new()
	procedural_sky.sky_top_color = Color(0.4, 0.6, 1.0)
	procedural_sky.sky_horizon_color = Color(0.8, 0.9, 1.0)
	procedural_sky.ground_bottom_color = Color(0.2, 0.2, 0.3)
	procedural_sky.ground_horizon_color = Color(0.6, 0.6, 0.7)
	sky.sky_material = procedural_sky
	
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky

func create_fallback_rtx_wall_material():
	print("Creating fallback RTX wall material...")
	rtx_wall_material = StandardMaterial3D.new()
	var mat = rtx_wall_material as StandardMaterial3D
	
	# RTX-style properties for walls
	mat.albedo_color = Color(0.7, 0.7, 0.8)
	mat.metallic = 0.1
	mat.roughness = 0.7
	mat.clearcoat = 0.3
	mat.clearcoat_roughness = 0.2
	mat.normal_scale = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

# Enhanced material application functions
func apply_rtx_material_to_wall(wall_node: Node3D):
	if not rtx_wall_material:
		return
	
	var mesh_instances = find_mesh_instances_recursive(wall_node)
	for mesh_instance in mesh_instances:
		if mesh_instance is MeshInstance3D:
			mesh_instance.material_override = rtx_wall_material
			mesh_instance.add_to_group("rtx_geometry")
			print("Applied RTX wall material to mesh")

func apply_rtx_material_to_floor(floor_node: Node3D):
	if not rtx_floor_material:
		return
	
	var mesh_instances = find_mesh_instances_recursive(floor_node)
	for mesh_instance in mesh_instances:
		if mesh_instance is MeshInstance3D:
			mesh_instance.material_override = rtx_floor_material
			mesh_instance.add_to_group("rtx_geometry")

func create_floor_tile(position: Vector3):
	var floor_asset = floor_assets[randi() % floor_assets.size()]
	if ResourceLoader.exists(floor_asset):
		var floor_scene = load(floor_asset)
		var floor_instance = floor_scene.instantiate()
		floor_instance.position = position
		
		# Apply RTX material to floor
		apply_rtx_material_to_floor(floor_instance)
		
		# Add collision to floor
		add_collision_to_mesh(floor_instance)
		floor_instance.add_to_group("floors")
		floor_container.add_child(floor_instance)

func create_foundation_tile(position: Vector3):
	var floor_asset = floor_assets[randi() % floor_assets.size()]
	if ResourceLoader.exists(floor_asset):
		var foundation_scene = load(floor_asset)
		var foundation_instance = foundation_scene.instantiate()
		foundation_instance.position = position
		
		# Apply RTX material to foundation
		apply_rtx_material_to_floor(foundation_instance)
		
		# Add collision to foundation
		add_collision_to_mesh(foundation_instance)
		foundation_instance.add_to_group("foundation")
		floor_container.add_child(foundation_instance)

func create_door_tile(position: Vector3, grid_x: int, grid_y: int):
	var door_type = wall_types[grid_x][grid_y]
	var door_asset = wall_assets["door"][0]
	
	if ResourceLoader.exists(door_asset):
		var door_scene = load(door_asset)
		var door_instance = door_scene.instantiate()
		door_instance.position = position
		
		# Apply appropriate rotation for door
		var rotation = get_door_rotation(door_type)
		door_instance.rotation.y = rotation
		
		# Apply RTX wall material to door
		apply_rtx_material_to_wall(door_instance)
		
		# Add collision to door
		add_collision_to_mesh(door_instance)
		door_instance.add_to_group("doors")
		wall_container.add_child(door_instance)
		print("Created door tile at: ", position)

func generate_dungeon():
	print("Generating enhanced procedural dungeon...")
	
	# Initialize grid
	initialize_grid()
	
	# Generate rooms
	generate_rooms()
	
	# Connect rooms with corridors and doors
	connect_rooms_with_doors()
	
	# Create walls around floors
	create_walls()
	
	# Analyze wall types (corners, straights, etc.)
	analyze_wall_types()
	
	# Instantiate 3D geometry
	instantiate_geometry()
	
	# Add floor tiles under walls
	add_foundation_floors()
	
	# Add environmental features
	add_puddles()
	
	# Add lighting with proper torch placement
	add_enhanced_lighting()
	
	# Place interactive content
	place_enemies()
	place_props()
	
	print("Enhanced dungeon generation complete!")
	print_generation_stats()

func initialize_grid():
	grid = []
	wall_types = []
	doors = []
	for x in range(dungeon_width):
		grid.append([])
		wall_types.append([])
		for y in range(dungeon_height):
			grid[x].append(CellType.EMPTY)
			wall_types[x].append(WallType.STRAIGHT_NS)

func generate_rooms():
	rooms.clear()
	var attempts = 0
	var max_attempts = 50
	
	while rooms.size() < max_rooms and attempts < max_attempts:
		attempts += 1
		
		var room_width = randi_range(room_min_size, room_max_size)
		var room_height = randi_range(room_min_size, room_max_size)
		var room_x = randi_range(1, dungeon_width - room_width - 1)
		var room_y = randi_range(1, dungeon_height - room_height - 1)
		
		var new_room = Rect2i(room_x, room_y, room_width, room_height)
		
		# Check if room overlaps with existing rooms (with padding)
		var overlaps = false
		for existing_room in rooms:
			var padded_room = Rect2i(
				existing_room.position.x - 1,
				existing_room.position.y - 1,
				existing_room.size.x + 2,
				existing_room.size.y + 2
			)
			if new_room.intersects(padded_room):
				overlaps = true
				break
		
		if not overlaps:
			rooms.append(new_room)
			
			# Mark first room center
			if rooms.size() == 1:
				first_room_center = Vector2i(
					room_x + room_width / 2,
					room_y + room_height / 2
				)
			
			# Fill room with floor tiles
			for x in range(room_x, room_x + room_width):
				for y in range(room_y, room_y + room_height):
					if x >= 0 and x < dungeon_width and y >= 0 and y < dungeon_height:
						grid[x][y] = CellType.FLOOR

func connect_rooms_with_doors():
	# Connect each room to the next with corridors and doors
	for i in range(rooms.size() - 1):
		var room_a = rooms[i]
		var room_b = rooms[i + 1]
		
		var start = Vector2i(
			room_a.position.x + room_a.size.x / 2,
			room_a.position.y + room_a.size.y / 2
		)
		var end = Vector2i(
			room_b.position.x + room_b.size.x / 2,
			room_b.position.y + room_b.size.y / 2
		)
		
		create_corridor_with_doors(start, end)

func create_corridor_with_doors(start: Vector2i, end: Vector2i):
	var current = start
	
	# Create L-shaped corridor
	# First horizontal
	while current.x != end.x:
		if current.x < end.x:
			current.x += 1
		else:
			current.x -= 1
		
		if is_valid_position(current):
			grid[current.x][current.y] = CellType.CORRIDOR
	
	# Then vertical
	while current.y != end.y:
		if current.y < end.y:
			current.y += 1
		else:
			current.y -= 1
		
		if is_valid_position(current):
			grid[current.x][current.y] = CellType.CORRIDOR

func add_doors_to_rooms():
	print("Adding doorways between rooms and corridors...")
	
	for room in rooms:
		# Find potential door locations on room perimeter
		var door_candidates = []
		
		# Check all edges of the room for walls that connect to corridors
		for x in range(room.position.x, room.position.x + room.size.x):
			# Top edge
			var top_pos = Vector2i(x, room.position.y - 1)
			if is_valid_position(top_pos) and grid[top_pos.x][top_pos.y] == CellType.WALL:
				var corridor_pos = Vector2i(x, room.position.y - 2)
				if is_valid_position(corridor_pos) and grid[corridor_pos.x][corridor_pos.y] == CellType.CORRIDOR:
					door_candidates.append(top_pos)
			
			# Bottom edge
			var bottom_pos = Vector2i(x, room.position.y + room.size.y)
			if is_valid_position(bottom_pos) and grid[bottom_pos.x][bottom_pos.y] == CellType.WALL:
				var corridor_pos = Vector2i(x, room.position.y + room.size.y + 1)
				if is_valid_position(corridor_pos) and grid[corridor_pos.x][corridor_pos.y] == CellType.CORRIDOR:
					door_candidates.append(bottom_pos)
		
		for y in range(room.position.y, room.position.y + room.size.y):
			# Left edge
			var left_pos = Vector2i(room.position.x - 1, y)
			if is_valid_position(left_pos) and grid[left_pos.x][left_pos.y] == CellType.WALL:
				var corridor_pos = Vector2i(room.position.x - 2, y)
				if is_valid_position(corridor_pos) and grid[corridor_pos.x][corridor_pos.y] == CellType.CORRIDOR:
					door_candidates.append(left_pos)
			
			# Right edge
			var right_pos = Vector2i(room.position.x + room.size.x, y)
			if is_valid_position(right_pos) and grid[right_pos.x][right_pos.y] == CellType.WALL:
				var corridor_pos = Vector2i(room.position.x + room.size.x + 1, y)
				if is_valid_position(corridor_pos) and grid[corridor_pos.x][corridor_pos.y] == CellType.CORRIDOR:
					door_candidates.append(right_pos)
		
		# Place 1-2 doors per room - ACTUALLY REPLACE WALLS WITH DOORS
		var door_count = mini(door_candidates.size(), randi_range(1, 3))
		for i in range(door_count):
			if door_candidates.size() > 0:
				var door_pos = door_candidates[randi() % door_candidates.size()]
				grid[door_pos.x][door_pos.y] = CellType.DOOR # Replace wall with door
				doors.append(door_pos)
				door_candidates.erase(door_pos)
				print("Placed door at: ", door_pos)

func get_wall_rotation(wall_type: WallType) -> float:
	match wall_type:
		WallType.STRAIGHT_NS:
			return PI / 2 # Wall runs north-south (rotated 90 degrees)
		WallType.STRAIGHT_EW:
			return 0.0 # Wall runs east-west (no rotation)
		WallType.JUNCTION_T_N:
			return 0.0 # T-junction opening north
		WallType.JUNCTION_T_E:
			return PI / 2 # T-junction opening east
		WallType.JUNCTION_T_S:
			return PI # T-junction opening south
		WallType.JUNCTION_T_W:
			return 3 * PI / 2 # T-junction opening west
		WallType.JUNCTION_CROSS:
			return 0.0 # 4-way crossing (no rotation needed)
		_:
			return 0.0

func get_corner_rotation_from_neighbors(x: int, y: int) -> float:
	# Check which directions have walls or boundaries
	var has_wall_north = is_valid_position(Vector2i(x, y - 1)) and (grid[x][y - 1] == CellType.WALL or !is_valid_position(Vector2i(x, y - 1)))
	var has_wall_south = is_valid_position(Vector2i(x, y + 1)) and (grid[x][y + 1] == CellType.WALL or !is_valid_position(Vector2i(x, y + 1)))
	var has_wall_east = is_valid_position(Vector2i(x + 1, y)) and (grid[x + 1][y] == CellType.WALL or !is_valid_position(Vector2i(x + 1, y)))
	var has_wall_west = is_valid_position(Vector2i(x - 1, y)) and (grid[x - 1][y] == CellType.WALL or !is_valid_position(Vector2i(x - 1, y)))
	
	# Check where the floors are (this determines which way the corner should "open")
	var has_floor_north = is_valid_position(Vector2i(x, y - 1)) and is_floor_or_corridor(x, y - 1)
	var has_floor_south = is_valid_position(Vector2i(x, y + 1)) and is_floor_or_corridor(x, y + 1)
	var has_floor_east = is_valid_position(Vector2i(x + 1, y)) and is_floor_or_corridor(x + 1, y)
	var has_floor_west = is_valid_position(Vector2i(x - 1, y)) and is_floor_or_corridor(x - 1, y)
	
	# For inner corners - corner opens where there are floors
	if has_floor_north and has_floor_east and !has_floor_south and !has_floor_west:
		return 0.0 # Corner opens to north-east
	elif has_floor_south and has_floor_east and !has_floor_north and !has_floor_west:
		return PI / 2 # Corner opens to south-east
	elif has_floor_south and has_floor_west and !has_floor_north and !has_floor_east:
		return PI # Corner opens to south-west
	elif has_floor_north and has_floor_west and !has_floor_south and !has_floor_east:
		return 3 * PI / 2 # Corner opens to north-west
	
	# For outer corners - corner blocks where there are walls
	elif has_wall_north and has_wall_east and !has_wall_south and !has_wall_west:
		return PI # Outer corner blocks north-east (faces south-west)
	elif has_wall_south and has_wall_east and !has_wall_north and !has_wall_west:
		return 3 * PI / 2 # Outer corner blocks south-east (faces north-west)
	elif has_wall_south and has_wall_west and !has_wall_north and !has_wall_east:
		return 0.0 # Outer corner blocks south-west (faces north-east)
	elif has_wall_north and has_wall_west and !has_wall_south and !has_wall_east:
		return PI / 2 # Outer corner blocks north-west (faces south-east)
	
	# Alternative approach - check diagonal floors for outer corners
	var has_floor_ne = is_valid_position(Vector2i(x + 1, y - 1)) and is_floor_or_corridor(x + 1, y - 1)
	var has_floor_se = is_valid_position(Vector2i(x + 1, y + 1)) and is_floor_or_corridor(x + 1, y + 1)
	var has_floor_sw = is_valid_position(Vector2i(x - 1, y + 1)) and is_floor_or_corridor(x - 1, y + 1)
	var has_floor_nw = is_valid_position(Vector2i(x - 1, y - 1)) and is_floor_or_corridor(x - 1, y - 1)
	
	# Check for diagonal floor patterns (outer corners)
	if has_floor_ne and !has_floor_nw and !has_floor_se and !has_floor_sw:
		return PI # Corner faces away from NE floor
	elif has_floor_se and !has_floor_ne and !has_floor_sw and !has_floor_nw:
		return 3 * PI / 2 # Corner faces away from SE floor
	elif has_floor_sw and !has_floor_se and !has_floor_nw and !has_floor_ne:
		return 0.0 # Corner faces away from SW floor
	elif has_floor_nw and !has_floor_sw and !has_floor_ne and !has_floor_se:
		return PI / 2 # Corner faces away from NW floor
	
	# Default case - no clear pattern detected
	return 0.0

func create_enhanced_wall_tile(position: Vector3, grid_x: int, grid_y: int):
	var wall_type = wall_types[grid_x][grid_y]
	var wall_asset = get_appropriate_wall_asset(wall_type)
	
	if ResourceLoader.exists(wall_asset):
		var wall_scene = load(wall_asset)
		var wall_instance = wall_scene.instantiate()
		wall_instance.position = position
		
		# Apply appropriate rotation based on wall type
		var rotation = 0.0
		
		# For corners, calculate rotation based on neighbors
		if wall_type in [WallType.CORNER_NE, WallType.CORNER_SE, WallType.CORNER_SW, WallType.CORNER_NW]:
			rotation = get_corner_rotation_from_neighbors(grid_x, grid_y)
		else:
			rotation = get_wall_rotation(wall_type)
		
		wall_instance.rotation.y = rotation
		
		 # Apply RTX wall material to all mesh instances
		apply_rtx_material_to_wall(wall_instance)
		
		# Add collision to wall
		add_collision_to_mesh(wall_instance)
		wall_instance.add_to_group("walls")
		wall_container.add_child(wall_instance)
		
		# DEBUG: Print corner information
		if wall_type in [WallType.CORNER_NE, WallType.CORNER_SE, WallType.CORNER_SW, WallType.CORNER_NW]:
			print("Corner at (", grid_x, ",", grid_y, ") type:", wall_type, " rotation:", rad_to_deg(rotation), "°")

func determine_wall_type(x: int, y: int) -> WallType:
	# Check neighboring floors in cardinal directions
	var has_floor_north = is_valid_position(Vector2i(x, y - 1)) and is_floor_or_corridor(x, y - 1)
	var has_floor_south = is_valid_position(Vector2i(x, y + 1)) and is_floor_or_corridor(x, y + 1)
	var has_floor_east = is_valid_position(Vector2i(x + 1, y)) and is_floor_or_corridor(x + 1, y)
	var has_floor_west = is_valid_position(Vector2i(x - 1, y)) and is_floor_or_corridor(x - 1, y)
	
	# Also check diagonal floors for better corner detection
	var has_floor_ne = is_valid_position(Vector2i(x + 1, y - 1)) and is_floor_or_corridor(x + 1, y - 1)
	var has_floor_se = is_valid_position(Vector2i(x + 1, y + 1)) and is_floor_or_corridor(x + 1, y + 1)
	var has_floor_sw = is_valid_position(Vector2i(x - 1, y + 1)) and is_floor_or_corridor(x - 1, y + 1)
	var has_floor_nw = is_valid_position(Vector2i(x - 1, y - 1)) and is_floor_or_corridor(x - 1, y - 1)
	
	var floor_count = 0
	if has_floor_north: floor_count += 1
	if has_floor_south: floor_count += 1
	if has_floor_east: floor_count += 1
	if has_floor_west: floor_count += 1
	
	# Determine wall type based on adjacent floors
	match floor_count:
		0:
			# No adjacent floors - check if it's an outer corner by looking at diagonals
			var diagonal_floor_count = 0
			if has_floor_ne: diagonal_floor_count += 1
			if has_floor_se: diagonal_floor_count += 1
			if has_floor_sw: diagonal_floor_count += 1
			if has_floor_nw: diagonal_floor_count += 1
			
			if diagonal_floor_count == 1:
				# Single diagonal floor = outer corner
				if has_floor_ne:
					return WallType.CORNER_NE # Outer corner with floor to NE
				elif has_floor_se:
					return WallType.CORNER_SE # Outer corner with floor to SE
				elif has_floor_sw:
					return WallType.CORNER_SW # Outer corner with floor to SW
				elif has_floor_nw:
					return WallType.CORNER_NW # Outer corner with floor to NW
			
			return WallType.STRAIGHT_NS # Default to straight
			
		1:
			# End wall - determine orientation based on single adjacent floor
			if has_floor_north or has_floor_south:
				return WallType.STRAIGHT_EW # Wall blocks north-south movement
			else:
				return WallType.STRAIGHT_NS # Wall blocks east-west movement
				
		2:
			# Either straight wall or inner corner
			if (has_floor_north and has_floor_south):
				return WallType.STRAIGHT_EW # Wall runs east-west
			elif (has_floor_east and has_floor_west):
				return WallType.STRAIGHT_NS # Wall runs north-south
			elif (has_floor_north and has_floor_east):
				return WallType.CORNER_NE # Inner corner opening north-east
			elif (has_floor_south and has_floor_east):
				return WallType.CORNER_SE # Inner corner opening south-east
			elif (has_floor_south and has_floor_west):
				return WallType.CORNER_SW # Inner corner opening south-west
			elif (has_floor_north and has_floor_west):
				return WallType.CORNER_NW # Inner corner opening north-west
			else:
				return WallType.STRAIGHT_NS # Default fallback
				
		3:
			# T-junction - determine which direction is missing
			if not has_floor_north:
				return WallType.JUNCTION_T_N # T-junction opening north
			elif not has_floor_east:
				return WallType.JUNCTION_T_E # T-junction opening east
			elif not has_floor_south:
				return WallType.JUNCTION_T_S # T-junction opening south
			elif not has_floor_west:
				return WallType.JUNCTION_T_W # T-junction opening west
			else:
				return WallType.JUNCTION_CROSS # Shouldn't happen with 3 floors
				
		4:
			# 4-way crossing
			return WallType.JUNCTION_CROSS
			
		_:
			# Default fallback
			return WallType.STRAIGHT_NS

func analyze_wall_types():
	print("Analyzing wall types for corners and orientations...")
	
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			match grid[x][y]:
				CellType.WALL:
					wall_types[x][y] = determine_wall_type(x, y)
				CellType.DOOR:
					wall_types[x][y] = determine_door_type(x, y)

func create_walls():
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			if grid[x][y] == CellType.FLOOR or grid[x][y] == CellType.CORRIDOR:
				# Check adjacent cells for wall placement (only cardinal directions)
				var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
				
				for dir in directions:
					var nx = x + dir.x
					var ny = y + dir.y
					
					if is_valid_position(Vector2i(nx, ny)) and grid[nx][ny] == CellType.EMPTY:
						grid[nx][ny] = CellType.WALL
	
	# ADD OUTER CORNERS - check for corner positions that need corner pieces
	add_outer_corners()
	
	# Add doors between rooms and corridors
	add_doors_to_rooms()

func add_outer_corners():
	print("Adding outer corner walls...")
	
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			if grid[x][y] == CellType.EMPTY:
				# Check if this empty space should be an outer corner
				if should_be_outer_corner(x, y):
					grid[x][y] = CellType.WALL

func should_be_outer_corner(x: int, y: int) -> bool:
	# Check if this position forms an outer corner between two walls
	var has_wall_north = is_valid_position(Vector2i(x, y - 1)) and grid[x][y - 1] == CellType.WALL
	var has_wall_south = is_valid_position(Vector2i(x, y + 1)) and grid[x][y + 1] == CellType.WALL
	var has_wall_east = is_valid_position(Vector2i(x + 1, y)) and grid[x + 1][y] == CellType.WALL
	var has_wall_west = is_valid_position(Vector2i(x - 1, y)) and grid[x - 1][y] == CellType.WALL
	
	# Check diagonal positions for floors (this indicates we need an outer corner)
	var has_floor_ne = is_valid_position(Vector2i(x + 1, y - 1)) and is_floor_or_corridor(x + 1, y - 1)
	var has_floor_se = is_valid_position(Vector2i(x + 1, y + 1)) and is_floor_or_corridor(x + 1, y + 1)
	var has_floor_sw = is_valid_position(Vector2i(x - 1, y + 1)) and is_floor_or_corridor(x - 1, y + 1)
	var has_floor_nw = is_valid_position(Vector2i(x - 1, y - 1)) and is_floor_or_corridor(x - 1, y - 1)
	
	# If we have walls on two adjacent sides and a floor diagonally opposite, we need an outer corner
	if (has_wall_north and has_wall_east and has_floor_se):
		return true # Outer corner NE
	elif (has_wall_south and has_wall_east and has_floor_sw):
		return true # Outer corner SE
	elif (has_wall_south and has_wall_west and has_floor_nw):
		return true # Outer corner SW
	elif (has_wall_north and has_wall_west and has_floor_ne):
		return true # Outer corner NW
	
	return false

func get_appropriate_wall_asset(wall_type: WallType) -> String:
	match wall_type:
		WallType.CORNER_NE, WallType.CORNER_SE, WallType.CORNER_SW, WallType.CORNER_NW:
			return wall_assets["corner"][0] if wall_assets["corner"].size() > 0 else wall_assets["straight"][0]
		WallType.JUNCTION_T_N, WallType.JUNCTION_T_E, WallType.JUNCTION_T_S, WallType.JUNCTION_T_W:
			return wall_assets["junction"][0] if wall_assets["junction"].size() > 0 else wall_assets["straight"][0]
		WallType.JUNCTION_CROSS:
			var junction_assets = wall_assets["junction"]
			return junction_assets[1] if junction_assets.size() > 1 else junction_assets[0]
		_:
			return wall_assets["straight"][randi() % wall_assets["straight"].size()]

func determine_door_type(x: int, y: int) -> WallType:
	# Check neighboring floors to determine door orientation
	var has_floor_north = is_valid_position(Vector2i(x, y - 1)) and is_floor_or_corridor(x, y - 1)
	var has_floor_south = is_valid_position(Vector2i(x, y + 1)) and is_floor_or_corridor(x, y + 1)
	var has_floor_east = is_valid_position(Vector2i(x + 1, y)) and is_floor_or_corridor(x + 1, y)
	var has_floor_west = is_valid_position(Vector2i(x - 1, y)) and is_floor_or_corridor(x - 1, y)
	
	if has_floor_north or has_floor_south:
		return WallType.DOOR_EW # Door in east-west wall
	else:
		return WallType.DOOR_NS # Door in north-south wall

func instantiate_geometry():
	var cell_size = 4.0
	
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			var world_pos = Vector3(x * cell_size, 0, y * cell_size)
			
			match grid[x][y]:
				CellType.FLOOR, CellType.CORRIDOR:
					create_floor_tile(world_pos)
				CellType.WALL:
					create_enhanced_wall_tile(world_pos, x, y)
				CellType.DOOR:
					create_door_tile(world_pos, x, y)

func get_door_rotation(door_type: WallType) -> float:
	match door_type:
		WallType.DOOR_NS:
			return PI / 2 # Door in north-south wall (rotated 90 degrees)
		WallType.DOOR_EW:
			return 0.0 # Door in east-west wall (no rotation)
		_:
			return 0.0

func add_foundation_floors():
	print("Adding foundation floors under walls...")
	
	var cell_size = 4.0
	
	# Add floor tiles under every wall and door
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			if grid[x][y] == CellType.WALL or grid[x][y] == CellType.DOOR:
				var foundation_pos = Vector3(x * cell_size, 0, y * cell_size)
				create_foundation_tile(foundation_pos)

func add_enhanced_lighting():
	print("Adding enhanced torch lighting...")
	
	var cell_size = 4.0
	
	# Place torches on suitable walls (not on doors)
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			if grid[x][y] == CellType.WALL and should_place_torch_on_wall(x, y):
				var wall_pos = Vector3(x * cell_size, 0, y * cell_size)
				var torch_info = calculate_torch_position(x, y, wall_pos)
				
				if torch_info.valid:
					create_wall_torch(torch_info.position, torch_info.rotation)

func should_place_torch_on_wall(grid_x: int, grid_y: int) -> bool:
	# Only place torches on walls that border floors/corridors
	var adjacent_floors = 0
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for dir in directions:
		var nx = grid_x + dir.x
		var ny = grid_y + dir.y
		if is_valid_position(Vector2i(nx, ny)) and is_floor_or_corridor(nx, ny):
			adjacent_floors += 1
	
	# Place torch on walls that have 1-2 adjacent floors and are spaced out
	if adjacent_floors >= 1 and adjacent_floors <= 2:
		# Add spacing logic - only place torch if no other torch nearby
		return not has_nearby_torch(grid_x, grid_y, 4)
	
	return false

func has_nearby_torch(grid_x: int, grid_y: int, radius: int) -> bool:
	# Check if there's already a torch within the radius
	for torch in torch_container.get_children():
		var torch_grid_pos = Vector2i(
			int(torch.position.x / 4.0),
			int(torch.position.z / 4.0)
		)
		var distance = abs(torch_grid_pos.x - grid_x) + abs(torch_grid_pos.y - grid_y)
		if distance < radius:
			return true
	return false

func calculate_torch_position(grid_x: int, grid_y: int, wall_pos: Vector3) -> Dictionary:
	var result = {"valid": false, "position": Vector3.ZERO, "rotation": 0.0}
	
	# Find the best direction to face the torch (towards floor)
	var directions = [
		Vector2i(0, -1), # North
		Vector2i(1, 0), # East
		Vector2i(0, 1), # South
		Vector2i(-1, 0) # West
	]
	
	var rotations = [PI, -PI / 2, 0.0, PI / 2] # Torch rotations to face floors
	var offsets = [
		Vector3(0, 0, -0.3), # North wall - torch faces south
		Vector3(0.3, 0, 0), # East wall - torch faces west
		Vector3(0, 0, 0.3), # South wall - torch faces north
		Vector3(-0.3, 0, 0) # West wall - torch faces east
	]
	
	for i in range(directions.size()):
		var dir = directions[i]
		var nx = grid_x + dir.x
		var ny = grid_y + dir.y
		
		if is_valid_position(Vector2i(nx, ny)) and is_floor_or_corridor(nx, ny):
			result.valid = true
			result.position = wall_pos + offsets[i] + Vector3(0, torch_height, 0)
			result.rotation = rotations[i]
			break
	
	return result

func create_wall_torch(position: Vector3, rotation: float):
	if torch_scene:
		var torch_instance = torch_scene.instantiate()
		torch_instance.position = position
		torch_instance.rotation.y = rotation
		
		# Add slight variation
		torch_instance.position.y += randf_range(-0.1, 0.1)
		
		torch_container.add_child(torch_instance)

func add_collision_to_mesh(node: Node3D):
	var mesh_instances = find_mesh_instances_recursive(node)
	
	for mesh_instance in mesh_instances:
		if mesh_instance is MeshInstance3D and mesh_instance.mesh:
			var static_body = StaticBody3D.new()
			var collision_shape = CollisionShape3D.new()
			var shape = mesh_instance.mesh.create_trimesh_shape()
			collision_shape.shape = shape
			static_body.add_child(collision_shape)
			mesh_instance.add_child(static_body)

func find_mesh_instances_recursive(node: Node) -> Array:
	var mesh_instances = []
	
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		mesh_instances.append_array(find_mesh_instances_recursive(child))
	
	return mesh_instances

func get_first_room_world_center() -> Vector3:
	var cell_size = 4.0
	return Vector3(first_room_center.x * cell_size, 0, first_room_center.y * cell_size)

func get_player_spawn_position() -> Vector3:
	if rooms.size() > 0:
		var room = rooms[0]
		var cell_size = 4.0
		var spawn_x = room.position.x + room.size.x / 2
		var spawn_y = room.position.y + room.size.y / 2
		return Vector3(spawn_x * cell_size, 1.0, spawn_y * cell_size)
	
	return Vector3(0, 1, 0)

func add_puddles():
	print("Adding puddles to dungeon floors...")
	
	var cell_size = 4.0
	var puddle_count = 0
	
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			if (grid[x][y] == CellType.FLOOR or grid[x][y] == CellType.CORRIDOR) and randf() < puddle_chance:
				if not is_position_occupied(Vector2i(x, y)) and is_good_puddle_location(x, y):
					var puddle_pos = Vector3(x * cell_size, 0.01, y * cell_size)
					create_puddle(puddle_pos)
					mark_position_occupied(Vector2i(x, y))
					puddle_count += 1
	
	print("Placed ", puddle_count, " puddles")

func create_puddle(position: Vector3):
	var puddle_asset = puddle_assets[randi() % puddle_assets.size()]
	if ResourceLoader.exists(puddle_asset):
		var puddle_scene = load(puddle_asset)
		var puddle_instance = puddle_scene.instantiate()
		puddle_instance.position = position
		
		# Add slight rotation variation
		puddle_instance.rotation.y = randf() * PI * 2
		
		puddle_instance.add_to_group("puddles")
		puddle_container.add_child(puddle_instance)

func is_good_puddle_location(grid_x: int, grid_y: int) -> bool:
	# Avoid placing puddles near doors or room centers
	for door_pos in doors:
		var distance = abs(door_pos.x - grid_x) + abs(door_pos.y - grid_y)
		if distance < 2:
			return false
	
	# Avoid room centers (first room spawn area)
	if abs(grid_x - first_room_center.x) <= 2 and abs(grid_y - first_room_center.y) <= 2:
		return false
	
	return true

func place_enemies():
	print("Spawning enemies...")
	
	var enemy_count = 0
	var target_enemies = int(rooms.size() * enemy_density)
	
	# Skip first room (player spawn)
	for i in range(1, rooms.size()):
		var room = rooms[i]
		var room_enemy_count = randi_range(0, 2)
		
		for j in range(room_enemy_count):
			if enemy_count >= target_enemies:
				break
			
			var enemy_pos = find_safe_room_position(room)
			if enemy_pos != Vector2i(-1, -1):
				spawn_enemy(enemy_pos)
				enemy_count += 1
	
	# Add some corridor enemies
	var corridor_enemies = int(target_enemies * 0.3)
	for i in range(corridor_enemies):
		var corridor_pos = find_safe_corridor_position()
		if corridor_pos != Vector2i(-1, -1):
			spawn_enemy(corridor_pos)
			enemy_count += 1
	
	print("Spawned ", enemy_count, " enemies")

func spawn_enemy(grid_pos: Vector2i):
	var available_enemies = []
	for enemy_scene_path in enemy_scenes:
		if ResourceLoader.exists(enemy_scene_path):
			available_enemies.append(enemy_scene_path)
	
	if available_enemies.size() == 0:
		print("Warning: No enemy scenes found")
		return
	
	var enemy_scene_path = available_enemies[randi() % available_enemies.size()]
	var enemy_scene = load(enemy_scene_path)
	var enemy_instance = enemy_scene.instantiate()
	
	var cell_size = 4.0
	var world_pos = Vector3(grid_pos.x * cell_size, 0.5, grid_pos.y * cell_size)
	enemy_instance.position = world_pos
	
	# Add slight position variation
	enemy_instance.position.x += randf_range(-0.5, 0.5)
	enemy_instance.position.z += randf_range(-0.5, 0.5)
	
	enemy_instance.add_to_group("enemies")
	enemy_container.add_child(enemy_instance)
	mark_position_occupied(grid_pos)

func place_props():
	print("Placing props...")
	
	var prop_count = 0
	
	# Place props in rooms
	for i in range(rooms.size()):
		var room = rooms[i]
		var room_prop_count = randi_range(1, 3)
		
		# Reduce props in first room
		if i == 0:
			room_prop_count = randi_range(0, 1)
		
		for j in range(room_prop_count):
			if randf() < prop_density:
				var prop_pos = find_safe_room_position(room)
				if prop_pos != Vector2i(-1, -1):
					place_random_prop(prop_pos)
					prop_count += 1
	
	print("Placed ", prop_count, " props")

func place_random_prop(grid_pos: Vector2i):
	var prop_categories = prop_assets.keys()
	var category = prop_categories[randi() % prop_categories.size()]
	var category_assets = prop_assets[category]
	
	if category_assets.size() == 0:
		return
	
	var prop_asset = category_assets[randi() % category_assets.size()]
	if ResourceLoader.exists(prop_asset):
		var prop_scene = load(prop_asset)
		var prop_instance = prop_scene.instantiate()
		
		var cell_size = 4.0
		var world_pos = Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)
		prop_instance.position = world_pos
		
		# Add rotation variation
		prop_instance.rotation.y = randf() * PI * 2
		
		prop_instance.add_to_group("props")
		prop_container.add_child(prop_instance)
		mark_position_occupied(grid_pos)

func find_safe_room_position(room: Rect2i) -> Vector2i:
	var attempts = 0
	var max_attempts = 20
	
	while attempts < max_attempts:
		var x = randi_range(room.position.x + 1, room.position.x + room.size.x - 2)
		var y = randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
		var pos = Vector2i(x, y)
		
		if not is_position_occupied(pos) and is_safe_spawn_location(x, y):
			return pos
		
		attempts += 1
	
	return Vector2i(-1, -1)

func find_safe_corridor_position() -> Vector2i:
	var corridor_positions = []
	
	# Find all corridor positions
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			if grid[x][y] == CellType.CORRIDOR and not is_position_occupied(Vector2i(x, y)):
				corridor_positions.append(Vector2i(x, y))
	
	if corridor_positions.size() == 0:
		return Vector2i(-1, -1)
	
	return corridor_positions[randi() % corridor_positions.size()]

func is_safe_spawn_location(grid_x: int, grid_y: int) -> bool:
	# Avoid spawning too close to player start
	var distance_to_spawn = abs(grid_x - first_room_center.x) + abs(grid_y - first_room_center.y)
	if distance_to_spawn < 3:
		return false
	
	# Avoid spawning near doors
	for door_pos in doors:
		var distance_to_door = abs(door_pos.x - grid_x) + abs(door_pos.y - grid_y)
		if distance_to_door < 2:
			return false
	
	return true

func is_position_occupied(pos: Vector2i) -> bool:
	return pos in occupied_positions

func mark_position_occupied(pos: Vector2i):
	if not is_position_occupied(pos):
		occupied_positions.append(pos)

func setup_containers():
	floor_container = Node3D.new()
	floor_container.name = "Floors"
	add_child(floor_container)
	
	wall_container = Node3D.new()
	wall_container.name = "Walls"
	add_child(wall_container)
	
	prop_container = Node3D.new()
	prop_container.name = "Props"
	add_child(prop_container)
	
	torch_container = Node3D.new()
	torch_container.name = "Torches"
	add_child(torch_container)
	
	enemy_container = Node3D.new()
	enemy_container.name = "Enemies"
	add_child(enemy_container)
	
	puddle_container = Node3D.new()
	puddle_container.name = "Puddles"
	add_child(puddle_container)

func print_generation_stats():
	print("=== Dungeon Generation Stats ===")
	print("Rooms: ", rooms.size())
	print("Doors: ", doors.size())
	print("Floors: ", floor_container.get_child_count())
	print("Walls: ", wall_container.get_child_count())
	print("Torches: ", torch_container.get_child_count())
	print("Puddles: ", puddle_container.get_child_count())
	print("Props: ", prop_container.get_child_count())
	print("Enemies: ", enemy_container.get_child_count())
	print("================================")

func clear_dungeon():
	occupied_positions.clear()
	rooms.clear()
	doors.clear()
	
	for container in [floor_container, wall_container, prop_container,
					 torch_container, enemy_container, puddle_container]:
		if container:
			for child in container.get_children():
				child.queue_free()

func regenerate_dungeon():
	print("Regenerating dungeon...")
	clear_dungeon()
	await get_tree().process_frame # Wait for cleanup
	generate_dungeon()

# Add these utility functions at the end of your script

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < dungeon_width and pos.y >= 0 and pos.y < dungeon_height

func is_floor_or_corridor(x: int, y: int) -> bool:
	if not is_valid_position(Vector2i(x, y)):
		return false
	return grid[x][y] == CellType.FLOOR or grid[x][y] == CellType.CORRIDOR
