extends Enemy
class_name MeleeEnemy

func _ready():
    super._ready()
    max_health = 80
    movement_speed = 3.0
    attack_damage = 15
    attack_radius = 1.8
    detection_radius = 12.0
    
    # Setup visuals for melee enemy
    if has_node("MeshInstance3D"):
        var material = StandardMaterial3D.new()
        material.albedo_color = Color(0.8, 0.2, 0.2) # Red for melee
        $MeshInstance3D.material_override = material

func perform_attack():
    # Melee attack with slight lunge
    if player and global_position.distance_to(player.global_position) <= attack_radius:
        # Small lunge toward player
        var lunge_dir = (player.global_position - global_position).normalized()
        velocity = lunge_dir * movement_speed * 2
        
        # Deal damage
        player.change_health(-attack_damage)
        
        if has_node("AnimationPlayer"):
            $AnimationPlayer.play("attack")