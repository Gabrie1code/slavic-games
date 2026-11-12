extends Node3D
## Тестовое лобби: игроки подключаются со своих устройств и бегают по комнате.
##
## Вход:  Пробел/E — левая клавиатура, Enter — правая клавиатура, A — геймпад.
## Выход: Q, Backspace/Shift или B на геймпаде.
## Начать партию: Tab или Start на геймпаде.
## Если есть свободные места — сначала спросим, сколько добавить ботов.
## Рынок (справа): подойти и нажать кнопку подтверждения — откроется гардероб.

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const SPAWN_RADIUS := 3.0
const ROUNDS := 5
const MARKET_POS := Vector3(7.0, 0.0, -1.6)
const MARKET_RADIUS := 2.0
const WARDROBE_SLOTS: Array[int] = [
	Cosmetics.Slot.HAT, Cosmetics.Slot.JACKET, Cosmetics.Slot.PANTS,
	Cosmetics.Slot.SHOES, Cosmetics.Slot.ACCESSORY,
]

var _characters: Dictionary = {} # PlayerData.id -> персонаж
var _slot_panels: Array[PanelContainer] = []

## Окно «Добавить ботов?»
var _bot_dialog: PanelContainer
var _bot_count_label: Label
var _bot_count := 0

## Открытые гардеробы: PlayerData.id -> {"panel": PanelContainer, "label": Label, "row": int}
var _wardrobes: Dictionary = {}

@onready var _players_root: Node3D = $Players
@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	_camera.look_at_from_position(Vector3(0, 9.5, 10.5), Vector3(0, 0, 0.5))
	_sun.rotation_degrees = Vector3(-55, -35, 0)
	_build_ui()
	_build_market()

	# Боты прошлой партии в лобби не нужны: при старте спросим заново.
	PlayerManager.remove_bots()
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.player_left.connect(_on_player_left)
	# Игроки, которые уже вошли раньше (например, вернулись в лобби).
	for p in PlayerManager.players:
		_on_player_joined(p)
	_refresh_slots()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_ESCAPE:
			if _bot_dialog.visible:
				_close_bot_dialog()
			else:
				get_tree().quit()
			return
		if key.physical_keycode == KEY_TAB:
			_start_match()
			return
		if _bot_dialog.visible:
			return
		var scheme := InputSetup.keyboard_join_scheme(key.physical_keycode)
		if scheme != -1:
			PlayerManager.add_local_player(scheme as PlayerData.DeviceKind)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if _bot_dialog.visible and button.button_index != JOY_BUTTON_START:
			return
		if button.button_index == JOY_BUTTON_A:
			PlayerManager.add_local_player(PlayerData.DeviceKind.JOYPAD, button.device)
		elif button.button_index == JOY_BUTTON_START:
			_start_match()


## Tab / Start: если есть свободные места — спросить про ботов, иначе сразу старт.
func _start_match() -> void:
	if PlayerManager.players.is_empty():
		return
	_close_all_wardrobes()
	if _bot_dialog.visible:
		_confirm_bots()
	elif PlayerManager.free_slots() > 0:
		_open_bot_dialog()
	else:
		_launch()


func _launch() -> void:
	MatchState.start_new_match(ROUNDS)
	SceneManager.change_scene(MatchState.SCENE_BOARD)


func _process(_delta: float) -> void:
	if _bot_dialog.visible:
		_process_bot_dialog()
		return
	for p in PlayerManager.players.duplicate():
		if p.input == null or p.is_bot():
			continue
		if _wardrobes.has(p.id):
			_process_wardrobe(p)
		elif p.input.is_just_pressed("confirm") and _is_at_market(p):
			_open_wardrobe(p)
		elif p.input.is_just_pressed("cancel"):
			PlayerManager.remove_player(p)


# ---------------- Рынок и гардероб ----------------

func _is_at_market(p: PlayerData) -> bool:
	if not _characters.has(p.id):
		return false
	var pos: Vector3 = (_characters[p.id] as Node3D).global_position
	return Vector2(pos.x - MARKET_POS.x, pos.z - MARKET_POS.z).length() < MARKET_RADIUS


func _open_wardrobe(p: PlayerData) -> void:
	var character: PlayerCharacter = _characters[p.id]
	character.input_enabled = false
	character.velocity = Vector3.ZERO
	character.rotation.y = PI # лицом к камере, чтобы было видно наряд

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.06, 0.92)
	style.border_color = p.color
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(430, 0)
	# Окна разных игроков — друг под другом у правого края.
	panel.position = Vector2(get_viewport().get_visible_rect().size.x - 460, 150 + p.slot * 215)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	panel.add_child(label)
	_ui.add_child(panel)
	_wardrobes[p.id] = {"panel": panel, "label": label, "row": 0}
	_update_wardrobe(p)


func _close_wardrobe(p: PlayerData) -> void:
	if not _wardrobes.has(p.id):
		return
	(_wardrobes[p.id]["panel"] as Node).queue_free()
	_wardrobes.erase(p.id)
	PlayerManager.save_outfit(p)
	if _characters.has(p.id):
		(_characters[p.id] as PlayerCharacter).input_enabled = true


func _close_all_wardrobes() -> void:
	for p in PlayerManager.players:
		_close_wardrobe(p)


## Вверх/вниз — выбор вещи (шапка, куртка...), влево/вправо — листать, подтвердить/отмена — готово.
func _process_wardrobe(p: PlayerData) -> void:
	var state: Dictionary = _wardrobes[p.id]
	if p.input.is_just_pressed("confirm") or p.input.is_just_pressed("cancel"):
		_close_wardrobe(p)
		return
	var row: int = state["row"]
	if p.input.is_just_pressed("move_up"):
		state["row"] = posmod(row - 1, WARDROBE_SLOTS.size())
	elif p.input.is_just_pressed("move_down"):
		state["row"] = posmod(row + 1, WARDROBE_SLOTS.size())
	elif p.input.is_just_pressed("move_left") or p.input.is_just_pressed("move_right"):
		var slot := WARDROBE_SLOTS[row]
		var options: Array[String] = [""]
		options.append_array(Cosmetics.items_for_slot(slot as Cosmetics.Slot))
		var current: String = p.outfit.get(slot, "")
		var step := -1 if p.input.is_just_pressed("move_left") else 1
		var next_id := options[posmod(options.find(current) + step, options.size())]
		if next_id == "":
			p.outfit.erase(slot)
		else:
			p.outfit[slot] = next_id
		(_characters[p.id] as PlayerCharacter).wear(slot, next_id)
	else:
		return
	_update_wardrobe(p)


func _update_wardrobe(p: PlayerData) -> void:
	var state: Dictionary = _wardrobes[p.id]
	var lines: PackedStringArray = ["%s — рынок" % p.display_name, ""]
	for i in WARDROBE_SLOTS.size():
		var slot := WARDROBE_SLOTS[i]
		var item := Cosmetics.item_name(p.outfit.get(slot, ""))
		var marker := "▶ " if i == state["row"] else "   "
		lines.append("%s%s:  ◀ %s ▶" % [marker, Cosmetics.SLOT_NAMES[slot], item])
	lines.append("")
	lines.append("вверх/вниз — вещь, влево/вправо — листать, подтвердить — готово")
	(state["label"] as Label).text = "\n".join(lines)


func _build_market() -> void:
	var market := Node3D.new()
	market.name = "Market"
	market.position = MARKET_POS
	add_child(market)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("7a4a2a")
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("c0392b")
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("eeeeee")
	# Прилавок, стойки и полосатый навес.
	_add_box(market, Vector3(3.2, 0.9, 0.9), Vector3(0, 0.45, -1.9), wood, true)
	for x in [-1.5, 1.5]:
		_add_box(market, Vector3(0.12, 2.6, 0.12), Vector3(x, 1.3, -2.3), wood, true)
	for i in 6:
		_add_box(market, Vector3(0.55, 0.08, 1.4), Vector3(-1.38 + i * 0.55, 2.62, -2.0),
			red if i % 2 == 0 else white, false)
	# На прилавке выложен товар.
	for item_info in [["hat_kepka", -0.8], ["hat_ushanka", 0.0], ["acc_glasses_drops", 0.8]]:
		var item := Cosmetics.load_item(item_info[0]).instantiate() as Node3D
		item.position = Vector3(item_info[1], -0.45, -1.9)
		market.add_child(item)

	var sign := Label3D.new()
	sign.text = "РЫНОК"
	sign.font_size = 96
	sign.outline_size = 18
	sign.modulate = Color("f6c343")
	sign.position = Vector3(0, 3.1, -2.0)
	market.add_child(sign)

	# Круг «встань сюда».
	var zone := MeshInstance3D.new()
	var zone_mesh := CylinderMesh.new()
	zone_mesh.top_radius = MARKET_RADIUS
	zone_mesh.bottom_radius = MARKET_RADIUS
	zone_mesh.height = 0.02
	zone_mesh.radial_segments = 24
	zone.mesh = zone_mesh
	var zone_mat := StandardMaterial3D.new()
	zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_mat.albedo_color = Color(0.96, 0.76, 0.26, 0.3)
	zone.material_override = zone_mat
	zone.position.y = 0.04
	market.add_child(zone)

	var hint := Label3D.new()
	hint.text = "Встань в круг и нажми\nПробел / Enter / A"
	hint.font_size = 36
	hint.outline_size = 10
	hint.rotation_degrees.x = -90
	hint.position = Vector3(0, 0.06, 0.6)
	market.add_child(hint)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, solid: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	if not solid:
		parent.add_child(mesh_instance)
		return
	var body := StaticBody3D.new()
	body.position = pos
	mesh_instance.position = Vector3.ZERO
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)


# ---------------- Окно ботов ----------------

func _open_bot_dialog() -> void:
	_close_all_wardrobes()
	_bot_count = PlayerManager.free_slots()
	_update_bot_dialog()
	_bot_dialog.visible = true
	_set_characters_input(false)


func _close_bot_dialog() -> void:
	_bot_dialog.visible = false
	_set_characters_input(true)


func _confirm_bots() -> void:
	_bot_dialog.visible = false
	for i in _bot_count:
		PlayerManager.add_bot()
	_launch()


## Управлять окном может любой живой игрок своими кнопками.
func _process_bot_dialog() -> void:
	for p in PlayerManager.players:
		if p.input == null or p.is_bot():
			continue
		if p.input.is_just_pressed("move_left") or p.input.is_just_pressed("move_down"):
			_bot_count = maxi(0, _bot_count - 1)
			_update_bot_dialog()
		elif p.input.is_just_pressed("move_right") or p.input.is_just_pressed("move_up"):
			_bot_count = mini(PlayerManager.free_slots(), _bot_count + 1)
			_update_bot_dialog()
		elif p.input.is_just_pressed("confirm"):
			_confirm_bots()
			return
		elif p.input.is_just_pressed("cancel"):
			_close_bot_dialog()
			return


func _update_bot_dialog() -> void:
	_bot_count_label.text = "◀   %d   ▶" % _bot_count


func _set_characters_input(enabled: bool) -> void:
	for character: PlayerCharacter in _characters.values():
		character.input_enabled = enabled


func _on_player_joined(p: PlayerData) -> void:
	var character := CHARACTER_SCENE.instantiate()
	var angle := TAU * p.slot / PlayerManager.MAX_PLAYERS
	var spawn := Vector3(sin(angle), 0.0, cos(angle)) * SPAWN_RADIUS + Vector3.UP * 0.5
	character.setup(p, spawn)
	_players_root.add_child(character)
	_characters[p.id] = character
	_refresh_slots()


func _on_player_left(p: PlayerData) -> void:
	if _wardrobes.has(p.id):
		(_wardrobes[p.id]["panel"] as Node).queue_free()
		_wardrobes.erase(p.id)
	if _characters.has(p.id):
		_characters[p.id].queue_free()
		_characters.erase(p.id)
	_refresh_slots()


# ---------------- Интерфейс ----------------

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 32)
	_ui.add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var title := Label.new()
	title.text = "SLAVIC GAMES"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("f6c343"))
	title.add_theme_color_override("font_outline_color", Color("7a1410"))
	title.add_theme_constant_override("outline_size", 16)
	column.add_child(title)

	var hint := Label.new()
	hint.text = ("Вход: Пробел (WASD) · Enter (стрелки) · A (геймпад)\n"
		+ "Прыжок: та же кнопка · Выйти: Q / Backspace / B · Закрыть игру: Esc\n"
		+ "Переодеться: зайди на РЫНОК справа · НАЧАТЬ ПАРТИЮ: Tab или Start на геймпаде")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 8)
	column.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_build_bot_dialog()

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 12)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(slots)
	for i in PlayerManager.MAX_PLAYERS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(280, 90)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		panel.add_child(label)
		slots.add_child(panel)
		_slot_panels.append(panel)


func _refresh_slots() -> void:
	for i in _slot_panels.size():
		var panel := _slot_panels[i]
		var label := panel.get_child(0) as Label
		var p := PlayerManager.get_by_slot(i)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		if p:
			style.bg_color = p.color.darkened(0.25)
			label.text = "%s\n%s" % [p.display_name, p.device_label()]
			label.add_theme_color_override("font_color", Color.WHITE)
		else:
			style.bg_color = Color(0, 0, 0, 0.45)
			label.text = "Свободно"
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		panel.add_theme_stylebox_override("panel", style)


func _build_bot_dialog() -> void:
	_bot_dialog = PanelContainer.new()
	_bot_dialog.visible = false
	_bot_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_bot_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bot_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.07, 0.95)
	style.border_color = Color("f6c343")
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(32)
	_bot_dialog.add_theme_stylebox_override("panel", style)
	_ui.add_child(_bot_dialog)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_bot_dialog.add_child(column)
	for line in [
		["Добавить ботов на свободные места?", 34, Color("f6c343")],
		["Сколько ботов:", 24, Color.WHITE],
	]:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		column.add_child(label)

	_bot_count_label = Label.new()
	_bot_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bot_count_label.add_theme_font_size_override("font_size", 64)
	column.add_child(_bot_count_label)

	var hint := Label.new()
	hint.text = ("Влево/вправо — меньше/больше\n"
		+ "Пробел / Enter / A или Tab — начать · Q / Backspace / B или Esc — назад")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.modulate.a = 0.75
	column.add_child(hint)
