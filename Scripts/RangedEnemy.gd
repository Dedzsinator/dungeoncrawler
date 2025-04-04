extends Enemy
class_name RangedEnemy

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 10.0
@export var optimal_distance: float = 7.0 # Tries to maintain this distance

func _ready():
    super._ready()
    max_health = 60
    movement_speed = 2.5
    attack_damage = 10
    attack_radius = 8.0
    attack_cooldown = 2.0
    detection_radius = 15.0
    
    # Setup visuals for ranged enemy
    if has_node("MeshInstance3D"):
        var material = StandardMaterial3D.new()
        material.albedo_color = Color(0.2, 0.2, 0.8) # Blue for ranged
        $MeshInstance3D.material_override = material

func chase_behavior(delta):
    if not player:
        return
        
    # Calculate distance to player
    var distance = global_position.distance_to(player.global_position)
    
    # If too close, back away
    if distance < optimal_distance - 1.0:
        var direction = (global_position - player.global_position).normalized()
        velocity = direction * movement_speed
    # If too far, get closer
    elif distance > optimal_distance + 1.0:
        var direction = (player.global_position - global_position).normalized()
        velocity = direction * movement_speed
    else:
        # At good distance, minimal movement
        velocity = Vector3.ZERO
    
    # Look at player (only Y-axis)
    look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

func perform_attack():
    # Create and shoot projectile
    if player:
        if has_node("AnimationPlayer"):
            $AnimationPlayer.play("shoot")
            
        # Create projectile
        var projectile
        if projectile_scene:
            projectile = projectile_scene.instantiate()
        else:
            # Create default projectile
            projectile = Area3D.new()
            var collision = CollisionShape3D.new()
            var shape = SphereShape3D.new()
            shape.radius = 0.2
            collision.shape = shape
            projectile.add_child(collision)
            
            # Add visual
            var mesh_instance = MeshInstance3D.new()
            var mesh = SphereMesh.new()
            mesh.radius = 0.2
            mesh.height = 0.4
            mesh_instance.mesh = mesh
            
            # Apply material
            var material = StandardMaterial3D.new()
            material.albedo_color = Color(1.0, 0.7, 0.2)
            material.emission_enabled = true
            material.emission = Color(1.0, 0.5, 0.0)
            material.emission_energy = 2.0
            mesh_instance.material_override = material
            
            projectile.add_child(mesh_instance)
            
            # Projectile script to handle collision
            var script = GDScript.new()
            script.source_code = """
            extends Area3D
            
            var speed = 10.0
            var damage = 10.0
            var direction = Vector3.FORWARD
            
            func _ready():
                # Connect signal
                body_entered.connect(_on_body_entered)
                
                # Self-destruct after 5 seconds
                await get_tree().create_timer(5.0).timeout
                queue_free()
            
            func _physics_process(delta):
                # Move forward
                position += direction * speed * delta
                
            func _on_body_entered(body):
                if body.is_in_group('player'):
                    body.change_health(-damage)
                    queue_free()
                elif not body.is_in_group('enemy'):
                    # Hit something else (like wall)
                    queue_free()
            """
            projectile.set_script(script)
        
        get_tree().root.add_child(projectile)
        projectile.position = global_position + Vector3(0, 1.0, 0)
        projectile.direction = (player.global_position - global_position).normalized()
        projectile.speed = projectile_speed
        projectile.damage = attack_damage