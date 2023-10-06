shader_type spatial;
render_mode unshaded, depth_test_disabled;

const float cutoff_ratio = 0.995;
varying float z_dist;
uniform sampler2D depth_texture : source_color, hint_depth_texture;


void vertex() {
	z_dist = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z * -1.0;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	
	float ratio = linear_depth / z_dist;
	
	ALBEDO = vec3(0.0);
	if (ratio < cutoff_ratio) {
		discard;
	}
}