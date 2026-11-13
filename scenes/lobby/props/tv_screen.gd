class_name TvScreen
extends MeshInstance3D
## Экран кинескопа советского телевизора: картинка «▶ ИГРАТЬ» рисуется во встроенном
## SubViewport и натягивается на выпуклую сетку той же формы, что экран модели
## (скруглённый прямоугольник с «горбом» к центру). Поэтому картинка лежит прямо на стекле,
## а не висит плоской пластинкой перед телевизором.
## Координаты — в модели телевизора (tools/blender/soviet_tv.py, Blender → Godot: z = −y).

const BG := preload("res://assets/textures/tv/tv_screen_bg.png")
const BUTTON := preload("res://assets/textures/tv/tv_play_button.png")
## Размер экрана модели и его середина.
const SIZE := Vector2(0.54, 0.44)
const CORNER := 0.09
const CENTER := Vector2(-0.12, 0.78)
## Глубина: край экрана, кольцо на 60 % и вершина «горба» (+ зазор над стеклом).
const EDGE_Z := 0.41
const MID_Z := 0.435
const TOP_Z := 0.445
const GAP := 0.004
const PIXELS := Vector2i(540, 440)
## Цвет стекла модели вокруг картинки: тёмная бирюза, как край фона картинки
## (раньше светящееся стекло модели давало светлый контур по краю экрана).
const GLASS_EDGE := Color8(20, 56, 54)


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = PIXELS
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(Picture.new())
	mesh = _build_mesh()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = viewport.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_darken_model_glass.call_deferred()


## Стекло самой модели («Screen») выглядывает по краю картинки — красим его в тёмный цвет фона.
func _darken_model_glass() -> void:
	var tv := get_parent()
	if tv == null:
		return
	var glass := StandardMaterial3D.new()
	glass.albedo_color = GLASS_EDGE
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node in tv.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == self or mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var surface := mesh_instance.mesh.surface_get_material(i)
			if surface and surface.resource_name.begins_with("Screen"):
				mesh_instance.set_surface_override_material(i, glass)


## Сетка как у модели: внешнее кольцо → кольцо поменьше → вершина в центре.
func _build_mesh() -> ArrayMesh:
	var outline := _rounded_rect()
	var outer: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for point in outline:
		outer.append(Vector3(CENTER.x + point.x, CENTER.y + point.y, EDGE_Z + GAP))
		mid.append(Vector3(CENTER.x + point.x * 0.6, CENTER.y + point.y * 0.6, MID_Z + GAP))
	var top := Vector3(CENTER.x, CENTER.y, TOP_Z + GAP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for i in n:
		var j := (i + 1) % n
		_triangle(st, [outer[i], mid[j], outer[j]])
		_triangle(st, [outer[i], mid[i], mid[j]])
		_triangle(st, [mid[i], top, mid[j]])
	return st.commit()


## Треугольник с UV по проекции на плоскость экрана (картинка не растягивается на «горбе»).
func _triangle(st: SurfaceTool, points: Array) -> void:
	for p: Vector3 in points:
		st.set_uv(Vector2((p.x - CENTER.x) / SIZE.x + 0.5, 0.5 - (p.y - CENTER.y) / SIZE.y))
		st.add_vertex(p)


## Контур скруглённого прямоугольника (как rounded_rect в soviet_tv.py, 3 сегмента на угол).
func _rounded_rect() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var w := SIZE.x / 2.0 - CORNER
	var h := SIZE.y / 2.0 - CORNER
	var corners: Array[Vector3] = [
		Vector3(w, h, 0), Vector3(-w, h, 90), Vector3(-w, -h, 180), Vector3(w, -h, 270),
	]
	for corner in corners:
		for i in 4:
			var a := deg_to_rad(corner.z + 90.0 * i / 3.0)
			points.append(Vector2(corner.x + CORNER * cos(a), corner.y + CORNER * sin(a)))
	return points


## Сама картинка: фон мерцает, кнопка «дышит», сверху вниз бежит светлая полоса.
class Picture extends Node2D:
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var flicker := 0.93 + randf() * 0.07
		draw_texture_rect(BG, Rect2(Vector2.ZERO, PIXELS), false,
			Color(flicker, flicker, flicker))
		var pulse := 1.0 + sin(_time * 3.0) * 0.04
		var size := Vector2(440, 169) * pulse
		var jitter := (randf() - 0.5) * 1.6
		draw_texture_rect(BUTTON, Rect2((Vector2(PIXELS) - size) / 2.0 + Vector2(jitter, 0), size),
			false)
		var scan_y := fmod(_time * 0.12, 0.4) / 0.4 * PIXELS.y
		draw_rect(Rect2(0, scan_y, PIXELS.x, 35), Color(0.7, 1.0, 0.9, 0.08))
