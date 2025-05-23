#version 450

// Local workgroup size
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Output texture
layout(set = 0, binding = 0, rgba16f) uniform restrict writeonly image2D output_image;

// Camera uniforms
layout(set = 0, binding = 1) uniform CameraData {
    mat4 view_matrix;
    mat4 projection_matrix;
    mat4 inv_view_matrix;
    mat4 inv_projection_matrix;
    vec3 camera_position;
    float camera_fov;
    vec2 screen_size;
    float near_plane;
    float far_plane;
} camera;

// Scene data
layout(set = 0, binding = 2) uniform SceneData {
    vec3 sun_direction;
    float sun_intensity;
    vec3 sun_color;
    float ambient_intensity;
    vec3 ambient_color;
    int max_bounces;
    int samples_per_pixel;
    float time;
} scene;

// Material data
struct Material {
    vec4 albedo;
    vec4 emission;
    float roughness;
    float metallic;
    float ior;
    float transmission;
};

layout(set = 0, binding = 3) readonly buffer MaterialBuffer {
    Material materials[];
};

// Geometry data
struct Triangle {
    vec3 v0, v1, v2;
    vec3 n0, n1, n2;
    vec2 uv0, uv1, uv2;
    uint material_id;
};

layout(set = 0, binding = 4) readonly buffer TriangleBuffer {
    Triangle triangles[];
};

// BVH node
struct BVHNode {
    vec3 min_bounds;
    uint left_child;
    vec3 max_bounds;
    uint right_child;
    uint triangle_count;
    uint first_triangle;
    vec2 padding;
};

layout(set = 0, binding = 5) readonly buffer BVHBuffer {
    BVHNode bvh_nodes[];
};

// Ray structure
struct Ray {
    vec3 origin;
    vec3 direction;
    float t_min;
    float t_max;
};

struct HitInfo {
    bool hit;
    float t;
    vec3 position;
    vec3 normal;
    vec2 uv;
    uint material_id;
};

// Random number generator
uint rng_state;

uint wang_hash(uint seed) {
    seed = (seed ^ 61u) ^ (seed >> 16u);
    seed *= 9u;
    seed = seed ^ (seed >> 4u);
    seed *= 0x27d4eb2du;
    seed = seed ^ (seed >> 15u);
    return seed;
}

float random() {
    rng_state = wang_hash(rng_state);
    return float(rng_state) / 4294967296.0;
}

vec3 random_hemisphere(vec3 normal) {
    float u1 = random();
    float u2 = random();
    
    float cos_theta = sqrt(u1);
    float sin_theta = sqrt(1.0 - u1);
    float phi = 2.0 * 3.14159265 * u2;
    
    vec3 direction = vec3(
        sin_theta * cos(phi),
        sin_theta * sin(phi),
        cos_theta
    );
    
    // Orient to hemisphere around normal
    vec3 nt = (abs(normal.x) > 0.1) ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(nt, normal));
    vec3 bitangent = cross(normal, tangent);
    
    return direction.x * tangent + direction.y * bitangent + direction.z * normal;
}

// Ray-triangle intersection
bool intersect_triangle(Ray ray, Triangle tri, out float t, out vec2 uv) {
    vec3 edge1 = tri.v1 - tri.v0;
    vec3 edge2 = tri.v2 - tri.v0;
    vec3 h = cross(ray.direction, edge2);
    float a = dot(edge1, h);
    
    if (a > -0.00001 && a < 0.00001) return false;
    
    float f = 1.0 / a;
    vec3 s = ray.origin - tri.v0;
    float u = f * dot(s, h);
    
    if (u < 0.0 || u > 1.0) return false;
    
    vec3 q = cross(s, edge1);
    float v = f * dot(ray.direction, q);
    
    if (v < 0.0 || u + v > 1.0) return false;
    
    t = f * dot(edge2, q);
    
    if (t > ray.t_min && t < ray.t_max) {
        uv = vec2(u, v);
        return true;
    }
    
    return false;
}

// Ray-AABB intersection
bool intersect_aabb(Ray ray, vec3 min_bounds, vec3 max_bounds) {
    vec3 inv_dir = 1.0 / ray.direction;
    vec3 t0 = (min_bounds - ray.origin) * inv_dir;
    vec3 t1 = (max_bounds - ray.origin) * inv_dir;
    
    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);
    
    float t_near = max(max(tmin.x, tmin.y), tmin.z);
    float t_far = min(min(tmax.x, tmax.y), tmax.z);
    
    return t_near <= t_far && t_far > ray.t_min && t_near < ray.t_max;
}

// BVH traversal
HitInfo trace_ray(Ray ray) {
    HitInfo hit_info;
    hit_info.hit = false;
    hit_info.t = ray.t_max;
    
    uint stack[64];
    int stack_ptr = 0;
    stack[0] = 0; // Root node
    
    while (stack_ptr >= 0) {
        uint node_index = stack[stack_ptr--];
        BVHNode node = bvh_nodes[node_index];
        
        if (!intersect_aabb(ray, node.min_bounds, node.max_bounds)) {
            continue;
        }
        
        if (node.triangle_count > 0) {
            // Leaf node - test triangles
            for (uint i = 0; i < node.triangle_count; i++) {
                Triangle tri = triangles[node.first_triangle + i];
                float t;
                vec2 uv;
                
                if (intersect_triangle(ray, tri, t, uv) && t < hit_info.t) {
                    hit_info.hit = true;
                    hit_info.t = t;
                    hit_info.position = ray.origin + ray.direction * t;
                    hit_info.uv = uv;
                    hit_info.material_id = tri.material_id;
                    
                    // Interpolate normal
                    float w = 1.0 - uv.x - uv.y;
                    hit_info.normal = normalize(w * tri.n0 + uv.x * tri.n1 + uv.y * tri.n2);
                    
                    ray.t_max = t; // Optimize subsequent tests
                }
            }
        } else {
            // Internal node - add children to stack
            if (node.right_child != 0) stack[++stack_ptr] = node.right_child;
            if (node.left_child != 0) stack[++stack_ptr] = node.left_child;
        }
    }
    
    return hit_info;
}

// Path tracing
vec3 trace_path(Ray primary_ray) {
    vec3 color = vec3(0.0);
    vec3 throughput = vec3(1.0);
    Ray ray = primary_ray;
    
    for (int bounce = 0; bounce < scene.max_bounces; bounce++) {
        HitInfo hit = trace_ray(ray);
        
        if (!hit.hit) {
            // Sky color
            color += throughput * scene.ambient_color * scene.ambient_intensity;
            break;
        }
        
        Material mat = materials[hit.material_id];
        
        // Add emission
        color += throughput * mat.emission.rgb * mat.emission.a;
        
        // Russian roulette
        float max_component = max(throughput.x, max(throughput.y, throughput.z));
        if (bounce > 3 && random() > max_component) break;
        if (bounce > 3) throughput /= max_component;
        
        // Sample new direction
        vec3 new_direction = random_hemisphere(hit.normal);
        
        // Update throughput
        float cos_theta = dot(new_direction, hit.normal);
        throughput *= mat.albedo.rgb * cos_theta * 2.0; // 2.0 for hemisphere sampling
        
        // Create new ray
        ray.origin = hit.position + hit.normal * 0.001;
        ray.direction = new_direction;
        ray.t_min = 0.001;
        ray.t_max = 1000.0;
    }
    
    return color;
}

void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    vec2 screen_size = camera.screen_size;
    
    if (pixel_coord.x >= int(screen_size.x) || pixel_coord.y >= int(screen_size.y)) {
        return;
    }
    
    // Initialize RNG
    rng_state = wang_hash(uint(pixel_coord.x + pixel_coord.y * int(screen_size.x) + int(scene.time * 1000.0)));
    
    vec3 final_color = vec3(0.0);
    
    // Multi-sampling
    for (int sample = 0; sample < scene.samples_per_pixel; sample++) {
        // Jittered pixel coordinates
        vec2 jitter = vec2(random(), random()) - 0.5;
        vec2 uv = (vec2(pixel_coord) + jitter) / screen_size;
        uv = uv * 2.0 - 1.0; // Convert to NDC
        
        // Create ray
        vec4 clip_pos = vec4(uv, 1.0, 1.0);
        vec4 view_pos = camera.inv_projection_matrix * clip_pos;
        view_pos /= view_pos.w;
        
        vec3 world_pos = (camera.inv_view_matrix * view_pos).xyz;
        vec3 ray_direction = normalize(world_pos - camera.camera_position);
        
        Ray ray;
        ray.origin = camera.camera_position;
        ray.direction = ray_direction;
        ray.t_min = camera.near_plane;
        ray.t_max = camera.far_plane;
        
        final_color += trace_path(ray);
    }
    
    final_color /= float(scene.samples_per_pixel);
    
    // Tone mapping and gamma correction
    final_color = final_color / (final_color + vec3(1.0)); // Reinhard
    final_color = pow(final_color, vec3(1.0 / 2.2)); // Gamma correction
    
    imageStore(output_image, pixel_coord, vec4(final_color, 1.0));
}