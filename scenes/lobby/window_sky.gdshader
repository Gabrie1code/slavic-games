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
uniform float sun_haze = 0.0;
uniform vec2 moon_uv = vec2(0.5, 0.7);
uniform float moon_alpha = 0.0;
uniform sampler2D clouds : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D moon_tex : source_color, filter_linear_mipmap;

const vec2 SIZE = vec2(600.0, 320.0);
const float HORIZON = 0.82;
// Радиус луны (м на квадрате неба).
const float MOON_R = 2.6;

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
	// Солнце (выбрано владельцем): днём — «яркое с сиянием» (светлый диск, широкое тёплое
	// сияние); на закате/рассвете — «сквозь дымку», оранжевое: размытое большое пятно.
	// sun_haze: 0 — день, 1 — солнце у горизонта.
	float sun_r = length((uv - sun_uv) * SIZE);
	vec3 day_glow = vec3(1.0, 0.95, 0.8) * 0.6 * exp(-sun_r / 4.0);
	vec3 haze_glow = vec3(1.0, 0.55, 0.25) * 0.75 * exp(-sun_r / 3.5);
	col += mix(day_glow, haze_glow, sun_haze) * sun_alpha;
	float day_disc = 1.0 - smoothstep(3.1, 3.4, sun_r);
	float haze_disc = 1.0 - smoothstep(2.5, 4.5, sun_r);
	vec3 disc_col = mix(vec3(1.0, 0.98, 0.88), vec3(1.0, 0.62, 0.3), sun_haze);
	col = mix(col, disc_col, sun_alpha * mix(day_disc, haze_disc, sun_haze));
	// Луна: картинка «реалистичный месяц» (tools/textures/moon.py) — кратеры, пепельный свет;
	// вокруг мягкое голубое сияние.
	vec2 m = (uv - moon_uv) * SIZE;
	col += vec3(0.75, 0.8, 1.0) * moon_alpha * 0.12 * exp(-length(m) / 8.0);
	vec2 muv = m / (MOON_R * 2.0) + 0.5;
	if (muv.x > 0.0 && muv.x < 1.0 && muv.y > 0.0 && muv.y < 1.0) {
		vec4 moon = texture(moon_tex, muv);
		col = mix(col, moon.rgb, moon.a * moon_alpha);
	}
	// Облака плывут медленно вбок.
	vec2 cuv = vec2(uv.x * 4.0 + TIME * 0.002, (uv.y - 0.45) / 0.37);
	if (cuv.y > 0.0 && cuv.y < 1.0) {
		float a = texture(clouds, cuv).a;
		col = mix(col, cloud_color, a * 0.95);
	}
	ALBEDO = col;
}
