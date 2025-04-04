extends Weapon

@export var swing_angle: float = 90.0
@export var knockback_force: float = 5.0

var swing_mesh: MeshInstance3D

func _ready():
	super._ready()
	
	# Set weapon properties
	item_name = "Sword"
	description = "A basic sword that deals damage in a wide arc"
	damage = 15.0
	cooldown = 0.8
	range = 2.0
	
	# Create weapon mesh
	swing_mesh = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.5, 1.5)
	swing_mesh.mesh = mesh
	
	# Apply material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.7, 0.8)
	material.metallic = 0.8
	material.roughness = 0.2
	swing_mesh.material_override = material
	
	add_child(swing_mesh)

func _weapon_effect():
	# Get player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Play swing animation
	var tween = create_tween()
	tween.tween_property(swing_mesh, "rotation_degrees:y", swing_angle / 2, 0.2)
	tween.tween_property(swing_mesh, "rotation_degrees:y", -swing_angle / 2, 0.2)
	tween.tween_property(swing_mesh, "rotation_degrees:y", 0, 0.1)
	
	# Create damage area
	var attack_area = Area3D.new()
	attack_area.name = "SwordSwing"
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 1.0, 2.0)
	collision.shape = shape
	attack_area.add_child(collision)
	
	# Create script for damage with values directly in the source
	var script = GDScript.new()
	script.source_code = """
	extends Area3D
	
	var damage = %s
	var knockback = %s
	var already_hit = []
	
	func _ready():
		# Connect signal
		body_entered.connect(_on_body_entered)
		
		# Remove after short duration
		await get_tree().create_timer(0.3).timeout
		queue_free()
	
	func _on_body_entered(body):
		# Don't hit same enemy twice
		if already_hit.has(body):
			return
			
		if body is Enemy:
			body.take_damage(damage)
			already_hit.append(body)
			
			# Apply knockback
			var knockback_dir = (body.global_position - get_parent().global_position).normalized()
			body.velocity = knockback_dir * knockback
	""" % [damage, knockback_force]
	
	# Set the script
	attack_area.set_script(script)
	
	# Add to scene in front of player
	player.add_child(attack_area)
	attack_area.position = Vector3(0, 0, -1.5)
