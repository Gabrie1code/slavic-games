class_name TableClock
extends Node3D
## Настольные часы на серванте: стрелки показывают настоящее время компьютера игрока
## (часы, минуты, секунды — плавно). Модель — tools/blender/china.py (mantel_clock).

const MODEL := preload("res://assets/models/apartment/mantel_clock.glb")
## Центр циферблата (в координатах часов) — ось стрелок.
const FACE := Vector3(0, 0.17, 0.074)

var _hour: Node3D
var _minute: Node3D
var _second: Node3D


func _ready() -> void:
	add_child(MODEL.instantiate())
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.06, 0.05)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.75, 0.1, 0.08)
	_hour = _hand(0.045, 0.008, dark, 0.0)
	_minute = _hand(0.068, 0.006, dark, 0.002)
	_second = _hand(0.072, 0.003, red, 0.004)


func _process(_delta: float) -> void:
	var now := Time.get_time_dict_from_system()
	var ms := float(Time.get_ticks_msec() % 1000) / 1000.0
	var seconds := float(now["second"]) + ms
	var minutes := float(now["minute"]) + seconds / 60.0
	var hours := float(int(now["hour"]) % 12) + minutes / 60.0
	# По часовой стрелке, если смотреть на циферблат спереди (+Z) — поворот вокруг Z «минусом».
	_hour.rotation.z = -hours / 12.0 * TAU
	_minute.rotation.z = -minutes / 60.0 * TAU
	_second.rotation.z = -seconds / 60.0 * TAU


## Стрелка: ось в центре циферблата, сама стрелка смотрит вверх (на 12).
func _hand(length: float, width: float, material: Material, lift: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = FACE + Vector3(0, 0, lift)
	add_child(pivot)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, length, 0.003)
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(0, length / 2.0 - 0.008, 0)
	pivot.add_child(mesh_instance)
	return pivot
