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

# Asset paths - using your KayKit assets
var floor_assets = [
    "res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/floor_tile_large.gltf.glb",
    "res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/floor_tile_large_rocks.gltf.glb"
]

var wall_assets = [
    "res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall_arched.gltf.glb",
    "res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall.gltf.glb",
    "res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall_corner.gltf.glb"
]

var door_assets = [
    "res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/wall_doorway.gltf.glb"
]

var prop_assets = [
    "res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/torch_mounted.gltf.glb",
    "res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/barrel.gltf.glb",
    "res://Assets/KayKit_DungeonRemastered_1.0_FREE/KayKit_DungeonRemastered_1.0_FREE/Assets/gltf/chest.gltf.glb"
]

# Grid representation
enum CellType {
    EMPTY,
    FLOOR,
    WALL,
    DOOR,
    CORRIDOR
}

var grid: Array[Array]
var rooms: Array[Rect2i]
var first_room_center: Vector2i

# Node references
var floor_container: Node3D
var wall_container: Node3D
var prop_container: Node3D
var torch_scene: PackedScene
var mage_scene: PackedScene

func _ready():
    setup_containers()
    load_scenes()
    generate_dungeon()

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

func load_scenes():
    torch_scene = preload("res://Scenes/Objects/torch.tscn")
    mage_scene = preload("res://Scenes/NPCs/mage.tscn")

func generate_dungeon():
    print("Generating procedural dungeon...")
    
    # Initialize grid
    initialize_grid()
    
    # Generate rooms
    generate_rooms()
    
    # Connect rooms with corridors
    connect_rooms()
    
    # Create walls around floors
    create_walls()
    
    # Instantiate 3D geometry
    instantiate_geometry()
    
    # Add lighting
    add_lighting()
    
    # Place NPCs and props
    place_npcs_and_props()
    
    print("Dungeon generation complete!")

func initialize_grid():
    grid = []
    for x in range(dungeon_width):
        grid.append([])
        for y in range(dungeon_height):
            grid[x].append(CellType.EMPTY)

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
        
        # Check if room overlaps with existing rooms
        var overlaps = false
        for existing_room in rooms:
            if new_room.intersects(existing_room):
                overlaps = true
                break
        
        if not overlaps:
            rooms.append(new_room)
            
            # Mark first room center for Mage placement
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

func connect_rooms():
    # Connect each room to the next with corridors
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
        
        create_corridor(start, end)

func create_corridor(start: Vector2i, end: Vector2i):
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

func create_walls():
    for x in range(dungeon_width):
        for y in range(dungeon_height):
            if grid[x][y] == CellType.FLOOR or grid[x][y] == CellType.CORRIDOR:
                # Check adjacent cells for wall placement
                for dx in range(-1, 2):
                    for dy in range(-1, 2):
                        var nx = x + dx
                        var ny = y + dy
                        
                        if is_valid_position(Vector2i(nx, ny)) and grid[nx][ny] == CellType.EMPTY:
                            grid[nx][ny] = CellType.WALL

func instantiate_geometry():
    var cell_size = 4.0
    
    for x in range(dungeon_width):
        for y in range(dungeon_height):
            var world_pos = Vector3(x * cell_size, 0, y * cell_size)
            
            match grid[x][y]:
                CellType.FLOOR, CellType.CORRIDOR:
                    create_floor_tile(world_pos)
                CellType.WALL:
                    create_wall_tile(world_pos, x, y)

func create_floor_tile(position: Vector3):
    var floor_asset = floor_assets[randi() % floor_assets.size()]
    if ResourceLoader.exists(floor_asset):
        var floor_scene = load(floor_asset)
        var floor_instance = floor_scene.instantiate()
        floor_instance.position = position
        floor_container.add_child(floor_instance)

func create_wall_tile(position: Vector3, grid_x: int, grid_y: int):
    # Choose wall type based on neighbors
    var wall_asset = get_appropriate_wall_asset(grid_x, grid_y)
    
    if ResourceLoader.exists(wall_asset):
        var wall_scene = load(wall_asset)
        var wall_instance = wall_scene.instantiate()
        wall_instance.position = position
        
        # Rotate wall based on neighboring floors
        var rotation = get_wall_rotation(grid_x, grid_y)
        wall_instance.rotation.y = rotation
        
        wall_container.add_child(wall_instance)

func get_appropriate_wall_asset(grid_x: int, grid_y: int) -> String:
    # Simple wall selection - could be enhanced for corners, etc.
    return wall_assets[0] # Use basic wall for now

func get_wall_rotation(grid_x: int, grid_y: int) -> float:
    # Determine rotation based on which side has floor
    var has_floor_north = is_valid_position(Vector2i(grid_x, grid_y - 1)) and is_floor_or_corridor(grid_x, grid_y - 1)
    var has_floor_south = is_valid_position(Vector2i(grid_x, grid_y + 1)) and is_floor_or_corridor(grid_x, grid_y + 1)
    var has_floor_east = is_valid_position(Vector2i(grid_x + 1, grid_y)) and is_floor_or_corridor(grid_x + 1, grid_y)
    var has_floor_west = is_valid_position(Vector2i(grid_x - 1, grid_y)) and is_floor_or_corridor(grid_x - 1, grid_y)
    
    if has_floor_south:
        return 0.0
    elif has_floor_west:
        return PI / 2
    elif has_floor_north:
        return PI
    elif has_floor_east:
        return 3 * PI / 2
    
    return 0.0

func add_lighting():
    # Add torches to rooms and corridors where it's dark
    var cell_size = 4.0
    var torch_spacing = 8 # Place torch every 8 units
    
    for x in range(0, dungeon_width, 2):
        for y in range(0, dungeon_height, 2):
            if grid[x][y] == CellType.FLOOR or grid[x][y] == CellType.CORRIDOR:
                # Check if this area needs lighting
                if should_place_torch(x, y):
                    var world_pos = Vector3(x * cell_size, 0, y * cell_size)
                    create_torch(world_pos)

func should_place_torch(grid_x: int, grid_y: int) -> bool:
    # Place torch if there's a wall nearby to mount it on
    for dx in [-1, 0, 1]:
        for dy in [-1, 0, 1]:
            var nx = grid_x + dx
            var ny = grid_y + dy
            if is_valid_position(Vector2i(nx, ny)) and grid[nx][ny] == CellType.WALL:
                return true
    return false

func create_torch(position: Vector3):
    if torch_scene:
        var torch_instance = torch_scene.instantiate()
        torch_instance.position = position + Vector3(0, 0, 0)
        prop_container.add_child(torch_instance)

func place_npcs_and_props():
    # Place Mage in the first room
    if mage_scene and first_room_center != Vector2i.ZERO:
        var mage_instance = mage_scene.instantiate()
        var cell_size = 4.0
        mage_instance.position = Vector3(
            first_room_center.x * cell_size,
            0,
            first_room_center.y * cell_size
        )
        add_child(mage_instance)
        print("Placed Mage at: ", mage_instance.position)
    
    # Add some random props to other rooms
    for i in range(1, rooms.size()):
        var room = rooms[i]
        var prop_count = randi_range(1, 3)
        
        for j in range(prop_count):
            place_random_prop_in_room(room)

func place_random_prop_in_room(room: Rect2i):
    var prop_asset = prop_assets[randi() % prop_assets.size()]
    if ResourceLoader.exists(prop_asset):
        var prop_scene = load(prop_asset)
        var prop_instance = prop_scene.instantiate()
        
        var cell_size = 4.0
        var prop_x = randi_range(room.position.x + 1, room.position.x + room.size.x - 2)
        var prop_y = randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
        
        prop_instance.position = Vector3(prop_x * cell_size, 0, prop_y * cell_size)
        prop_container.add_child(prop_instance)

func is_valid_position(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < dungeon_width and pos.y >= 0 and pos.y < dungeon_height

func is_floor_or_corridor(grid_x: int, grid_y: int) -> bool:
    return grid[grid_x][grid_y] == CellType.FLOOR or grid[grid_x][grid_y] == CellType.CORRIDOR