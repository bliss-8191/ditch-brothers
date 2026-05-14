shader_type spatial;

render_mode cull_disabled;

uniform vec3 albedo = vec3(0.8, 0.8, 0.8);
uniform float roughness = 0.5;
uniform float metallic = 1.0;
uniform sampler2D alpha : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal : filter_linear_mipmap_anisotropic, hint_normal, repeat_enable;
uniform float uv_scale = 1;

void fragment() {
	ALPHA *= texture(alpha, uv_scale * UV, 0.5).r;
	NORMAL_MAP = texture(normal, uv_scale * UV, 0.9).xyz;
	METALLIC = metallic;
	ALBEDO = albedo;
	ROUGHNESS = roughness;
}
