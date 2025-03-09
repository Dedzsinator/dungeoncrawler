shader_type sky;

// Sky colors - Using brighter default values to check visibility
uniform vec3 sky_top_color : source_color = vec3(0.1, 0.1, 0.3);
uniform vec3 sky_horizon_color : source_color = vec3(0.4, 0.2, 0.6);
uniform vec3 ground_bottom_color : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 ground_horizon_color : source_color = vec3(0.3, 0.2, 0.4);

// Sun settings
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_size : hint_range(0.01, 0.5) = 0.2;
uniform float sun_blur : hint_range(0.0, 10.0) = 2.0;

// Stars settings
uniform bool enable_stars = true;
uniform float stars_speed : hint_range(0.0, 2.0) = 0.2;
uniform float stars_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float stars_density : hint_range(0.1, 10.0) = 3.0;

// Clouds settings
uniform bool enable_clouds = true;
uniform float clouds_speed : hint_range(0.0, 2.0) = 0.1;
uniform float clouds_coverage : hint_range(0.0, 1.0) = 0.3;
uniform float clouds_softness : hint_range(0.0, 1.0) = 0.5;

// Atmosphere settings
uniform float atmosphere_thickness : hint_range(0.0, 1.0) = 0.8;
uniform float atmosphere_intensity : hint_range(0.0, 2.0) = 1.2;

// Time-based animation
uniform float time_scale : hint_range(0.0, 2.0) = 1.0;

// Hash function for noise generation
float hash(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

// Noise function for stars
float star_noise(vec3 p, float time) {
    vec3 pos = floor(p);
    vec3 fr = fract(p);
    
    float n = hash(pos);
    
    // Make stars twinkle
    float brightness = n * 0.8 + 0.2; // Base brightness
    brightness *= 0.5 + 0.5 * sin(time * 3.0 * brightness); // Twinkle effect
    
    // Stars shape
    float d = length(fr - 0.5);
    float star = smoothstep(0.25 * brightness, 0.0, d);
    
    // Only show brightest stars based on density
    return star * step(1.0 - stars_density * 0.1, n) * brightness;
}

// Cloud noise function - Simplified for performance
float cloud_noise(vec3 p, float time) {
    vec3 pos = floor(p);
    vec3 fr = fract(p);
    
    float n = hash(pos);
    float n2 = hash(pos + vec3(1.0, 0.0, 0.0));
    float n3 = hash(pos + vec3(0.0, 1.0, 0.0));
    float n4 = hash(pos + vec3(1.0, 1.0, 0.0));
    
    // Smooth interpolation
    fr = fr * fr * (3.0 - 2.0 * fr);
    
    float nx = mix(n, n2, fr.x);
    float ny = mix(n3, n4, fr.x);
    float nxy = mix(nx, ny, fr.y);
    
    // Animate clouds
    nxy += 0.1 * sin(time * clouds_speed + p.x * 0.5 + p.y * 0.3);
    
    // Make clouds shape
    return smoothstep(clouds_coverage, clouds_coverage + clouds_softness, nxy);
}

void sky() {
    // Get direction
    vec3 dir = EYEDIR;
    
    // Time for animations
    float time = TIME * time_scale;
    
    // Calculate horizon gradient based on Y direction
    float horizon = clamp(dir.y / atmosphere_thickness, -1.0, 1.0) * 0.5 + 0.5;
    
    // Set sky color based on horizon
    vec3 sky_color = mix(sky_horizon_color, sky_top_color, pow(horizon, 0.3));
    vec3 ground_color = mix(ground_horizon_color, ground_bottom_color, pow(1.0 - horizon, 0.3));
    
    // Combine sky and ground
    vec3 final_color = mix(ground_color, sky_color, step(0.0, dir.y));
    
    // Add basic color to make sure we see something
    final_color += vec3(0.05);
    
    // Sun
    float sun_dot = max(dot(normalize(dir), normalize(vec3(0.0, 0.1, 1.0))), 0.0);
    float sun_factor = pow(sun_dot, 1.0 / sun_size) * sun_blur;
    vec3 sun = sun_color * clamp(sun_factor, 0.0, 1.0);
    
    // Add sun to sky
    final_color = mix(final_color, sun_color, clamp(sun_factor, 0.0, 0.95));
    
    // Stars (only visible in dark areas)
    if (enable_stars && dir.y > 0.0) {
        // Scale and rotate stars slowly
        vec3 star_dir = normalize(dir);
        star_dir.xz *= mat2(cos(time * 0.01), -sin(time * 0.01), 
                            sin(time * 0.01), cos(time * 0.01));
        
        // Calculate stars
        float stars = star_noise(star_dir * 50.0, time * stars_speed);
        stars *= smoothstep(0.5, 0.0, sun_factor); // Hide stars near sun
        stars *= pow(horizon, 0.5); // More stars higher in sky
        
        // Add stars to sky
        final_color += stars * stars_intensity * vec3(0.9, 0.95, 1.0);
    }
    
    // Clouds (only in sky)
    if (enable_clouds && dir.y > 0.0) {
        // Project direction onto a dome
        vec3 cloud_dir = normalize(dir);
        cloud_dir.y = max(cloud_dir.y, 0.01); // Keep clouds above horizon
        
        // Scale and time animation
        cloud_dir.xz *= 2.0;
        cloud_dir.xz += time * clouds_speed * vec2(0.1, 0.2);
        
        // Calculate cloud density
        float clouds = 0.0;
        clouds += cloud_noise(cloud_dir * 5.0, time) * 0.5;
        clouds += cloud_noise(cloud_dir * 10.0, time) * 0.25;
        
        clouds = smoothstep(0.1, 0.6, clouds);
        
        // Modulate clouds by height
        clouds *= smoothstep(-0.1, 0.4, dir.y);
        
        // Add clouds to sky (brighter for visibility)
        vec3 cloud_color = mix(sky_horizon_color, vec3(1.0), 0.5);
        final_color = mix(final_color, cloud_color, clouds * 0.7);
    }
    
    // Apply atmosphere intensity
    final_color *= atmosphere_intensity;
    
    // Ensure minimum brightness
    final_color = max(final_color, vec3(0.02, 0.02, 0.04));
    
    // Output final color
    COLOR = final_color;
}