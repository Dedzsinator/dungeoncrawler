shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D roughness_texture : hint_roughness_r;
uniform sampler2D metallic_texture : hint_metallic_r;
uniform sampler2D emission_texture : hint_emission;

uniform float roughness_factor : hint_range(0.0, 1.0) = 0.5;
uniform float metallic_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_strength : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    vec2 uv = UV;
    
    // Base color
    vec4 albedo_tex = texture(albedo_texture, uv);
    ALBEDO = albedo_tex.rgb;
    
    // Normal mapping
    NORMAL_MAP = texture(normal_texture, uv).rgb;
    
    // PBR properties
    ROUGHNESS = texture(roughness_texture, uv).r * roughness_factor;
    METALLIC = texture(metallic_texture, uv).r * metallic_factor;
    
    // Emission for glow effects
    vec3 emission = texture(emission_texture, uv).rgb * emission_color * emission_strength;
    EMISSION = emission;
}