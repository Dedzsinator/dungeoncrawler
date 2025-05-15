extends Node3D

# Paths to your room scenes
const START_ROOM_SCENE = "res://Scenes/StartRoom.tscn"
const BOSS_ROOM_SCENE = "res://Scenes/BossRoom.tscn"
const GENERIC_ROOM_SCENE = "res://Scenes/Corridor.tscn"

# More room type definitions for variety
const ROOM_SCENES = {
	"corridor": "res://Scenes/Corridor.tscn",
	"corridor_l": "res://Scenes/CorridorL.tscn",
	"corridor_t": "res://Scenes/CorridorT.tscn",
	# "corridor_x": "res://Scenes/CorridorX.tscn",
	"long_room_1": "res://Scenes/LongRoom1.tscn",
	"long_room_2": "res://Scenes/LongRoom2.tscn",
	"long_room_3": "res://Scenes/LongRoom3.tscn",
	"room_3": "res://Scenes/Room3.tscn",
	"room_4": "res://Scenes/Room4.tscn"
}

# Number of generic rooms between start and boss rooms
const NUM_GENERIC_ROOMS = 10

# Configureable percentage of non-corridor rooms that should be included 
# (increase for more variety, decrease for more corridors)
@export_range(0, 100) var non_corridor_room_percent: int = 40

# Reference to the player scene
const PLAYER_SCENE = "res://Scenes/Player.tscn"
const DOOR_SCENE = "res://Assets/Door.fbx"

# Store room instances
var rooms = []
var player = null
var active_enemies = []
var locked_room = null
var door_instances = []

# Reference to the dungeon generator
var dungeon_generator = null

func _ready():
	print("=== GAME INITIALIZATION ===")
	
	# Add to main group for easier reference
	add_to_group("main")

	# Register ui_help action if it doesn't exist
	if not InputMap.has_action("ui_help"):
		InputMap.add_action("ui_help")
		var event = InputEventKey.new()
		event.keycode = KEY_F1
		InputMap.action_add_event("ui_help", event)
		print("Added ui_help action mapped to F1 key")

	var hud = preload("res://Scenes/HUD.tscn").instantiate()
	add_child(hud)

	var enemy_manager = preload("res://Scripts/EnemyManager.gd").new()
	add_child(enemy_manager)
	
	# Add the room manager to handle seasons and boss rooms
	var room_manager = RoomManager.new()
	room_manager.add_to_group("room_manager")
	add_child(room_manager)
	print("Room manager initialized with seasonal system")
	
	if not InputMap.has_action("switch_weapon"):
		InputMap.add_action("switch_weapon")
		var event = InputEventKey.new()
		event.keycode = KEY_SHIFT
		InputMap.action_add_event("switch_weapon", event)
		print("Added switch_weapon action mapped to Left Shift key")

	# EMERGENCY DEBUG: Skip dungeon generation and just spawn the player in a start room
	if false: # Keep this false to enable dungeon generation
		var start_room = load(START_ROOM_SCENE).instantiate()
		add_child(start_room)
		start_room.name = "StartRoom"
		rooms.append(start_room)
		
		# Spawn the player in the starting room
		spawn_player()
		add_safety_floor()
		return
		
	# Initialize dungeon generator
	dungeon_generator = preload("res://Scripts/DungeonGenerator.gd").new()
	add_child(dungeon_generator)
	
	# Generate dungeon using the generator
	rooms = dungeon_generator.generate_dungeon(NUM_GENERIC_ROOMS, non_corridor_room_percent)
	
	# Debug room information
	if rooms.size() > 0:
		var start_room = rooms[0]
		print("StartRoom name: " + start_room.name)
		print("StartRoom position: " + str(start_room.global_position))
		
		# Check for SpawnPoint specifically
		if start_room.has_node("SpawnPoint"):
			var spawn_point = start_room.get_node("SpawnPoint")
			print("SpawnPoint found at: " + str(spawn_point.global_position))
		else:
			print("WARNING: No SpawnPoint found! Creating one...")
			var spawn_point = Marker3D.new()
			spawn_point.name = "SpawnPoint"
			spawn_point.position = Vector3(4, 1, 4) # Match your StartRoom's spawn point position
			start_room.add_child(spawn_point)
			print("Created SpawnPoint at: " + str(spawn_point.global_position))
	
	# Spawn the player in the starting room
	spawn_player()
	add_safety_floor()
	
	# Connect room signals for all rooms
	for room in rooms:
		if room.has_signal("player_entered") and not room.is_connected("player_entered", _on_player_entered_room):
			room.connect("player_entered", _on_player_entered_room)
	
	# Visualize the room connections for debugging
	debug_draw_room_connections()
	debug_draw_room_bounds()

func add_safety_floor():
	var safety_floor = StaticBody3D.new()
	safety_floor.name = "SafetyFloor"
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collision.shape = shape
	safety_floor.add_child(collision)
	
	safety_floor.position = Vector3(0, -10, 0)
	add_child(safety_floor)
	
	print("Added safety floor at y=-10")

# Spawn player in the starting room
func spawn_player():
	print("=== SPAWNING PLAYER ===")
	
	# Check for existing player
	var existing_player = get_tree().get_first_node_in_group("player")
	if existing_player:
		player = existing_player
		print("Using existing player")
	else:
		# Create new player
		player = load(PLAYER_SCENE).instantiate()
		add_child(player)
		player.add_to_group("player")
		print("Created new player instance")
	
	# Position player in the start room
	if rooms.size() > 0:
		var start_room = rooms[0]
		if start_room.has_node("SpawnPoint"):
			var spawn_point = start_room.get_node("SpawnPoint")
			
			# Position player at the spawn point
			var spawn_pos = spawn_point.global_position
			player.global_position = spawn_pos
			player.velocity = Vector3.ZERO
			
			print("Player spawned at: " + str(player.global_position))
			
			# Force position after a short delay to ensure physics are applied
			get_tree().create_timer(0.1).timeout.connect(func():
				player.global_position = spawn_pos
				player.velocity = Vector3.ZERO
				print("Player position reinforced")
			)
		else:
			print("No SpawnPoint found in start room")
			player.global_position = start_room.global_position + Vector3(4, 1, 4)
	else:
		print("ERROR: No rooms available to spawn player!")

func _on_player_entered_room(entered_room):
	print("Player entered room: " + entered_room.name)
	
	# Check if this is a big room that should trigger a fight
	var is_big_room = entered_room.name.begins_with("Room") or entered_room.name.begins_with("Long")
	
	if is_big_room and not entered_room.has_meta("cleared"):
		print("Starting fight sequence in " + entered_room.name)
		start_fight_sequence(entered_room)
	else:
		print("Room already cleared or not a big room.")
		
func _on_boss_room_entered(_room):
	print("Player entered the boss room!")
	# Implement boss fight logic or victory screen here

func start_fight_sequence(room):
	# Set current locked room
	locked_room = room
	room.set_meta("fighting", true)
	
	# Spawn doors at all exits
	spawn_blocking_doors(room)
	
	# Spawn enemies
	spawn_enemies_in_room(room)
	
	# Connect to enemy death signals directly rather than relying on EnemyManager
	active_enemies.clear() # Reset active enemies list

func spawn_blocking_doors(room):
	# Remove any existing doors first
	for door in door_instances:
		door.queue_free()
	door_instances.clear()
	
	# Get all connection points
	if room.has_node("ConnectionPoints"):
		var connection_points = room.get_node("ConnectionPoints")
		
		# Spawn doors at each connection point
		for direction in ["north", "south", "east", "west"]:
			if connection_points.has_node(direction):
				var connection_point = connection_points.get_node(direction)
				spawn_door_at_point(connection_point, direction)

func spawn_door_at_point(point, direction):
	var door = load(DOOR_SCENE).instantiate()
	add_child(door)
	door.name = "BlockingDoor_" + direction
	
	# Position the door at the connection point
	door.global_position = point.global_position
	
	# Rotate the door based on direction
	match direction:
		"north":
			door.rotate_y(PI) # 180 degrees
		"east":
			door.rotate_y(PI / 2) # 90 degrees
		"west":
			door.rotate_y(-PI / 2) # -90 degrees
	
	# Add to our tracking array
	door_instances.append(door)
	print("Door spawned at " + direction + " exit")

func spawn_enemies_in_room(room):
	# Get room bounds for enemy spawning
	var bounds = dungeon_generator.get_room_bounds(room)
	if not bounds:
		print("Error: Could not get room bounds for enemy spawning")
		return
		
	# Calculate spawn area dimensions
	var size = bounds["max"] - bounds["min"]
	var center = bounds["min"] + size / 2
	
	# Determine number of enemies based on room size
	var enemy_count = 3 # default
	if size.x * size.z > 100:
		enemy_count = 5 # more enemies in bigger rooms
	
	print("Spawning " + str(enemy_count) + " enemies in " + room.name)
	
	# Get player position to avoid spawning too close
	var player_pos = player.global_position
	
	# Spawn enemies
	var positions_used = []
	for i in range(enemy_count):
		var valid_position = false
		var spawn_pos = Vector3.ZERO
		var attempts = 0
		
		# Try to find a position not too close to player or other enemies
		while not valid_position and attempts < 10:
			# Random position within the room bounds
			var x_offset = randf_range(-size.x / 3, size.x / 3)
			var z_offset = randf_range(-size.z / 3, size.z / 3)
			spawn_pos = center + Vector3(x_offset, 1.0, z_offset)
			
			# Check if too close to player (minimum 5 units away)
			var too_close_to_player = spawn_pos.distance_to(player_pos) < 5.0
			
			# Check if too close to other enemies
			var too_close_to_others = false
			for pos in positions_used:
				if spawn_pos.distance_to(pos) < 3.0:
					too_close_to_others = true
					break
					
			valid_position = not (too_close_to_player or too_close_to_others)
			attempts += 1
		
		if valid_position:
			# Spawn an enemy
			var enemy = spawn_enemy(spawn_pos)
			if enemy:
				active_enemies.append(enemy)
				positions_used.append(spawn_pos)
				print("Spawned enemy at " + str(spawn_pos))
		else:
			print("Failed to find valid position for enemy " + str(i))

func spawn_enemy(position):
	var enemy_script = load("res://Scripts/MeleeEnemy.gd")
	
	# Create enemy instance
	var enemy = CharacterBody3D.new()
	enemy.set_script(enemy_script)
	enemy.name = "Enemy" + str(randi())
	
	# Position enemy
	enemy.global_position = position
	
	# Connect to enemy death signal
	enemy.connect("enemy_died", _on_enemy_died)
	
	# Add to scene
	add_child(enemy)
	
	return enemy

func _on_enemy_died(enemy):
	# Remove from active enemies list
	active_enemies.erase(enemy)
	
	print("Enemy died: " + enemy.name + ". Remaining: " + str(active_enemies.size()))
	
	# Check if all enemies are defeated
	if active_enemies.size() == 0 and locked_room:
		print("All enemies defeated! Unlocking room.")
		end_fight_sequence()

func end_fight_sequence():
	# Mark room as cleared
	if locked_room:
		locked_room.set_meta("cleared", true)
		locked_room.set_meta("fighting", false)
		
	# Remove all doors
	for door in door_instances:
		var tween = create_tween()
		tween.tween_property(door, "position:y", -3.0, 1.0)
		
		# Free the door after animation
		tween.tween_callback(func():
			door.queue_free()
		)
	
	door_instances.clear()
	locked_room = null
	print("Room fight completed!")

func debug_draw_room_bounds():
	# Use rooms from dungeon_generator if available
	var room_list = rooms
	if dungeon_generator and dungeon_generator.rooms:
		room_list = dungeon_generator.rooms
		
	# Clear previous debug visualization
	for room in room_list:
		var existing = room.get_node_or_null("DebugBounds")
		if existing:
			existing.queue_free()
	
	# Create mesh for each room boundary
	for room in room_list:
		var bounds = dungeon_generator.get_room_bounds(room)
		if not bounds:
			continue
			
		var size = bounds["max"] - bounds["min"]
		var center = bounds["min"] + size / 2
		
		var box = BoxMesh.new()
		box.size = size
		
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = box
		mesh_instance.name = "DebugBounds"
		mesh_instance.position = center - room.global_position
		
		# Use a transparent material
		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1, 0, 0, 0.2) # Red with transparency
		mesh_instance.material_override = material
		
		room.add_child(mesh_instance)

func debug_draw_room_connections():
	# Use rooms from dungeon_generator if available
	var room_list = rooms
	if dungeon_generator and dungeon_generator.rooms:
		room_list = dungeon_generator.rooms
	
	# Clear previous connection lines
	var existing_lines = get_tree().get_nodes_in_group("debug_lines")
	for line in existing_lines:
		line.queue_free()
	
	# Draw lines between connected rooms
	for i in range(1, room_list.size()):
		var room = room_list[i]
		var prev_room = room_list[i - 1]
		
		# Find connection points between these rooms
		var entry_point = null
		var exit_point = null
		
		for direction in ["north", "south", "east", "west"]:
			if prev_room.has_node("ConnectionPoints/" + direction):
				var test_exit = prev_room.get_node("ConnectionPoints/" + direction)
				var opposite = get_opposite_direction(direction)
				
				if room.has_node("ConnectionPoints/" + opposite):
					var test_entry = room.get_node("ConnectionPoints/" + opposite)
					
					# Check if these points are close to each other
					if test_exit.global_position.distance_to(test_entry.global_position) < 2.0:
						exit_point = test_exit
						entry_point = test_entry
						break
		
		if exit_point and entry_point:
			draw_connection_line(exit_point.global_position, entry_point.global_position)

# Helper function to get opposite direction
func get_opposite_direction(direction: String) -> String:
	match direction:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
	return ""

func draw_connection_line(point_a, point_b):
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.add_to_group("debug_lines")
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 1, 0) # Green
	material.emission_enabled = true
	material.emission = Color(0, 1, 0)
	material.emission_energy = 1.0
	
	mi.material_override = material
	
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(point_a)
	im.surface_add_vertex(point_b)
	im.surface_end()
	
	add_child(mi)

func _process(delta):
	# Handle debug inputs
	if Input.is_action_just_pressed("ui_accept"):
		debug_player_physics()
		
	# Escape key to exit game
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	
	# Press F1 to visualize room connections
	if Input.is_action_just_pressed("ui_help"): # F1 key
		debug_draw_room_bounds()
		debug_draw_room_connections()

	# This is where the error is - we need to access inventory through player
	if Input.is_action_just_pressed("switch_weapon"):
		if player and player.inventory:
			player.inventory.handle_input_action("switch_weapon")

func debug_player_physics():
	print("=== PLAYER PHYSICS DEBUG ===")
	if not player:
		print("No player found!")
		return
		
	print("Player position: " + str(player.global_position))
	print("Player is on floor: " + str(player.is_on_floor()))
	print("Player velocity: " + str(player.velocity))
	
	# Check collisions below player
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		player.global_position,
		player.global_position + Vector3(0, -2, 0)
	)
	var result = space_state.intersect_ray(query)
	
	if result:
		print("Ray hit: " + str(result.collider.name) + " at distance: " +
			  str(result.position.distance_to(player.global_position)))
	else:
		print("No collision detected below player!")

# Called when proceeding to the next floor through the boss room
func regenerate_dungeon():
	print("=== REGENERATING DUNGEON FOR NEXT FLOOR ===")
	
	# Save player's state before regenerating
	var player_health = 0
	var player_position = Vector3.ZERO
	if player:
		player_health = player.hearts
		player_position = player.global_position
		player.queue_free()
		player = null
	
	# Clear all existing rooms and enemies
	for room in rooms:
		room.queue_free()
	rooms.clear()
	
	get_tree().call_group("enemies", "queue_free")
	
	# Generate new dungeon using the generator
	rooms = dungeon_generator.generate_dungeon(NUM_GENERIC_ROOMS, non_corridor_room_percent)
	
	# Spawn the player in the starting room
	spawn_player()
	
	# Restore player's health (maybe with a small bonus)
	if player:
		player.hearts = min(player.max_hearts, player_health + 1) # Give 1 extra heart
		player.update_health_display()
		
		# Add a message about proceeding to the next floor
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_message"):
			var room_manager = get_tree().get_first_node_in_group("room_manager")
			var floor_num = 1
			if room_manager:
				floor_num = room_manager.current_floor
			hud.show_message("Descended to floor " + str(floor_num) + "!")
