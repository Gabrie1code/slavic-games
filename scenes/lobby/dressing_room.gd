class_name DressingRoom
extends LobbyRoom
## Примерочная одного игрока: слева крупно его персонаж, справа список вещей.
##
## Открывается на рынке в лобби. Если примеряют несколько игроков — экран делится,
## у каждого своя примерочная. Для шапки и лица камера приближается к голове.
##
## Управление кнопками своего устройства или мышью:
##   вверх/вниз (или клик по строке) — слот;
##   влево/вправо (или стрелки ◀ ▶) — листать вещи, вещь сразу примеряется;
##   подтвердить (или кнопка «Купить и надеть») — купить закрытую вещь;
##   на своей вещи подтвердить / отмена (или кнопка «Готово») — выйти.
## При выходе примеренные, но не купленные вещи снимаются.

## Игрок сменил цвет (лобби обновит слоты игроков).
signal color_changed(player: PlayerData)

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")
const SLOTS: Array[int] = [
	Cosmetics.Slot.HAT, Cosmetics.Slot.FACE, Cosmetics.Slot.JACKET,
	Cosmetics.Slot.PANTS, Cosmetics.Slot.SHOES, Cosmetics.Slot.NECK,
]
## Для этих слотов камера показывает голову крупным планом.
const CLOSEUP_SLOTS: Array[int] = [Cosmetics.Slot.HAT, Cosmetics.Slot.FACE]
const CAM_BODY := [Vector3(0, 1.0, 3.3), Vector3(0, 0.85, 0)]
const CAM_HEAD := [Vector3(0, 1.36, 2.4), Vector3(0, 1.22, 0)]
## Строки: слоты одежды, затем «Цвет», затем строка кнопок («Купить и надеть», «Готово»).
const COLOR_ROW := 6
const BUTTONS_ROW := 7
const GOLD := Color("f6c343")
const GREEN := Color("8fd694")
const RED := Color("ff7a6b")

## Персонаж игрока в лобби: одежда меняется и на нём.
var lobby_character: PlayerCharacter

var _row := 0
## Какой цвет сейчас показан в строке «Цвет» (может быть занятый — тогда не применён).
var _color_candidate := 0
## В строке кнопок: 0 — «Купить и надеть», 1 — «Готово».
var _button_focus := 1
## Вещь, на которую смотрит кнопка «Купить и надеть»: последняя выбранная строка одежды.
var _item_row := 0
var _saved: Dictionary = {}
## Слоты, которые освободились из-за «занятости» (платье ↔ штаны) во время примерки.
var _conflict_cleared: Array[int] = []
var _message := ""
var _message_color := GREEN
var _time := 0.0

var _mannequin: PlayerCharacter
var _camera: Camera3D
var _cam_target: Array = CAM_BODY
var _wallet: MoneyLabel
var _confirm: ConfirmDialog
## Вещь, которую подтверждаем в окне покупки.
var _pending_buy := ""
var _title_label: Label
var _message_label: Label
var _hint_label: Label
var _buy_button: Button
var _done_button: Button
var _shortage_label: Label
var _row_panels: Array[PanelContainer] = []
var _row_names: Array[Label] = []
var _row_items: Array[Label] = []
var _row_prices: Array[Label] = []
var _arrow_buttons: Array[Button] = []


func setup(p: PlayerData, character: PlayerCharacter) -> void:
	player = p
	lobby_character = character
	_saved = p.outfit.duplicate()
	_color_candidate = p.color_index


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
	# Вернуть вещи, снятые из-за некупленной примерки (например, штаны под платьем).
	for slot in _conflict_cleared:
		var back: String = _saved.get(slot, "")
		if player.outfit.get(slot, "") == "" and back != "" \
				and Cosmetics.covered_by(player.outfit, slot) == "":
			player.outfit[slot] = back
			_mannequin.wear(slot, back)
			if lobby_character:
				lobby_character.wear(slot, back)
	PlayerManager.save_outfit(player)
	closed.emit(player)


## Обновить надписи (например, после пополнения кошелька).
func refresh() -> void:
	_refresh()


# ---------------- Действия (кнопки устройства и мышь) ----------------

func _handle_input() -> void:
	var input := player.input
	# Первые доли секунды кнопки не слушаем: иначе нажатие, которым открыли
	# примерочную, тут же её закроет.
	if input == null or _time < 0.2:
		return
	# Пока открыто окно подтверждения — кнопки только для него.
	if _confirm.handle_input(input):
		return
	if input.is_just_pressed("cancel"):
		close()
	elif input.menu_just_pressed("confirm"):
		if _row == BUTTONS_ROW:
			if _button_focus == 0:
				_buy_current()
			else:
				close()
		elif _row == COLOR_ROW:
			if _color_candidate == player.color_index:
				close()
		elif PlayerManager.owns(player, _current_id()):
			close()
		else:
			_buy_current()
	elif input.menu_just_pressed("move_up"):
		_select_row(_row - 1)
	elif input.menu_just_pressed("move_down"):
		_select_row(_row + 1)
	elif input.menu_just_pressed("move_left"):
		_cycle_item(-1)
	elif input.menu_just_pressed("move_right"):
		_cycle_item(1)


## Строк в списке (одежда + цвет), без строки кнопок.
func _row_count() -> int:
	return SLOTS.size() + 1


## Слот одежды строки (для «Цвета» и кнопок — -1).
func _slot_at(row: int) -> int:
	return SLOTS[row] if row < SLOTS.size() else -1


func _current_id() -> String:
	var row := _row if _row < SLOTS.size() else _item_row
	return player.outfit.get(SLOTS[row], "")


func _select_row(row: int) -> void:
	# Листаем по кругу: одежда → цвет → кнопки → снова шапка.
	_row = posmod(row, _row_count() + 1)
	if _row < SLOTS.size():
		_item_row = _row
	if _row != COLOR_ROW:
		_color_candidate = player.color_index # ушли со строки — показываем свой цвет
	_message = ""
	_cam_target = CAM_HEAD if CLOSEUP_SLOTS.has(_slot_at(_row)) else CAM_BODY
	_refresh()


## Листать цвета. Свободный цвет применяется сразу, занятый — только показывается.
func _cycle_color(step: int) -> void:
	_color_candidate = posmod(_color_candidate + step, PlayerManager.COLORS.size())
	if PlayerManager.set_color(player, _color_candidate):
		_mannequin.set_player_color(player.color)
		if lobby_character:
			lobby_character.set_player_color(player.color)
		color_changed.emit(player)
	_message = ""
	_refresh()


## Листать вещи в выбранном слоте (по кругу, «Ничего» — тоже вариант). Вещь сразу примеряется.
func _cycle_item(step: int) -> void:
	if _row == COLOR_ROW:
		_cycle_color(step)
		return
	if _row == BUTTONS_ROW:
		_button_focus = posmod(_button_focus + step, 2)
		_refresh()
		return
	var slot := _slot_at(_row)
	var options: Array[String] = [""]
	options.append_array(Cosmetics.items_for_slot(slot as Cosmetics.Slot))
	var next_id := options[posmod(options.find(_current_id()) + step, options.size())]
	# Платье занимает и штаны: надели платье — штаны снялись (и наоборот). Запоминаем,
	# что сняли, чтобы при выходе вернуть, если примерка не куплена.
	for cleared in Cosmetics.equip(player.outfit, slot, next_id):
		if not _conflict_cleared.has(cleared):
			_conflict_cleared.append(cleared)
	_mannequin.wear(slot, next_id)
	if lobby_character:
		lobby_character.wear(slot, next_id)
	_message = ""
	_refresh()


## Купить: сначала окно «Купить … за … ₽?», покупка — только после «Да».
func _buy_current() -> void:
	var id := _current_id()
	if PlayerManager.owns(player, id):
		return
	if PlayerManager.wallet(player) < Cosmetics.price(id):
		_message = "Не хватает рублей"
		_message_color = RED
		_refresh()
		return
	_pending_buy = id
	_confirm.ask("Купить «%s» за %d ₽?" % [Cosmetics.item_name(id), Cosmetics.price(id)])


func _on_confirm_answered(yes: bool) -> void:
	var id := _pending_buy
	_pending_buy = ""
	if not yes or id == "":
		return
	if PlayerManager.buy(player, id):
		_message = "Куплено: %s!" % Cosmetics.item_name(id)
		_message_color = GREEN
		_wallet.set_amount(PlayerManager.wallet(player))
	else:
		_message = "Не хватает рублей"
		_message_color = RED
	_refresh()


func _on_arrow(row: int, step: int) -> void:
	if row != _row:
		_select_row(row)
	_cycle_item(step)


func _on_row_clicked(event: InputEvent, row: int) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_select_row(row)


# ---------------- Отображение ----------------

func _refresh() -> void:
	var wallet := PlayerManager.wallet(player)
	if _wallet.get_meta("ready", false) == false:
		_wallet.set_amount(wallet, false)
		_wallet.set_meta("ready", true)
	elif _pending_buy == "":
		_wallet.set_amount(wallet) # пополнили (F9) или потратили — анимация счётчика
	var color_owner := PlayerManager.color_owner(_color_candidate, player)
	for i in _row_count():
		if i == COLOR_ROW:
			_row_names[i].text = "Цвет"
			_row_items[i].text = "■  " + PlayerManager.COLOR_NAMES[_color_candidate]
			_row_items[i].add_theme_color_override("font_color",
				PlayerManager.COLORS[_color_candidate].lightened(0.15))
			_row_prices[i].text = "Занято" if color_owner else ""
		else:
			var slot := _slot_at(i)
			var id: String = player.outfit.get(slot, "")
			var owned := PlayerManager.owns(player, id)
			_row_names[i].text = Cosmetics.SLOT_NAMES[slot]
			_row_items[i].text = Cosmetics.item_name(id)
			var blocker := Cosmetics.covered_by(player.outfit, slot)
			if id == "" and blocker != "":
				_row_items[i].text = "Занято: " + Cosmetics.item_name(blocker)
			_row_prices[i].text = "" if owned else "%d ₽" % Cosmetics.price(id)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_content_margin_all(8)
		if i == _row:
			style.bg_color = Color(0.35, 0.22, 0.12, 0.95)
			style.border_color = GOLD
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0.18, 0.12, 0.09, 0.85)
		_row_panels[i].add_theme_stylebox_override("panel", style)

	# Большая кнопка под списком: что будет с выбранной вещью.
	var id := _current_id()
	var item_title := Cosmetics.item_name(id)
	_style_focus(_buy_button, _row == BUTTONS_ROW and _button_focus == 0)
	_style_focus(_done_button, _row == BUTTONS_ROW and _button_focus == 1)
	_set_button_colors(_done_button, Color("3a2a22"), Color.WHITE)
	if _row == COLOR_ROW:
		if color_owner == null:
			_buy_button.text = "Цвет выбран ✓"
			_buy_button.disabled = true
			_set_button_colors(_buy_button, Color("2f5a33"), GREEN)
			_shortage_label.text = ""
		else:
			# Занятый цвет — как вещь, на которую не хватает денег: выбрать нельзя.
			_buy_button.text = "Цвет занят"
			_buy_button.disabled = true
			_set_button_colors(_buy_button, Color("4a4a4a"), Color(1, 1, 1, 0.5))
			_shortage_label.text = "Этот цвет у: %s" % color_owner.display_name
	elif PlayerManager.owns(player, id):
		_buy_button.text = "Надето ✓" if id != "" else "Ничего не надето"
		_buy_button.disabled = true
		_set_button_colors(_buy_button, Color("2f5a33"), GREEN)
		_shortage_label.text = ""
	else:
		var cost := Cosmetics.price(id)
		_buy_button.text = "Купить и надеть «%s» — %d ₽" % [item_title, cost]
		var enough := wallet >= cost
		_buy_button.disabled = not enough
		_set_button_colors(_buy_button, Color("8a5a12") if enough else Color("4a4a4a"),
			Color.WHITE if enough else Color(1, 1, 1, 0.5))
		_shortage_label.text = "" if enough else "Не хватает: %d ₽" % (cost - wallet)
	_message_label.text = _message
	_message_label.add_theme_color_override("font_color", _message_color)
	_hint_label.text = ("↑↓ — что меняем (внизу — цвет и кнопки)   ←→ — листать\n"
		+ "Подтвердить — купить / готово   Отмена — выйти")


## Рамка «выбрано с клавиатуры» у кнопки (на строке кнопок).
func _style_focus(button: Button, focused: bool) -> void:
	button.set_meta("focused", focused)


func _set_button_colors(button: Button, bg: Color, font: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = bg.lightened(0.12) if state == "hover" else bg
		style.set_corner_radius_all(12)
		style.set_content_margin_all(12)
		var focused: bool = button.get_meta("focused", false)
		style.border_color = GOLD if state == "hover" or focused else bg.lightened(0.25)
		style.set_border_width_all(5 if focused else 2)
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, font)


# ---------------- Построение экрана ----------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("2b1d18")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(split)

	# Слева: 3D-примерочная со своим «миром».
	var view_container := SubViewportContainer.new()
	view_container.stretch = true
	view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(view_container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	view_container.add_child(viewport)
	_build_room(viewport)

	# Баланс — крупно слева сверху, поверх примерочной.
	var wallet_panel := PanelContainer.new()
	var wallet_style := StyleBoxFlat.new()
	wallet_style.bg_color = Color(0.1, 0.07, 0.05, 0.85)
	wallet_style.border_color = GOLD
	wallet_style.set_border_width_all(3)
	wallet_style.set_corner_radius_all(12)
	wallet_style.set_content_margin_all(12)
	wallet_panel.add_theme_stylebox_override("panel", wallet_style)
	wallet_panel.position = Vector2(20, 20)
	var wallet_box := VBoxContainer.new()
	wallet_panel.add_child(wallet_box)
	var wallet_caption := _label("Кошелёк", Color("c9b98f"))
	wallet_caption.name = "WalletCaption"
	wallet_box.add_child(wallet_caption)
	_wallet = MoneyLabel.new()
	wallet_box.add_child(_wallet)
	add_child(wallet_panel)

	# Справа: список вещей и кнопки.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 1.15
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	split.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_title_label = _label("РЫНОК · %s" % player.display_name, GOLD)
	column.add_child(_title_label)
	for i in _row_count():
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_row_clicked.bind(i))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)
		var name_label := _label("", Color("c9b98f"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var left := _arrow_button("◀")
		left.pressed.connect(_on_arrow.bind(i, -1))
		var item_label := _label("", Color.WHITE)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.clip_text = true
		var right := _arrow_button("▶")
		right.pressed.connect(_on_arrow.bind(i, 1))
		var price_label := _label("", Color("ff9f5a"))
		for child in [name_label, left, item_label, right, price_label]:
			row.add_child(child)
		column.add_child(panel)
		_row_panels.append(panel)
		_row_names.append(name_label)
		_row_items.append(item_label)
		_row_prices.append(price_label)
		_arrow_buttons.append_array([left, right])

	_buy_button = Button.new()
	_buy_button.focus_mode = Control.FOCUS_NONE
	_buy_button.pressed.connect(_buy_current)
	column.add_child(_buy_button)
	_shortage_label = _label("", RED)
	column.add_child(_shortage_label)
	_message_label = _label("", GREEN)
	column.add_child(_message_label)

	_done_button = Button.new()
	_done_button.text = "Готово"
	_done_button.focus_mode = Control.FOCUS_NONE
	_done_button.pressed.connect(close)
	_set_button_colors(_done_button, Color("3a2a22"), Color.WHITE)
	column.add_child(_done_button)
	_hint_label = _label("", Color(1, 1, 1, 0.6))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint_label)

	_confirm = ConfirmDialog.new()
	_confirm.visible = false
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm.answered.connect(_on_confirm_answered)
	add_child(_confirm)

	var frame := ReferenceRect.new()
	frame.border_color = player.color
	frame.border_width = 4
	frame.editor_only = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)


func _arrow_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	_set_button_colors(button, Color("4a3020"), GOLD)
	return button


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
	var k := clampf(size.y / 1080.0, 0.5, 1.0)
	var base := int(34 * k)
	_title_label.add_theme_font_size_override("font_size", int(base * 1.25))
	_wallet.set_font_size(int(base * 1.2))
	(_wallet.get_parent().get_node("WalletCaption") as Label) \
		.add_theme_font_size_override("font_size", int(base * 0.6))
	for i in _row_names.size():
		_row_names[i].add_theme_font_size_override("font_size", int(base * 0.75))
		_row_names[i].custom_minimum_size.x = 150 * k
		_row_items[i].add_theme_font_size_override("font_size", base)
		_row_prices[i].add_theme_font_size_override("font_size", int(base * 0.9))
	for button in _arrow_buttons:
		button.add_theme_font_size_override("font_size", base)
		button.custom_minimum_size = Vector2(52, 44) * k
	_buy_button.add_theme_font_size_override("font_size", base)
	_done_button.add_theme_font_size_override("font_size", int(base * 0.85))
	_shortage_label.add_theme_font_size_override("font_size", int(base * 0.8))
	_message_label.add_theme_font_size_override("font_size", int(base * 0.8))
	_hint_label.add_theme_font_size_override("font_size", int(base * 0.5))


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	return label
