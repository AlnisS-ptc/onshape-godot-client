shader_type spatial;

render_mode unshaded;

uniform vec4 modulate : hint_color = vec4(0.6157, 0.8118, 0.9294, 1.0);
uniform sampler2D matcap : hint_white;


void fragment() {
	vec3 matcap_normal = vec3(NORMALMAP.xy * 2.0 - 1.0, 1.0) * NORMALMAP_DEPTH;
	matcap_normal.z = 1.0 - (pow(matcap_normal.x, 2.0) + pow(matcap_normal.y, 2.0));
	matcap_normal = matcap_normal.x * TANGENT + matcap_normal.y * BINORMAL + matcap_normal.z * NORMAL;
	
	vec3 uv = matcap_normal.xyz * vec3(0.48, -0.48, 1.0) + 0.5;
	
	ALBEDO = texture(matcap, uv.xy).rgb * COLOR.rgb;
}