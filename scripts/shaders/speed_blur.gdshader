shader_type canvas_item;





















uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;



uniform float strength : hint_range(0.0, 1.0) = 0.0;





uniform float clear_radius : hint_range(0.0, 1.0) = 0.18;



uniform float max_blur : hint_range(0.0, 0.2) = 0.035;




uniform vec2 focal_point = vec2(0.5, 0.5);




const int SAMPLE_COUNT = 8;

void fragment() {
	vec4 original = texture(screen_texture, SCREEN_UV);

	
	
	if (strength <= 0.001) {
		COLOR = original;
	} else {
		
		
		vec2 offset = SCREEN_UV - focal_point;
		float dist = length(offset);

		
		
		float falloff = smoothstep(clear_radius, 1.0, dist / 0.7071);

		if (falloff <= 0.0) {
			COLOR = original;
		} else {
			
			
			
			vec2 direction = dist > 0.0001 ? offset / dist : vec2(0.0);
			float blur_length = max_blur * falloff * strength;

			
			
			
			vec4 accum = original;
			for (int i = 1; i < SAMPLE_COUNT; i++) {
				float t = float(i) / float(SAMPLE_COUNT - 1);
				vec2 sample_uv = SCREEN_UV - direction * blur_length * t;
				accum += texture(screen_texture, clamp(sample_uv, vec2(0.0), vec2(1.0)));
			}
			COLOR = accum / float(SAMPLE_COUNT);
		}
	}
}
