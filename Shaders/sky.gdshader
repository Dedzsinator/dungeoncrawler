shader_type sky;

uniform vec3 sky_color_top : source_color = vec3(0.4, 0.6, 1.0);
uniform vec3 sky_color_bottom : source_color = vec3(0.8, 0.9, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float cloud_density : hint_range(0.0, 1.0) = 0.3;
uniform float sun_size : hint_range(0.01, 0.5) = 0.05;
uniform float time_of_day : hint_range(0.0, 1.0) = 0.5;

vec3 get_sky_color(vec3 dir) {
    float elevation = dir.y;
    
    // Time-based sky colors
    vec3 day_top = sky_color_top;
    vec3 day_bottom = sky_color_bottom;
    vec3 night_top = vec3(0.1, 0.1, 0.3);
    vec3 night_bottom = vec3(0.2, 0.2, 0.4);
    
    // Interpolate between day and night
    vec3 current_top = mix(night_top, day_top, time_of_day);
    vec3 current_bottom = mix(night_bottom, day_bottom, time_of_day);
    
    // Basic gradient from horizon to zenith
    vec3 sky_gradient = mix(current_bottom, current_top, clamp(elevation, 0.0, 1.0));
    
    // Sun effect
    vec3 sun_dir = normalize(vec3(0.3, 0.6, 0.3));
    float sun_distance = distance(dir, sun_dir);
    float sun_mask = 1.0 - smoothstep(0.0, sun_size, sun_distance);
    
    // Add sun to sky (only during day)
    sky_gradient = mix(sky_gradient, sun_color, sun_mask * time_of_day);
    
    // Simple clouds using noise approximation
    float cloud_noise = sin(dir.x * 10.0) * cos(dir.z * 10.0) * sin(dir.y * 5.0);
    cloud_noise = smoothstep(-cloud_density, cloud_density, cloud_noise);
    
    // Mix clouds with sky
    vec3 cloud_color = vec3(0.9, 0.9, 0.95);
    sky_gradient = mix(sky_gradient, cloud_color, cloud_noise * 0.3 * time_of_day);
    
    return sky_gradient;
}

void sky() {
    COLOR = get_sky_color(EYEDIR);
}