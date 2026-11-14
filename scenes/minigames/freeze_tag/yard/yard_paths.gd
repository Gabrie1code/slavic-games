class_name YardPaths
extends Node3D
## Тропинки и тротуары вокруг площадки «Морожки» (только картинка, без столкновений):
## асфальтовое кольцо вокруг забора, тротуары вдоль домов, прямые дорожки от ровно стоящих
## домов к кольцу, асфальт перед гаражами. Всё асфальтовое — одного цвета и на одной высоте
## (раньше коричневые тропы и дорожки ложились поверх тротуаров «слоями» и шли ломаными).

const ASPHALT := Color(0.33, 0.33, 0.35)
const ASPHALT_OLD := Color(0.4, 0.39, 0.38)
## Половина размера кольца (по средней линии) и его ширина.
const RING := Vector2(19.0, 13.0)
const RING_W := 1.6
## Размер домов (ширина, глубина) — тротуар у их лицевой стороны.
const SIZES := {
	"khrushchevka": Vector2(28, 11), "khrushchevka_yard": Vector2(28, 11),
	"brick_khrushchevka": Vector2(26, 10),
	"panel_ninestory": Vector2(30, 12), "stalinka": Vector2(28, 13), "tower_block": Vector2(16, 16),
}
var _mats: Dictionary = {}


## buildings — то же, что FreezeYard.SURROUNDINGS: [модель, место, поворот].
func build(buildings: Array) -> void:
	for side: float in [-1.0, 1.0]: # асфальтовое кольцо вокруг забора
		_strip(Vector3(0, 0, side * RING.y), Vector2(RING.x * 2 + RING_W, RING_W), 0.0, ASPHALT, 0.0)
		_strip(Vector3(side * RING.x, 0, 0), Vector2(RING_W, RING.y * 2 - RING_W), 0.0, ASPHALT, 0.0)
	for i in buildings.size():
		var item: Array = buildings[i]
		var pos: Vector3 = item[1]
		if pos.length() > 60.0:
			continue # дальние дома — без тротуаров
		var yaw := float(item[2])
		var front := Vector3(sin(yaw), 0, cos(yaw))
		var model := String(item[0])
		if model == "garage_row":
			_strip(pos + front * 2.0, Vector2(20.4, 4.0), yaw, ASPHALT_OLD, 0.0)
			continue
		if not SIZES.has(model):
			continue
		var size: Vector2 = SIZES[model]
		var walk := pos + front * (size.y / 2.0 + 2.4) # за балконами и козырьками подъездов
		_strip(walk, Vector2(size.x, 1.8), yaw, ASPHALT, 0.0)
		# Прямая дорожка к кольцу — только от домов, стоящих ровно (лицом по оси двора).
		# Встык, без наложения: от края тротуара (0.9 м) до края кольца (RING_W / 2).
		var inward := -front
		if absf(front.x) > 0.99:
			var ring_x := signf(walk.x) * (RING.x + RING_W / 2.0)
			_segment(walk + inward * 0.9, Vector3(ring_x, 0, walk.z), 1.4, ASPHALT, 0.0)
		elif absf(front.z) > 0.99:
			var ring_z := signf(walk.z) * (RING.y + RING_W / 2.0)
			_segment(walk + inward * 0.9, Vector3(walk.x, 0, ring_z), 1.4, ASPHALT, 0.0)


## Отрезок дорожки от a до b шириной width.
func _segment(a: Vector3, b: Vector3, width: float, color: Color, lift: float) -> void:
	var d := b - a
	if d.length() < 0.2:
		return
	_strip((a + b) / 2.0, Vector2(width, d.length()), atan2(d.x, d.z), color, lift)


## Плоская полоса: size.x — поперёк (по X после поворота), size.y — вдоль (по Z).
func _strip(center: Vector3, size: Vector2, yaw: float, color: Color, lift: float) -> void:
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 0.02, size.y)
	strip.mesh = box
	strip.material_override = _mat(color)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position = Vector3(center.x, 0.012 + lift, center.z)
	strip.rotation.y = yaw
	add_child(strip)


func _mat(color: Color) -> StandardMaterial3D:
	if not _mats.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		_mats[color] = mat
	return _mats[color]
