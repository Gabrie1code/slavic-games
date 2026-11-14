// «Фильтр времени суток» для двора за окном: второй проход поверх каждой вещи двора
// (material_overlay), умножает её цвет — ночью тёмно-синий, на закате и рассвете тёплый.
// Небо его не получает: у него свои цвета (window_sky.gdshader).
shader_type spatial;
// cull_disabled: у двусторонних граней (тарелки и т.п.) видна «изнанка» — без него фильтр её
// пропускал, и такие вещи ночью светились.
render_mode unshaded, blend_mul, depth_draw_never, fog_disabled, shadows_disabled, cull_disabled;

uniform vec3 tint : source_color = vec3(1.0);

void fragment() {
	ALBEDO = tint;
}
