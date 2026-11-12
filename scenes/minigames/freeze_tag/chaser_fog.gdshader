// Туман водящего: тёмная пелена над площадкой с «дыркой» вокруг водящего.
// Плоскость висит над головами; её видит только камера водящего (свой слой).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 center = vec3(0.0);
uniform float radius = 4.5;
uniform float softness = 1.3;
uniform vec4 fog_color : source_color = vec4(0.04, 0.05, 0.09, 0.94);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = distance(world_pos.xz, center.xz);
	float a = smoothstep(radius - softness, radius, d);
	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a * a;
}
