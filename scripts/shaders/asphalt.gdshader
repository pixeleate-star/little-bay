shader_type spatial;






















render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_never;


uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);






global uniform float wetness;


uniform float grain_scale : hint_range(0.005, 0.1) = 0.02;

uniform float patch_scale : hint_range(1.0, 40.0) = 8.0;




uniform float albedo_variation : hint_range(0.0, 1.0) = 0.025;

uniform float roughness_base : hint_range(0.0, 1.0) = 0.92;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.04;


uniform float bump_strength : hint_range(0.0, 2.0) = 0.12;








uniform float markings_enabled : hint_range(0.0, 1.0) = 0.0;

uniform float road_width : hint_range(0.5, 60.0) = 5.0;

uniform float lane_count : hint_range(1.0, 16.0) = 2.0;
uniform float forward_lanes : hint_range(0.0, 16.0) = 1.0;

uniform float one_way : hint_range(0.0, 1.0) = 0.0;

uniform vec3 marking_color : source_color = vec3(0.85, 0.82, 0.62);
uniform float line_width : hint_range(0.02, 0.6) = 0.12;
uniform float dash_length : hint_range(0.2, 8.0) = 3.0;
uniform float dash_gap : hint_range(0.2, 8.0) = 5.0;


uniform float end_fade : hint_range(0.0, 8.0) = 1.5;

uniform float road_length : hint_range(0.0, 100000.0) = 0.0;








const int MAX_TRANSVERSE_MARKINGS = 8;

uniform int transverse_count = 0;

uniform float transverse_along[MAX_TRANSVERSE_MARKINGS];


uniform float transverse_kind[MAX_TRANSVERSE_MARKINGS];



uniform float transverse_facing[MAX_TRANSVERSE_MARKINGS];


varying vec3 world_pos;



float line_coverage(float pos_m, float center, float half_w, float aa) {
	float d = abs(pos_m - center);
	return 1.0 - smoothstep(half_w - aa, half_w + aa, d);
}





const float TOOTH_BASE = 0.5;    
const float TOOTH_HEIGHT = 0.5;  
const float TOOTH_PERIOD = 1.0;  








float shark_teeth_coverage(
		float centre, float facing, float along, float across,
		float span, float along_aa, float across_aa) {
	
	
	float u = ((along - centre) * facing + TOOTH_HEIGHT * 0.5) / TOOTH_HEIGHT;
	if (u < -along_aa || u > 1.0 + along_aa) {
		return 0.0;
	}
	
	float half_w_here = TOOTH_BASE * 0.5 * clamp(u, 0.0, 1.0);
	
	float phase = fract((across + span) / TOOTH_PERIOD) * TOOTH_PERIOD;
	float offset = abs(phase - TOOTH_PERIOD * 0.5);
	
	
	
	float aa = across_aa + along_aa * (TOOTH_BASE / TOOTH_HEIGHT) * 0.5;
	float tooth = 1.0 - smoothstep(half_w_here - aa, half_w_here + aa, offset);
	
	float ends = (1.0 - smoothstep(1.0 - along_aa, 1.0 + along_aa, u))
		* smoothstep(-along_aa, along_aa, u);
	return tooth * ends;
}










float transverse_coverage(
		float kind, float centre, float facing, float along, float across,
		float half_w, float along_aa, float across_aa) {
	float da = abs(along - centre);          
	
	float span = max(half_w - 0.15, 0.05);
	float edge = 1.0 - smoothstep(span - across_aa, span + across_aa, abs(across));
	if (edge <= 0.0) {
		return 0.0;
	}

	if (kind < 1.5) {
		
		
		float band_half = 1.5;               
		if (da > band_half + along_aa) {
			return 0.0;
		}
		float band = 1.0 - smoothstep(band_half - along_aa, band_half + along_aa, da);
		
		float stripe_period = 1.0;
		float stripe_phase = fract((across + span) / stripe_period);
		float stripe = step(stripe_phase, 0.5);
		return band * edge * stripe;
	} else if (kind < 2.5) {
		
		float bar_half = 0.2;
		float bar = 1.0 - smoothstep(bar_half - along_aa, bar_half + along_aa, da);
		return bar * edge;
	} else if (kind < 3.5) {
		
		float bar_half = 0.15;
		float bar = 1.0 - smoothstep(bar_half - along_aa, bar_half + along_aa, da);
		float dash_period = 0.9;
		float dash_phase = fract((across + span) / dash_period);
		float dash = step(dash_phase, 0.55);
		return bar * edge * dash;
	} else {
		
		
		
		
		return shark_teeth_coverage(
			centre, facing, along, across, span, along_aa, across_aa) * edge;
	}
}










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
		METALLIC = 0.08 * wet;
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

	
	if (markings_enabled > 0.5 && road_width > 0.01) {
		
		float half_w = road_width * 0.5;
		float across = (UV.y - 0.5) * road_width;   
		float along = UV.x;                          

		
		float aa = fwidth(across) * 0.75 + 0.0005;
		float half_line = line_width * 0.5;

		float paint = 0.0;   

		
		
		float edge_inset = min(half_line + 0.10, half_w);
		paint = max(paint, line_coverage(across, -(half_w - edge_inset), half_line, aa));
		paint = max(paint, line_coverage(across,  (half_w - edge_inset), half_line, aa));

		
		float period = max(dash_length + dash_gap, 0.001);
		float dash_phase = fract(along / period) * period;
		float dash_aa = fwidth(along) + 0.01;
		float dash_on = 1.0 - smoothstep(dash_length - dash_aa, dash_length + dash_aa, dash_phase);

		
		
		float lane_w = road_width / max(lane_count, 1.0);
		int lanes_i = int(lane_count + 0.5);
		int fwd_i = int(forward_lanes + 0.5);
		bool two_way = one_way < 0.5 && fwd_i > 0 && fwd_i < lanes_i;

		for (int i = 1; i < lanes_i; i++) {
			float center = -half_w + float(i) * lane_w;
			float cov = line_coverage(across, center, half_line, aa);
			if (cov <= 0.0) {
				continue;
			}
			if (two_way && i == fwd_i) {
				
				
				float dbl = max(
					line_coverage(across, center - half_line * 1.6, half_line * 0.7, aa),
					line_coverage(across, center + half_line * 1.6, half_line * 0.7, aa));
				paint = max(paint, dbl);
			} else {
				
				paint = max(paint, cov * dash_on);
			}
		}

		
		
		float fade = 1.0;
		if (road_length > 0.01 && end_fade > 0.001) {
			float d_end = min(along, road_length - along);
			fade = clamp(d_end / end_fade, 0.0, 1.0);
		}
		paint *= fade;

		ALBEDO = mix(ALBEDO, marking_color, clamp(paint, 0.0, 1.0));
		
		ROUGHNESS = mix(ROUGHNESS, 0.55, clamp(paint, 0.0, 1.0));
	}

	
	
	
	
	if (transverse_count > 0 && road_width > 0.01) {
		float half_w = road_width * 0.5;
		float across = (UV.y - 0.5) * road_width;
		float along = UV.x;
		float across_aa = fwidth(across) * 0.75 + 0.0005;
		float along_aa = fwidth(along) * 0.75 + 0.0005;

		float tpaint = 0.0;
		for (int i = 0; i < MAX_TRANSVERSE_MARKINGS; i++) {
			if (i >= transverse_count) {
				break;
			}
			tpaint = max(tpaint, transverse_coverage(
				transverse_kind[i], transverse_along[i], transverse_facing[i],
				along, across, half_w, along_aa, across_aa));
		}

		ALBEDO = mix(ALBEDO, marking_color, clamp(tpaint, 0.0, 1.0));
		ROUGHNESS = mix(ROUGHNESS, 0.55, clamp(tpaint, 0.0, 1.0));
	}
}
