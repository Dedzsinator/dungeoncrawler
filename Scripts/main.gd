extends Node3D

@export var grid_size: Vector2 = Vector2(10, 10)
@export var room_size: float = 10.0
@export var rooms: Array[PackedScene] = []

var dungeon_grid: Array = []

func _ready() -> void:
	generate_dungeon()

func generate_dungeon() -> void:
	dungeon_grid = []
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			dungeon_grid.append([])
			for y in range(grid_size.y):
				dungeon_grid[x].append(null)
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			if randf() < 0.7:
				var room = rooms[randi() % rooms.size()].instantiate()
				add_child(room)
				room.position = Vector3(x * room_size, 0, y * room_size)
				dungeon_grid[x][y] = room

	var start_room = rooms[0].instantiate()
	add_child(start_room)
	start_room.position = Vector3(0, 0, 0)
	dungeon_grid[0][0] = start_room

	var end_room = rooms[-1].instantiate()
	add_child(end_room)
	end_room.position = Vector3((grid_size.x - 1) * room_size, 0, (grid_size.y - 1) * room_size)
	dungeon_grid[grid_size.x - 1][grid_size.y - 1] = end_room
	