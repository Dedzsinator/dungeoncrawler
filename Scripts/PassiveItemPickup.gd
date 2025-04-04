extends ItemPickup

class_name PassiveItemPickup

@export var passive_type: String = "health_boost"
@export var amount: float = 20.0

func _ready():
    super._ready()
    
    # Set appearance based on passive type
    if passive_type == "health_boost":
        item_name = "Health Boost"
        # Create a health mesh if no item scene provided
        if not item:
            var mesh = MeshInstance3D.new()
            var sphere = SphereMesh.new()
            sphere.radius = 0.3
            sphere.height = 0.6
            mesh.mesh = sphere
            
            var material = StandardMaterial3D.new()
            material.albedo_color = Color(1, 0.2, 0.2)
            material.emission_enabled = true
            material.emission = Color(1, 0.2, 0.2)
            material.emission_energy = 0.5
            mesh.material_override = material
            
            add_child(mesh)
    elif passive_type == "speed_boost":
        item_name = "Speed Boost"
        # Create a speed mesh if no item scene provided
        if not item:
            var mesh = MeshInstance3D.new()
            var sphere = SphereMesh.new()
            sphere.radius = 0.3
            sphere.height = 0.6
            mesh.mesh = sphere
            
            var material = StandardMaterial3D.new()
            material.albedo_color = Color(0.2, 1, 0.2)
            material.emission_enabled = true
            material.emission = Color(0.2, 1, 0.2)
            material.emission_energy = 0.5
            mesh.material_override = material
            
            add_child(mesh)

func _give_item_to_player(player):
    var passive_item
    
    if passive_type == "health_boost":
        passive_item = preload("res://Scripts/HealthBoost.gd").new()
        passive_item.health_increase = amount
    elif passive_type == "speed_boost":
        passive_item = preload("res://Scripts/SpeedBoost.gd").new()
        passive_item.speed_increase = amount
    else:
        push_error("Unknown passive item type: " + passive_type)
        return
    
    # Add to player inventory
    print("Giving " + passive_type + " to player")
    player.add_passive_item(passive_item)