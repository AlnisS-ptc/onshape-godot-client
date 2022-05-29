shader_type spatial;

render_mode unshaded, depth_test_disable;

varying float z_dist;

void vertex() {
	z_dist = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z * -1.0;
}

void fragment() { 
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	vec3 pixel_position = upos.xyz / upos.w;
	ALBEDO = vec3(-pixel_position.z);
	
//	if (-pixel_position.z < z_dist - 0.04) {
	float ratio = -pixel_position.z / z_dist;
	if (ratio < 0.97) {
//		ALBEDO = vec3(1.0);
		discard;
	} else {
		ALPHA = clamp((ratio - 0.97) / 0.03, 0.0, 1.0);
		ALBEDO = vec3(0.0);
	}

//	ALBEDO = vec3(z_dist * 0.1);
}