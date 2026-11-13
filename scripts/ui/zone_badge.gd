class_name ZoneBadge
extends Sprite3D
## Компактная «кнопка»-значок над местом, где можно что-то сделать (зона в лобби, горка, качели):
## цветная плашка с иконкой и коротким словом (assets/ui/prompts/<name>.png, см.
## tools/textures/prompt_badges.py). Всегда смотрит в камеру и плавно покачивается.

## Слой значков и табло над столом: их не показывает камера крупного плана у стола
## (там они только мешают), а все остальные камеры — показывают.
const OVERHEAD_LAYER := 1 << 18
const BOB := 0.15
const BOB_TIME := 1.2

var _base_y := 0.0
## 0 — виден, 1 — растворился (кто-то стоит рядом выше пола — на столе, — значок закрывал вид).
var _fade := 0.0


## name — имя картинки без .png, height — на какой высоте висеть над точкой узла-родителя.
func setup(badge_name: String, height: float) -> ZoneBadge:
	texture = load("res://assets/ui/prompts/%s.png" % badge_name)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size = 0.0028
	shaded = false
	layers = OVERHEAD_LAYER
	position.y += height
	return self


func _ready() -> void:
	_base_y = position.y
	var bob := create_tween().set_loops()
	bob.tween_property(self, "position:y", _base_y + BOB, BOB_TIME).set_trans(Tween.TRANS_SINE)
	bob.tween_property(self, "position:y", _base_y, BOB_TIME).set_trans(Tween.TRANS_SINE)


## Значок плавно растворяется, когда персонаж стоит рядом на возвышении (стол под значком):
## иначе он заслонял вид от первого лица.
func _process(delta: float) -> void:
	var target := 0.0
	for node in get_tree().get_nodes_in_group("lobby_character"):
		var person := node as Node3D
		var flat := Vector2(person.global_position.x - global_position.x,
			person.global_position.z - global_position.z).length()
		if flat < 1.6 and person.global_position.y > 0.4:
			target = 1.0
			break
	_fade = move_toward(_fade, target, delta * 3.0)
	modulate.a = 1.0 - _fade
	visible = _fade < 0.99
