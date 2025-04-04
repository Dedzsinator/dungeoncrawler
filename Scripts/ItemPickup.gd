extends Area3D

class_name ItemPickup

@export var item_scene: PackedScene
@export var item_name: String = "Unknown Item"
@export var pickup_sound: AudioStream
@export var float_height: float = 0.5
@export var rotation_speed: float = 1.0
@export var hover_speed: float = 2.0
@export var hover_amount: float = 0.1

var item = null
var start_y = 0.0
var collected = false

func _ready():
    # Set collision and interaction properties
    collision_layer = 4 # Layer for items
    collision_mask = 0 # Don't collide with anything
    input_ray_pickable = true
    
    # Connect signals
    body_entered.connect(_on_body_entered)
    
    # Set up visual representation
    if item_scene:
        item = item_scene.instantiate()
        add_child(item)
    else:
        # Create a default visual representation
        var mesh = MeshInstance3D.new()
        var cube = BoxMesh.new()
        cube.size = Vector3(0.5, 0.5, 0.5)
        mesh.mesh = cube
        
        var material = StandardMaterial3D.new()
        material.albedo_color = Color(1, 0.8, 0)
        material.emission_enabled = true
        material.emission = Color(1, 0.8, 0)
        material.emission_energy = 0.5
        mesh.material_override = material
        
        add_child(mesh)
    
    # Add to item pickup group
    add_to_group("item_pickup")
    
    # Store initial Y position for floating effect
    start_y = position.y

func _process(delta):
    if collected:
        return
        
    # Rotate the item
    rotate_y(rotation_speed * delta)
    
    # Make the item float up and down
    position.y = start_y + sin(Time.get_ticks_msec() / 1000.0 * hover_speed) * hover_amount

func _on_body_entered(body):
    if collected:
        return
        
    if body.is_in_group("player"):
        interact(body)

func interact(player):
    if collected:
        return
        
    # Mark as collected to prevent multiple pickups
    collected = true
    
    # Play pickup sound
    if pickup_sound:
        var audio = AudioStreamPlayer3D.new()
        audio.stream = pickup_sound
        audio.pitch_scale = randf_range(0.9, 1.1)
        add_child(audio)
        audio.play()
        
        # Remove after playing
        await audio.finished
    
    # Handle the actual item acquisition
    _give_item_to_player(player)
    
    # Visual effect
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
    await tween.finished
    
    # Remove from scene
    queue_free()

# Override this in child classes
func _give_item_to_player(player):
    print("Base item pickup - override _give_item_to_player in child class")