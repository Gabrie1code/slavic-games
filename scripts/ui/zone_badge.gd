class_name ZoneBadge
extends Sprite3D
## Компактная «кнопка»-значок над местом, где можно что-то сделать (зона в лобби, горка, качели):
## цветная плашка с иконкой и коротким словом (assets/ui/prompts/<name>.png, см.
## tools/textures/prompt_badges.py). Всегда смотрит в камеру и плавно покачивается.

const BOB := 0.15
const BOB_TIME := 1.2

var _base_y := 0.0


## name — имя картинки без .png, height — на какой высоте висеть над точкой узла-родителя.
func setup(badge_name: String, height: float) -> ZoneBadge:
	texture = load("res://assets/ui/prompts/%s.png" % badge_name)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size = 0.0028
	shaded = false
	position.y += height
	return self


func _ready() -> void:
	_base_y = position.y
	var bob := create_tween().set_loops()
	bob.tween_property(self, "position:y", _base_y + BOB, BOB_TIME).set_trans(Tween.TRANS_SINE)
	bob.tween_property(self, "position:y", _base_y, BOB_TIME).set_trans(Tween.TRANS_SINE)
