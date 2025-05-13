extends Node

class_name RoomManager

# Dependencies
var season_manager: SeasonManager

# Room statistics
var total_rooms := 0
var rooms_per_floor := 10
var current_floor := 1
var rooms_on_current_floor := 0
var boss_room_created := false

# Initialization
func _init():
    season_manager = SeasonManager.new()
    add_child(season_manager)

# Apply a random season to a room
func apply_random_season_to_room(room: Node3D) -> void:
    season_manager.select_random_season()
    season_manager.apply_season_to_room(room)
    
    # Add the room to tracking
    total_rooms += 1
    rooms_on_current_floor += 1
    
    # Check if this should be a boss room
    if rooms_on_current_floor >= rooms_per_floor and not boss_room_created:
        convert_to_boss_room(room)

# Try to convert a room to a boss room
func convert_to_boss_room(room: Node3D) -> void:
    # Don't convert if already converted
    if room.has_meta("is_boss_room") and room.get_meta("is_boss_room"):
        return
    
    print("Converting room to boss room...")
    
    # Create a boss room controller
    var boss_room = BossRoom.new(room)
    boss_room.setup()
    boss_room_created = true
    
    # Set the season to fall for boss room atmosphere
    season_manager.current_season = SeasonManager.Season.FALL
    season_manager.apply_season_to_room(room)
    
    print("Boss room created on floor " + str(current_floor))

# Process season effects on entities in a room
func process_season_effects(entity: Node3D, current_room: Node3D) -> void:
    if not current_room.has_meta("season"):
        return
    
    var season = current_room.get_meta("season")
    
    # Apply movement modifier
    if current_room.has_meta("movement_modifier"):
        var movement_mod = current_room.get_meta("movement_modifier")
        if entity.has_method("set_movement_modifier"):
            entity.set_movement_modifier(movement_mod)
        elif entity.has_property("movement_speed"):
            var base_speed = 1.0
            if entity.has_meta("base_movement_speed"):
                base_speed = entity.get_meta("base_movement_speed")
            else:
                # Store original speed first time
                entity.set_meta("base_movement_speed", entity.movement_speed)
                base_speed = entity.movement_speed
            
            entity.movement_speed = base_speed * movement_mod
            
    # Apply damage modifier
    if current_room.has_meta("damage_modifier"):
        var damage_mod = current_room.get_meta("damage_modifier")
        if entity.has_method("set_damage_modifier"):
            entity.set_damage_modifier(damage_mod)
        elif entity.has_property("damage"):
            var base_damage = 1.0
            if entity.has_meta("base_damage"):
                base_damage = entity.get_meta("base_damage")
            else:
                # Store original damage first time
                entity.set_meta("base_damage", entity.damage)
                base_damage = entity.damage
                
            entity.damage = base_damage * damage_mod
    
    # Apply knockback modifier
    if current_room.has_meta("knockback_modifier"):
        var knockback_mod = current_room.get_meta("knockback_modifier")
        if entity.has_method("set_knockback_modifier"):
            entity.set_knockback_modifier(knockback_mod)
        elif entity.has_property("knockback_force"):
            var base_knockback = 1.0
            if entity.has_meta("base_knockback"):
                base_knockback = entity.get_meta("base_knockback")
            else:
                # Store original knockback first time
                entity.set_meta("base_knockback", entity.knockback_force)
                base_knockback = entity.knockback_force
                
            entity.knockback_force = base_knockback * knockback_mod

# Start a new floor
func start_new_floor() -> void:
    current_floor += 1
    rooms_on_current_floor = 0
    boss_room_created = false
    print("Starting floor " + str(current_floor))
    
    # Increase difficulty with each floor
    increase_floor_difficulty()

# Increase difficulty as player progresses to higher floors
func increase_floor_difficulty() -> void:
    # Increase rooms needed to reach boss room
    rooms_per_floor = 10 + (current_floor - 1) * 2
    
    # Communicate difficulty increase to enemies
    # This is just a multiplier - the actual enemy scripts would use this
    var difficulty_multiplier = 1.0 + (current_floor - 1) * 0.2 # 20% increase per floor
    get_tree().call_group("enemies", "set_difficulty_level", difficulty_multiplier)
