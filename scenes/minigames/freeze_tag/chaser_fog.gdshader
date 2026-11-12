// Туман водящего: экранный эффект. Для каждой точки экрана по буферу глубины восстанавливается
// её место в мире; всё, что по полу дальше radius от водящего, закрывается тёмной пеленой.
// Так закрываются и высокие вещи (деревья, дома) — раньше туман был плоскостью на высоте 2.7 м,
// и всё, что выше, «прорезалось» сквозь него. Пелена непрозрачна на 95% (fog_color.a).
// Квадрат на весь экран (QuadMesh 2×2); его видит только камера водящего (свой слой).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform vec3 center = vec3(0.0);
uniform float radius = 4.5;
uniform float softness = 1.0;
uniform vec4 fog_color : source_color = vec4(0.0, 0.002, 0.008, 0.95);
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0); // всегда на весь экран
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	float d = distance(world.xz, center.xz);
	float a = smoothstep(radius - softness, radius, d);
	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a * a;
}
