shader_type canvas_item;

varying vec3 world_position;
varying vec3 world_normal;

uniform sampler2D albedo_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D metallic_texture : hint_default_white;
uniform sampler2D roughness_texture : hint_default_white;

uniform vec3 albedo_color : source_color = vec3(0.8, 0.8, 0.9);
uniform float metallic_value : hint_range(0.0, 1.0) = 0.9;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.1;
uniform float normal_scale : hint_range(-2.0, 2.0) = 1.0;

uniform vec3 light_position = vec3(0.0, 10.0, 10.0);
uniform vec3 light_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float light_intensity = 3.0;

vec3 get_normal_from_map(vec2 uv, vec3 normal, vec3 tangent, vec3 binormal) {
    vec3 normal_map = texture(normal_texture, uv).rgb * 2.0 - 1.0;
    normal_map.xy *= normal_scale;

    mat3 tbn = mat3(tangent, binormal, normal);
    return normalize(tbn * normal_map);
}

float distribution_ggx(vec3 N, vec3 H, float roughness_param) {
    float a = roughness_param * roughness_param;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return num / max(denom, 0.0001);
}

float geometry_schlick_ggx(float NdotV, float roughness_param) {
    float r = (roughness_param + 1.0);
    float k = (r * r) / 8.0;

    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

float geometry_smith(vec3 N, vec3 V, vec3 L, float roughness_param) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = geometry_schlick_ggx(NdotV, roughness_param);
    float ggx1 = geometry_schlick_ggx(NdotL, roughness_param);

    return ggx1 * ggx2;
}

vec3 fresnel_schlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

void fragment() {
    vec2 uv = UV;

    // Sample textures
    vec3 albedo_sample = texture(albedo_texture, uv).rgb * albedo_color;
    float metallic_sample = texture(metallic_texture, uv).r * metallic_value;
    float roughness_sample = texture(roughness_texture, uv).r * roughness_value;

    // Calculate normals (simplified for 2D)
    vec3 N = vec3(0.0, 0.0, 1.0);
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 binormal = vec3(0.0, 1.0, 0.0);
    N = get_normal_from_map(uv, N, tangent, binormal);

    // View direction (camera looking down -Z)
    vec3 V = vec3(0.0, 0.0, 1.0);

    // Calculate F0 (surface reflection at zero incidence)
    vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo_sample, metallic_sample);

    // Light direction
    vec3 world_pos = vec3(SCREEN_UV * 2.0 - 1.0, 0.0);
    vec3 L = normalize(light_position - world_pos);
    vec3 H = normalize(V + L);

    // Calculate distance and attenuation
    float distance = length(light_position - world_pos);
    float attenuation = light_intensity / (1.0 + distance * distance * 0.1);
    vec3 radiance = light_color * attenuation;

    // BRDF calculations
    float NDF = distribution_ggx(N, H, roughness_sample);
    float G = geometry_smith(N, V, L, roughness_sample);
    vec3 F = fresnel_schlick(max(dot(H, V), 0.0), F0);

    // Energy conservation
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - metallic_sample;

    // Cook-Torrance BRDF
    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;

    // Add to outgoing radiance Lo
    float NdotL = max(dot(N, L), 0.0);
    vec3 Lo = (kD * albedo_sample / PI + specular) * radiance * NdotL;

    // Enhanced ambient for metallics
    vec3 ambient = vec3(0.1) * albedo_sample * (1.0 + metallic_sample * 0.5);

    vec3 color = ambient + Lo;

    // Enhanced metallic brightness
    color *= 1.0 + metallic_sample * 0.3;

    // HDR tonemapping and gamma correction
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0/2.2));

    COLOR = vec4(color, 1.0);
}