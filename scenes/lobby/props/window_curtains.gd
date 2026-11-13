class_name WindowCurtains
extends HingedProp
## Шторы у окна гостиной на потолочном карнизе: «подтвердить» у окна — задёрнуть / раздвинуть.
## Использует механику HingedProp («открыть» = задёрнуть): вместо поворота дверцы полотна
## плавно растягиваются от краёв к середине окна или собираются гармошкой обратно.
## Начало координат — как у модели окна (по центру окна, на полу, в плоскости рамы).

## Где висят полотна: на 37 см перед окном — перед подоконником (он выступает на 30 см).
const PANEL_Z := 0.37
## Внешний край полотна (от середины окна) и его полная ширина (задёрнуто).
const EDGE_X := 1.15
const PANEL_W := 1.14
## Ширина раздвинутой шторы от полной (1.14 м → ~0.32 м, сбоку от подоконника).
const OPEN_SCALE := 0.28
## Раздвинутая штора собрана гармошкой — складки глубже.
const OPEN_DEPTH := 1.6

var _panels: Array[Node3D] = []


func _ready() -> void:
	add_child(_load("curtain_cornice"))
	for side: float in [-1.0, 1.0]:
		var panel := _load("curtain_left" if side < 0.0 else "curtain_right")
		panel.position = Vector3(side * EDGE_X, 0.0, PANEL_Z)
		add_child(panel)
		_panels.append(panel)
	# «Дверца» — пустой узел: HingedProp поворачивает его, а мы по углу двигаем полотна.
	door = Node3D.new()
	add_child(door)
	open_angle = 2.0 # «угол» — просто ход: за 0.5 сек
	cooldown = 0.6
	open_text = "Закрыть жалюзи"
	close_text = "Открыть жалюзи"
	front_offset = Vector3(0.0, 1.2, 0.5)
	_door_moved(0.0)


## Персонаж смотрит именно на штору (левую или правую — там, где она сейчас висит), а не в
## просвет окна между ними, и стоит не дальше reach от неё.
func aimed_by(character: Node3D, reach: float) -> bool:
	var origin := to_local(character.global_position)
	var forward := global_basis.inverse() * -character.global_basis.z
	if forward.z > -0.05:
		return false # смотрит не в сторону окна
	var t := (PANEL_Z - origin.z) / forward.z
	if t < 0.0 or Vector2(forward.x, forward.z).length() * t > reach:
		return false
	var x := absf(origin.x + forward.x * t)
	var width := PANEL_W * _panels[0].scale.x # ширина шторы сейчас (раздвинута — узкая)
	return x <= EDGE_X + 0.12 and x >= EDGE_X - width - 0.04


func _door_moved(amount: float) -> void:
	# amount: 0 — шторы раздвинуты, 1 — задёрнуты. Плавнее к краям (smoothstep).
	var t := smoothstep(0.0, 1.0, amount)
	for panel in _panels:
		panel.scale = Vector3(lerpf(OPEN_SCALE, 1.0, t), 1.0, lerpf(OPEN_DEPTH, 1.0, t))


static func _load(model_name: String) -> Node3D:
	var path := "res://assets/models/apartment/%s.glb" % model_name
	return (load(path) as PackedScene).instantiate() as Node3D
