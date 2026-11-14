class_name DoorCasing
extends RefCounted
## Наличники на дверных проёмах квартиры (с обеих сторон стены): две стойки по бокам и
## перекладина сверху, светлое крашеное дерево. Только картинка (без столкновений), проёмы не
## сужаются — наличник лежит на стене снаружи проёма.

const WIDTH := 0.075
const THICK := 0.022
const COLOR := Color("ece4d2")


## Все проёмы квартиры: в спальню, в игровую, на кухню, в туалет.
static func build_all(apartment: Apartment) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.roughness = 0.55
	add(apartment, true, Apartment.PARTITION_X, 0.08, Vector2(Apartment.DOOR_FROM_Z,
		Apartment.DOOR_TO_Z), 2.4, mat)
	add(apartment, true, Apartment.LEFT_X - 0.11, 0.11, Vector2(Apartment.RUBGAME_DOOR_FROM_Z,
		Apartment.RUBGAME_DOOR_TO_Z), 2.4, mat)
	add(apartment, true, ToiletRoom.X0 + 0.01, 0.09, Vector2(ToiletRoom.DOOR_FROM_Z,
		ToiletRoom.DOOR_TO_Z), ToiletRoom.DOOR_TOP, mat)
	# Кухня: передняя стена гостиной видна только от первого лица — наличник тоже.
	add(apartment, false, Apartment.LIVING_FRONT_Z + 0.1, 0.1, Vector2(KitchenRoom.DOOR_X0,
		KitchenRoom.DOOR_X1), KitchenRoom.DOOR_TOP, mat, Apartment.FP_ONLY_LAYER)


## Наличник проёма в стене: across_x — стена поперёк X (проём вдоль Z), center/half — середина
## и половина толщины стены, span — края проёма вдоль стены, top — высота проёма.
static func add(parent: Node3D, across_x: bool, center: float, half: float, span: Vector2,
		top: float, mat: Material, layer: int = 1) -> void:
	for side: float in [-1.0, 1.0]:
		var face := center + side * (half + THICK / 2.0)
		var mid := (span.x + span.y) / 2.0
		var length := span.y - span.x + WIDTH * 2.0
		for edge: float in [span.x - WIDTH / 2.0, span.y + WIDTH / 2.0]: # стойки
			_piece(parent, across_x, face, edge, Vector2(WIDTH, top + WIDTH), (top + WIDTH) / 2.0,
				mat, layer)
		_piece(parent, across_x, face, mid, Vector2(length, WIDTH), top + WIDTH / 2.0, mat, layer)


static func _piece(parent: Node3D, across_x: bool, face: float, along: float, size: Vector2,
		y: float, mat: Material, layer: int) -> void:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(THICK, size.y, size.x) if across_x else Vector3(size.x, size.y, THICK)
	piece.mesh = box
	piece.material_override = mat
	piece.layers = layer
	piece.position = Vector3(face, y, along) if across_x else Vector3(along, y, face)
	parent.add_child(piece)
