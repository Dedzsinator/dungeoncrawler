extends ItemPickup

class_name WeaponPickup

@export var weapon_type: String = "sword"
@export var auto_equip: bool = true

func _ready():
    super._ready()
    
    # Set appearance based on weapon type
    if weapon_type == "sword":
        item_name = "Sword"
        # Create a sword mesh if no item scene provided
        if not item:
            var mesh = MeshInstance3D.new()
            var box = BoxMesh.new()
            box.size = Vector3(0.1, 0.5, 1.5)
            mesh.mesh = box
            
            var material = StandardMaterial3D.new()
            material.albedo_color = Color(0.7, 0.7, 0.8)
            material.metallic = 0.8
            material.roughness = 0.2
            mesh.material_override = material
            
            add_child(mesh)
    elif weapon_type == "bow":
        item_name = "Bow"
        # Create a bow mesh if no item scene provided
        if not item:
            var mesh = MeshInstance3D.new()
            var cyl = CylinderMesh.new()
            cyl.top_radius = 0.05
            cyl.bottom_radius = 0.05
            cyl.height = 1.2
            mesh.mesh = cyl
            
            var material = StandardMaterial3D.new()
            material.albedo_color = Color(0.4, 0.2, 0.1)
            mesh.material_override = material
            
            add_child(mesh)
            mesh.rotation_degrees.x = 90

func _give_item_to_player(player):
    var weapon
    
    if weapon_type == "sword":
        weapon = preload("res://Scripts/Sword.gd").new()
    elif weapon_type == "bow":
        weapon = preload("res://Scripts/Bow.gd").new()
    else:
        push_error("Unknown weapon type: " + weapon_type)
        return
    
    # Equip or add to inventory
    print("Giving " + weapon_type + " to player")
    player.equip_weapon(weapon, -1 if not auto_equip else player.inventory.current_active_slot)