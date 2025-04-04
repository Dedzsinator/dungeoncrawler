extends Node

# Enemy scenes (load these in a real project)
var ENEMY_SCENES = {
	"melee": preload("res://Scripts/MeleeEnemy.gd"),
	"ranged": preload("res://Scripts/RangedEnemy.gd"),
	"explosive": preload("res://Scripts/ExplosiveEnemy.gd"),
	"swarm": preload("res://Scripts/SwarmEnemy.gd"),
	"trail": preload("res://Scripts/TrailEnemy.gd"),
	"boss": preload("res://Scripts/BossEnemy.gd")
}

# Spawn parameters 
@export var max_enemies_per_room = 5
@export var min_enemies_per_room = 2
@export var boss_health_multiplier = 2.0

# Enemy tracking
var active_enemies = []
var total_enemies_spawned = 0
var boss_spawned = false

signal enemy_died(enemy)

func _ready():
	# Subscribe to room detection events
	for room in get_tree().get_nodes_in_group("rooms"):
		if room.has_signal("player_entered"):
			room.connect("player_entered", _on_player_entered_room)

func spawn_enemy(enemy_type: String, position: Vector3) -> Enemy:
	if not ENEMY_SCENES.has(enemy_type):
		push_error("Unknown enemy type: " + enemy_type)
		return null
		
	var enemy_script = ENEMY_SCENES[enemy_type]
	
	# Create enemy instance
	var enemy = CharacterBody3D.new()
	enemy.set_script(enemy_script)
	enemy.name = enemy_type.capitalize() + "Enemy" + str(total_enemies_spawned)
	
	# Position enemy
	enemy.global_position = position
	
	# Connect to enemy death signal
	enemy.connect("enemy_died", _on_enemy_died)
	
	# Add to scene
	get_parent().add_child(enemy)
	active_enemies.append(enemy)
	total_enemies_spawned += 1
	
	return enemy

func spawn_boss(position: Vector3) -> BossEnemy:
	var boss = spawn_enemy("boss", position) as BossEnemy
	if boss:
		boss_spawned = true
		boss.max_health *= boss_health_multiplier
		boss.health = boss.max_health
		print("Boss spawned with " + str(boss.max_health) + " health")
	return boss

func spawn_enemies_in_room(room: Node3D):
	# Don't respawn enemies in rooms
	if room.has_meta("enemies_spawned"):
		return
		
	# Mark room as having enemies
	room.set_meta("enemies_spawned", true)
	
	# Check if this is the boss room
	if room.name.begins_with("BossRoom"):
		var boss_spawn_point = room.get_node_or_null("BossSpawnPoint")
		var spawn_pos = boss_spawn_point.global_position if boss_spawn_point else room.global_position + Vector3(0, 1, 0)
		spawn_boss(spawn_pos)
		return
		
	# Regular room - spawn random enemies
	var num_enemies = randi_range(min_enemies_per_room, max_enemies_per_room)
	var room_size = Vector3(8, 0, 8) # Default room size
	
	if room.name.begins_with("Corridor"):
		room_size = Vector3(8, 0, 2)
		# Fewer enemies in corridors
		num_enemies = min(2, num_enemies)
	
	# Get room bounds
	var detector = room.get_node_or_null("RoomDetector")
	if detector and detector.get_child_count() > 0:
		var shape = detector.get_child(0)
		if shape is CollisionShape3D and shape.shape is BoxShape3D:
			room_size = shape.shape.size
	
	# Spawn enemies in random positions within the room
	for i in range(num_enemies):
		var x = randf_range(-room_size.x / 2 + 1, room_size.x / 2 - 1)
		var z = randf_range(-room_size.z / 2 + 1, room_size.z / 2 - 1)
		var spawn_pos = room.global_position + Vector3(room_size.x / 2 + x, 1, room_size.z / 2 + z)
		
		# Choose random enemy type
		var enemy_types = ["melee", "ranged", "explosive", "swarm", "trail"]
		var enemy_type = enemy_types[randi() % enemy_types.size()]
		
		# Spawn the enemy
		spawn_enemy(enemy_type, spawn_pos)
		
	print("Spawned " + str(num_enemies) + " enemies in " + room.name)

func _on_player_entered_room(room: Node3D):
	spawn_enemies_in_room(room)

func _on_enemy_died(enemy: Enemy):
	# Remove from active enemies list
	active_enemies.erase(enemy)
	
	# Forward the signal
	emit_signal("enemy_died", enemy)
	
	# Check if this was a boss
	if enemy is BossEnemy and boss_spawned:
		boss_spawned = false
		print("Boss defeated!")
		# Trigger victory condition or next level

func get_enemy_at_position(position: Vector3, radius: float = 1.0) -> Enemy:
	for enemy in active_enemies:
		if enemy.global_position.distance_to(position) <= radius:
			return enemy
	return null
