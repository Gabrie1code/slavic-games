class_name Mirror
extends Node3D
## Настоящее зеркало (плоское отражение). Камера ставится зеркально к глазам ближайшего
## игрока (отражение через плоскость зеркала), её пирамида видимости подгоняется точно под
## прямоугольник зеркала (set_frustum), картинка рисуется в SubViewport и показывается на
## зеркале, отражённая по горизонтали. В отражении видно и самого себя, и других.
## Зеркало смотрит вдоль своей +Z. Работает, только когда перед ним кто-то есть (экономия).

const PIXELS_PER_METER := 640
## Отражение строится для ближайших глаз перед зеркалом на любом расстоянии (раньше дальше
## 4.5 м была неподвижная «заглушка», и при подходе картинка резко перескакивала).
const VIEW_DISTANCE := 1000.0
## Камеры игроков, которые «смотрят» в зеркала (лобби добавляет камеры от первого лица).
const VIEWER_GROUP := "fp_camera"
const NEAR := 0.05

var size := Vector2(0.42, 0.54)

var _viewport: SubViewport
var _camera: Camera3D
## В прошлом кадре кто-то смотрел (true в начале — чтобы зеркало один раз нарисовалось сразу).
var _had_viewer := true


func setup(mirror_size: Vector2) -> Mirror:
	size = mirror_size
	return self


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(size * PIXELS_PER_METER)
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	# Видно всех персонажей (и себя), без «кулаков в кадре», значков и картинок для вида сверху.
	# Стена, на которой висит зеркало (и рамка), — на слоях стены туалета: камера зеркала стоит
	# «за стеной» и её не рисует (иначе вместо отражения — тёмная стена).
	_camera.cull_mask = 0xFFFFF & ~(0b1111 << 10) & ~ZoneBadge.OVERHEAD_LAYER \
		& ~Apartment.OVERVIEW_ONLY_LAYER & ~ToiletRoom.WALL_LAYER & ~ToiletRoom.WALL_HIGH_LAYER \
		& ~PlayerCharacter.all_name_layers() # имена над головами в зеркале не показываем
	_viewport.add_child(_camera)
	_camera.current = true
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _viewport.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Отражение: картинку с камеры «за зеркалом» переворачиваем слева направо.
	mat.uv1_scale = Vector3(-1, 1, 1)
	mat.uv1_offset = Vector3(1, 0, 0)
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)


func _process(_delta: float) -> void:
	var normal := global_basis.z.normalized()
	var viewer := _nearest_viewer()
	# Никого рядом — отражение «как будто стоят в метре от зеркала», обновляется редко.
	var eye := global_position + normal * 1.2 + Vector3.DOWN * 0.1
	if viewer:
		eye = viewer.global_position
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif _had_viewer:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE # отошли — дорисовать раз
	_had_viewer = viewer != null
	var dist := (eye - global_position).dot(normal)
	var reflected := eye - normal * dist * 2.0
	# Камера «за зеркалом» смотрит сквозь него в комнату.
	_camera.global_transform = Transform3D(Basis.looking_at(normal, Vector3.UP), reflected)
	var center := _camera.global_transform.affine_inverse() * global_position
	# Пирамида видимости точно по рамке зеркала: размер и сдвиг на ближней плоскости (NEAR)
	# пропорционально уменьшены от плоскости зеркала (до неё dist).
	var k := NEAR / maxf(dist, 0.05)
	_camera.set_frustum(size.y * k, Vector2(center.x, center.y) * k, NEAR, 80.0)


## Ближайшие глаза перед зеркалом (null — никого рядом).
func _nearest_viewer() -> Camera3D:
	var normal := global_basis.z.normalized()
	var best: Camera3D = null
	var best_dist := VIEW_DISTANCE
	for node in get_tree().get_nodes_in_group(VIEWER_GROUP):
		var camera := node as Camera3D
		if camera == null or not camera.is_visible_in_tree():
			continue
		var offset := camera.global_position - global_position
		var d := offset.length()
		if offset.dot(normal) > 0.05 and d < best_dist:
			best_dist = d
			best = camera
	return best
