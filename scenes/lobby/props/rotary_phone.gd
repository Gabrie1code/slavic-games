class_name RotaryPhone
extends Node3D
## Дисковый телефон на тумбочке. Один игрок за раз: снял трубку — она у его уха, рука поднята
## (видят все), к трубке тянется чёрный витой провод. С трубкой можно ходить, но недалеко:
## отошёл дальше CORD_LENGTH — трубка вырывается из рук и падает на пол, а через RESTORE_TIME
## сама «возвращается» на рычаг (как разбитая посуда). Пока трубка лежит на полу — телефоном
## пользоваться нельзя. Рядом с телефоном кнопка удара (ЛКМ/F) крутит диск; когда диск
## вернётся, над головой появляется облачко со смешной фразой.

const DIR := "res://assets/models/apartment/"
const DIAL_POS := Vector3(0, 0.108, 0.047)
const DIAL_TILT := deg_to_rad(16.0)
const HANDSET_POS := Vector3(0, 0.16, -0.07)
## Трубка у правого уха (координаты в части Head персонажа).
const EAR_POS := Vector3(0.31, 0.27, 0.0)
## Откуда выходит провод (сбоку корпуса) и на какой длине трубка вырывается.
const CORD_ANCHOR := Vector3(-0.11, 0.05, 0.0)
const CORD_LENGTH := 2.6
const CORD_SEGMENTS := 28
const CORD_COILS := 14.0
const RESTORE_TIME := 10.0
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

## Кто сейчас говорит (null — трубка на рычаге или на полу).
var user: PlayerData
## Трубку вырвали — лежит на полу, ждём восстановления.
var dropped := false

var _user_character: PlayerCharacter
var _dial: Node3D
var _handset: Node3D
var _dialing := false
var _bubble: Label3D
var _cord: Array[MeshInstance3D] = []


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
	_build_cord()


func _process(_delta: float) -> void:
	if user == null:
		return
	if not is_instance_valid(_user_character):
		_drop()
		return
	var flat := _user_character.global_position - global_position
	flat.y = 0.0
	if flat.length() > CORD_LENGTH:
		_drop() # отошёл слишком далеко — трубка вырвалась
		return
	_update_cord()


## Можно ли этому игроку взять трубку.
func can_use(p: PlayerData) -> bool:
	return not dropped and (user == null or user == p)


## Поднять трубку: она у уха персонажа, рука поднята, тянется провод. Ходить можно.
func pick_up(p: PlayerData, character: PlayerCharacter) -> void:
	if user != null or dropped:
		return
	user = p
	_user_character = character
	_handset.get_parent().remove_child(_handset)
	character.attach_to_part("Head", _handset)
	_handset.position = EAR_POS
	_handset.rotation = Vector3(0, 0, PI / 2) # трубка вертикально у щеки
	character.set_arm_pose(2.45, 0.35, 0.25)
	for piece in _cord:
		piece.visible = true
	_update_cord()


## Положить трубку на рычаг.
func hang_up() -> void:
	if user == null:
		return
	_release_user()
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


## Трубка вырвалась: падает на пол рядом с персонажем, через время возвращается на рычаг.
func _drop() -> void:
	var at := global_position
	if is_instance_valid(_user_character):
		at = _user_character.global_position
	_release_user()
	dropped = true
	_handset.get_parent().remove_child(_handset)
	get_parent().add_child(_handset)
	_set_layers(_handset, 1)
	_handset.global_position = at + Vector3(randf_range(-0.3, 0.3), 1.3, randf_range(-0.3, 0.3))
	_handset.rotation = Vector3(0, randf() * TAU, 0)
	var floor_y := (get_parent() as Node3D).global_position.y + 0.03
	var fall := create_tween()
	fall.tween_property(_handset, "global_position:y", floor_y, 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(RESTORE_TIME).timeout
	if not is_inside_tree():
		return
	_handset.get_parent().remove_child(_handset)
	_hang_handset()
	_handset.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_handset, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dropped = false


func _release_user() -> void:
	if is_instance_valid(_user_character):
		_user_character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.2)
	if _bubble and is_instance_valid(_bubble):
		_bubble.queue_free()
	user = null
	_user_character = null
	for piece in _cord:
		piece.visible = false


func _hang_handset() -> void:
	add_child(_handset)
	_set_layers(_handset, 1)
	_handset.position = HANDSET_POS
	_handset.rotation = Vector3.ZERO
	_handset.scale = Vector3.ONE


# ---------------- Витой провод ----------------

func _build_cord() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.008
	mesh.bottom_radius = 0.008
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 1
	var cord_mat := StandardMaterial3D.new()
	cord_mat.albedo_color = Color(0.03, 0.03, 0.035)
	cord_mat.roughness = 0.4
	for i in CORD_SEGMENTS:
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.material_override = cord_mat
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.top_level = true # ставим в мировых координатах
		piece.visible = false
		add_child(piece)
		_cord.append(piece)


## Провод от корпуса к трубке: провисает дугой и закручен пружинкой (волнистый).
func _update_cord() -> void:
	var from := to_global(CORD_ANCHOR)
	var to := _handset.global_position
	var span := from.distance_to(to)
	var sag := clampf(CORD_LENGTH - span, 0.0, CORD_LENGTH) * 0.35 + 0.05
	var side := (to - from).cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up := side.cross(to - from).normalized()
	var points: Array[Vector3] = []
	for i in CORD_SEGMENTS + 1:
		var t := float(i) / CORD_SEGMENTS
		var p := from.lerp(to, t) + Vector3.DOWN * sin(t * PI) * sag
		# Пружинка: маленький виток вокруг линии провода (не у самых концов).
		var coil := 0.025 * sin(t * PI)
		var a := t * CORD_COILS * TAU
		p += (side * cos(a) + up * sin(a)) * coil
		points.append(p)
	for i in CORD_SEGMENTS:
		var a := points[i]
		var b := points[i + 1]
		var piece := _cord[i]
		var length := maxf(a.distance_to(b), 0.001)
		var dir := (b - a) / length
		var helper := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
		var piece_basis := Basis.looking_at(dir, helper) * Basis(Vector3.RIGHT, PI / 2)
		var stretched := piece_basis * Basis.from_scale(Vector3(1, length, 1))
		piece.global_transform = Transform3D(stretched, (a + b) / 2.0)


func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)


func _model(model_name: String) -> Node3D:
	return (load(DIR + model_name + ".glb") as PackedScene).instantiate() as Node3D
