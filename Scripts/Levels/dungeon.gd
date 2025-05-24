extends Node3D

@onready var player_scene: PackedScene = preload("res://Scenes/Player/player.tscn")
@onready var mage_scene: PackedScene = preload("res://Scenes/NPCs/mage.tscn")
@onready var warrior_scene: PackedScene = preload("res://Scenes/Monsters/SkeletonWarrior/skeleton_warrior.tscn")
@onready var water_puddle_scene: PackedScene = preload("res://Scenes/water_puddle.tscn")

# Procedural generation
var dungeon_generator: ProceduralDungeonGenerator

# RTX Settings
@export var enable_rtx: bool = true
@export var enable_water_puddles: bool = true
@export var puddle_density: float = 0.2
@export var max_puddles: int = 10

@export var enable_daylight_cycle: bool = true
@export var start_at_dawn: bool = true
var daylight_cycle: UnifiedEnvironment

# Generation parameters
@export var dungeon_width: int = 25
@export var dungeon_height: int = 25
@export var room_min_size: int = 6
@export var room_max_size: int = 12
@export var max_rooms: int = 10

# Rock generation parameters
@export var rock_density: float = 0.1 # Reduced from typical 0.3-0.5
@export var max_rocks_per_room: int = 2 # Limit rocks per room
@export var enable_rocks: bool = true # Allow disabling rocks entirely

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
	
	if enable_daylight_cycle:
		setup_daylight_cycle()

	# Setup RTX if enabled
	if enable_rtx:
		setup_rtx()
	
	print("Procedural level generation complete!")

func setup_daylight_cycle():
	print("Setting up dynamic daylight cycle...")
	
	# Find the unified environment
	var unified_env = get_node_or_null("WorldEnvironment")
	if not unified_env:
		print("Warning: WorldEnvironment not found!")
		return
	
	# Check if it has the unified environment script attached
	if unified_env.get_script() and unified_env.has_method("set_time_of_day"):
		# Cast to the correct type or use as Node
		daylight_cycle = unified_env as Node # or unified_env as UnifiedEnvironment
		print("Connected to unified environment system")
		
		# Configure settings
		if start_at_dawn:
			daylight_cycle.start_time = 0.25
		else:
			daylight_cycle.start_time = 0.5
		
		daylight_cycle.day_duration = 300.0
		
		# Force setup if not auto-started
		if not daylight_cycle.auto_start:
			daylight_cycle.setup_unified_environment()
		
		# Connect signals
		if daylight_cycle.has_signal("time_changed"):
			daylight_cycle.connect("time_changed", _on_time_changed)
			print("Connected to time_changed signal")
	else:
		print("Warning: WorldEnvironment doesn't have unified environment script!")
		print("Script found: ", unified_env.get_script())
	
	print("Daylight cycle setup complete!")

# Update your time control methods:
func set_time_to_dawn():
	if daylight_cycle and daylight_cycle.has_method("set_time_of_day"):
		daylight_cycle.set_time_of_day(6, 0)
		print("Time set to dawn")

func set_time_to_noon():
	if daylight_cycle and daylight_cycle.has_method("set_time_of_day"):
		daylight_cycle.set_time_of_day(12, 0)
		print("Time set to noon")

func set_time_to_sunset():
	if daylight_cycle and daylight_cycle.has_method("set_time_of_day"):
		daylight_cycle.set_time_of_day(19, 0)
		print("Time set to sunset")

func set_time_to_midnight():
	if daylight_cycle and daylight_cycle.has_method("set_time_of_day"):
		daylight_cycle.set_time_of_day(0, 0)
		print("Time set to midnight")

func toggle_time_pause():
	if daylight_cycle:
		if daylight_cycle.time_speed_multiplier > 0:
			daylight_cycle.pause_time()
			print("Time paused")
		else:
			daylight_cycle.resume_time()
			print("Time resumed")

# Update RTX connection:
func _on_rtx_time_changed(time: float, time_text: String):
	if not rtx_manager:
		return
	
	var is_night = false
	if daylight_cycle and daylight_cycle.has_method("is_night_time"):
		is_night = daylight_cycle.is_night_time()
	
	update_water_reflections_for_time(is_night)

func _on_time_changed(new_time: float, time_text: String):
	# This gets called every frame with time updates
	# You can use this for time-based gameplay mechanics
	pass

func _on_day_phase_changed(phase: String):
	print("Day phase changed to: ", phase)
	
	# You can trigger different events based on time of day
	match phase:
		"Dawn":
			print("The sun rises, monsters retreat to shadows...")
		"Day":
			print("Bright daylight floods the dungeon...")
		"Evening":
			print("Shadows grow longer...")
		"Night":
			print("Darkness falls, monsters become more active...")

func _input(event):
	if event.is_action_pressed("ui_text_backspace"):
		regenerate_dungeon()
	
	# Add time control inputs
	if event.is_action_pressed("ui_accept"): # Space key
		toggle_time_pause()
	
	# Number keys for quick time changes
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				set_time_to_dawn()
				print("Time set to dawn")
			KEY_2:
				set_time_to_noon()
				print("Time set to noon")
			KEY_3:
				set_time_to_sunset()
				print("Time set to sunset")
			KEY_4:
				set_time_to_midnight()
				print("Time set to midnight")
			KEY_5:
				if daylight_cycle:
					daylight_cycle.set_time_speed(5.0)
					print("Time speed increased")
			KEY_6:
				if daylight_cycle:
					daylight_cycle.set_time_speed(1.0)
					print("Time speed normal")

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
	
	# Configure rock generation if the generator supports it
	if "rock_density" in dungeon_generator:
		dungeon_generator.rock_density = rock_density
	if "max_rocks_per_room" in dungeon_generator:
		dungeon_generator.max_rocks_per_room = max_rocks_per_room
	if "enable_rocks" in dungeon_generator:
		dungeon_generator.enable_rocks = enable_rocks
	
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
	if ResourceLoader.exists("res://Scripts/rtx_manager.gd"):
		var rtx_manager_script = preload("res://Scripts/rtx_manager.gd")
		rtx_manager = Node3D.new()
		rtx_manager.set_script(rtx_manager_script)
		rtx_manager.name = "RTXManager"
		add_child(rtx_manager)
		print("RTX Manager loaded successfully")
	else:
		print("Warning: RTX manager script not found, creating basic RTX setup")
		create_basic_rtx_setup()
	
	# Tag geometry for RTX
	tag_geometry_for_rtx()
	
	# Setup player RTX armor
	if player and player.has_method("setup_rtx_armor"):
		player.setup_rtx_armor()
	
	if daylight_cycle:
		daylight_cycle.connect("time_changed", _on_rtx_time_changed)
		print("RTX connected to daylight cycle")

	print("RTX setup complete!")
	
func update_water_reflections_for_time(is_night: bool):
	var puddles_node = get_node_or_null("WaterPuddles")
	if not puddles_node:
		return
	
	for puddle in puddles_node.get_children():
		if puddle is MeshInstance3D and puddle.material_override:
			var material = puddle.material_override as StandardMaterial3D
			if is_night:
				# More reflective at night with moon/stars
				material.metallic = 0.98
				material.roughness = 0.02
				material.clearcoat = 1.0
			else:
				# Less reflective during day
				material.metallic = 0.85
				material.roughness = 0.08
				material.clearcoat = 0.7

func create_basic_rtx_setup():
	# Create a basic RTX manager if the script doesn't exist
	rtx_manager = Node3D.new()
	rtx_manager.name = "RTXManager"
	add_child(rtx_manager)
	
	# Add basic lighting for RTX showcase
	var rtx_light = OmniLight3D.new()
	rtx_light.name = "RTXLight"
	rtx_light.light_energy = 1.2
	rtx_light.light_color = Color(1.0, 0.9, 0.8)
	rtx_light.omni_range = 20.0
	rtx_light.position = Vector3(0, 8, 0)
	rtx_light.shadow_enabled = true
	rtx_manager.add_child(rtx_light)

func tag_geometry_for_rtx():
	print("Tagging geometry for RTX...")
	
	# Find all mesh instances in the dungeon
	var mesh_instances = []
	
	# Get floor meshes
	var floors_node = dungeon_generator.get_node_or_null("Floors")
	if floors_node:
		mesh_instances.append_array(find_all_mesh_instances(floors_node))
	
	# Get wall meshes
	var walls_node = dungeon_generator.get_node_or_null("Walls")
	if walls_node:
		mesh_instances.append_array(find_all_mesh_instances(walls_node))
		# Tag walls specifically for RTX wall material
		for mesh_instance in find_all_mesh_instances(walls_node):
			if mesh_instance is MeshInstance3D:
				mesh_instance.add_to_group("rtx_walls")
	
	# Get prop meshes
	var props_node = dungeon_generator.get_node_or_null("Props")
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

# Add water puddles using water_puddle.tscn
func spawn_water_puddles():
	if not enable_water_puddles:
		return
	
	print("Adding water puddles using water_puddle.tscn...")
	
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
		var puddle_pos = Vector3(puddle_x * cell_size, 0.01, puddle_y * cell_size) # Very slightly above floor
		
		# Create puddle using water_puddle.tscn
		create_water_puddle(puddle_pos, puddles_node)
		puddle_count += 1
	
	print("Spawned ", puddle_count, " water puddles using water_puddle.tscn")

func create_water_puddle(position: Vector3, container: Node3D):
	var puddle: Node3D
	
	if water_puddle_scene:
		puddle = water_puddle_scene.instantiate()
		print("Using water_puddle.tscn")
	else:
		# Fallback: create simple puddle mesh if scene doesn't exist
		puddle = create_simple_puddle()
		print("water_puddle.tscn not found, using fallback puddle")
	
	puddle.position = position
	
	# Varied puddle sizes for visual interest
	var puddle_size = randf_range(0.7, 1.3)
	puddle.scale = Vector3(puddle_size, 1.0, puddle_size) # Keep Y scale at 1.0 for proper water surface
	
	# Add some random rotation for natural look
	puddle.rotation.y = randf() * PI * 2
	
	# Add to RTX water group for enhanced rendering
	puddle.add_to_group("rtx_water")
	
	container.add_child(puddle)

func create_simple_puddle() -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(2.0, 2.0)
	plane_mesh.subdivide_width = 4
	plane_mesh.subdivide_depth = 4
	mesh_instance.mesh = plane_mesh
	
	# Simple water material for fallback
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.4, 0.6, 0.7)
	material.metallic = 0.2
	material.roughness = 0.3
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
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
		player = null
	if mage:
		mage.queue_free()
		mage = null
	
	# Clear RTX manager
	if rtx_manager:
		rtx_manager.queue_free()
		rtx_manager = null
	
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
