extends Node3D
## Тестовое лобби: игроки подключаются со своих устройств и бегают по комнате.
##
## Вход:  Пробел/E — левая клавиатура, Enter — правая клавиатура, A — геймпад.
## Выход: Q, Backspace/Shift или B на геймпаде.
## Начать партию: Tab или Start на геймпаде.

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const SPAWN_RADIUS := 3.0
const ROUNDS := 5

var _characters: Dictionary = {} # PlayerData.id -> персонаж
var _slot_panels: Array[PanelContainer] = []

@onready var _players_root: Node3D = $Players
@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	_camera.look_at_from_position(Vector3(0, 9.5, 10.5), Vector3(0, 0, 0.5))
	_sun.rotation_degrees = Vector3(-55, -35, 0)
	_build_ui()

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
			get_tree().quit()
			return
		if key.physical_keycode == KEY_TAB:
			_start_match()
			return
		var scheme := InputSetup.keyboard_join_scheme(key.physical_keycode)
		if scheme != -1:
			PlayerManager.add_local_player(scheme as PlayerData.DeviceKind)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.button_index == JOY_BUTTON_A:
			PlayerManager.add_local_player(PlayerData.DeviceKind.JOYPAD, button.device)
		elif button.button_index == JOY_BUTTON_START:
			_start_match()


func _start_match() -> void:
	if PlayerManager.players.is_empty():
		return
	MatchState.start_new_match(ROUNDS)
	SceneManager.change_scene(MatchState.SCENE_BOARD)


func _process(_delta: float) -> void:
	for p in PlayerManager.players.duplicate():
		if p.input and p.input.is_just_pressed("cancel"):
			PlayerManager.remove_player(p)


func _on_player_joined(p: PlayerData) -> void:
	var character := CHARACTER_SCENE.instantiate()
	var angle := TAU * p.slot / PlayerManager.MAX_PLAYERS
	var spawn := Vector3(sin(angle), 0.0, cos(angle)) * SPAWN_RADIUS + Vector3.UP * 0.5
	character.setup(p, spawn)
	_players_root.add_child(character)
	_characters[p.id] = character
	_refresh_slots()


func _on_player_left(p: PlayerData) -> void:
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
		+ "НАЧАТЬ ПАРТИЮ: Tab или Start на геймпаде")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 8)
	column.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

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
