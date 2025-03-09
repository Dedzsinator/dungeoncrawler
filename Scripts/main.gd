extends Node3D

# Paths to your room scenes
const START_ROOM_SCENE = "res://Scenes/StartRoom.tscn"
const BOSS_ROOM_SCENE = "res://Scenes/BossRoom.tscn"
const GENERIC_ROOM_SCENE = "res://Scenes/Corridor.tscn"

# Number of generic rooms between start and boss rooms
const NUM_GENERIC_ROOMS = 5

# Reference to the player scene
const PLAYER_SCENE = "res://Scenes/Player.tscn"

# Store room instances
var rooms = []
var player = null

func _ready():
	print("=== GAME INITIALIZATION ===")
	
	# EMERGENCY DEBUG: Skip dungeon generation and just spawn the player in a start room
	if false:  # Keep this false to enable dungeon generation
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
			spawn_point.position = Vector3(4, 1, 4)  # Match your StartRoom's spawn point position
			start_room.add_child(spawn_point)
			print("Created SpawnPoint at: " + str(spawn_point.global_position))
	
	# Spawn the player in the starting room
	spawn_player()
	add_safety_floor()
	
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

# New function to ensure more reliable room placement
func create_linear_dungeon_path(start_room):
	var current_room = start_room
	var remaining_rooms = NUM_GENERIC_ROOMS
	var previous_exit_dir = ""  # Track the last used exit direction
	
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
			exits.erase(get_opposite_direction(previous_exit_dir))  # Don't go back the way we came
			if exits.is_empty():
				print("No valid exits available in room " + current_room.name)
				break
			exit_dir = exits[randi() % exits.size()]
		
		# Create corridor
		var corridor = load(GENERIC_ROOM_SCENE).instantiate()
		add_child(corridor)
		corridor.name = "Corridor_" + str(NUM_GENERIC_ROOMS - remaining_rooms)
		ensure_room_has_collision(corridor)
		
		# Get entry points for the corridor (we need the opposite of our exit)
		var desired_entry = get_opposite_direction(exit_dir)
		var corridor_entries = get_available_connection_points(corridor)
		
		if not corridor_entries.has(desired_entry):
			print("Corridor doesn't have the needed entry point: " + desired_entry)
			corridor.queue_free()
			exits.erase(exit_dir)
			continue
		
		# Connect and align rooms
		if connect_and_align_rooms(current_room, corridor, exit_dir, desired_entry):
			rooms.append(corridor)
			current_room = corridor
			previous_exit_dir = exit_dir
			remaining_rooms -= 1
		else:
			print("Failed to connect corridor")
			corridor.queue_free()
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
			print("Boss room has no valid entry points, using default placement")
			return
		else:
			desired_entry = boss_entries[0] # Just use the first available entry
	
	# Connect boss room
	if connect_and_align_rooms(last_corridor, boss_room, exit_dir, desired_entry):
		rooms.append(boss_room)
		
		# Connect signal for boss room if it has one
		if boss_room.has_signal("player_entered"):
			boss_room.connect("player_entered", _on_boss_room_entered)
	else:
		# Fallback placement if connection fails
		boss_room.global_position = last_corridor.global_position + Vector3(8, 0, 0)
		rooms.append(boss_room)
		print("Failed to connect boss room, using fallback placement")

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
	var room_size = Vector3(8, 0.5, 8)  # Default size
	
	if room.name.begins_with("Corridor"):
		room_size = Vector3(8, 0.5, 2)
	elif room.name.begins_with("BossRoom"):
		room_size = Vector3(12, 0.5, 12)
	
	floor_box.size = room_size
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(room_size.x/2, 0, room_size.z/2)
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
		"north": PI,        # -Z axis (180 degrees)
		"south": 0,         # +Z axis (0 degrees)
		"east": -PI/2,      # +X axis (-90 degrees)
		"west": PI/2        # -X axis (90 degrees)
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
				"min": global_pos - size/2,
				"max": global_pos + size/2
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
				"min": Vector3(global_pos.x - size.x/2, global_pos.y, global_pos.z - size.z/2),
				"max": Vector3(global_pos.x + size.x/2, global_pos.y + 5, global_pos.z + size.z/2)
			}
	
	# As a last resort, use a default size around the room's center
	var room_size = Vector3(8, 5, 8)
	if room.name.begins_with("Corridor"):
		room_size = Vector3(8, 3, 2)
	elif room.name.begins_with("BossRoom"):
		room_size = Vector3(12, 5, 12)
	
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

# Debug helper function
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
	if Input.is_action_just_pressed("ui_help"):  # F1 key
		debug_draw_room_bounds()
		debug_draw_room_connections()

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
		var center = bounds["min"] + size/2
		
		var box = BoxMesh.new()
		box.size = size
		
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = box
		mesh_instance.name = "DebugBounds"
		mesh_instance.position = center - room.global_position
		
		# Use a transparent material
		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1, 0, 0, 0.2)  # Red with transparency
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
		var prev_room = rooms[i-1]
		
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
	material.albedo_color = Color(0, 1, 0)  # Green
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
