extends Node3D

# Paths to your room scenes
const START_ROOM_SCENE = "res://Scenes/StartRoom.tscn"
const BOSS_ROOM_SCENE = "res://Scenes/BossRoom.tscn"
const GENERIC_ROOM_SCENE = "res://Scenes/Corridor.tscn"

# More room type definitions for variety
const ROOM_SCENES = {
	"corridor": "res://Scenes/Corridor.tscn",
	"corridor_l": "res://Scenes/CorridorL.tscn", # Will create these
	"corridor_t": "res://Scenes/CorridorT.tscn", # Will create these
	"corridor_x": "res://Scenes/CorridorX.tscn", # Will create these
	"long_room_1": "res://Scenes/LongRoom1.tscn", # Will create these
	"long_room_2": "res://Scenes/LongRoom2.tscn", # Will create these
	"long_room_3": "res://Scenes/LongRoom3.tscn", # Will create these
	"room_3": "res://Scenes/Room3.tscn", # Will create these
	"room_4": "res://Scenes/Room4.tscn" # Will create these
}

# Number of generic rooms between start and boss rooms
const NUM_GENERIC_ROOMS = 5

# Reference to the player scene
const PLAYER_SCENE = "res://Scenes/Player.tscn"
const DOOR_SCENE = "res://Assets/Door.fbx"

# Store room instances
var rooms = []
var player = null
var active_enemies = []
var locked_room = null
var door_instances = []

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
		
	# Normal initialization below
	generate_dungeon()
	
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

func generate_dungeon():
	# Clear existing rooms
	for room in rooms:
		room.queue_free()
	rooms.clear()

	print("Generating new dungeon layout...")
	
	# 1. Create the start room
	var start_room = load(START_ROOM_SCENE).instantiate()
	add_child(start_room)
	start_room.name = "StartRoom"
	ensure_room_has_collision(start_room)
	rooms.append(start_room)
	
	# 2. Create a simple linear path through the dungeon
	# This ensures we have a clear path from start to boss
	create_linear_dungeon_path(start_room)
	
	print("Dungeon generation complete with " + str(rooms.size()) + " rooms")

# Function to select a random room type for dungeon generation
func get_random_room_type() -> String:
	var room_types = ROOM_SCENES.keys()
	var special_rooms = ["corridor_l", "corridor_t", "corridor_x"]
	var normal_rooms = ["room_3", "room_4", "long_room_1", "long_room_2", "long_room_3"]
	
	# 60% chance of normal corridor, 20% chance of special corridor, 20% chance of room
	var random_val = randf()
	
	if random_val < 0.6:
		# Regular corridor
		return "corridor"
	elif random_val < 0.8:
		# Special corridor (L, T, X)
		return special_rooms[randi() % special_rooms.size()]
	else:
		# Room
		return normal_rooms[randi() % normal_rooms.size()]

# Create a more interesting dungeon with multiple room types
func create_linear_dungeon_path(start_room):
	var current_room = start_room
	var remaining_rooms = NUM_GENERIC_ROOMS
	var previous_exit_dir = "" # Track the last used exit direction
	
	# For a linear path, we'll use a fixed direction if possible (east)
	var preferred_direction = "east"
	
	while remaining_rooms > 0:
		# Get available exits from current room
		var exits = get_available_connection_points(current_room)
		
		if exits.is_empty():
			print("No more exits available from room " + current_room.name)
			break
			
		# Try to use the preferred direction first
		var exit_dir = preferred_direction
		if not exits.has(exit_dir):
			# Fall back to any available exit, but try to avoid the direction we came from
			exits.erase(get_opposite_direction(previous_exit_dir)) # Don't go back the way we came
			if exits.is_empty():
				print("No valid exits available in room " + current_room.name)
				break
			exit_dir = exits[randi() % exits.size()]
		
		# Select a room type based on our improved logic
		var room_type = get_random_room_type()
		var room_scene_path = ROOM_SCENES[room_type]
		print("Selected room type: " + room_type)
		
		# Create new room
		var new_room = load(room_scene_path).instantiate()
		add_child(new_room)
		new_room.name = room_type.capitalize() + "_" + str(NUM_GENERIC_ROOMS - remaining_rooms)
		ensure_room_has_collision(new_room)
		
		# Get entry points for the new room (we need the opposite of our exit)
		var desired_entry = get_opposite_direction(exit_dir)
		var room_entries = get_available_connection_points(new_room)
		
		if not room_entries.has(desired_entry):
			print("New room doesn't have the needed entry point: " + desired_entry)
			# Try to find any valid entry point
			if room_entries.is_empty():
				print("Room has no entry points, can't connect")
				new_room.queue_free()
				exits.erase(exit_dir)
				continue
			desired_entry = room_entries[0]
		
		# Connect and align rooms
		if connect_and_align_rooms(current_room, new_room, exit_dir, desired_entry):
			rooms.append(new_room)
			
			# Apply a random season to the new room
			var room_manager = get_tree().get_first_node_in_group("room_manager")
			if room_manager:
				room_manager.apply_random_season_to_room(new_room)
			
			current_room = new_room
			previous_exit_dir = exit_dir
			remaining_rooms -= 1
		else:
			print("Failed to connect new room")
			new_room.queue_free()
			exits.erase(exit_dir)
			
			if exits.is_empty():
				print("No more valid exits available, ending corridor generation")
				break
	
	# Add boss room at the end
	add_boss_room(current_room, previous_exit_dir)

func add_boss_room(last_corridor, previous_exit_dir):
	# Get available exits from last corridor - prefer the same direction we've been going
	var exits = get_available_connection_points(last_corridor)
	
	if exits.is_empty():
		var boss_room = load(BOSS_ROOM_SCENE).instantiate()
		add_child(boss_room)
		boss_room.name = "BossRoom"
		boss_room.global_position = last_corridor.global_position + Vector3(8, 0, 0)
		ensure_room_has_collision(boss_room)
		rooms.append(boss_room)
		
		# Set up as boss room using our new system
		setup_boss_room(boss_room)
		print("No exits available for boss room, placed at default position")
		return
	
	# Prefer to continue in the same direction
	var exit_dir = previous_exit_dir
	if not exits.has(exit_dir) or exit_dir == "":
		exit_dir = exits[randi() % exits.size()]
	
	# Create boss room
	var boss_room = load(BOSS_ROOM_SCENE).instantiate()
	add_child(boss_room)
	boss_room.name = "BossRoom"
	ensure_room_has_collision(boss_room)
	
	# Get entry points for the boss room
	var desired_entry = get_opposite_direction(exit_dir)
	var boss_entries = get_available_connection_points(boss_room)
	
	if not boss_entries.has(desired_entry):
		if boss_entries.is_empty():
			boss_room.global_position = last_corridor.global_position + Vector3(8, 0, 0)
			rooms.append(boss_room)
			setup_boss_room(boss_room)
			print("Boss room has no valid entry points, using default placement")
			return
		else:
			desired_entry = boss_entries[0] # Just use the first available entry
	
	# Connect boss room
	if connect_and_align_rooms(last_corridor, boss_room, exit_dir, desired_entry):
		rooms.append(boss_room)
		
		# Set up as boss room using our new system
		setup_boss_room(boss_room)
		
		# Connect signal for boss room if it has one
		if boss_room.has_signal("player_entered"):
			boss_room.connect("player_entered", _on_boss_room_entered)
	else:
		# Fallback placement if connection fails
		boss_room.global_position = last_corridor.global_position + Vector3(8, 0, 0)
		rooms.append(boss_room)
		setup_boss_room(boss_room)
		print("Failed to connect boss room, using fallback placement")
		
# Setup the boss room using our BossRoom controller
func setup_boss_room(room_node):
	var room_manager = get_tree().get_first_node_in_group("room_manager")
	if room_manager:
		room_manager.convert_to_boss_room(room_node)
	else:
		# Fallback if room manager isn't available
		var boss_room_controller = BossRoom.new(room_node)
		boss_room_controller.setup()

# Helper function to get opposite direction
func get_opposite_direction(direction: String) -> String:
	match direction:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
	return ""

# Helper function to get available connection points from a room
func get_available_connection_points(room: Node3D) -> Array:
	var connection_points = []
	
	if not room.has_node("ConnectionPoints"):
		print("Room " + room.name + " has no ConnectionPoints node")
		return connection_points
		
	var cp_node = room.get_node("ConnectionPoints")
	
	# Check for each possible direction
	for direction in ["north", "south", "east", "west"]:
		if cp_node.has_node(direction):
			connection_points.append(direction)
			
	return connection_points

# Function to ensure proper hitboxes for rooms
func ensure_room_has_collision(room: Node3D):
	# Check if room already has collision
	if room.has_node("CollisionBounds") or room.has_node("FloorCollision"):
		print(room.name + " already has collision")
		return
		
	print("Adding collision to " + room.name)
	var collision_bounds = StaticBody3D.new()
	collision_bounds.name = "CollisionBounds"
	room.add_child(collision_bounds)
	
	# Add floor collision
	var floor_shape = CollisionShape3D.new()
	var floor_box = BoxShape3D.new()
	
	# Get room size based on type
	var room_size = Vector3(8, 0.5, 8) # Default size
	
	if room.name.begins_with("Corridor"):
		room_size = Vector3(8, 0.5, 2)
	elif room.name.begins_with("BossRoom"):
		room_size = Vector3(12, 0.5, 12)
	elif room.name.begins_with("LongRoom"):
		room_size = Vector3(12, 0.5, 6) # Longer rooms
	elif room.name.begins_with("Room"):
		room_size = Vector3(10, 0.5, 10) # Regular rooms
	
	floor_box.size = room_size
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(room_size.x / 2, 0, room_size.z / 2)
	collision_bounds.add_child(floor_shape)

# Advanced function to connect and align rooms, handling rotation
func connect_and_align_rooms(room_a, room_b, exit_dir, entry_dir) -> bool:
	print("Connecting " + room_a.name + " to " + room_b.name +
		  " using " + exit_dir + " -> " + entry_dir)
		
	# Verify if ConnectionPoints node exists in both rooms
	if not room_a.has_node("ConnectionPoints") or not room_b.has_node("ConnectionPoints"):
		push_error("ConnectionPoints node missing in one of the rooms")
		return false
	
	# Get connection points of both rooms
	var exit_path = "ConnectionPoints/" + exit_dir
	var entry_path = "ConnectionPoints/" + entry_dir
	
	# Verify that both points exist
	if not room_a.has_node(exit_path) or not room_b.has_node(entry_path):
		push_error("Missing connection point: " + exit_path + " or " + entry_path)
		return false
	
	var exit_point = room_a.get_node(exit_path)
	var entry_point = room_b.get_node(entry_path)
	
	# Store original transform to restore if needed
	var original_transform = room_b.global_transform
	
	# Determine rotation needed based on entry and exit directions
	var rotation_angle = get_rotation_angle(exit_dir, entry_dir)
	
	# Apply rotation to room_b around Y axis
	if rotation_angle != 0:
		room_b.basis = Basis(Vector3(0, 1, 0), rotation_angle) * room_b.basis
		print("Rotated room " + room_b.name + " by " + str(rad_to_deg(rotation_angle)) + " degrees")
	
	# Get updated entry point position after rotation
	var updated_entry_point_global = room_b.global_transform * entry_point.position
	
	# Calculate the position offset to align the entry point with the exit point
	var offset = exit_point.global_position - updated_entry_point_global
	
	# Position room_b with the correct alignment
	room_b.global_position += offset
	
	# Draw a connection line for debugging
	draw_connection_line(exit_point.global_position, room_b.to_global(entry_point.position))
	
	# Check if this placement causes collisions with existing rooms
	if check_room_overlap(room_b, room_a):
		# Restore original transform and report failure
		room_b.global_transform = original_transform
		print("Room placement would cause overlap, cancelling connection")
		return false
	
	print("Room " + room_b.name + " positioned at " + str(room_b.global_position))
	return true

# Calculate the rotation angle needed based on exit and entry directions
func get_rotation_angle(exit_dir: String, entry_dir: String) -> float:
	# Define the cardinal directions as angles (in radians)
	var dir_angles = {
		"north": PI, # -Z axis (180 degrees)
		"south": 0, # +Z axis (0 degrees)
		"east": - PI / 2, # +X axis (-90 degrees)
		"west": PI / 2 # -X axis (90 degrees)
	}
	
	# Calculate the needed rotation:
	# 1. Start from the angle of the exit_dir
	# 2. Add 180 degrees (PI radians) because we want to face the opposite way
	# 3. Subtract the angle of the entry_dir to align with it
	var angle = dir_angles[exit_dir] + PI - dir_angles[entry_dir]
	
	# Normalize angle to be between -PI and PI
	while angle > PI:
		angle -= 2 * PI
	while angle < -PI:
		angle += 2 * PI
		
	return angle

# Fixed room overlap check to work properly
func check_room_overlap(new_room: Node3D, connecting_room: Node3D = null) -> bool:
	# If there's only one room (the first one), no overlap is possible
	if rooms.size() <= 1:
		return false
	
	# Get bounds of the new room
	var new_room_bounds = get_room_bounds(new_room)
	if not new_room_bounds:
		print("Could not determine bounds for " + new_room.name)
		return false
	
	# Add some tolerance at connection points
	var tolerance = 2.0
	
	# Check against all existing rooms except the connecting room
	for room in rooms:
		if room == new_room or room == connecting_room:
			continue
		
		var room_bounds = get_room_bounds(room)
		if not room_bounds:
			continue
		
		# Check for overlap with tolerance
		if boxes_overlap(new_room_bounds, room_bounds, tolerance):
			print("Room " + new_room.name + " would overlap with " + room.name)
			return true
	
	return false

# Get room bounds (AABB) based on its detector or floor collision
func get_room_bounds(room: Node3D) -> Dictionary:
	# Try to get bounds from RoomDetector
	var detector = room.get_node_or_null("RoomDetector")
	if detector and detector.get_child_count() > 0:
		var shape = detector.get_child(0)
		if shape is CollisionShape3D and shape.shape is BoxShape3D:
			var box_shape = shape.shape as BoxShape3D
			var size = box_shape.size
			var global_pos = shape.global_position
			
			return {
				"min": global_pos - size / 2,
				"max": global_pos + size / 2
			}
	
	# Try to get bounds from floor collision as fallback
	var collision_bounds = room.get_node_or_null("CollisionBounds")
	if collision_bounds and collision_bounds.get_child_count() > 0:
		var floor_shape = collision_bounds.get_child(0)
		if floor_shape is CollisionShape3D and floor_shape.shape is BoxShape3D:
			var box_shape = floor_shape.shape as BoxShape3D
			var size = box_shape.size
			var global_pos = floor_shape.global_position
			
			# For floor shapes, expand vertically to create a proper volume
			return {
				"min": Vector3(global_pos.x - size.x / 2, global_pos.y, global_pos.z - size.z / 2),
				"max": Vector3(global_pos.x + size.x / 2, global_pos.y + 5, global_pos.z + size.z / 2)
			}
	
	# As a last resort, use a default size around the room's center
	var room_size = Vector3(8, 5, 8)
	if room.name.begins_with("Corridor"):
		room_size = Vector3(8, 3, 2)
	elif room.name.begins_with("BossRoom"):
		room_size = Vector3(12, 5, 12)
	elif room.name.begins_with("LongRoom"):
		room_size = Vector3(12, 5, 6)
	elif room.name.begins_with("Room"):
		room_size = Vector3(10, 5, 10)
	
	return {
		"min": room.global_position,
		"max": room.global_position + room_size
	}

# Check if two boxes overlap, with optional tolerance
func boxes_overlap(box_a: Dictionary, box_b: Dictionary, tolerance: float = 0.0) -> bool:
	return (
		box_a["min"].x - tolerance <= box_b["max"].x and
		box_a["max"].x + tolerance >= box_b["min"].x and
		box_a["min"].y - tolerance <= box_b["max"].y and
		box_a["max"].y + tolerance >= box_b["min"].y and
		box_a["min"].z - tolerance <= box_b["max"].z and
		box_a["max"].z + tolerance >= box_b["min"].z
	)

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

func _on_boss_room_entered(_room):
	print("Player entered the boss room!")
	# Implement boss fight logic or victory screen here

func _on_player_entered_room(entered_room):
	print("Player entered room: " + entered_room.name)
	
	# Check if this is a big room that should trigger a fight
	var is_big_room = entered_room.name.begins_with("Room") or entered_room.name.begins_with("Long")
	
	if is_big_room and not entered_room.has_meta("cleared"):
		print("Starting fight sequence in " + entered_room.name)
		start_fight_sequence(entered_room)
	else:
		print("Room already cleared or not a big room.")
		
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
	var bounds = get_room_bounds(room)
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

func debug_draw_room_bounds():
	# Clear previous debug visualization
	for room in rooms:
		var existing = room.get_node_or_null("DebugBounds")
		if existing:
			existing.queue_free()
	
	# Create mesh for each room boundary
	for room in rooms:
		var bounds = get_room_bounds(room)
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
	# Clear previous connection lines
	var existing_lines = get_tree().get_nodes_in_group("debug_lines")
	for line in existing_lines:
		line.queue_free()
	
	# Draw lines between connected rooms
	for i in range(1, rooms.size()):
		var room = rooms[i]
		var prev_room = rooms[i - 1]
		
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
	
	# Generate new dungeon
	generate_dungeon()
	
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
