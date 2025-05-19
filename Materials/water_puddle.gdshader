shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.2, 0.3, 0.4, 0.8);
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;
uniform float reflectance : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D noise_texture;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.1;
uniform float wave_intensity : hint_range(0.0, 0.2) = 0.03;

uniform bool enable_shadows = true;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.8;

void fragment() {
    vec2 uv = UV;
    
    // Create wave effect with time
    float time = TIME * wave_speed;
    uv += texture(noise_texture, uv * 0.5 + time * 0.1).rg * wave_intensity;
    
    // Base water color with transparency
    ALBEDO = albedo.rgb;
    ALPHA = albedo.a;
    
    // Material properties
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = reflectance;
    
    // Set up SSR (Screen Space Reflections)
    SSS_STRENGTH = 0.0;
    
    // Enhanced reflection
    if (ROUGHNESS < 0.2) {
        SSS_TRANSMITTANCE_DEPTH = 0.5;
    }
}