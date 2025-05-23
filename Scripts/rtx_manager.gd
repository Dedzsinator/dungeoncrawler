extends Node3D

@export var enable_rtx: bool = true
@export var samples_per_pixel: int = 4
@export var max_bounces: int = 8
@export var rtx_resolution_scale: float = 1.0

var rd: RenderingDevice
var compute_shader: RID
var output_texture: RID
var uniform_set: RID

# Buffers
var camera_buffer: RID
var scene_buffer: RID
var material_buffer: RID
var triangle_buffer: RID
var bvh_buffer: RID

# Data structures
var materials: Array = []
var triangles: Array = []
var bvh_nodes: Array = []

# Camera reference
var camera: Camera3D

func _ready():
	if not enable_rtx:
		return
	
	# Add to RTX manager group
	add_to_group("rtx_manager")
	
	# Get the main camera
	camera = get_viewport().get_camera_3d()
	if not camera:
		print("No camera found for RTX")
		return
	
	# Initialize compute shader
	setup_compute_shader()
	
	# Build scene data
	build_scene_geometry()
	
	# Setup buffers
	setup_buffers()

func build_scene_geometry():
	materials.clear()
	triangles.clear()
	
	# Collect all MeshInstance3D nodes
	var mesh_instances = get_tree().get_nodes_in_group("rtx_geometry")
	if mesh_instances.is_empty():
		mesh_instances = find_all_mesh_instances(get_tree().root)
	
	var material_map = {}
	var triangle_index = 0
	
	for mesh_instance in mesh_instances:
		if not mesh_instance is MeshInstance3D:
			continue
			
		var mesh = mesh_instance.mesh
		if not mesh:
			continue
			
		# Process each surface
		for surface_idx in range(mesh.get_surface_count()):
			# Get material
			var material = mesh_instance.get_surface_override_material(surface_idx)
			if not material:
				material = mesh.surface_get_material(surface_idx)
			
			var material_id = get_or_create_material_id(material, material_map)
			
			# Get mesh data
			var arrays = mesh.surface_get_arrays(surface_idx)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var normals = arrays[Mesh.ARRAY_NORMAL]
			var uvs = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else []
			var indices = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else []
			
			# Transform vertices to world space
			var transform = mesh_instance.global_transform
			
			# Create triangles
			if indices.size() > 0:
				for i in range(0, indices.size(), 3):
					create_triangle(vertices, normals, uvs, indices, i, transform, material_id)
			else:
				for i in range(0, vertices.size(), 3):
					create_triangle_direct(vertices, normals, uvs, i, transform, material_id)
	
	# Build BVH
	build_bvh()

func find_all_mesh_instances(node: Node) -> Array:
	var result = []
	
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		result.append_array(find_all_mesh_instances(child))
	
	return result

func get_or_create_material_id(material: Material, material_map: Dictionary) -> int:
	if not material:
		# Default material
		if not material_map.has("default"):
			var default_mat = {
				"albedo": Vector4(0.8, 0.8, 0.8, 1.0),
				"emission": Vector4(0.0, 0.0, 0.0, 0.0),
				"roughness": 0.5,
				"metallic": 0.0,
				"ior": 1.45,
				"transmission": 0.0
			}
			materials.append(default_mat)
			material_map["default"] = materials.size() - 1
		return material_map["default"]
	
	var key = str(material.get_rid())
	if material_map.has(key):
		return material_map[key]
	
	# Extract material properties
	var mat_data = {
		"albedo": Vector4(1.0, 1.0, 1.0, 1.0),
		"emission": Vector4(0.0, 0.0, 0.0, 0.0),
		"roughness": 0.5,
		"metallic": 0.0,
		"ior": 1.45,
		"transmission": 0.0
	}
	
	if material is StandardMaterial3D:
		var std_mat = material as StandardMaterial3D
		mat_data.albedo = Vector4(std_mat.albedo_color.r, std_mat.albedo_color.g, std_mat.albedo_color.b, std_mat.albedo_color.a)
		
		# Fix: In Godot 4, emission energy is built into the emission color
		var emission_color = std_mat.emission
		var emission_intensity = (emission_color.r + emission_color.g + emission_color.b) / 3.0
		mat_data.emission = Vector4(emission_color.r, emission_color.g, emission_color.b, emission_intensity)
		
		mat_data.roughness = std_mat.roughness
		mat_data.metallic = std_mat.metallic
		
		# Handle additional PBR properties if available
		if std_mat.refraction_enabled:
			mat_data.ior = 1.0 + std_mat.refraction_scale
		if std_mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mat_data.transmission = 1.0 - std_mat.albedo_color.a
	
	elif material is ShaderMaterial:
		var shader_mat = material as ShaderMaterial
		
		# Try to extract common shader parameters
		var albedo_param = shader_mat.get_shader_parameter("albedo_color")
		if albedo_param is Color:
			var color = albedo_param as Color
			mat_data.albedo = Vector4(color.r, color.g, color.b, color.a)
		elif albedo_param is Vector4:
			mat_data.albedo = albedo_param as Vector4
		
		var metallic_param = shader_mat.get_shader_parameter("metallic")
		if metallic_param is float:
			mat_data.metallic = metallic_param
		
		var roughness_param = shader_mat.get_shader_parameter("roughness")
		if roughness_param is float:
			mat_data.roughness = roughness_param
		
		var emission_param = shader_mat.get_shader_parameter("emission")
		if emission_param is Color:
			var emission = emission_param as Color
			mat_data.emission = Vector4(emission.r, emission.g, emission.b, (emission.r + emission.g + emission.b) / 3.0)
		
		# Handle RTX armor shader parameters
		var rim_color_param = shader_mat.get_shader_parameter("rim_color")
		if rim_color_param is Color:
			var rim = rim_color_param as Color
			# Add rim lighting as emission
			mat_data.emission = Vector4(
				mat_data.emission.x + rim.r * rim.a,
				mat_data.emission.y + rim.g * rim.a,
				mat_data.emission.z + rim.b * rim.a,
				mat_data.emission.w + rim.a
			)
	
	materials.append(mat_data)
	material_map[key] = materials.size() - 1
	return materials.size() - 1

func create_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, start_idx: int, transform: Transform3D, material_id: int):
	var triangle = {
		"v0": transform * vertices[indices[start_idx]],
		"v1": transform * vertices[indices[start_idx + 1]],
		"v2": transform * vertices[indices[start_idx + 2]],
		"n0": transform.basis * (normals[indices[start_idx]] if normals.size() > indices[start_idx] else Vector3.UP),
		"n1": transform.basis * (normals[indices[start_idx + 1]] if normals.size() > indices[start_idx + 1] else Vector3.UP),
		"n2": transform.basis * (normals[indices[start_idx + 2]] if normals.size() > indices[start_idx + 2] else Vector3.UP),
		"uv0": uvs[indices[start_idx]] if uvs.size() > indices[start_idx] else Vector2.ZERO,
		"uv1": uvs[indices[start_idx + 1]] if uvs.size() > indices[start_idx + 1] else Vector2.ZERO,
		"uv2": uvs[indices[start_idx + 2]] if uvs.size() > indices[start_idx + 2] else Vector2.ZERO,
		"material_id": material_id
	}
	triangles.append(triangle)

func create_triangle_direct(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, start_idx: int, transform: Transform3D, material_id: int):
	var triangle = {
		"v0": transform * vertices[start_idx],
		"v1": transform * vertices[start_idx + 1],
		"v2": transform * vertices[start_idx + 2],
		"n0": transform.basis * (normals[start_idx] if normals.size() > start_idx else Vector3.UP),
		"n1": transform.basis * (normals[start_idx + 1] if normals.size() > start_idx + 1 else Vector3.UP),
		"n2": transform.basis * (normals[start_idx + 2] if normals.size() > start_idx + 2 else Vector3.UP),
		"uv0": uvs[start_idx] if uvs.size() > start_idx else Vector2.ZERO,
		"uv1": uvs[start_idx + 1] if uvs.size() > start_idx + 1 else Vector2.ZERO,
		"uv2": uvs[start_idx + 2] if uvs.size() > start_idx + 2 else Vector2.ZERO,
		"material_id": material_id
	}
	triangles.append(triangle)

func build_bvh():
	if triangles.is_empty():
		return
	
	# Simple BVH construction (can be optimized)
	bvh_nodes.clear()
	
	# Calculate bounding boxes for all triangles
	var triangle_bounds = []
	for triangle in triangles:
		var min_bound = Vector3(INF, INF, INF)
		var max_bound = Vector3(-INF, -INF, -INF)
		
		for vertex in [triangle.v0, triangle.v1, triangle.v2]:
			min_bound = min_bound.min(vertex)
			max_bound = max_bound.max(vertex)
		
		triangle_bounds.append({"min": min_bound, "max": max_bound})
	
	# Create root node
	var root_node = {
		"min_bounds": Vector3(INF, INF, INF),
		"max_bounds": Vector3(-INF, -INF, -INF),
		"left_child": 0,
		"right_child": 0,
		"triangle_count": triangles.size(),
		"first_triangle": 0
	}
	
	# Calculate root bounds
	for bounds in triangle_bounds:
		root_node.min_bounds = root_node.min_bounds.min(bounds.min)
		root_node.max_bounds = root_node.max_bounds.max(bounds.max)
	
	bvh_nodes.append(root_node)

func setup_buffers():
	var viewport_size = get_viewport().get_visible_rect().size
	var rtx_size = Vector2i(
		int(viewport_size.x * rtx_resolution_scale),
		int(viewport_size.y * rtx_resolution_scale)
	)
	
	# Create output texture
	var output_format = RDTextureFormat.new()
	output_format.width = rtx_size.x
	output_format.height = rtx_size.y
	output_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	output_format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	output_texture = rd.texture_create(output_format, RDTextureView.new())
	
	# Create buffers
	create_camera_buffer()
	create_scene_buffer()
	create_material_buffer()
	create_triangle_buffer()
	create_bvh_buffer()
	
	# Create uniform set
	var uniform_list = []
	
	# Output texture
	var output_uniform = RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_uniform.binding = 0
	output_uniform.add_id(output_texture)
	uniform_list.append(output_uniform)
	
	# Camera buffer
	var camera_uniform = RDUniform.new()
	camera_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	camera_uniform.binding = 1
	camera_uniform.add_id(camera_buffer)
	uniform_list.append(camera_uniform)
	
	# Scene buffer
	var scene_uniform = RDUniform.new()
	scene_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	scene_uniform.binding = 2
	scene_uniform.add_id(scene_buffer)
	uniform_list.append(scene_uniform)
	
	# Material buffer
	var material_uniform = RDUniform.new()
	material_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	material_uniform.binding = 3
	material_uniform.add_id(material_buffer)
	uniform_list.append(material_uniform)
	
	# Triangle buffer
	var triangle_uniform = RDUniform.new()
	triangle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	triangle_uniform.binding = 4
	triangle_uniform.add_id(triangle_buffer)
	uniform_list.append(triangle_uniform)
	
	# BVH buffer
	var bvh_uniform = RDUniform.new()
	bvh_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	bvh_uniform.binding = 5
	bvh_uniform.add_id(bvh_buffer)
	uniform_list.append(bvh_uniform)
	
	uniform_set = rd.uniform_set_create(uniform_list, compute_shader, 0)

func create_camera_buffer():
	var camera_data = PackedFloat32Array()
	
	# View matrix (16 floats)
	var view_matrix = camera.get_camera_transform().inverse()
	var view_basis = view_matrix.basis
	var view_origin = view_matrix.origin
	
	# Add basis columns and origin
	camera_data.append_array([view_basis.x.x, view_basis.x.y, view_basis.x.z, 0.0])
	camera_data.append_array([view_basis.y.x, view_basis.y.y, view_basis.y.z, 0.0])
	camera_data.append_array([view_basis.z.x, view_basis.z.y, view_basis.z.z, 0.0])
	camera_data.append_array([view_origin.x, view_origin.y, view_origin.z, 1.0])
	
	# Projection matrix (16 floats)
	var projection_matrix = camera.get_camera_projection()
	for i in range(4):
		for j in range(4):
			camera_data.append(projection_matrix[i][j])
	
	# Inverse view matrix (16 floats)
	var inv_view_matrix = camera.get_camera_transform()
	var inv_view_basis = inv_view_matrix.basis
	var inv_view_origin = inv_view_matrix.origin
	
	camera_data.append_array([inv_view_basis.x.x, inv_view_basis.x.y, inv_view_basis.x.z, 0.0])
	camera_data.append_array([inv_view_basis.y.x, inv_view_basis.y.y, inv_view_basis.y.z, 0.0])
	camera_data.append_array([inv_view_basis.z.x, inv_view_basis.z.y, inv_view_basis.z.z, 0.0])
	camera_data.append_array([inv_view_origin.x, inv_view_origin.y, inv_view_origin.z, 1.0])
	
	# Inverse projection matrix (16 floats)
	var inv_projection_matrix = projection_matrix.inverse()
	for i in range(4):
		for j in range(4):
			camera_data.append(inv_projection_matrix[i][j])
	
	# Camera position (3 floats + 1 padding)
	var cam_pos = camera.global_position
	camera_data.append_array([cam_pos.x, cam_pos.y, cam_pos.z, camera.fov])
	
	# Screen size (2 floats + 2 padding)
	var viewport_size = get_viewport().get_visible_rect().size
	camera_data.append_array([viewport_size.x * rtx_resolution_scale, viewport_size.y * rtx_resolution_scale, camera.near, camera.far])
	
	var camera_data_bytes = camera_data.to_byte_array()
	camera_buffer = rd.uniform_buffer_create(camera_data_bytes.size())
	rd.buffer_update(camera_buffer, 0, true, camera_data_bytes)

func create_scene_buffer():
	var scene_data = PackedFloat32Array()
	
	# Sun direction (3 floats + 1 intensity)
	var sun_dir = Vector3(0.5, -1.0, 0.3).normalized()
	scene_data.append_array([sun_dir.x, sun_dir.y, sun_dir.z, 2.0])
	
	# Sun color (3 floats + 1 ambient intensity)
	scene_data.append_array([1.0, 0.95, 0.8, 0.1])
	
	# Ambient color (3 floats + 1 padding)
	scene_data.append_array([0.2, 0.3, 0.5, 0.0])
	
	# Max bounces, samples per pixel, time, padding
	var current_time = Time.get_time_dict_from_system()
	scene_data.append_array([float(max_bounces), float(samples_per_pixel), float(current_time["second"]), 0.0])
	
	var scene_data_bytes = scene_data.to_byte_array()
	scene_buffer = rd.uniform_buffer_create(scene_data_bytes.size())
	rd.buffer_update(scene_buffer, 0, true, scene_data_bytes)

func create_material_buffer():
	if materials.is_empty():
		# Create default material
		materials.append({
			"albedo": Vector4(0.8, 0.8, 0.8, 1.0),
			"emission": Vector4(0.0, 0.0, 0.0, 0.0),
			"roughness": 0.5,
			"metallic": 0.0,
			"ior": 1.45,
			"transmission": 0.0
		})
	
	var material_data = PackedFloat32Array()
	
	for material in materials:
		# Albedo (4 floats)
		material_data.append_array([material.albedo.x, material.albedo.y, material.albedo.z, material.albedo.w])
		# Emission (4 floats)
		material_data.append_array([material.emission.x, material.emission.y, material.emission.z, material.emission.w])
		# Properties (4 floats)
		material_data.append_array([material.roughness, material.metallic, material.ior, material.transmission])
		# Padding to align to 16 bytes (4 floats)
		material_data.append_array([0.0, 0.0, 0.0, 0.0])
	
	var material_data_bytes = material_data.to_byte_array()
	material_buffer = rd.storage_buffer_create(material_data_bytes.size())
	rd.buffer_update(material_buffer, 0, true, material_data_bytes)

func create_triangle_buffer():
	if triangles.is_empty():
		# Create a default triangle
		triangles.append({
			"v0": Vector3(0, 0, 0), "v1": Vector3(1, 0, 0), "v2": Vector3(0, 1, 0),
			"n0": Vector3(0, 0, 1), "n1": Vector3(0, 0, 1), "n2": Vector3(0, 0, 1),
			"uv0": Vector2(0, 0), "uv1": Vector2(1, 0), "uv2": Vector2(0, 1),
			"material_id": 0
		})
	
	var triangle_data = PackedFloat32Array()
	
	for triangle in triangles:
		# Vertices (9 floats)
		triangle_data.append_array([triangle.v0.x, triangle.v0.y, triangle.v0.z])
		triangle_data.append_array([triangle.v1.x, triangle.v1.y, triangle.v1.z])
		triangle_data.append_array([triangle.v2.x, triangle.v2.y, triangle.v2.z])
		
		# Normals (9 floats)
		triangle_data.append_array([triangle.n0.x, triangle.n0.y, triangle.n0.z])
		triangle_data.append_array([triangle.n1.x, triangle.n1.y, triangle.n1.z])
		triangle_data.append_array([triangle.n2.x, triangle.n2.y, triangle.n2.z])
		
		# UVs (6 floats)
		triangle_data.append_array([triangle.uv0.x, triangle.uv0.y])
		triangle_data.append_array([triangle.uv1.x, triangle.uv1.y])
		triangle_data.append_array([triangle.uv2.x, triangle.uv2.y])
		
		# Material ID (1 float) + padding (1 float)
		triangle_data.append_array([float(triangle.material_id), 0.0])
	
	var triangle_data_bytes = triangle_data.to_byte_array()
	triangle_buffer = rd.storage_buffer_create(triangle_data_bytes.size())
	rd.buffer_update(triangle_buffer, 0, true, triangle_data_bytes)

func create_bvh_buffer():
	if bvh_nodes.is_empty():
		# Create default BVH node
		bvh_nodes.append({
			"min_bounds": Vector3(-10, -10, -10),
			"max_bounds": Vector3(10, 10, 10),
			"left_child": 0,
			"right_child": 0,
			"triangle_count": triangles.size(),
			"first_triangle": 0
		})
	
	var bvh_data = PackedFloat32Array()
	
	for node in bvh_nodes:
		# Min bounds (3 floats) + left child (1 uint as float)
		bvh_data.append_array([node.min_bounds.x, node.min_bounds.y, node.min_bounds.z, float(node.left_child)])
		# Max bounds (3 floats) + right child (1 uint as float)
		bvh_data.append_array([node.max_bounds.x, node.max_bounds.y, node.max_bounds.z, float(node.right_child)])
		# Triangle count (1 uint as float) + first triangle (1 uint as float) + padding (2 floats)
		bvh_data.append_array([float(node.triangle_count), float(node.first_triangle), 0.0, 0.0])
	
	var bvh_data_bytes = bvh_data.to_byte_array()
	bvh_buffer = rd.storage_buffer_create(bvh_data_bytes.size())
	rd.buffer_update(bvh_buffer, 0, true, bvh_data_bytes)

# Also fix the setup_compute_shader function to use the correct shader loading method
func setup_compute_shader():
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		print("Failed to create rendering device")
		return
	
	# Load compute shader using FileAccess (since load() won't work for .glsl files)
	var shader_file = FileAccess.open("res://Materials/rtx.glsl", FileAccess.READ)
	if not shader_file:
		print("Failed to open rtx.glsl")
		return
	
	var shader_source = shader_file.get_as_text()
	shader_file.close()
	
	# Create shader source
	var shader_source_rd = RDShaderSource.new()
	shader_source_rd.source_compute = shader_source
	shader_source_rd.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	
	# Compile shader
	var shader_spirv = rd.shader_compile_spirv_from_source(shader_source_rd)
	if shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE) != "":
		print("Shader compilation error: ", shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE))
		return
	
	compute_shader = rd.shader_create_from_spirv(shader_spirv)
	if not compute_shader.is_valid():
		print("Failed to create compute shader")
		return
	
	print("RTX compute shader loaded successfully")


var geometry_dirty: bool = false

func mark_geometry_dirty():
	geometry_dirty = true

func _process(_delta):
	if not enable_rtx or not rd or not compute_shader.is_valid():
		return
	
	# Rebuild geometry if it's dirty
	if geometry_dirty:
		print("Rebuilding RTX geometry...")
		build_scene_geometry()
		setup_buffers() # Recreate buffers with new data
		geometry_dirty = false
	
	# Update camera buffer
	create_camera_buffer()
	create_scene_buffer()
	
	# Dispatch compute shader
	var viewport_size = get_viewport().get_visible_rect().size
	var rtx_size = Vector2i(
		int(viewport_size.x * rtx_resolution_scale),
		int(viewport_size.y * rtx_resolution_scale)
	)
	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, compute_shader)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	var group_size = Vector3i(
		(rtx_size.x + 7) / 8,
		(rtx_size.y + 7) / 8,
		1
	)
	
	rd.compute_list_dispatch(compute_list, group_size.x, group_size.y, group_size.z)
	rd.compute_list_end()
	rd.submit()
	rd.wait()

func _exit_tree():
	if rd:
		rd.free()
