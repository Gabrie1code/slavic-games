class_name InputSetup
extends RefCounted
## Создаёт отдельные действия ввода для каждого локального игрока.
##
## Для игрока в слоте N создаются действия вида "pN_move_left", "pN_confirm" и т.д.,
## привязанные только к его устройству. Так несколько человек могут играть
## за одним компьютером: двое на клавиатуре и остальные на геймпадах.
##
## Клавиши задаются по физическому положению (physical_keycode),
## поэтому WASD работает и при русской раскладке.

const ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down", "confirm", "cancel", "attack",
	"crouch", "sprint", "drop",
]
const DEADZONE := 0.3


## Общие «стрелки меню» (стрелки + Enter) — для игрока на WASD в меню. Создаются один раз.
static func ensure_menu_arrows() -> void:
	var keys := {
		"menu_arrow_up": [KEY_UP], "menu_arrow_down": [KEY_DOWN],
		"menu_arrow_left": [KEY_LEFT], "menu_arrow_right": [KEY_RIGHT],
		"menu_arrow_confirm": [KEY_ENTER, KEY_KP_ENTER],
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			e.device = -1
			InputMap.action_add_event(action, e)


static func action_name(slot: int, action: String) -> StringName:
	return StringName("p%d_%s" % [slot, action])


## Регистрирует все действия игрока в InputMap (старые для этого слота удаляются).
static func register_player(player: PlayerData) -> void:
	for action in ACTIONS:
		var full_name := action_name(player.slot, action)
		if InputMap.has_action(full_name):
			InputMap.erase_action(full_name)
		InputMap.add_action(full_name, DEADZONE)
		for event in _events_for(player, action):
			InputMap.action_add_event(full_name, event)


static func unregister_slot(slot: int) -> void:
	for action in ACTIONS:
		var full_name := action_name(slot, action)
		if InputMap.has_action(full_name):
			InputMap.erase_action(full_name)


## Какую клавиатурную схему выбирает нажатая клавиша при входе в игру.
## Возвращает -1, если клавиша не входит ни в одну схему.
static func keyboard_join_scheme(physical_keycode: Key) -> int:
	if physical_keycode in [KEY_SPACE, KEY_E]:
		return PlayerData.DeviceKind.KEYBOARD_WASD
	if physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		return PlayerData.DeviceKind.KEYBOARD_ARROWS
	return -1


static func _keyboard_layout(kind: PlayerData.DeviceKind) -> Dictionary:
	if kind == PlayerData.DeviceKind.KEYBOARD_WASD:
		return {
			"move_left": [KEY_A],
			"move_right": [KEY_D],
			"move_up": [KEY_W],
			"move_down": [KEY_S],
			"confirm": [KEY_SPACE, KEY_E],
			"cancel": [KEY_Q],
			"attack": [KEY_F], # + левая кнопка мыши (см. _events_for)
			"crouch": [KEY_C], # + левый Ctrl (см. _events_for)
			"sprint": [], # левый Shift (см. _events_for)
			"drop": [KEY_G], # выбросить то, что в руке (баллончик)
		}
	return {
		"move_left": [KEY_LEFT],
		"move_right": [KEY_RIGHT],
		"move_up": [KEY_UP],
		"move_down": [KEY_DOWN],
		"confirm": [KEY_ENTER, KEY_KP_ENTER],
		"cancel": [KEY_BACKSPACE],
		"attack": [KEY_SLASH, KEY_KP_0],
		"crouch": [], # правый Ctrl (см. _events_for)
		"sprint": [], # правый Shift (см. _events_for)
		"drop": [KEY_PERIOD, KEY_KP_PERIOD],
	}


static func _events_for(player: PlayerData, action: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	match player.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD, PlayerData.DeviceKind.KEYBOARD_ARROWS:
			for key in _keyboard_layout(player.device_kind)[action]:
				var e := InputEventKey.new()
				e.physical_keycode = key
				e.device = -1
				events.append(e)
			# Shift и Ctrl делятся на левый и правый: левые — игроку на WASD, правые — на стрелках.
			var sided := _sided_key(player.device_kind, action)
			if sided:
				events.append(sided)
			# Удар у игрока на WASD — ещё и левой кнопкой мыши.
			if action == "attack" and player.device_kind == PlayerData.DeviceKind.KEYBOARD_WASD:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.device = -1
				events.append(click)
		PlayerData.DeviceKind.JOYPAD:
			events.append_array(_joypad_events(action, player.joypad_id))
	return events


static func _joypad_events(action: String, device: int) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	match action:
		"move_left":
			events.append(_axis(JOY_AXIS_LEFT_X, -1.0, device))
			events.append(_button(JOY_BUTTON_DPAD_LEFT, device))
		"move_right":
			events.append(_axis(JOY_AXIS_LEFT_X, 1.0, device))
			events.append(_button(JOY_BUTTON_DPAD_RIGHT, device))
		"move_up":
			events.append(_axis(JOY_AXIS_LEFT_Y, -1.0, device))
			events.append(_button(JOY_BUTTON_DPAD_UP, device))
		"move_down":
			events.append(_axis(JOY_AXIS_LEFT_Y, 1.0, device))
			events.append(_button(JOY_BUTTON_DPAD_DOWN, device))
		"confirm":
			events.append(_button(JOY_BUTTON_A, device))
		"cancel":
			events.append(_button(JOY_BUTTON_B, device))
		"attack":
			events.append(_button(JOY_BUTTON_X, device))
		"crouch":
			events.append(_button(JOY_BUTTON_RIGHT_STICK, device))
		"sprint":
			events.append(_button(JOY_BUTTON_LEFT_SHOULDER, device))
			events.append(_button(JOY_BUTTON_LEFT_STICK, device))
		"drop":
			events.append(_button(JOY_BUTTON_Y, device))
	return events


## Клавиша с нужной стороной: левые Shift/Ctrl — игроку на WASD, правые — на стрелках.
## Shift — бег (спринт), Ctrl — присесть. null — такой клавиши нет.
static func _sided_key(kind: PlayerData.DeviceKind, action: String) -> InputEventKey:
	var key := KEY_NONE
	if action == "sprint":
		key = KEY_SHIFT
	elif action == "crouch":
		key = KEY_CTRL
	var side := KEY_LOCATION_LEFT if kind == PlayerData.DeviceKind.KEYBOARD_WASD \
		else KEY_LOCATION_RIGHT
	if key == KEY_NONE:
		return null
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.location = side
	e.device = -1
	return e


static func _axis(axis: JoyAxis, value: float, device: int) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = device
	return e


static func _button(button: JoyButton, device: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = device
	return e
