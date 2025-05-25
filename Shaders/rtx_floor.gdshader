shader_type spatial;

uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.5;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.1;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.4;
uniform sampler2D albedo_texture : source_color;
uniform sampler2D normal_texture : hint_normal;

void fragment() {
    vec4 albedo = texture(albedo_texture, UV);
    vec3 normal_map = texture(normal_texture, UV).rgb;
    
    normal_map = normal_map * 2.0 - 1.0;
    normal_map.xy *= normal_strength;
    
    ALBEDO = albedo.rgb;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    NORMAL_MAP = normal_map;
    EMISSION = albedo.rgb * emission_strength;
    CLEARCOAT = clearcoat;
    CLEARCOAT_ROUGHNESS = clearcoat_roughness;
}