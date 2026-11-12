class_name DressingRoom
extends Control
## Примерочная одного игрока: слева крупно его персонаж, справа список вещей.
##
## Открывается на рынке в лобби. Если примеряют несколько игроков — экран делится,
## у каждого своя примерочная. Для шапки и лица камера приближается к голове.
##
## Управление (кнопками своего устройства):
##   вверх/вниз — слот, влево/вправо — листать вещи (примерка),
##   подтвердить — купить закрытую вещь или выйти, отмена — выйти.
## При выходе примеренные, но не купленные вещи снимаются.

signal closed(player: PlayerData)

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const SLOTS: Array[int] = [
	Cosmetics.Slot.HAT, Cosmetics.Slot.FACE, Cosmetics.Slot.JACKET,
	Cosmetics.Slot.PANTS, Cosmetics.Slot.SHOES, Cosmetics.Slot.NECK,
]
## Для этих слотов камера показывает голову крупным планом.
const CLOSEUP_SLOTS: Array[int] = [Cosmetics.Slot.HAT, Cosmetics.Slot.FACE]
const CAM_BODY := [Vector3(0, 1.0, 3.3), Vector3(0, 0.85, 0)]
const CAM_HEAD := [Vector3(0, 1.36, 2.4), Vector3(0, 1.22, 0)]
const GOLD := Color("f6c343")

var player: PlayerData
## Персонаж игрока в лобби: одежда меняется и на нём.
var lobby_character: PlayerCharacter

var _row := 0
var _saved: Dictionary = {}
var _message := ""
var _time := 0.0

var _mannequin: PlayerCharacter
var _camera: Camera3D
var _cam_target: Array = CAM_BODY
var _wallet_label: Label
var _message_label: Label
var _hint_label: Label
var _title_label: Label
var _row_panels: Array[PanelContainer] = []
var _row_names: Array[Label] = []
var _row_items: Array[Label] = []
var _row_prices: Array[Label] = []


func setup(p: PlayerData, character: PlayerCharacter) -> void:
	player = p
	lobby_character = character
	_saved = p.outfit.duplicate()


func _ready() -> void:
	_build()
	resized.connect(_apply_font_sizes)
	_apply_font_sizes()
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	# Персонаж покачивается, поворачиваясь то одним, то другим боком.
	_mannequin.rotation.y = PI + sin(_time * 0.8) * 0.9
	var pos: Vector3 = _cam_target[0]
	_camera.position = _camera.position.lerp(pos, minf(1.0, delta * 6.0))
	_camera.look_at(_camera.position + (Vector3(_cam_target[1]) - pos))
	_handle_input()


## Закрыть примерочную: снять некупленное, сохранить наряд.
func close() -> void:
	for slot: int in SLOTS:
		var id: String = player.outfit.get(slot, "")
		if not PlayerManager.owns(player, id):
			var back: String = _saved.get(slot, "")
			if back == "":
				player.outfit.erase(slot)
			else:
				player.outfit[slot] = back
			if lobby_character:
				lobby_character.wear(slot, back)
	PlayerManager.save_outfit(player)
	closed.emit(player)


## Обновить надписи (например, после пополнения кошелька).
func refresh() -> void:
	_refresh()


func _handle_input() -> void:
	var input := player.input
	# Первые доли секунды кнопки не слушаем: иначе нажатие, которым открыли
	# примерочную, тут же её закроет.
	if input == null or _time < 0.2:
		return
	var slot := SLOTS[_row]
	var current: String = player.outfit.get(slot, "")
	if input.is_just_pressed("cancel"):
		close()
		return
	if input.is_just_pressed("confirm"):
		if PlayerManager.owns(player, current):
			close()
			return
		if PlayerManager.buy(player, current):
			_message = "Куплено: %s!" % Cosmetics.item_name(current)
		else:
			_message = "Не хватает рублей: нужно %d ₽" % Cosmetics.price(current)
	elif input.is_just_pressed("move_up"):
		_select_row(_row - 1)
	elif input.is_just_pressed("move_down"):
		_select_row(_row + 1)
	elif input.is_just_pressed("move_left") or input.is_just_pressed("move_right"):
		var options: Array[String] = [""]
		options.append_array(Cosmetics.items_for_slot(slot as Cosmetics.Slot))
		var step := -1 if input.is_just_pressed("move_left") else 1
		var next_id := options[posmod(options.find(current) + step, options.size())]
		if next_id == "":
			player.outfit.erase(slot)
		else:
			player.outfit[slot] = next_id
		_mannequin.wear(slot, next_id)
		if lobby_character:
			lobby_character.wear(slot, next_id)
		_message = ""
	else:
		return
	_refresh()


func _select_row(row: int) -> void:
	_row = posmod(row, SLOTS.size())
	_message = ""
	_cam_target = CAM_HEAD if CLOSEUP_SLOTS.has(SLOTS[_row]) else CAM_BODY


func _refresh() -> void:
	_wallet_label.text = "Кошелёк: %d ₽" % PlayerManager.wallet(player)
	for i in SLOTS.size():
		var slot := SLOTS[i]
		var id: String = player.outfit.get(slot, "")
		var owned := PlayerManager.owns(player, id)
		_row_names[i].text = Cosmetics.SLOT_NAMES[slot]
		_row_items[i].text = "◀  %s  ▶" % Cosmetics.item_name(id)
		_row_prices[i].text = "" if owned else "%d ₽" % Cosmetics.price(id)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_content_margin_all(10)
		if i == _row:
			style.bg_color = Color(0.35, 0.22, 0.12, 0.95)
			style.border_color = GOLD
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0.18, 0.12, 0.09, 0.85)
		_row_panels[i].add_theme_stylebox_override("panel", style)

	var row_id: String = player.outfit.get(SLOTS[_row], "")
	if PlayerManager.owns(player, row_id):
		_hint_label.text = "↑↓ — что меняем   ←→ — листать\nПодтвердить — готово   Отмена — выйти"
	else:
		_hint_label.text = "Примерка. Подтвердить — купить за %d ₽\nОтмена — выйти без покупки" \
			% Cosmetics.price(row_id)
	_message_label.text = _message


# ---------------- Построение экрана ----------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("2b1d18")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var frame := ReferenceRect.new()
	frame.border_color = player.color
	frame.border_width = 4
	frame.editor_only = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(split)
	add_child(frame)

	# Слева: 3D-примерочная со своим «миром».
	var view_container := SubViewportContainer.new()
	view_container.stretch = true
	view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_container.size_flags_stretch_ratio = 1.0
	split.add_child(view_container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	view_container.add_child(viewport)
	_build_room(viewport)

	# Справа: список вещей.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 1.1
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	split.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_title_label = _label("РЫНОК · %s" % player.display_name, GOLD)
	column.add_child(_title_label)
	_wallet_label = _label("", Color.WHITE)
	column.add_child(_wallet_label)
	for i in SLOTS.size():
		var panel := PanelContainer.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var name_label := _label("", Color("c9b98f"))
		name_label.custom_minimum_size.x = 150
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var item_label := _label("", Color.WHITE)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price_label := _label("", Color("ff9f5a"))
		row.add_child(name_label)
		row.add_child(item_label)
		row.add_child(price_label)
		column.add_child(panel)
		_row_panels.append(panel)
		_row_names.append(name_label)
		_row_items.append(item_label)
		_row_prices.append(price_label)
	_message_label = _label("", Color("a8f0a0"))
	column.add_child(_message_label)
	_hint_label = _label("", Color(1, 1, 1, 0.7))
	column.add_child(_hint_label)


## 3D-сцена примерочной: ковёр на стене, пол, свет, персонаж.
func _build_room(viewport: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("3a2a22")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.94, 0.86)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	viewport.add_child(sun)

	# Ковёр на стене — главный предмет советского интерьера.
	var carpet := MeshInstance3D.new()
	var carpet_mesh := BoxMesh.new()
	carpet_mesh.size = Vector3(3.2, 2.4, 0.05)
	carpet.mesh = carpet_mesh
	var carpet_mat := StandardMaterial3D.new()
	carpet_mat.albedo_color = Color("7a1c1a")
	carpet.material_override = carpet_mat
	carpet.position = Vector3(0, 1.4, -1.0)
	viewport.add_child(carpet)
	var border := MeshInstance3D.new()
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(3.4, 2.6, 0.04)
	border.mesh = border_mesh
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color("c8962e")
	border.material_override = border_mat
	border.position = Vector3(0, 1.4, -1.03)
	viewport.add_child(border)

	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(8, 0.1, 6)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("5a3a22")
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0, -0.05, 0)
	viewport.add_child(floor_mesh)

	_mannequin = CHARACTER_SCENE.instantiate()
	_mannequin.setup(player, Vector3.ZERO)
	viewport.add_child(_mannequin)
	_mannequin.set_physics_process(false)
	_mannequin.input_enabled = false
	_mannequin.show_name(false)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.position = CAM_BODY[0]
	viewport.add_child(_camera)
	_camera.look_at(CAM_BODY[1])


## Крупный шрифт, если примерочная одна на экран; мельче — если экран поделён.
func _apply_font_sizes() -> void:
	var scale_factor := clampf(size.y / 1080.0, 0.5, 1.0)
	var base := int(36 * scale_factor)
	_title_label.add_theme_font_size_override("font_size", int(base * 1.3))
	_wallet_label.add_theme_font_size_override("font_size", base)
	for i in SLOTS.size():
		_row_names[i].add_theme_font_size_override("font_size", int(base * 0.8))
		_row_names[i].custom_minimum_size.x = 170 * scale_factor
		_row_items[i].add_theme_font_size_override("font_size", base)
		_row_prices[i].add_theme_font_size_override("font_size", base)
	_message_label.add_theme_font_size_override("font_size", int(base * 0.8))
	_hint_label.add_theme_font_size_override("font_size", int(base * 0.6))


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	return label
