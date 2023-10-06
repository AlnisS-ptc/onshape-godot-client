shader_type spatial;

//render_mode unshaded;
render_mode unshaded, depth_test_disabled;

uniform float cutoff_ratio = 0.995;

varying float z_dist;

//uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : source_color, hint_depth_texture;



void vertex() {
	z_dist = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z * -1.0;
}

void fragment() { 
//	ALBEDO = vec3(0.0);
//	ALPHA = 1.0;

//	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	float depth = texture(depth_texture, SCREEN_UV).x;
	
	
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	
	
//	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
//	vec3 pixel_position = upos.xyz / upos.w;
	
	
//	ALBEDO = vec3(-pixel_position.z * 1.0);
//	ALBEDO = vec3(pixel_position.z);
//	ALBEDO = vec3(-pixel_position.z);
//	ALBEDO = vec3(1.0);
//
//	if (-pixel_position.z < z_dist - 0.04) {
	float ratio = linear_depth / z_dist;
	
//	float val = ratio;
//	ALBEDO = vec3(1.0 + val, 1.0 - abs(val), 1.0 - val);
	
	ALBEDO = vec3(ratio * 40.0);
	if (ratio < cutoff_ratio) {
//		ALBEDO = vec3(0.8, 0.0, 0.0);
////		ALBEDO = vec3(1.0);
		discard;
	} else {
		ALBEDO = vec3(0.0);
//		ALPHA = clamp((ratio - 0.995) / 0.002, 0.0, 1.0);
//		ALBEDO = vec3(0.0);
	}

//	ALBEDO = vec3(z_dist * 0.1);
}