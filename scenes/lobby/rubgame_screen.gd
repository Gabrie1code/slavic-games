class_name RubgameScreen
extends LobbyRoom
## Экран игрока у стола рулетки: стол крупным планом (тот же мир, что и лобби —
## видно, как персонаж стоит у стола и как другие ставят фишки).
##
## Слева сверху — кошелёк в рублях, справа — фишки с ценами и «Купить»,
## снизу — «У вас» (сколько каких фишек) и выбор ставки.
##
## Управление кнопками своего устройства или мышью:
##   вверх/вниз — строка; влево/вправо — листать ставку / число / фишку;
##   подтвердить — купить фишку, поставить, обменять; отмена — отойти от стола.

const VIEWMODEL_LAYERS := 0b1111 << 10
const GOLD := Color("f6c343")
## Скорость перелёта камеры между столом и колесом.
const CAMERA_SPEED := 3.0
const GREEN := Color("8fd694")
const RED := Color("ff7a6b")
const CREAM := Color("c9b98f")
## Строки управления (сверху вниз).
const ROW_CASH_OUT := 4
const ROW_BET := 5
const ROW_NUMBER := 6
const ROW_CHIP := 7
const ROW_PLACE := 8
const ROW_EXIT := 9
const ROW_COUNT := 10
const BET_ORDER: Array[int] = [
	Roulette.Bet.RED, Roulette.Bet.BLACK, Roulette.Bet.ZERO,
	Roulette.Bet.EVEN, Roulette.Bet.ODD, Roulette.Bet.NUMBER,
]

var table: RubgameTable
var lobby_character: PlayerCharacter

var _row := ROW_BET
var _bet_index := 0
var _number := 17
var _chip_index := 0
var _time := 0.0
var _message := ""
var _message_color := GREEN
var _message_time := 0.0
## Что подтверждаем в окне: номинал фишки или -1 — обмен всех фишек на рубли.
var _pending := 0

var _camera: Camera3D
var _wallet: MoneyLabel
var _confirm: ConfirmDialog
var _status: Label
var _message_label: Label
var _have_box: HBoxContainer
var _bets_label: Label
var _hint: Label
## Все элементы, у которых есть рамка «выбрано»: номер строки -> Control.
var _rows: Dictionary = {}
var _value_labels: Dictionary = {} # строка -> Label с текущим значением
var _buy_buttons: Array[Button] = []
var _fonts: Array[Array] = [] # [Control, множитель размера шрифта]


func setup(p: PlayerData, character: PlayerCharacter, rubgame_table: RubgameTable) -> void:
	player = p
	lobby_character = character
	table = rubgame_table


func _ready() -> void:
	_build()
	resized.connect(_apply_font_sizes)
	_apply_font_sizes()
	table.round_finished.connect(_on_round_finished)
	# Персонаж встаёт за стол, лицом к нему.
	if lobby_character:
		lobby_character.global_position = table.stand_point(player.slot)
		lobby_character.rotation.y = table.stand_yaw()
		lobby_character.velocity = Vector3.ZERO
	_camera.global_transform = table.camera_transform() # дальше камера двигается плавно
	_wallet.set_amount(PlayerManager.wallet(player), false)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	# Пока колесо крутится и показывает итог — плавно летим к колесу (вид сверху),
	# на время ставок — обратно ко всему столу.
	var target := table.camera_transform()
	if table.phase != RubgameTable.Phase.BETTING:
		target = table.wheel_camera_transform()
	_camera.global_transform = _camera.global_transform.interpolate_with(target,
		minf(1.0, delta * CAMERA_SPEED))
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message = ""
	_update_status()
	_handle_input()


func refresh() -> void:
	_wallet.set_amount(PlayerManager.wallet(player))
	_refresh()


# ---------------- Действия ----------------

func _handle_input() -> void:
	var input := player.input
	# Нажатие, которым открыли стол, не должно сразу что-то купить.
	if input == null or _time < 0.2:
		return
	if _confirm.handle_input(input):
		return
	if input.is_just_pressed("cancel"):
		close()
	elif input.menu_just_pressed("confirm"):
		_activate(_row)
	elif input.menu_just_pressed("move_up"):
		_move_row(-1)
	elif input.menu_just_pressed("move_down"):
		_move_row(1)
	elif input.menu_just_pressed("move_left"):
		_cycle(_row, -1)
	elif input.menu_just_pressed("move_right"):
		_cycle(_row, 1)


func _move_row(step: int) -> void:
	_row = posmod(_row + step, ROW_COUNT)
	# Строка «Число» есть только у ставки на число.
	if _row == ROW_NUMBER and _bet() != Roulette.Bet.NUMBER:
		_row = posmod(_row + step, ROW_COUNT)
	_refresh()


## Подтвердить на строке row (клавиатура/геймпад или клик мышью).
func _activate(row: int) -> void:
	_row = row
	if row < PlayerManager.CHIP_VALUES.size():
		_ask_buy(PlayerManager.CHIP_VALUES[row])
	elif row == ROW_CASH_OUT:
		_ask_cash_out()
	elif row == ROW_EXIT:
		close()
	else:
		_place()
	_refresh()


## Листать значение в строке row.
func _cycle(row: int, step: int) -> void:
	_row = row
	match row:
		ROW_BET:
			_bet_index = posmod(_bet_index + step, BET_ORDER.size())
		ROW_NUMBER:
			_number = posmod(_number - 1 + step, 36) + 1
		ROW_CHIP:
			_chip_index = posmod(_chip_index + step, PlayerManager.CHIP_VALUES.size())
	_refresh()


func _ask_buy(value: int) -> void:
	if PlayerManager.wallet(player) < value:
		_say("Не хватает рублей на фишку %d" % value, RED)
		return
	_pending = value
	_confirm.ask("Купить фишку «%d» за %d ₽?" % [value, value])


func _ask_cash_out() -> void:
	var total := _chips_total()
	if total == 0:
		_say("Фишек нет — менять нечего", RED)
		return
	_pending = -1
	_confirm.ask("Обменять все фишки на %d ₽?" % total)


func _on_confirm_answered(yes: bool) -> void:
	if not yes:
		return
	if _pending == -1:
		var got := _chips_total()
		for value in PlayerManager.CHIP_VALUES:
			PlayerManager.add_chips(player, value, -int(PlayerManager.chips(player)[value]))
		PlayerManager.add_to_wallet(player, got)
		_say("Фишки обменяны: +%d ₽" % got, GREEN)
	elif PlayerManager.wallet(player) >= _pending:
		PlayerManager.add_to_wallet(player, -_pending)
		PlayerManager.add_chips(player, _pending, 1)
		_say("Куплена фишка «%d»" % _pending, GREEN)
	_wallet.set_amount(PlayerManager.wallet(player))
	_refresh()


func _place() -> void:
	var value: int = PlayerManager.CHIP_VALUES[_chip_index]
	if table.phase != RubgameTable.Phase.BETTING:
		_say("Ставки закрыты — ждём следующий круг", RED)
	elif int(PlayerManager.chips(player)[value]) < 1:
		_say("Нет фишки «%d» — купи справа" % value, RED)
	elif table.place_bet(player, _bet(), _number, value):
		_say("Ставка: %s, фишка %d" % [Roulette.bet_title(_bet(), _number), value], GREEN)
	_refresh()


func _on_round_finished(result: int) -> void:
	var text := "Выпало %d — %s." % [result, Roulette.color_name(result)]
	if table.last_round.has(player.id):
		var stats: Dictionary = table.last_round[player.id]
		var won: int = stats["won"]
		var lost: int = stats["lost"]
		if won > 0:
			_say("%s Выигрыш +%d фишками!" % [text, won], GREEN)
		else:
			_say("%s Ставка не сыграла: −%d" % [text, lost], RED)
	else:
		_say(text, CREAM)
	_refresh()


func _say(text: String, color: Color) -> void:
	_message = text
	_message_color = color
	_message_time = 4.0
	_refresh()


func _bet() -> int:
	return BET_ORDER[_bet_index]


func _chips_total() -> int:
	var total := 0
	var all := PlayerManager.chips(player)
	for value: int in all:
		total += value * int(all[value])
	return total


# ---------------- Надписи ----------------

func _update_status() -> void:
	match table.phase:
		RubgameTable.Phase.BETTING:
			_status.text = "Ставки принимаются: %d с" % ceili(table.time_left)
			_status.add_theme_color_override("font_color", GREEN)
		RubgameTable.Phase.SPINNING:
			_status.text = "Ставок больше нет — крутим!"
			_status.add_theme_color_override("font_color", GOLD)
		RubgameTable.Phase.RESULT:
			_status.text = "Выпало: %d (%s)" % [table.result, Roulette.color_name(table.result)]
			_status.add_theme_color_override("font_color", Color.WHITE)
	_message_label.text = _message
	_message_label.add_theme_color_override("font_color", _message_color)


func _refresh() -> void:
	var chips := PlayerManager.chips(player)
	var money := PlayerManager.wallet(player)
	for i in _buy_buttons.size():
		_buy_buttons[i].disabled = money < PlayerManager.CHIP_VALUES[i]
	var bet := _bet()
	(_value_labels[ROW_BET] as Label).text = "%s  ×%d" % [Roulette.BET_NAMES[bet],
		Roulette.multiplier(bet)]
	(_value_labels[ROW_NUMBER] as Label).text = str(_number)
	_rows[ROW_NUMBER].visible = bet == Roulette.Bet.NUMBER
	var value: int = PlayerManager.CHIP_VALUES[_chip_index]
	(_value_labels[ROW_CHIP] as Label).text = "%d  (у вас %d)" % [value, chips[value]]
	# «У вас»: значок фишки и количество.
	for i in PlayerManager.CHIP_VALUES.size():
		var count_label := _have_box.get_child(i * 2 + 2) as Label
		count_label.text = "×%d" % chips[PlayerManager.CHIP_VALUES[i]]
	var lines := PackedStringArray()
	for group in table.bets_of(player):
		lines.append("%s: %d×%d" % [group["title"], group["count"], group["value"]])
	_bets_label.text = ("На столе: " + ", ".join(lines)) if not lines.is_empty() else ""
	for row: int in _rows:
		_style_row(_rows[row], row == _row)


func _style_row(control: Control, focused: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.06, 0.85) if not focused else Color(0.3, 0.2, 0.08, 0.95)
	style.border_color = GOLD if focused else Color(0.4, 0.3, 0.2)
	style.set_border_width_all(4 if focused else 2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8)
	if control is Button:
		for state in ["normal", "hover", "pressed", "disabled"]:
			control.add_theme_stylebox_override(state, style)
		control.add_theme_color_override("font_color", Color.WHITE)
		control.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		control.add_theme_stylebox_override("panel", style)


# ---------------- Построение экрана ----------------

func _build() -> void:
	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	var viewport := SubViewport.new() # мир общий с лобби — своя только камера
	viewport.msaa_3d = Viewport.MSAA_2X
	view.add_child(viewport)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.cull_mask = 0xFFFFF & ~VIEWMODEL_LAYERS
	viewport.add_child(_camera)
	_camera.current = true

	# Слева сверху — кошелёк.
	var wallet_panel := _panel()
	wallet_panel.position = Vector2(16, 16)
	var wallet_box := VBoxContainer.new()
	wallet_panel.add_child(wallet_box)
	wallet_box.add_child(_label("Кошелёк", CREAM, 0.6))
	_wallet = MoneyLabel.new()
	wallet_box.add_child(_wallet)
	add_child(wallet_panel)

	# Сверху по центру — что происходит за столом.
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 16
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_status = _label("", GREEN, 1.0)
	top.add_child(_status)
	_message_label = _label("", GREEN, 0.7)
	top.add_child(_message_label)

	_build_shop()
	_build_bottom()

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


## Справа: фишки с ценами и «Купить», ниже — обмен фишек на рубли.
func _build_shop() -> void:
	var shop := _panel()
	shop.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	shop.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	shop.grow_vertical = Control.GROW_DIRECTION_BOTH
	shop.offset_right = -16
	add_child(shop)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	shop.add_child(column)
	column.add_child(_label("ФИШКИ", GOLD, 0.8))
	for i in PlayerManager.CHIP_VALUES.size():
		var value: int = PlayerManager.CHIP_VALUES[i]
		var row_panel := PanelContainer.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_panel.add_child(row)
		row.add_child(_icon("res://assets/ui/icons/chip_%d.png" % value))
		var price := _label("%d ₽" % value, Color.WHITE, 0.75)
		price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(price)
		var buy := _button("Купить", 0.6)
		buy.pressed.connect(_activate.bind(i))
		row.add_child(buy)
		_buy_buttons.append(buy)
		column.add_child(row_panel)
		_rows[i] = row_panel
	var cash := _button("Обменять фишки на ₽", 0.6)
	cash.pressed.connect(_activate.bind(ROW_CASH_OUT))
	column.add_child(cash)
	_rows[ROW_CASH_OUT] = cash


## Снизу: «У вас» (фишки), выбор ставки и кнопки.
func _build_bottom() -> void:
	var bottom := _panel()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -16
	add_child(bottom)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	bottom.add_child(column)

	_have_box = HBoxContainer.new()
	_have_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_have_box.add_theme_constant_override("separation", 8)
	column.add_child(_have_box)
	_have_box.add_child(_label("У вас:", CREAM, 0.7))
	for value in PlayerManager.CHIP_VALUES:
		_have_box.add_child(_icon("res://assets/ui/icons/chip_%d.png" % value))
		_have_box.add_child(_label("×0", Color.WHITE, 0.7))
	# Первый ребёнок — подпись, дальше пары (значок, число): число i-й фишки — child(i*2+2).

	var choose := HBoxContainer.new()
	choose.alignment = BoxContainer.ALIGNMENT_CENTER
	choose.add_theme_constant_override("separation", 8)
	column.add_child(choose)
	for row in [ROW_BET, ROW_NUMBER, ROW_CHIP]:
		var caption: String = {ROW_BET: "Ставка", ROW_NUMBER: "Число", ROW_CHIP: "Фишка"}[row]
		var panel := PanelContainer.new()
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		panel.add_child(line)
		line.add_child(_label(caption, CREAM, 0.55))
		var left := _button("◀", 0.6)
		left.pressed.connect(_cycle.bind(row, -1))
		line.add_child(left)
		var value_label := _label("", Color.WHITE, 0.7)
		line.add_child(value_label)
		var right := _button("▶", 0.6)
		right.pressed.connect(_cycle.bind(row, 1))
		line.add_child(right)
		choose.add_child(panel)
		_rows[row] = panel
		_value_labels[row] = value_label
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var place := _button("Поставить", 0.75)
	place.pressed.connect(_activate.bind(ROW_PLACE))
	buttons.add_child(place)
	_rows[ROW_PLACE] = place
	var leave := _button("Отойти от стола", 0.6)
	leave.pressed.connect(_activate.bind(ROW_EXIT))
	buttons.add_child(leave)
	_rows[ROW_EXIT] = leave
	_bets_label = _label("", GOLD, 0.55)
	column.add_child(_bets_label)
	_hint = _label("Вверх/вниз — выбор   Влево/вправо — листать   Подтвердить — купить / "
		+ "поставить   Отмена — отойти", Color(1, 1, 1, 0.6), 0.4)
	column.add_child(_hint)


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.05, 0.85)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(text: String, color: Color, font_scale: float) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	_fonts.append([label, font_scale])
	return label


func _button(text: String, font_scale: float) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	_style_row(button, false)
	_fonts.append([button, font_scale])
	return button


func _icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonts.append([icon, -1.0]) # значок: размер по шрифту
	return icon


## Крупный шрифт, если стол на весь экран; мельче — если экран поделён.
func _apply_font_sizes() -> void:
	var k := clampf(size.y / 1080.0, 0.45, 1.0)
	var base := 40.0 * k
	for entry in _fonts:
		var control: Control = entry[0]
		var font_scale: float = entry[1]
		if font_scale < 0.0:
			control.custom_minimum_size = Vector2.ONE * base * 1.1
		else:
			control.add_theme_font_size_override("font_size", int(base * font_scale))
	_wallet.set_font_size(int(base * 0.9))
