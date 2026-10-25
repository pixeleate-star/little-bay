shader_type sky;















uniform vec3 zenith_color : source_color = vec3(0.18, 0.35, 0.62);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.74, 0.86);
uniform vec3 ground_color : source_color = vec3(0.30, 0.32, 0.34);

uniform float horizon_falloff : hint_range(1.0, 16.0) = 4.0;




uniform vec3 sun_direction = vec3(0.0, -0.6, -0.8);
uniform vec3 sun_color : source_color = vec3(8.0, 7.2, 5.6);

uniform float sun_size : hint_range(0.002, 0.2) = 0.03;
uniform float sun_glow_size : hint_range(0.02, 1.0) = 0.25;

uniform float sun_energy : hint_range(0.0, 20.0) = 1.0;


uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);

uniform vec3 cloud_shadow_color : source_color = vec3(0.55, 0.6, 0.68);

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;

uniform float cloud_softness : hint_range(0.01, 0.6) = 0.25;

uniform float cloud_scale : hint_range(0.2, 8.0) = 2.0;

uniform vec2 cloud_wind = vec2(0.01, 0.006);

uniform float cloud_opacity : hint_range(0.0, 1.0) = 1.0;



float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i + vec2(0.0, 0.0));
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}


float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p * freq) * amp;
		freq *= 2.13;
		amp *= 0.5;
	}
	return total;
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	
	
	float up = dir.y;
	float t = pow(clamp(up, 0.0, 1.0), 1.0 / horizon_falloff);
	vec3 sky_col = mix(horizon_color, zenith_color, t);
	
	float below = clamp(-up * 4.0, 0.0, 1.0);
	sky_col = mix(sky_col, ground_color, below);

	
	
	float sun_cos = dot(dir, normalize(-sun_direction));
	float sun_ang = acos(clamp(sun_cos, -1.0, 1.0));
	
	float disk = 1.0 - smoothstep(sun_size, sun_size + 0.01, sun_ang);
	
	float glow = pow(max(sun_cos, 0.0), 1.0 / max(sun_glow_size, 0.001) * 8.0);
	vec3 sun = sun_color * sun_energy * (disk + glow * 0.6);
	sky_col += sun;

	
	
	
	
	float cloud_amount = 0.0;
	if (up > 0.02) {
		vec2 plane = dir.xz / max(dir.y, 0.08) * cloud_scale;
		plane += cloud_wind * TIME;
		float density = fbm(plane);
		
		float threshold = mix(0.75, 0.25, cloud_coverage);
		cloud_amount = smoothstep(threshold, threshold + cloud_softness, density);
		
		cloud_amount *= smoothstep(0.02, 0.25, up);
		cloud_amount *= cloud_opacity;

		
		
		float shade = fbm(plane * 1.7 + 4.0);
		vec3 cloud = mix(cloud_shadow_color, cloud_color, clamp(shade + 0.2, 0.0, 1.0));
		
		cloud += sun_color * sun_energy * glow * 0.15 * cloud_amount;

		sky_col = mix(sky_col, cloud, cloud_amount);
	}

	COLOR = sky_col;
}
