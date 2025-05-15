extends Node

# Room scenes for dungeon generation
var ROOM_SCENES = {
	"corridor": "res://Scenes/Corridor.tscn",
	"corridor_l": "res://Scenes/CorridorL.tscn",
	"corridor_t": "res://Scenes/CorridorT.tscn",
	"long_room_1": "res://Scenes/LongRoom1.tscn",
	"long_room_2": "res://Scenes/LongRoom2.tscn",
	"long_room_3": "res://Scenes/LongRoom3.tscn",
	"room_3": "res://Scenes/Room3.tscn",
	"room_4": "res://Scenes/Room4.tscn"
}
const START_ROOM_SCENE = "res://Scenes/StartRoom.tscn"
const BOSS_ROOM_SCENE = "res://Scenes/BossRoom.tscn"

# Track generated rooms
var rooms = []

# Maximum placement attempts before giving up on a specific room
const MAX_PLACEMENT_ATTEMPTS = 20

# Generate the full dungeon layout
func generate_dungeon(num_generic_rooms: int, non_corridor_room_percent: int) -> Array:
	print("Starting dungeon generation with " + str(num_generic_rooms) + " rooms")
	
	# Clear any existing rooms
	for room in rooms:
		room.queue_free()
	rooms.clear()
	
	# 1. Place the start room
	var start_room = load(START_ROOM_SCENE).instantiate()
	get_tree().current_scene.add_child(start_room)
	start_room.name = "StartRoom"
	ensure_room_has_collision(start_room)
	rooms.append(start_room)
	print("Start room placed")
	
	# 2. Generate the path rooms
	var last_room = start_room
	var successful_rooms = 0
	var attempts = 0
	
	while successful_rooms < num_generic_rooms and attempts < MAX_PLACEMENT_ATTEMPTS * 2:
		var room_type = get_random_room_type(non_corridor_room_percent)
		var room_path = ROOM_SCENES[room_type]
		var new_room = load(room_path).instantiate()
		get_tree().current_scene.add_child(new_room)
		new_room.name = room_type.capitalize() + "_" + str(successful_rooms)
		ensure_room_has_collision(new_room)
		
		var placed = try_place_room(last_room, new_room)
		
		if placed:
			rooms.append(new_room)
			last_room = new_room
			successful_rooms += 1
			print("Placed room " + str(successful_rooms) + ": " + new_room.name)
			
			# Apply seasons if room manager exists
			var room_manager = get_tree().get_first_node_in_group("room_manager")
			if room_manager and room_manager.has_method("apply_random_season_to_room"):
				room_manager.apply_random_season_to_room(new_room)
		else:
			print("Failed to place room, trying again")
			new_room.queue_free()
		
		attempts += 1
	
	print("Generated " + str(successful_rooms) + " rooms out of " + str(num_generic_rooms) + " requested")
	
	# 3. Place the boss room with extra placement attempts
	print("Attempting to place boss room...")
	var boss_room = load(BOSS_ROOM_SCENE).instantiate()
	get_tree().current_scene.add_child(boss_room)
	boss_room.name = "BossRoom"
	ensure_room_has_collision(boss_room)
	
	var boss_placed = false
	var boss_attempts = 0
	
	# Try multiple connection attempts for the boss room
	while not boss_placed and boss_attempts < MAX_PLACEMENT_ATTEMPTS * 3:
		if try_place_room(last_room, boss_room):
			rooms.append(boss_room)
			print("Boss room successfully placed after " + str(boss_attempts) + " attempts")
			
			# Set up boss room using BossRoom class if available
			var room_manager = get_tree().get_first_node_in_group("room_manager")
			if room_manager and room_manager.has_method("convert_to_boss_room"):
				room_manager.convert_to_boss_room(boss_room)
			
			boss_placed = true
			break
		boss_attempts += 1
	
	if not boss_placed:
		# Last resort: Place boss room at a fixed offset from the last room
		print("WARNING: Could not place boss room normally, using fallback placement")
		boss_room.global_position = last_room.global_position + Vector3(20, 0, 0)
		rooms.append(boss_room)
		
		# We'll need to create a special corridor to the boss room
		var corridor = load(ROOM_SCENES["corridor"]).instantiate()
		get_tree().current_scene.add_child(corridor)
		corridor.name = "ForcedCorridor_ToBoss"
		ensure_room_has_collision(corridor)
		
		# Position corridor between last room and boss room
		corridor.global_position = last_room.global_position + Vector3(10, 0, 0)
		rooms.append(corridor)
		
		# Set up boss room
		var room_manager = get_tree().get_first_node_in_group("room_manager")
		if room_manager and room_manager.has_method("convert_to_boss_room"):
			room_manager.convert_to_boss_room(boss_room)
	
	# Connect signal for boss room if it has one
	if boss_room.has_signal("player_entered"):
		var main_node = get_tree().current_scene
		if main_node.has_method("_on_boss_room_entered"):
			if not boss_room.is_connected("player_entered", main_node._on_boss_room_entered):
				boss_room.connect("player_entered", main_node._on_boss_room_entered)
	
	print("Dungeon generation completed with " + str(rooms.size()) + " total rooms")
	return rooms

# Try to place a room connected to an existing room, handles rotation and overlap checks
func try_place_room(source_room: Node3D, new_room: Node3D) -> bool:
	var source_exits = get_available_connection_points(source_room)
	
	# Shuffle source exits for randomness
	source_exits.shuffle()
	
	for exit_dir in source_exits:
		var entry_points = get_available_connection_points(new_room)
		
		# Try all possible rotations (0, 90, 180, 270 degrees)
		for rotation_angle in [0.0, PI / 2, PI, -PI / 2]:
			for entry_dir in entry_points:
				# Apply rotation to the room
				new_room.rotation.y = rotation_angle
				
				# Attempt to connect
				if connect_rooms(source_room, new_room, exit_dir, entry_dir):
					# Check for overlaps
					if not check_room_overlap(new_room, source_room):
						print("Successfully placed " + new_room.name +
							  " connected to " + exit_dir + " of " + source_room.name)
						return true
			
			# Reset position before trying next rotation
			new_room.global_position = Vector3.ZERO
	
	return false

# Connect two rooms together by matching connection points
func connect_rooms(room_a: Node3D, room_b: Node3D, exit_dir: String, entry_dir: String) -> bool:
	if not room_a.has_node("ConnectionPoints") or not room_b.has_node("ConnectionPoints"):
		print("Missing ConnectionPoints node")
		return false
	
	# Get exit and entry points
	var exit_path = "ConnectionPoints/" + exit_dir
	var entry_path = "ConnectionPoints/" + entry_dir
	
	if not room_a.has_node(exit_path) or not room_b.has_node(entry_path):
		print("Missing connection point paths")
		return false
	
	var exit_point = room_a.get_node(exit_path)
	var entry_point = room_b.get_node(entry_path)
	
	# Calculate offset to align entry point with exit point
	var exit_global = exit_point.global_position
	var entry_local = entry_point.position
	var entry_global = room_b.to_global(entry_local)
	
	var offset = exit_global - entry_global
	room_b.global_position += offset
	
	# Debug
	print("Connected " + room_a.name + ":" + exit_dir +
		  " to " + room_b.name + ":" + entry_dir +
		  " at position " + str(room_b.global_position))
	
	return true

# Check if the room overlaps with any existing rooms (except the connecting room)
func check_room_overlap(new_room: Node3D, connecting_room: Node3D = null) -> bool:
	var new_bounds = get_room_bounds(new_room)
	
	# Check overlap with all other rooms
	for room in rooms:
		if room == new_room or room == connecting_room:
			continue
		
		var room_bounds = get_room_bounds(room)
		if boxes_overlap(new_bounds, room_bounds):
			print("Room " + new_room.name + " would overlap with " + room.name)
			return true
	
	return false

# Get random room type based on corridor vs. non-corridor percentage
func get_random_room_type(non_corridor_room_percent: int) -> String:
	var corridor_percent = 100 - non_corridor_room_percent
	var special_corridor_percent = min(corridor_percent / 2, 30)
	var regular_corridor_percent = corridor_percent - special_corridor_percent
	
	var random_val = randf()
	
	if random_val < regular_corridor_percent / 100.0:
		return "corridor"
	elif random_val < (regular_corridor_percent + special_corridor_percent) / 100.0:
		return ["corridor_l", "corridor_t"].pick_random()
	else:
		return ["room_3", "room_4", "long_room_1", "long_room_2", "long_room_3"].pick_random()

# Get available connection points from a room
func get_available_connection_points(room: Node3D) -> Array:
	var connection_points = []
	
	if not room.has_node("ConnectionPoints"):
		return connection_points
		
	var cp_node = room.get_node("ConnectionPoints")
	
	# Check for each possible direction
	for direction in ["north", "south", "east", "west"]:
		if cp_node.has_node(direction):
			connection_points.append(direction)
			
	return connection_points

# Ensure room has proper collision bounds
func ensure_room_has_collision(room: Node3D):
	if room.has_node("CollisionBounds") or room.has_node("FloorCollision"):
		return
		
	var collision_bounds = StaticBody3D.new()
	collision_bounds.name = "CollisionBounds"
	room.add_child(collision_bounds)
	
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
	
	# Add room detector for trigger volume
	var detector = Area3D.new()
	detector.name = "RoomDetector"
	room.add_child(detector)
	
	var detector_shape = CollisionShape3D.new()
	var detector_box = BoxShape3D.new()
	detector_box.size = Vector3(room_size.x, 4, room_size.z)
	detector_shape.shape = detector_box
	detector_shape.position = Vector3(room_size.x / 2, 2, room_size.z / 2)
	detector.add_child(detector_shape)

# Get room bounds for collision detection
func get_room_bounds(room: Node3D) -> Dictionary:
	if not room:
		return {"min": Vector3.ZERO, "max": Vector3.ZERO}
		
	# Try to get bounds from RoomDetector
	var detector = room.get_node_or_null("RoomDetector")
	if detector and detector.get_child_count() > 0:
		var shape = detector.get_child(0)
		if shape is CollisionShape3D and shape.shape is BoxShape3D:
			var box_shape = shape.shape as BoxShape3D
			var size = box_shape.size
			var global_pos = detector.to_global(shape.position)
			
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
			var global_pos = collision_bounds.to_global(floor_shape.position)
			
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
func boxes_overlap(box_a: Dictionary, box_b: Dictionary, tolerance: float = 0.1) -> bool:
	# Allow small overlap at connection points by using tolerance
	return (
		box_a["min"].x - tolerance <= box_b["max"].x and
		box_a["max"].x + tolerance >= box_b["min"].x and
		box_a["min"].y - tolerance <= box_b["max"].y and
		box_a["max"].y + tolerance >= box_b["min"].y and
		box_a["min"].z - tolerance <= box_b["max"].z and
		box_a["max"].z + tolerance >= box_b["min"].z
	)
