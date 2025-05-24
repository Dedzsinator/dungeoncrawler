extends Node3D

@onready var player_scene: PackedScene = preload("res://Scenes/Player/player.tscn")
@onready var mage_scene: PackedScene = preload("res://Scenes/NPCs/mage.tscn")
@onready var warrior_scene: PackedScene = preload("res://Scenes/Monsters/SkeletonWarrior/skeleton_warrior.tscn")
@onready var puddle_model_scene: PackedScene = preload("res://Models/PuddleModel.fbx")

# Procedural generation
var dungeon_generator: ProceduralDungeonGenerator

# RTX Settings
@export var enable_rtx: bool = true
@export var enable_water_puddles: bool = true
@export var puddle_density: float = 0.2
@export var max_puddles: int = 10

# Generation parameters
@export var dungeon_width: int = 25
@export var dungeon_height: int = 25
@export var room_min_size: int = 6
@export var room_max_size: int = 12
@export var max_rooms: int = 10

# References
var player: Node3D
var mage: Node3D
var rtx_manager: Node3D

func _ready() -> void:
	print("Starting procedural level generation...")
	
	# Generate the dungeon first
	await generate_procedural_dungeon()
	# Spawn entities in the first room
	spawn_player_and_mage()
	
	# Spawn monsters in other rooms
	spawn_monsters()
	
	# Add water puddles if enabled
	if enable_water_puddles:
		spawn_water_puddles()
	
	# Setup RTX if enabled
	if enable_rtx:
		setup_rtx()
	
	print("Procedural level generation complete!")

func generate_procedural_dungeon():
	print("Generating procedural dungeon...")
	
	# Create and configure the dungeon generator
	dungeon_generator = ProceduralDungeonGenerator.new()
	dungeon_generator.name = "DungeonGenerator"
	dungeon_generator.dungeon_width = dungeon_width
	dungeon_generator.dungeon_height = dungeon_height
	dungeon_generator.room_min_size = room_min_size
	dungeon_generator.room_max_size = room_max_size
	dungeon_generator.max_rooms = max_rooms
	
	add_child(dungeon_generator)
	
	# Wait a few frames for generation to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Dungeon generation complete! Generated ", dungeon_generator.rooms.size(), " rooms")

func spawn_player_and_mage():
	print("Spawning player and mage in first room...")
	
	if not dungeon_generator or dungeon_generator.rooms.is_empty():
		print("ERROR: No rooms available for spawning!")
		# Fallback: spawn at origin
		spawn_player(Vector3(0, 2, 0))
		spawn_mage(Vector3(4, 0, 4))
		return
	
	# Get the first room
	var first_room = dungeon_generator.rooms[0]
	var cell_size = 4.0 # This should match the generator's cell size
	
	# Calculate room center in world coordinates
	var room_center_x = first_room.position.x + (first_room.size.x / 2.0)
	var room_center_y = first_room.position.y + (first_room.size.y / 2.0)
	var center_world_pos = Vector3(room_center_x * cell_size, 0, room_center_y * cell_size)
	
	print("First room: ", first_room)
	print("Room center (grid): ", Vector2(room_center_x, room_center_y))
	print("Room center (world): ", center_world_pos)
	
	# Spawn Player slightly offset from center
	var player_pos = center_world_pos + Vector3(-1, 2, -1) # Reduced offset and added Y height
	spawn_player(player_pos)
	
	# Check if mage already exists in the scene
	var existing_mage = find_existing_mage()
	if existing_mage:
		mage = existing_mage
		print("Found existing mage at: ", mage.global_position)
	else:
		# Spawn Mage slightly offset from center
		var mage_pos = center_world_pos + Vector3(1, 0, 1) # Reduced offset
		spawn_mage(mage_pos)
	
	print("Player spawned at: ", player_pos)
	print("Mage position: ", mage.global_position if mage else "None")

func spawn_player(position: Vector3):
	player = player_scene.instantiate()
	player.position = position # Remove the extra +Vector3(0, 5, 0) that was pushing it too high
	player.name = "Player"
	add_child(player)
	
	print("Player spawned at: ", player.position)

func spawn_mage(position: Vector3):
	mage = mage_scene.instantiate()
	mage.position = position
	mage.name = "Mage"
	add_child(mage)
	
	print("Mage spawned at: ", position)

func find_existing_mage() -> Node3D:
	# Check if the dungeon generator already created a mage
	var all_children = get_all_children(dungeon_generator)
	for child in all_children:
		if child.name.to_lower().contains("mage"):
			return child
	return null

func get_all_children(node: Node) -> Array:
	var children = []
	for child in node.get_children():
		children.append(child)
		children.append_array(get_all_children(child))
	return children

func spawn_monsters():
	print("Spawning monsters in rooms...")
	
	if not dungeon_generator or dungeon_generator.rooms.size() < 2:
		print("Not enough rooms for monster spawning")
		return
	
	var monsters_node = Node3D.new()
	monsters_node.name = "Monsters"
	add_child(monsters_node)
	
	# Skip first room (has player and mage), spawn monsters in other rooms
	for i in range(1, dungeon_generator.rooms.size()):
		var room = dungeon_generator.rooms[i]
		var monster_count = randi_range(1, 3)
		
		for j in range(monster_count):
			spawn_monster_in_room(room, monsters_node)
	
	print("Monster spawning complete!")

func spawn_monster_in_room(room: Rect2i, monsters_container: Node3D):
	var monster = warrior_scene.instantiate()
	
	# Find random position in room, avoiding walls
	var cell_size = 4.0
	var monster_x = randi_range(room.position.x + 1, room.position.x + room.size.x - 2)
	var monster_y = randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
	
	monster.position = Vector3(monster_x * cell_size, 0, monster_y * cell_size)
	
	# Set player reference if monster script expects it
	if player and monster.has_method("set_target"):
		monster.set_target(player)
	elif player and "player" in monster:
		monster.player = player
	
	monsters_container.add_child(monster)
	print("Monster spawned at: ", monster.position)

func setup_rtx():
	print("Setting up RTX for procedural level...")
	
	# Create RTX manager
	var rtx_manager_script = preload("res://Scripts/rtx_manager.gd")
	rtx_manager = Node3D.new()
	rtx_manager.set_script(rtx_manager_script)
	rtx_manager.name = "RTXManager"
	add_child(rtx_manager)
	
	# Tag geometry for RTX
	tag_geometry_for_rtx()
	
	# Setup player RTX armor
	if player and player.has_method("setup_rtx_armor"):
		player.setup_rtx_armor()
	
	print("RTX setup complete!")

func tag_geometry_for_rtx():
	print("Tagging geometry for RTX...")
	
	# Find all mesh instances in the dungeon
	var mesh_instances = []
	
	# Get floor meshes
	var floors_node = dungeon_generator.get_node("Floors")
	if floors_node:
		mesh_instances.append_array(find_all_mesh_instances(floors_node))
	
	# Get wall meshes
	var walls_node = dungeon_generator.get_node("Walls")
	if walls_node:
		mesh_instances.append_array(find_all_mesh_instances(walls_node))
	
	# Get prop meshes
	var props_node = dungeon_generator.get_node("Props")
	if props_node:
		mesh_instances.append_array(find_all_mesh_instances(props_node))
	
	# Tag all found meshes for RTX
	for mesh_instance in mesh_instances:
		if mesh_instance is MeshInstance3D:
			mesh_instance.add_to_group("rtx_geometry")
	
	print("Tagged ", mesh_instances.size(), " mesh instances for RTX")

func find_all_mesh_instances(node: Node) -> Array:
	var result = []
	
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		result.append_array(find_all_mesh_instances(child))
	
	return result

# Add water puddles using PuddleModel.fbx
func spawn_water_puddles():
	if not enable_water_puddles:
		return
	
	print("Adding water puddles using PuddleModel.fbx...")
	
	var puddles_node = Node3D.new()
	puddles_node.name = "WaterPuddles"
	add_child(puddles_node)
	
	var puddle_count = 0
	var max_attempts = 50
	
	# Try to place puddles in random floor locations
	for attempt in range(max_attempts):
		if puddle_count >= max_puddles:
			break
		
		if randf() > puddle_density:
			continue
		
		# Pick a random room to place puddle in
		if dungeon_generator.rooms.is_empty():
			continue
		
		var room = dungeon_generator.rooms[randi() % dungeon_generator.rooms.size()]
		var cell_size = 4.0
		
		# Random position within room
		var puddle_x = randi_range(room.position.x + 1, room.position.x + room.size.x - 2)
		var puddle_y = randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
		var puddle_pos = Vector3(puddle_x * cell_size, 0.05, puddle_y * cell_size) # Slightly above floor
		
		# Create puddle using PuddleModel.fbx
		create_enhanced_water_puddle(puddle_pos, puddles_node)
		puddle_count += 1
	
	print("Spawned ", puddle_count, " water puddles using PuddleModel.fbx")

func create_enhanced_water_puddle(position: Vector3, container: Node3D):
	var puddle: Node3D
	
	if puddle_model_scene:
		puddle = puddle_model_scene.instantiate()
		print("Using PuddleModel.fbx for enhanced reflections")
		
		# Apply enhanced water material for RTX
		apply_water_material_to_puddle(puddle)
	else:
		# Fallback: create simple puddle mesh
		puddle = create_simple_puddle()
		print("Created fallback water puddle")
	
	puddle.transform.origin = position
	
	# Varied puddle sizes for visual interest
	var puddle_size = randf_range(0.5, 1.2)
	puddle.scale = Vector3(puddle_size, 0.1, puddle_size) # Keep Y scale small for puddle
	
	# Add some random rotation for natural look
	puddle.rotation.y = randf() * PI * 2
	
	container.add_child(puddle)

func apply_water_material_to_puddle(puddle_node: Node3D):
	var mesh_instances = find_all_mesh_instances(puddle_node)
	
	for mesh_instance in mesh_instances:
		if mesh_instance is MeshInstance3D:
			var material = StandardMaterial3D.new()
			
			# Much more conservative water settings
			material.albedo_color = Color(0.1, 0.3, 0.5, 0.6) # Darker, less saturated
			material.metallic = 0.1 # Much less metallic
			material.roughness = 0.4 # Much rougher
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			
			# Minimal clearcoat to prevent overexposure
			material.clearcoat_enabled = true
			material.clearcoat = 0.1 # Very low clearcoat
			material.clearcoat_roughness = 0.3 # Rougher clearcoat
			
			# Disable rim lighting that can cause overexposure
			material.rim_enabled = false
			
			# Add some subtle refraction instead
			material.refraction_enabled = true
			material.refraction_scale = 0.05 # Very subtle
			
			mesh_instance.material_override = material
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.add_to_group("rtx_water")

func create_simple_puddle() -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(2.0, 2.0)
	plane_mesh.subdivide_width = 4
	plane_mesh.subdivide_depth = 4
	mesh_instance.mesh = plane_mesh
	
	# Much more conservative fallback material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.3, 0.4, 0.5) # Darker, less reflective
	material.metallic = 0.0 # No metallic
	material.roughness = 0.6 # Much rougher
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# No clearcoat for fallback
	material.clearcoat_enabled = false
	
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	return mesh_instance

# Optional: Add method to regenerate dungeon
func regenerate_dungeon():
	print("Regenerating dungeon...")
	
	# Clear existing dungeon
	if dungeon_generator:
		dungeon_generator.queue_free()
	
	# Clear entities
	if player:
		player.queue_free()
	if mage:
		mage.queue_free()
	
	# Clear monsters
	var monsters_node = get_node_or_null("Monsters")
	if monsters_node:
		monsters_node.queue_free()
	
	# Clear water puddles
	var puddles_node = get_node_or_null("WaterPuddles")
	if puddles_node:
		puddles_node.queue_free()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	# Regenerate everything
	await generate_procedural_dungeon()
	spawn_player_and_mage()
	spawn_monsters()
	
	if enable_water_puddles:
		spawn_water_puddles()
	
	if enable_rtx:
		setup_rtx()
	
	print("Dungeon regeneration complete!")

func _input(event):
	if event.is_action_pressed("ui_text_backspace"):
		regenerate_dungeon()
