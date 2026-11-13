// Небо за окном (WindowView): градиент от горизонта вверх, солнце или луна, звёзды ночью и
// плывущие облака. Цвета задаёт WindowView по времени суток игрока.
// Квадрат неба 600×320 м; UV.y = 0 — верх, у горизонта UV.y ≈ 0.82.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 top_color : source_color = vec3(0.37, 0.59, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.9, 0.96);
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform float night = 0.0;
uniform vec2 sun_uv = vec2(0.5, 0.7);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.75);
uniform float sun_alpha = 1.0;
uniform vec2 moon_uv = vec2(0.5, 0.7);
uniform float moon_alpha = 0.0;
uniform sampler2D clouds : source_color, repeat_enable, filter_linear_mipmap;

const vec2 SIZE = vec2(600.0, 320.0);
const float HORIZON = 0.82;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float up = clamp((HORIZON - uv.y) / 0.25, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 1.0, up));
	// Звёзды: редкие точки, мерцают, у горизонта их нет.
	vec2 cell = floor(uv * SIZE * 2.0);
	float star = step(0.995, hash(cell)) * (0.6 + 0.4 * sin(TIME * 2.0 + hash(cell + 3.0) * 30.0));
	col += vec3(star) * night * smoothstep(0.05, 0.4, up);
	// Солнце: диск и мягкое сияние вокруг.
	float sun_r = length((uv - sun_uv) * SIZE);
	col += sun_color * sun_alpha * 0.45 * exp(-sun_r / 9.0);
	col = mix(col, sun_color, sun_alpha * (1.0 - smoothstep(3.2, 3.6, sun_r)));
	// Луна: светлый диск с тенью (месяц).
	vec2 m = (uv - moon_uv) * SIZE;
	float disc = 1.0 - smoothstep(2.2, 2.5, length(m));
	float shade = 1.0 - smoothstep(2.0, 2.3, length(m - vec2(1.1, -0.5)));
	col += vec3(0.75, 0.8, 1.0) * moon_alpha * 0.12 * exp(-length(m) / 8.0);
	col = mix(col, vec3(0.95, 0.93, 0.82), moon_alpha * disc * (1.0 - shade * 0.88));
	// Облака плывут медленно вбок.
	vec2 cuv = vec2(uv.x * 4.0 + TIME * 0.002, (uv.y - 0.45) / 0.37);
	if (cuv.y > 0.0 && cuv.y < 1.0) {
		float a = texture(clouds, cuv).a;
		col = mix(col, cloud_color, a * 0.95);
	}
	ALBEDO = col;
}
