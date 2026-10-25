shader_type spatial;

// Clean, texture-free Jame Gam ground. Two palette greens form large, quiet
// colour blocks instead of noisy grass detail, keeping the scene readable and
// lightweight for a browser build.

render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.431, 0.631, 0.431, 1.0);
uniform vec4 patch_color : source_color = vec4(0.0, 0.608, 0.533, 1.0);

// Large patch scale (metres) and fine blade-grain scale (metres).
uniform float patch_scale : hint_range(2.0, 60.0) = 14.0;
uniform float grain_scale : hint_range(0.05, 2.0) = 0.4;

uniform float albedo_variation : hint_range(0.0, 0.8) = 0.16;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.95;
uniform float bump_strength : hint_range(0.0, 2.0) = 0.5;

// Global wetness 0..1, shared with the asphalt shader (set by WeatherController).
// Wet ground darkens and gains a damp sheen, but far less mirror-like than a
// road — grass and soil scatter, they don't pool into a reflective film.
global uniform float wetness;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i + vec2(0.0, 0.0));
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	const mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amp * value_noise(p);
		p = rot * p * 2.0 + 17.3;
		amp *= 0.5;
	}
	return sum / 0.9375;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Large alternating blocks create a simple stylised ground pattern while
	// using only the two supplied greens.
	float block_x = floor(world_pos.x / 24.0);
	float block_z = floor(world_pos.z / 24.0);
	float alternate = mod(block_x + block_z, 2.0);
	vec3 col = mix(base_color.rgb, patch_color.rgb, alternate * 0.42);
	float wet = clamp(wetness, 0.0, 1.0);
	col *= 1.0 - 0.16 * wet;
	ALBEDO = col;
	ROUGHNESS = 0.98;
	METALLIC = 0.0;
	SPECULAR = 0.12;
	NORMAL = normalize(world_normal);
}
