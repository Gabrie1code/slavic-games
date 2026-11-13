class_name WindowGlass
extends Node3D
## Стёкла окна гостиной: 4 створки между рамами (window.glb — tools/blender/apartment.py).
## Каждую можно разбить молотком (как стёкла серванта); через RESTORE сек после последнего
## удара все разбитые стёкла разом плавно проявляются снова. Стекло на 50% прозрачнее, чем у
## серванта (сквозь окно смотрят на двор).
## Узел ставится в ту же точку, что и окно; плоскость стёкол — z = 0 в его координатах.

const RESTORE := 20.0
const ALPHA := SideboardCabinet.GLASS_ALPHA * 0.5 # на 50% прозрачнее стекла серванта
## Проёмы между рамами окна: [центр x, центр y, ширина, высота].
const PANES: Array[Vector4] = [
	Vector4(-0.36, 1.4425, 0.65, 1.055), Vector4(0.36, 1.4425, 0.65, 1.055),
	Vector4(-0.36, 2.2075, 0.65, 0.355), Vector4(0.36, 2.2075, 0.65, 0.355),
]

## Створки этого окна (по умолчанию — окно гостиной; у кухни свои — задать до add_child).
var panes: Array[Vector4] = PANES

var _panes: Array[MeshInstance3D] = []
var _broken: Array[bool] = []
var _time := 0.0
var _restore_at := -1.0


func _ready() -> void:
	for rect in panes:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.82, 0.92, 0.96, ALPHA)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.04
		mat.metallic = 0.2
		mat.metallic_specular = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var pane := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rect.z, rect.w, 0.006)
		pane.mesh = mesh
		pane.material_override = mat
		pane.position = Vector3(rect.x, rect.y, 0.0)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pane)
		_panes.append(pane)
		_broken.append(false)


func _process(delta: float) -> void:
	_time += delta
	if _restore_at >= 0.0 and _time >= _restore_at:
		_restore_at = -1.0
		_restore_all()


func pane_broken(index: int) -> bool:
	return _broken[index]


## По какому стеклу попадает удар из origin в сторону dir (в мире): −1 — мимо или дальше reach.
## Точка — где луч взгляда пересекает плоскость стёкол (с наклоном головы: верхние створки
## бьются, если смотреть вверх).
func pane_hit(origin: Vector3, dir: Vector3, reach: float) -> int:
	var o := to_local(origin)
	var d := global_basis.inverse() * dir
	if d.z >= -0.01:
		return -1 # смотрим не на окно
	var t := -o.z / d.z
	if t < 0.0 or t > reach:
		return -1
	var hit := Vector2(o.x + d.x * t, o.y + d.y * t)
	for i in panes.size():
		var rect := panes[i]
		var inside_x := absf(hit.x - rect.x) <= rect.z / 2.0 + 0.04
		if inside_x and absf(hit.y - rect.y) <= rect.w / 2.0 + 0.04:
			return i
	return -1


## Разбить створку: осколки, стекла нет; таймер восстановления — заново от этого удара.
func break_pane(index: int) -> bool:
	if _broken[index]:
		return false
	_broken[index] = true
	_panes[index].visible = false
	_restore_at = _time + RESTORE
	var rect := panes[index]
	var shards := CPUParticles3D.new()
	shards.one_shot = true
	shards.amount = 30
	shards.lifetime = 1.2
	shards.explosiveness = 0.95
	shards.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	shards.emission_box_extents = Vector3(rect.z * 0.45, rect.w * 0.45, 0.01)
	shards.direction = Vector3(0, 0.3, 1) # в комнату
	shards.spread = 50.0
	shards.initial_velocity_min = 0.6
	shards.initial_velocity_max = 1.8
	shards.gravity = Vector3(0, -9.8, 0)
	shards.scale_amount_min = 0.5
	shards.scale_amount_max = 1.4
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.04, 0.004)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mesh.material = mat
	shards.mesh = mesh
	add_child(shards)
	shards.position = Vector3(rect.x, rect.y, 0.0)
	shards.emitting = true
	shards.finished.connect(shards.queue_free)
	return true


## Все разбитые створки разом плавно проявляются.
func _restore_all() -> void:
	for i in _panes.size():
		if not _broken[i]:
			continue
		_broken[i] = false
		var pane := _panes[i]
		pane.visible = true
		var mat := pane.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.0
		pane.create_tween().tween_property(mat, "albedo_color:a", ALPHA, 0.5)
