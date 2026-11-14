// «Живая» цензура: крупные пиксели картинки (censor_mosaic.png), у каждого свой оттенок розового
// медленно переливается со временем — как в телепередачах, где что-то скрыто.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D mosaic : source_color, filter_nearest;
uniform vec2 cells = vec2(5.0, 4.0);
uniform float speed = 2.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 base = texture(mosaic, UV);
	vec2 cell = floor(UV * cells);
	float r = hash(cell);
	float wave = 0.5 + 0.5 * sin(TIME * speed * (0.7 + r) + r * 6.2832);
	vec3 pink = vec3(0.93, 0.45, 0.68);
	vec3 pale = vec3(0.97, 0.78, 0.86);
	vec3 deep = vec3(0.72, 0.28, 0.5);
	vec3 shade = mix(mix(deep, pink, wave), pale, step(0.75, fract(r * 7.0 + TIME * 0.5)) * 0.6);
	ALBEDO = mix(base.rgb, shade, 0.65);
	ALPHA = base.a;
}
