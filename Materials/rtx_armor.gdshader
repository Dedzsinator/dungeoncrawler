shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// RTX Enhanced parameters
uniform float metallic : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.8;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.02;
uniform vec4 armor_tint : source_color = vec4(0.8, 0.85, 0.9, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.5;
uniform vec4 rim_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform sampler2D armor_texture : source_color, hint_default_white;
uniform sampler2D normal_map : hint_normal;
uniform float normal_scale : hint_range(-2.0, 2.0) = 1.0;
uniform float reflection_intensity : hint_range(0.0, 2.0) = 1.0;

// Additional RTX enhancements
uniform float fresnel_power : hint_range(0.1, 5.0) = 2.0;
uniform float metallic_edge_enhancement : hint_range(0.0, 1.0) = 0.3;
uniform vec3 light_direction = vec3(0.0, 1.0, 0.5);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = VERTEX;
    world_normal = NORMAL;
}

void fragment() {
    vec4 tex = texture(armor_texture, UV);
    vec3 normal_tex = texture(normal_map, UV).rgb;
    
    // Enhanced metallic armor look
    ALBEDO = tex.rgb * armor_tint.rgb;
    METALLIC = metallic;
    ROUGHNESS = roughness * (1.0 - tex.a * 0.5); // Use alpha for roughness variation
    
    // Enhanced normal mapping
    NORMAL_MAP = normal_tex;
    NORMAL_MAP_DEPTH = normal_scale;
    
    // RTX clearcoat for realistic armor shine
    CLEARCOAT = clearcoat;
    CLEARCOAT_ROUGHNESS = clearcoat_roughness;
    
    // Enhanced rim lighting with fresnel effect
    float fresnel = dot(NORMAL, VIEW);
    fresnel = pow(1.0 - fresnel, fresnel_power);
    
    float rim = 1.0 - dot(NORMAL, VIEW);
    rim = pow(rim, 2.0);
    
    // Combine rim and fresnel for enhanced metallic look
    float enhanced_rim = mix(rim, fresnel, metallic);
    EMISSION = rim_color.rgb * enhanced_rim * rim_strength;
    
    // Enhanced reflectivity based on metallic value
    SPECULAR = reflection_intensity * (0.5 + metallic * 0.5);
    
    // Edge enhancement for metallic surfaces
    float edge_factor = 1.0 - abs(dot(NORMAL, VIEW));
    METALLIC += edge_factor * metallic_edge_enhancement * metallic;
    
    ALPHA = tex.a * armor_tint.a;
}