class_name RotaryPhone
extends Node3D
## Дисковый телефон на тумбочке. Один игрок за раз: поднял трубку — она у его уха (видят все),
## остальным действие «серое». С трубкой у уха кнопка удара (ЛКМ/F) крутит диск;
## когда диск вернётся назад, над головой появляется облачко со смешной фразой.

const DIR := "res://assets/models/apartment/"
const DIAL_POS := Vector3(0, 0.108, 0.047)
const DIAL_TILT := deg_to_rad(16.0)
const HANDSET_POS := Vector3(0, 0.16, -0.07)
## Трубка у правого уха (координаты в части Head персонажа).
const EAR_POS := Vector3(0.31, 0.27, 0.0)
const BUBBLE_TIME := 4.0
const PHRASES: Array[String] = [
	"Алло, это прачечная? — Нет, это Министерство культуры!",
	"Мама, я покушал! Можно ещё в «Денди» поиграть?",
	"Галя, колбасу выбросили! Беги, пока очередь маленькая!",
	"Алло, ЖЭК? У нас опять горячую воду отключили!",
	"Девушка, дайте межгород! Ташкент, срочно!",
	"Пейджер? Какой пейджер? У нас дисковый!",
	"Вовочка дома? Скажите, что Серёга звонил.",
	"Бабушка, это я! Пирожки с капустой уже готовы?",
	"Говорите громче, тут коммутатор шумит!",
	"Алло, шиномонтаж? Шины на «копейку» есть?",
	"Это радио? Поставьте «Ласковый май» для Светы из 5-го подъезда!",
	"Алло… Алло?! Опять линию перерезали…",
]

## Кто сейчас говорит (null — трубка лежит).
var user: PlayerData

var _user_character: PlayerCharacter
var _dial: Node3D
var _handset: Node3D
var _dialing := false
var _bubble: Label3D


func _ready() -> void:
	add_child(_model("phone_base"))
	var dial_mount := Node3D.new()
	dial_mount.position = DIAL_POS
	dial_mount.rotation.x = DIAL_TILT
	add_child(dial_mount)
	_dial = Node3D.new()
	dial_mount.add_child(_dial)
	# Диск в Blender крутится вокруг своей оси Z — в Godot это ось Y узла.
	_dial.add_child(_model("phone_dial"))
	_handset = _model("phone_handset")
	_hang_handset()


## Свободен ли телефон для этого игрока.
func can_use(p: PlayerData) -> bool:
	return user == null or user == p


## Поднять трубку: она переезжает к уху персонажа.
func pick_up(p: PlayerData, character: PlayerCharacter) -> void:
	if user != null:
		return
	user = p
	_user_character = character
	_handset.get_parent().remove_child(_handset)
	character.attach_to_part("Head", _handset)
	_handset.position = EAR_POS
	_handset.rotation = Vector3(0, 0, PI / 2) # трубка вертикально у щеки
	character.set_arm_pose(2.45, 0.35, 0.25)


## Положить трубку на место.
func hang_up() -> void:
	if user == null:
		return
	if is_instance_valid(_user_character):
		_user_character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)
	if _bubble and is_instance_valid(_bubble):
		_bubble.queue_free()
	user = null
	_user_character = null
	_handset.get_parent().remove_child(_handset)
	_hang_handset()


## Крутануть диск (если он не крутится). Когда вернётся — фраза в облачке.
func dial() -> void:
	if user == null or _dialing:
		return
	_dialing = true
	var digit := randi_range(1, 10)
	var angle := -deg_to_rad(40.0 + digit * 26.0) # по часовой стрелке, если смотреть сверху
	var tween := create_tween()
	tween.tween_property(_dial, "rotation:y", angle, 0.25 + digit * 0.03) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dial, "rotation:y", 0.0, 0.2 + digit * 0.07)
	tween.tween_callback(_on_dial_returned)


func _on_dial_returned() -> void:
	_dialing = false
	if user == null or not is_instance_valid(_user_character):
		return
	if _bubble and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = Label3D.new()
	_bubble.text = PHRASES.pick_random()
	_bubble.font_size = 40
	_bubble.outline_size = 0
	_bubble.modulate = Color(0.1, 0.08, 0.05)
	_bubble.width = 520
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.pixel_size = 0.004
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.position = Vector3(0, 2.45, 0)
	# Белое «облачко» под текстом — через фон Label3D нельзя, поэтому отдельная плашка.
	var cloud := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.3, 0.7)
	cloud.mesh = quad
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1, 1, 0.96, 0.95)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cloud_mat.no_depth_test = true
	cloud_mat.render_priority = -1
	cloud.material_override = cloud_mat
	cloud.position.z = -0.01
	_bubble.add_child(cloud)
	_bubble.render_priority = 1
	_user_character.add_child(_bubble)
	var bubble := _bubble
	get_tree().create_timer(BUBBLE_TIME).timeout.connect(func() -> void:
		if is_instance_valid(bubble):
			bubble.queue_free())


func _hang_handset() -> void:
	add_child(_handset)
	_set_layers(_handset, 1)
	_handset.position = HANDSET_POS
	_handset.rotation = Vector3.ZERO


func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)


func _model(model_name: String) -> Node3D:
	return (load(DIR + model_name + ".glb") as PackedScene).instantiate() as Node3D
