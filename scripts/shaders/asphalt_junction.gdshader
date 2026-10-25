shader_type spatial;
























render_mode cull_back, diffuse_burley, specular_schlick_ggx;


uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);



global uniform float wetness;

uniform float grain_scale : hint_range(0.005, 0.1) = 0.02;
uniform float patch_scale : hint_range(1.0, 40.0) = 8.0;
uniform float albedo_variation : hint_range(0.0, 1.0) = 0.025;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.92;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.04;
uniform float bump_strength : hint_range(0.0, 2.0) = 0.12;

varying vec3 world_pos;



float hash(vec2 p) {
	uvec2 cell = uvec2(ivec2(p));
	uint h = cell.x * 1597334677u ^ cell.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h ^= h >> 16u;
	return float(h >> 8u) / 16777216.0;
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

float fbm(vec2 p, float footprint) {
	const mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		
		float visibility = 1.0 - smoothstep(0.25, 1.0, footprint);
		float sample_value = 0.5;
		if (visibility > 0.0) {
			sample_value = mix(0.5, value_noise(p), visibility);
		}
		sum += amp * sample_value;
		p = rot * p * 2.0 + 17.3;
		footprint *= 2.0;
		amp *= 0.5;
	}
	return sum / 0.9375;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	
	vec2 grain_uv = world_pos.xz / grain_scale;
	vec2 patch_uv = world_pos.xz / patch_scale;

	float footprint = max(length(dFdx(grain_uv)), length(dFdy(grain_uv)));
	float grain = fbm(grain_uv, footprint);
	float patch = value_noise(patch_uv);

	float lum = (grain - 0.5) * albedo_variation + (patch - 0.5) * albedo_variation * 0.25;
	vec3 col = clamp(base_color.rgb + vec3(lum), vec3(0.0), vec3(1.0));
	ALBEDO = col;

	float rough = clamp(roughness_base - (patch - 0.5) * roughness_variation * 2.0, 0.0, 1.0);
	float spec = 0.4;

	float wet = clamp(wetness, 0.0, 1.0);
	if (wet > 0.001) {
		float puddle = wet * (0.6 + 0.4 * (1.0 - patch));
		ALBEDO = mix(col * (1.0 - 0.45 * wet), vec3(0.055, 0.075, 0.095), 0.22 * wet);
		rough = mix(rough, 0.055, puddle);
		spec = mix(spec, 0.98, wet);
	}

	ROUGHNESS = rough;
	METALLIC = 0.08 * wet;
	SPECULAR = spec;

	float bump = bump_strength * (1.0 - 0.85 * wet);
	float hx = fbm(grain_uv + vec2(0.5, 0.0), footprint)
		- fbm(grain_uv - vec2(0.5, 0.0), footprint);
	float hz = fbm(grain_uv + vec2(0.0, 0.5), footprint)
		- fbm(grain_uv - vec2(0.0, 0.5), footprint);
	vec3 n = normalize(vec3(-hx * bump, -hz * bump, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
