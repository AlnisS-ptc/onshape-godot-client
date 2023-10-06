shader_type spatial;

render_mode unshaded, depth_test_disabled;

const vec4 color = vec4(0.847, 0.847, 0.847, 1.0);

void fragment() { 
	ALBEDO = color.rgb;
	ALPHA = color.a;
}