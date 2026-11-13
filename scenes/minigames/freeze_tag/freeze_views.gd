class_name FreezeViews
extends Node
## Вид от первого лица в «Морожке»: у каждого живого игрока своя часть экрана (1 — весь экран,
## 2 — пополам, 3–4 — по четвертям), камера на уровне глаз. Обзор: мышь (WASD), правый стик
## (геймпад); на стрелках влево/вправо поворачивают персонажа.
## Когда игрок на качелях, едет с горки или лежит под лавочкой (busy), камера плавно отъезжает
## назад-вверх — вид от третьего лица (недалеко), потом так же плавно возвращается в глаза.

const MOUSE_SENSITIVITY := 0.0025
const STICK_LOOK_SPEED := 2.8
const PITCH_LIMIT := 1.2
const EYE_HEIGHT := 1.42
const CROUCH_EYE_DROP := 0.45
## Третье лицо: насколько камера сзади и выше точки над персонажем, и как быстро переезжает.
const BACK_DISTANCE := 2.6
const BACK_HEIGHT := 1.1
const TARGET_HEIGHT := 0.9
const BLEND_TIME := 0.6

## PlayerData.id -> {"player", "character", "camera", "container", "yaw", "pitch", "blend"}.
var views: Dictionary = {}

var _layer: CanvasLayer
var _mouse_delta := Vector2.ZERO


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 0 # под интерфейсом мини-игры (таймер, очки)
	add_child(_layer)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).relative


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Слой модели персонажа в слоте: своя камера его не рисует (не видно себя изнутри).
static func body_layer(slot: int) -> int:
	return 1 << (slot + 1)


## Свой вид игроку p. mask — что видит камера (без своего тела — его уберём сами).
## Возвращает контейнер вида (в него можно добавить надписи только для этого игрока).
func add_view(p: PlayerData, character: PlayerCharacter, mask: int) -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(container)
	var viewport := SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport) # мир общий с мини-игрой — своя только камера
	var camera := Camera3D.new()
	camera.fov = 75.0
	camera.cull_mask = mask & ~body_layer(p.slot)
	viewport.add_child(camera)
	camera.current = true
	var frame := ReferenceRect.new()
	frame.border_color = p.color
	frame.border_width = 3
	frame.editor_only = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	var dot := Label.new()
	dot.text = "•"
	dot.add_theme_font_size_override("font_size", 28)
	dot.add_theme_color_override("font_outline_color", Color.BLACK)
	dot.add_theme_constant_override("outline_size", 6)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dot.grow_vertical = Control.GROW_DIRECTION_BOTH
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(dot)
	character.first_person = true
	views[p.id] = {"player": p, "character": character, "camera": camera, "container": container,
		"mask": mask, "yaw": character.rotation.y, "pitch": 0.0, "blend": 0.0, "dot": dot}
	_layout()
	return container


## Камера вида игрока с этим id (null — у него нет своего вида).
func camera_of(id: int) -> Camera3D:
	return views[id]["camera"] if views.has(id) else null


func has_views() -> bool:
	return not views.is_empty()


## Каждый кадр: обзор, камеры. busy_ids — кто сейчас на качелях / горке / под лавочкой.
func update(delta: float, busy_ids: Array[int]) -> void:
	var mouse := _mouse_delta
	_mouse_delta = Vector2.ZERO
	var wants_mouse := false
	for id: int in views:
		var view: Dictionary = views[id]
		var p: PlayerData = view["player"]
		var character: PlayerCharacter = view["character"]
		var look := _look(p, character, mouse, delta)
		wants_mouse = wants_mouse or p.device_kind == PlayerData.DeviceKind.KEYBOARD_WASD
		var busy := busy_ids.has(id)
		var yaw: float = view["yaw"]
		var control := not busy and character.input_enabled
		if control:
			if not view.get("control", true):
				character.rotation.y = yaw # снова управляет: тело — туда, куда смотрела камера
			# Тело поворачивается за взглядом (на стрелках тело поворачивается само);
			# с зажатым Alt мышь крутит только голову (FreeLook), камера — тело + голова.
			character.rotation.y -= FreeLook.step(character, p, look.x, delta)
			yaw = character.rotation.y
		else:
			character.head_yaw = 0.0
			yaw -= look.x # стоит во льду / на качелях: крутится только камера
		view["control"] = control
		var pitch := clampf(float(view["pitch"]) - look.y, -PITCH_LIMIT, PITCH_LIMIT)
		character.fp_pitch = pitch
		var blend := move_toward(float(view["blend"]), 1.0 if busy else 0.0, delta / BLEND_TIME)
		view["yaw"] = yaw
		view["pitch"] = pitch
		view["blend"] = blend
		_place_camera(view, character, yaw + (character.head_yaw if control else 0.0), pitch, blend)
	var mode := Input.MOUSE_MODE_CAPTURED if wants_mouse else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


## Игра закончилась — мышь снова видна (кнопки итогов нажимаются мышью).
func release_mouse() -> void:
	set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _look(p: PlayerData, character: PlayerCharacter, mouse: Vector2, delta: float) -> Vector2:
	match p.device_kind:
		PlayerData.DeviceKind.KEYBOARD_WASD:
			character.fp_strafe = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			return mouse * MOUSE_SENSITIVITY
		PlayerData.DeviceKind.JOYPAD:
			character.fp_strafe = true
			var stick := Vector2(Input.get_joy_axis(p.joypad_id, JOY_AXIS_RIGHT_X),
				Input.get_joy_axis(p.joypad_id, JOY_AXIS_RIGHT_Y))
			return stick * STICK_LOOK_SPEED * delta if stick.length() > 0.2 else Vector2.ZERO
	character.fp_strafe = false # стрелки: влево/вправо — поворот
	return Vector2.ZERO


## Камера между глазами (blend 0) и видом сзади-сверху (blend 1), плавно (smoothstep).
func _place_camera(view: Dictionary, character: PlayerCharacter, yaw: float, pitch: float,
		blend: float) -> void:
	var camera: Camera3D = view["camera"]
	var eye := character.global_position \
		+ Vector3.UP * (EYE_HEIGHT - CROUCH_EYE_DROP * character.crouch_amount)
	var fp := Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), eye)
	var t := smoothstep(0.0, 1.0, blend)
	# Своё тело видно, только пока камера отъехала (изнутри головы его не рисуем).
	var p: PlayerData = view["player"]
	var mask: int = view["mask"]
	camera.cull_mask = mask if t > 0.15 else mask & ~body_layer(p.slot)
	(view["dot"] as Control).visible = t < 0.5
	if t <= 0.0:
		camera.global_transform = fp
		return
	var target := character.global_position + Vector3.UP * TARGET_HEIGHT
	var back := Vector3(0.0, BACK_HEIGHT, BACK_DISTANCE).rotated(Vector3.UP, yaw)
	var tp := Transform3D.IDENTITY.translated(target + back).looking_at(target, Vector3.UP)
	camera.global_transform = fp.interpolate_with(tp, t)


## Одна камера — весь экран, две — пополам, три-четыре — по четвертям (по порядку слотов).
func _layout() -> void:
	var ids: Array[int] = []
	for id: int in views:
		ids.append(id)
	ids.sort_custom(func(a: int, b: int) -> bool:
		return (views[a]["player"] as PlayerData).slot < (views[b]["player"] as PlayerData).slot)
	var n := ids.size()
	for i in n:
		var from := Vector2.ZERO
		var to := Vector2.ONE
		if n == 2:
			from = Vector2(0.5 * i, 0.0)
			to = Vector2(0.5 * i + 0.5, 1.0)
		elif n > 2:
			from = Vector2(0.5 * (i % 2), 0.5 * floorf(i / 2.0))
			to = from + Vector2(0.5, 0.5)
		var container: Control = views[ids[i]]["container"]
		container.anchor_left = from.x
		container.anchor_top = from.y
		container.anchor_right = to.x
		container.anchor_bottom = to.y
		container.offset_left = 0
		container.offset_top = 0
		container.offset_right = 0
		container.offset_bottom = 0
