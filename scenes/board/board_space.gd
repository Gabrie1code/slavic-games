class_name BoardSpace
extends Node3D
## Одна клетка игровой доски.

enum Type {
	START, ## Старт
	BLUE,  ## +рубли
	RED,   ## −рубли
	EVENT, ## Случайное событие
}

const TYPE_COLORS := {
	Type.START: Color("e8e2d0"),
	Type.BLUE: Color("2f6fd6"),
	Type.RED: Color("d93a2b"),
	Type.EVENT: Color("3aa655"),
}
const RADIUS := 0.8

@export var type: Type = Type.BLUE

## Порядковый номер клетки на доске.
var index: int = -1
## Куда можно пойти дальше. Больше одной клетки = развилка.
var next: Array[BoardSpace] = []
## Можно ли поставить сюда ларёк «Дефицит».
var kiosk_allowed := true

var _top: MeshInstance3D
var _kiosk: Node3D


func _ready() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = RADIUS
	base_mesh.bottom_radius = RADIUS + 0.08
	base_mesh.height = 0.2
	base_mesh.radial_segments = 12
	base_mesh.rings = 1
	base.mesh = base_mesh
	base.position.y = 0.1
	base.material_override = _material(Color("3b3430"))
	add_child(base)

	_top = MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = RADIUS - 0.12
	top_mesh.bottom_radius = RADIUS - 0.12
	top_mesh.height = 0.05
	top_mesh.radial_segments = 12
	top_mesh.rings = 1
	_top.mesh = top_mesh
	_top.position.y = 0.21
	_top.material_override = _material(TYPE_COLORS[type])
	add_child(_top)

	var icon := ""
	match type:
		Type.START:
			icon = "СТАРТ"
		Type.BLUE:
			icon = "+"
		Type.RED:
			icon = "−"
		Type.EVENT:
			icon = "?"
	var label := Label3D.new()
	label.text = icon
	label.font_size = 96 if type != Type.START else 40
	label.outline_size = 16
	label.rotation_degrees.x = -90
	label.position.y = 0.25
	label.modulate = Color.WHITE if type != Type.START else Color("3b3430")
	add_child(label)


## Позиция фишки игрока на клетке (чтобы фишки не стояли друг в друге).
func stand_position(slot: int) -> Vector3:
	var offsets: Array[Vector3] = [
		Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, -0.3), Vector3(-0.3, 0, 0.3), Vector3(0.3, 0, 0.3),
	]
	return global_position + Vector3.UP * 0.24 + offsets[slot % offsets.size()]


func set_highlight(on: bool) -> void:
	scale = Vector3.ONE * (1.3 if on else 1.0)


## Показать или убрать ларёк «Дефицит» рядом с клеткой.
func set_kiosk(on: bool) -> void:
	if on and _kiosk == null:
		_kiosk = _build_kiosk()
		add_child(_kiosk)
	elif not on and _kiosk:
		_kiosk.queue_free()
		_kiosk = null


func _build_kiosk() -> Node3D:
	var root := Node3D.new()
	# Ставим ларёк снаружи доски, лицом к центру.
	var outward := Vector3(position.x, 0.0, position.z)
	outward = outward.normalized() if outward.length() > 0.01 else Vector3.BACK
	root.position = outward * 1.5
	root.basis = Basis.looking_at(outward, Vector3.UP)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.4, 1.3, 0.9)
	body.mesh = body_mesh
	body.position.y = 0.65
	body.material_override = _material(Color("4a8fb8"))
	root.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.6, 0.12, 1.1)
	roof.mesh = roof_mesh
	roof.position.y = 1.36
	roof.material_override = _material(Color("e8e2d0"))
	root.add_child(roof)

	var window := MeshInstance3D.new()
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.9, 0.5, 0.05)
	window.mesh = window_mesh
	window.position = Vector3(0, 0.85, 0.46)
	window.material_override = _material(Color("f6e7a8"))
	root.add_child(window)

	var sign := Label3D.new()
	sign.text = "ДЕФИЦИТ"
	sign.font_size = 72
	sign.outline_size = 18
	sign.modulate = Color("f6c343")
	sign.outline_modulate = Color("7a1410")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position.y = 2.0
	root.add_child(sign)
	return root


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	return m
