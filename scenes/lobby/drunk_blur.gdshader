// Сильное опьянение: картинка расплывается и двоится (сдвинутая копия «плавает» по кругу).
// Накладывается поверх вида игрока (ColorRect в его SubViewportContainer); amount 0..1.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;

void fragment() {
	float lod = 0.6 * amount; // размытие — совсем слабое
	vec2 drift = vec2(sin(TIME * 1.3), cos(TIME * 0.9)) * 0.022 * amount; // двоение — заметнее
	vec3 base = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	vec3 ghost = textureLod(screen_tex, SCREEN_UV + drift, lod).rgb;
	vec3 ghost2 = textureLod(screen_tex, SCREEN_UV - drift * 0.6, lod).rgb;
	COLOR = vec4(mix(base, ghost * 0.6 + ghost2 * 0.4, 0.55 * amount), 1.0);
}
