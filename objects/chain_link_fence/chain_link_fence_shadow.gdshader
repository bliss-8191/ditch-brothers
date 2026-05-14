shader_type spatial;

render_mode depth_prepass_alpha, cull_disabled;

uniform sampler2D alpha : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 1;
uniform float shadow_pass_alpha_threshold = 0.25;

void fragment() {
	ALPHA *= texture(alpha, uv_scale * UV, 0.5).r;
	if (ALPHA < shadow_pass_alpha_threshold) {
		discard;
	}
}
