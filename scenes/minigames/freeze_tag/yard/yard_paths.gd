class_name YardPaths
extends Node3D
## Тропинки и тротуары вокруг площадки «Морожки» (только картинка, без столкновений):
## асфальтовое кольцо вокруг забора, тротуары вдоль домов, дорожки от них к кольцу,
## асфальт перед гаражами и протоптанные «народные тропы» через газон.

const ASPHALT := Color(0.33, 0.33, 0.35)
const ASPHALT_OLD := Color(0.4, 0.39, 0.38)
const DIRT := Color(0.5, 0.41, 0.29)
## Половина размера кольца (по средней линии) и его ширина.
const RING := Vector2(19.0, 13.0)
const RING_W := 1.6
## Размер домов (ширина, глубина) — тротуар у их лицевой стороны.
const SIZES := {
	"khrushchevka": Vector2(28, 11), "brick_khrushchevka": Vector2(26, 10),
	"panel_ninestory": Vector2(30, 12), "stalinka": Vector2(28, 13), "tower_block": Vector2(16, 16),
}
## Протоптанные тропы через газон (точки по земле, x/z).
const TRAILS: Array = [
	[Vector2(-19, 8), Vector2(-24, 11), Vector2(-29, 14.5), Vector2(-33, 21)],
	[Vector2(19, -8), Vector2(23.5, -13), Vector2(26, -19), Vector2(27, -24)],
	[Vector2(-8, -13), Vector2(-7, -16), Vector2(-5.5, -18.7)],
	[Vector2(-14, -19.6), Vector2(-19, -22), Vector2(-24, -24.5)],
	[Vector2(8, 13), Vector2(9.2, 16.5), Vector2(10.2, 19.6)],
	[Vector2(-19, -3), Vector2(-23, -2), Vector2(-27, -1.5)],
]

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
		if walk.x > 15.0 and walk.z > 15.0:
			continue # дом за гаражами: прямая дорожка шла бы сквозь них
		# Дорожка от тротуара к кольцу (по прямой к центру двора).
		var scale_to_ring := minf(RING.x / maxf(absf(walk.x), 0.01), RING.y / maxf(absf(walk.z), 0.01))
		var target := walk * minf(1.0, scale_to_ring)
		_segment(walk, target, 1.4, ASPHALT if i % 2 == 0 else DIRT, 0.003)
	for trail: Array in TRAILS:
		for k in trail.size() - 1:
			var a: Vector2 = trail[k]
			var b: Vector2 = trail[k + 1]
			_segment(Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), 0.9, DIRT, 0.006)


## Отрезок дорожки от a до b шириной width (lift — чуть выше, чтобы пересечения не мерцали).
func _segment(a: Vector3, b: Vector3, width: float, color: Color, lift: float) -> void:
	var d := b - a
	if d.length() < 0.2:
		return
	_strip((a + b) / 2.0, Vector2(width, d.length() + width * 0.6), atan2(d.x, d.z), color, lift)


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
