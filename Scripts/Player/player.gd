extends CharacterBody3D


@onready var cam_root_h: Node = get_node("CamRoot/H")
@onready var player_mesh: Node = get_node("Knight")
@onready var animation_tree: Node = get_node("AnimationTree")
@onready var playback: Variant = animation_tree.get("parameters/playback")

@export var gravity: float = 9.8
@export var jump_force: int = 9
@export var walk_speed: int = 3
@export var run_speed: int = 10

# animation node names
var idle_node_name: String = "Idle"
var walk_node_name: String = "Walk"
var run_node_name: String = "Run"
var jump_node_name: String = "Jump"
var attack1_node_name: String = "Attack1"
var death_node_name: String = "Death"

# state machine conditions
var is_walking: bool
var is_running: bool
var is_attacking: bool
var is_dying: bool

# physics
var direction: Vector3
var horizontal_velocity: Vector3
var vertical_velocity: Vector3
var movement: Vector3
var movement_speed: int
var angular_acceleration: int
var acceleration: int
var aim_turn: float
var just_hit: bool

@export var enable_rtx_armor: bool = true
var rtx_armor_material: ShaderMaterial
var original_armor_material: Material

func _ready() -> void:
	direction = Vector3.BACK.rotated(Vector3.UP, cam_root_h.global_transform.basis.get_euler().y)
	GameManager.level_up.connect(Callable(self, "level_up"))

	if enable_rtx_armor:
		setup_rtx_armor()

func setup_rtx_armor():
	print("Setting up RTX armor for player...")
	
	# Find the armor mesh in the knight model
	var knight_node = get_node("Knight")
	if not knight_node:
		print("Knight node not found!")
		return
	
	# Look for mesh instances in the knight hierarchy
	var armor_meshes = find_armor_meshes(knight_node)
	
	for mesh_instance in armor_meshes:
		apply_rtx_armor_material(mesh_instance)
	
	print("RTX armor setup complete!")

func find_armor_meshes(node: Node) -> Array:
	var armor_meshes = []
	
	if node is MeshInstance3D:
		# Check if this mesh is part of the armor/body
		var mesh_name = node.name.to_lower()
		if "body" in mesh_name or "armor" in mesh_name or "chest" in mesh_name or "torso" in mesh_name:
			armor_meshes.append(node)
		# Also include the main knight mesh
		elif "knight" in mesh_name:
			armor_meshes.append(node)
	
	# Recursively search child nodes
	for child in node.get_children():
		armor_meshes.append_array(find_armor_meshes(child))
	
	return armor_meshes

func apply_rtx_armor_material(mesh_instance: MeshInstance3D):
	# Store original material for potential restoration
	if mesh_instance.material_override:
		original_armor_material = mesh_instance.material_override
	elif mesh_instance.get_surface_override_material(0):
		original_armor_material = mesh_instance.get_surface_override_material(0)
	
	# Create RTX armor material
	var rtx_material = create_rtx_armor_material()
	
	# Apply the RTX material
	mesh_instance.material_override = rtx_material
	
	# Add to RTX geometry group for compute shader integration
	mesh_instance.add_to_group("rtx_geometry")
	
	# Notify RTX manager that geometry has changed
	var rtx_manager = get_tree().get_first_node_in_group("rtx_manager")
	if rtx_manager and rtx_manager.has_method("mark_geometry_dirty"):
		rtx_manager.mark_geometry_dirty()
	
	print("Applied RTX armor material to: ", mesh_instance.name)

func create_rtx_armor_material() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	
	# Load the RTX armor shader
	if ResourceLoader.exists("res://Materials/rtx_armor.gdshader"):
		material.shader = load("res://Materials/rtx_armor.gdshader")
	else:
		print("RTX armor shader not found, creating fallback material")
		return create_fallback_rtx_armor_material()
	
	# Set shader parameters for realistic metallic armor
	material.set_shader_parameter("metallic", 0.95) # Very metallic
	material.set_shader_parameter("roughness", 0.08) # Very smooth/shiny
	material.set_shader_parameter("clearcoat", 0.9) # Strong clearcoat
	material.set_shader_parameter("clearcoat_roughness", 0.02) # Very smooth clearcoat
	material.set_shader_parameter("armor_tint", Color(0.75, 0.8, 0.9, 1.0)) # Steel blue tint
	material.set_shader_parameter("rim_strength", 0.8) # Strong rim lighting
	material.set_shader_parameter("rim_color", Color(0.4, 0.7, 1.0, 1.0)) # Blue rim
	material.set_shader_parameter("reflection_intensity", 1.5) # Enhanced reflections
	material.set_shader_parameter("normal_scale", 1.2) # Enhanced normal mapping
	material.set_shader_parameter("fresnel_power", 2.5) # Realistic fresnel
	material.set_shader_parameter("metallic_edge_enhancement", 0.4) # Edge enhancement
	
	# Try to use existing texture if available
	if original_armor_material and original_armor_material is StandardMaterial3D:
		var std_mat = original_armor_material as StandardMaterial3D
		if std_mat.albedo_texture:
			material.set_shader_parameter("armor_texture", std_mat.albedo_texture)
		if std_mat.normal_texture:
			material.set_shader_parameter("normal_map", std_mat.normal_texture)
	else:
		# Load default knight texture
		var knight_texture_path = "res://Assets/KayKit_Adventurers_1.0_FREE/KayKit_Adventurers_1.0_FREE/Characters/gltf/Knight_knight_texture.png"
		if ResourceLoader.exists(knight_texture_path):
			var texture = load(knight_texture_path)
			material.set_shader_parameter("armor_texture", texture)
	
	return material

func create_fallback_rtx_armor_material() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	
	# Create a simple metallic shader as fallback for spatial rendering
	var shader_code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float metallic : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform vec4 albedo_color : source_color = vec4(0.75, 0.8, 0.85, 1.0);
uniform sampler2D armor_texture : source_color, hint_default_white;

void fragment() {
	vec4 tex = texture(armor_texture, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 0.8;
	ALPHA = tex.a;
}
"""
	
	var fallback_shader = Shader.new()
	fallback_shader.code = shader_code
	material.shader = fallback_shader
	
	# Set basic metallic parameters
	material.set_shader_parameter("metallic", 0.95)
	material.set_shader_parameter("roughness", 0.1)
	material.set_shader_parameter("albedo_color", Color(0.75, 0.8, 0.85, 1.0))
	
	# Try to use the knight texture
	var knight_texture_path = "res://Assets/KayKit_Adventurers_1.0_FREE/KayKit_Adventurers_1.0_FREE/Characters/gltf/Knight_knight_texture.png"
	if ResourceLoader.exists(knight_texture_path):
		var texture = load(knight_texture_path)
		material.set_shader_parameter("armor_texture", texture)
	
	return material

# Add method to toggle RTX armor on/off
func toggle_rtx_armor():
	enable_rtx_armor = !enable_rtx_armor
	
	if enable_rtx_armor:
		setup_rtx_armor()
	else:
		restore_original_armor()

func restore_original_armor():
	var knight_node = get_node("Knight")
	if not knight_node:
		return
	
	var armor_meshes = find_armor_meshes(knight_node)
	
	for mesh_instance in armor_meshes:
		if original_armor_material:
			mesh_instance.material_override = original_armor_material
		else:
			mesh_instance.material_override = null
		
		mesh_instance.remove_from_group("rtx_geometry")
	
	print("Restored original armor materials")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		aim_turn = - event.relative.x * 0.015
	if event.is_action_pressed("aim"):
		direction = cam_root_h.global_transform.basis.z
	if event.is_action_pressed("ui_right") and Input.is_action_pressed("ui_select"):
		toggle_rtx_armor()
		print("RTX Armor toggled: ", enable_rtx_armor)

func attack1() -> void:
	if idle_node_name in playback.get_current_node() or walk_node_name in playback.get_current_node() or run_node_name in playback.get_current_node():
		if Input.is_action_pressed("attack"):
			if !is_attacking:
				playback.travel(attack1_node_name)

func _physics_process(delta: float) -> void:
	var on_floor = is_on_floor()
	if !is_dying:
		attack1()
		if !on_floor:
			vertical_velocity += Vector3.DOWN * gravity * 2 * delta
		else:
			vertical_velocity = Vector3.DOWN * gravity / 10
		if Input.is_action_pressed("jump") and !is_attacking and on_floor:
			vertical_velocity = Vector3.UP * jump_force
		movement_speed = 0
		angular_acceleration = 10
		acceleration = 15
		if attack1_node_name in playback.get_current_node():
			is_attacking = true
		else:
			is_attacking = false
		var h_rot = cam_root_h.global_transform.basis.get_euler().y
		if Input.is_action_pressed("forward") or Input.is_action_pressed("backward") or Input.is_action_pressed("left") or Input.is_action_pressed("right"):
			direction = Vector3(Input.get_action_strength("left") - Input.get_action_strength("right"),
								0,
								Input.get_action_strength("forward") - Input.get_action_strength("backward"))
			direction = direction.rotated(Vector3.UP, h_rot).normalized()
			is_walking = true
			if Input.is_action_pressed("sprint"):
				movement_speed = run_speed
				is_running = true
			else:
				movement_speed = walk_speed
				is_running = false
		else:
			is_walking = false
			is_running = false
		if is_running:
			$VFX_Puff_Run.emitting = true
		else:
			$VFX_Puff_Run.emitting = false
		if Input.is_action_pressed("aim"):
			player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, cam_root_h.rotation.y, angular_acceleration * delta)
		else:
			player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, atan2(direction.x, direction.z) - rotation.y, angular_acceleration * delta)
		if is_attacking:
			horizontal_velocity = horizontal_velocity.lerp(direction.normalized() * 0.01, acceleration * delta)
		else:
			horizontal_velocity = horizontal_velocity.lerp(direction.normalized() * movement_speed, acceleration * delta)
		velocity.x = horizontal_velocity.x + vertical_velocity.x
		velocity.y = vertical_velocity.y
		velocity.z = horizontal_velocity.z + vertical_velocity.z
		move_and_slide()
	animation_tree["parameters/conditions/is_on_floor"] = on_floor
	animation_tree["parameters/conditions/is_in_air"] = !on_floor
	animation_tree["parameters/conditions/is_walking"] = is_walking
	animation_tree["parameters/conditions/is_not_walking"] = !is_walking
	animation_tree["parameters/conditions/is_running"] = is_running
	animation_tree["parameters/conditions/is_not_running"] = !is_running
	animation_tree["parameters/conditions/is_dying"] = is_dying
	
func die() -> void:
	await get_tree().create_timer(1).timeout
	get_node("../GameOverOverlay").game_over()

func hit(amount: int) -> void:
	if !just_hit:
		$Hit.play()
		if GameManager.damage_player(amount):
			just_hit = true
			get_node("HitTimer").start()
		if GameManager.player_health <= 0:
			is_dying = true
			playback.travel(death_node_name)
		else:
			var tween = get_tree().create_tween()
			tween.tween_property(self, "global_position", global_position - (direction / 1.5), 0.2)
			
func level_up() -> void:
	$VFX_Level_Up/AnimationPlayer.play("init")

func _on_damage_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("monster") and is_attacking:
		body.hit(GameManager.player_damage)
		$Knight/Rig/Skeleton3D/RightHandSlot/VFX_Hit/AnimationPlayer.play("hit")
		$Damage.play()

func _on_hit_timer_timeout() -> void:
	just_hit = false

func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if "Death" in anim_name:
		die()
