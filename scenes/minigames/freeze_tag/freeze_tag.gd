extends Node3D
## Мини-игра «Морожка» (догонялки с заморозкой).
##
## Один случайный игрок — водящий, остальные убегают.
## Водящий касается бегущего — тот замерзает (покрывается льдом) и стоит.
## Разморозка: свободный игрок стоит рядом с замороженным и держит кнопку 2 сек.
## Против караула: вокруг замороженного зона. Кто водит и пробыл в зонах
## дольше ZONE_LIMIT секунд — отлетает и на секунду не может морозить.
##
## Очки: бегущий — секунды на свободе. Водящий — среднее время заморозки
## бегущих (чтобы шкала была такой же, 0..90). Заморозил всех досрочно —
## оставшееся время идёт водящему.
##
## Туман: водящий (если он живой игрок) видит площадку только рядом с собой — радиус
## FOG_RADIUS = 1.2 × зона караула. Тогда экран делится: слева водящий в тумане,
## справа бегущие видят всё. Бегущим туман не мешает.
## Площадка: горка (неуязвим, пока едешь, на выходе ускорение), качели (толкать; сесть на
## 2–10 сек — неуязвим), лавочки (залезть под лавочку на 2–10 сек — неуязвим),
## карусель (только раскручивать).

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")

const ROUND_TIME := 90.0
const RUNNER_SPEED := 6.0
const CHASER_SPEED := 5.6 # было 6.6, −15%: водящий слишком быстро догонял
## Водящий «считает до трёх»: стоит на месте после старта.
const CHASER_HEAD_START := 2.0
const TOUCH_DISTANCE := 1.1
const UNFREEZE_RADIUS := 1.7
const UNFREEZE_TIME := 2.0
## После разморозки нельзя сразу заморозить снова.
const IMMUNE_TIME := 1.5
const ZONE_RADIUS := 3.0
## Как близко к лавочке (спереди или сзади), чтобы под неё залезть.
const BENCH_RADIUS := 1.0
const ZONE_LIMIT := 3.0
const ZONE_PUSH := 13.0
const STUN_TIME := 1.0
const ALERT := preload("res://assets/textures/fx/alert.png")
## Арена: прямоугольник внутри забора.
const ARENA_HALF := Vector2(15.75, 9.75) # двор увеличен в 1.5 раза
## Туман водящего: радиус обзора и слои (туман видит только камера водящего,
## надписи над головами — только общая камера бегущих).
const FOG_RADIUS := ZONE_RADIUS * 1.2
const FOG_LAYER := 1 << 17
const HUD_LAYER := 1 << 16
const FOG_SHADER := preload("res://scenes/minigames/freeze_tag/chaser_fog.gdshader")
const RUNNER_SPAWNS: Array[Vector3] = [
	Vector3(-12.75, 0.3, -6.75), Vector3(12.75, 0.3, -6.75), Vector3(-12.75, 0.3, 6.75),
	Vector3(12.75, 0.3, 6.75),
]
const CHASER_SPAWN := Vector3(0, 0.3, 0)


## Состояние одного участника.
class Racer:
	var player: PlayerData
	var character: PlayerCharacter
	var is_chaser := false
	var frozen := false
	var free_time := 0.0
	var frozen_time := 0.0
	var immune_left := 0.0
	var unfreeze_progress := 0.0
	var stun_left := 0.0
	## Едет с горки или сидит на качелях — водящий не может заморозить.
	var busy := false
	## Спринт на Shift: +50% на 3 сек, перезарядка 15 сек (только у убегающих).
	var sprint := SprintAbility.new()
	## Жёлтые лучики-вспышка у головы, пока размораживает друга.
	var alert: Sprite3D
	var zone_time := 0.0
	var ice: Node3D
	var zone: MeshInstance3D
	var status: Label3D
	## Полоска разморозки над головой (фон + заполнение).
	var bar: Node3D
	var bar_fill: MeshInstance3D


var _racers: Array[Racer] = []
var _chaser: Racer
var _time_left := ROUND_TIME
var _running := false
var _finished := false

var _timer_label: Label
var _message_label: Label
var _score_labels: Dictionary = {} # PlayerData.id -> Label

var _run_fx: RunEffects
## Строит ледяные глыбы (материалы создаются один раз).
var _ice: IceBuilder
## Крупные полоски разморозки внизу экрана: PlayerData.id -> {"box", "bar"}.
var _hud_bars: Dictionary = {}
var _hud_bars_box: VBoxContainer
var _zone_material: StandardMaterial3D
var _yard: FreezeYard
var _fog_material: ShaderMaterial
var _chaser_camera: Camera3D
## Кто прячется под лавочкой: PlayerData.id -> {"bench", "left", "racer"}.
var _hiding: Dictionary = {}
## Половина экрана бегущих (когда водящий — живой игрок и экран разделён).
var _runners_view: Control

@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _racers_root: Node3D = $Racers
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	if not MatchState.in_progress:
		# Запуск сцены напрямую (F6) для теста.
		if PlayerManager.players.is_empty():
			PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_WASD)
			PlayerManager.add_local_player(PlayerData.DeviceKind.KEYBOARD_ARROWS)
		MatchState.start_new_match(1)

	_sun.rotation_degrees = Vector3(-60, -25, 0)
	_camera.look_at_from_position(Vector3(0, 25.5, 18.75), Vector3(0, 0, 1.2))
	_make_materials()
	for fence in ["FenceNorth", "FenceSouth", "FenceWest", "FenceEast"]:
		(get_node(fence + "/Mesh") as Node3D).visible = false # вместо них — модели забора
	_run_fx = RunEffects.new()
	add_child(_run_fx)
	_yard = FreezeYard.new()
	add_child(_yard)
	_yard.slide.ride_finished.connect(_on_playground_done)
	_yard.swing.sit_finished.connect(_on_playground_done)
	_spawn_racers()
	_setup_views()
	_prewarm_effects()
	_build_ui()
	_run_intro.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			MatchState.abort_to_lobby()


func _spawn_racers() -> void:
	var order := MatchState.turn_order()
	var chaser_player: PlayerData = order.pick_random()
	var spawn_index := 0
	for p in order:
		var r := Racer.new()
		r.player = p
		r.is_chaser = p == chaser_player
		r.character = CHARACTER_SCENE.instantiate()
		var spawn := CHASER_SPAWN if r.is_chaser else RUNNER_SPAWNS[spawn_index % RUNNER_SPAWNS.size()]
		if not r.is_chaser:
			spawn_index += 1
		r.character.setup(p, spawn)
		r.character.can_jump = true # прыгать можно; рядом с замороженным/горкой/качелями — нет
		r.character.input_enabled = false # включим после отсчёта
		r.character.speed = CHASER_SPEED if r.is_chaser else RUNNER_SPEED
		_racers_root.add_child(r.character)

		r.status = Label3D.new()
		r.status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		r.status.no_depth_test = true
		r.status.font_size = 40
		r.status.outline_size = 10
		r.status.position.y = 2.5
		r.status.layers = HUD_LAYER
		r.character.add_child(r.status)
		r.character.set_name_layer(HUD_LAYER)

		if r.is_chaser:
			_chaser = r
			r.status.text = "ВОДЯЩИЙ"
			r.status.modulate = Color("ff6b5a")
			_add_chaser_hat(r.character)
		_racers.append(r)


func _run_intro() -> void:
	var chaser_name := _chaser.player.display_name
	_message_label.text = "Водит %s!" % chaser_name
	await get_tree().create_timer(1.5).timeout
	for text in ["3", "2", "1"]:
		_message_label.text = text
		await get_tree().create_timer(0.6).timeout
	_message_label.text = "Разбегайтесь!"
	_running = true
	for r in _racers:
		if not r.is_chaser:
			r.character.input_enabled = true
	await get_tree().create_timer(CHASER_HEAD_START).timeout
	if _finished:
		return
	_chaser.character.input_enabled = true
	_message_label.text = "%s пошёл ловить!" % chaser_name
	_clear_message_later()


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_time_left -= delta
	_timer_label.text = "%d" % ceili(maxf(_time_left, 0.0))

	for r in _racers:
		if r.is_chaser:
			continue
		if r.frozen:
			r.frozen_time += delta
		else:
			r.free_time += delta
		r.immune_left = maxf(0.0, r.immune_left - delta)
		if r.player.is_bot():
			_bot_runner(r) # бот мог нажать спринт — проверяем ниже в этом же кадре
		if r.sprint.update(delta, r.character, r.player.input, RUNNER_SPEED,
				not r.frozen and not r.busy and r.character.input_enabled):
			_show_message("%s включил спринт!" % r.player.display_name)
	if _chaser.player.is_bot():
		_bot_chaser()

	_update_playground(delta)
	_run_fx.update(delta, _racers.filter(func(r: Racer) -> bool: return not r.frozen) \
		.map(func(r: Racer) -> PlayerCharacter: return r.character))
	_update_chaser(delta)
	_update_unfreezing(delta)
	_update_fog()
	_face_bars()
	_update_scores()

	var runners := _runners()
	var all_frozen := not runners.is_empty() and runners.all(func(r: Racer) -> bool: return r.frozen)
	if _time_left <= 0.0 or all_frozen or runners.is_empty():
		_finish(all_frozen)


func _runners() -> Array[Racer]:
	var result: Array[Racer] = []
	for r in _racers:
		if not r.is_chaser:
			result.append(r)
	return result


## Касания водящего и защита от караула.
func _update_chaser(delta: float) -> void:
	var c := _chaser
	if c.stun_left > 0.0:
		c.stun_left = maxf(0.0, c.stun_left - delta)
		if c.stun_left == 0.0:
			c.character.input_enabled = true
		return
	if not c.character.input_enabled:
		return # ещё «считает до трёх»

	var pos := c.character.global_position
	for r in _runners():
		if r.frozen or r.immune_left > 0.0 or r.busy:
			continue
		if _flat_distance(pos, r.character.global_position) < TOUCH_DISTANCE:
			_freeze(r)

	# Караулит? Время в зонах копится, вне зон — убывает.
	var nearest_frozen: Racer = null
	var nearest_dist := INF
	for r in _runners():
		if not r.frozen:
			continue
		var d := _flat_distance(pos, r.character.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_frozen = r
	if nearest_frozen and nearest_dist < ZONE_RADIUS:
		c.zone_time += delta
	else:
		c.zone_time = maxf(0.0, c.zone_time - delta)

	if c.zone_time >= ZONE_LIMIT and nearest_frozen:
		var away := pos - nearest_frozen.character.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3.BACK
		c.character.apply_knockback(away * ZONE_PUSH + Vector3.UP * 4.0)
		c.zone_time = 0.0
		c.stun_left = STUN_TIME
		c.character.input_enabled = false
		_show_message("%s, не карауль!" % c.player.display_name)

	if c.zone_time > 0.3:
		c.status.text = "НЕ КАРАУЛЬ! %.1f" % (ZONE_LIMIT - c.zone_time)
	else:
		c.status.text = "ВОДЯЩИЙ"


## Разморозка: свободный игрок рядом держит кнопку.
func _update_unfreezing(delta: float) -> void:
	var helpers: Array[Racer] = []
	for f in _runners():
		if not f.frozen:
			continue
		var helper: Racer = null
		for r in _runners():
			if r.frozen or r.busy or r == f or r.player.input == null:
				continue
			var d := _flat_distance(r.character.global_position, f.character.global_position)
			if d < UNFREEZE_RADIUS and r.player.input.is_pressed("confirm"):
				helper = r
				break
		if helper:
			helpers.append(helper)
			f.unfreeze_progress += delta
		else:
			f.unfreeze_progress = maxf(0.0, f.unfreeze_progress - delta * 0.5)
		if f.unfreeze_progress >= UNFREEZE_TIME:
			_unfreeze(f, helper)
		else:
			_set_unfreeze_bar(f, f.unfreeze_progress / UNFREEZE_TIME, helper)
	_show_alerts(helpers)


func _freeze(r: Racer) -> void:
	r.frozen = true
	r.unfreeze_progress = 0.0
	r.character.input_enabled = false
	r.character.velocity = Vector3.ZERO
	if r.player.is_bot():
		r.player.bot_input().move = Vector2.ZERO
		r.player.bot_input().hold("confirm", false)

	r.ice = _ice.build()
	r.character.add_child(r.ice)
	r.character.set_tint(Color(0.45, 0.75, 1.0, 0.45)) # внутри льда — синеватый
	r.ice.scale = Vector3.ONE * 0.2
	create_tween().tween_property(r.ice, "scale", Vector3.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_build_bar(r)

	r.zone = MeshInstance3D.new()
	var zone_mesh := CylinderMesh.new()
	zone_mesh.top_radius = ZONE_RADIUS
	zone_mesh.bottom_radius = ZONE_RADIUS
	zone_mesh.height = 0.02
	zone_mesh.radial_segments = 24
	r.zone.mesh = zone_mesh
	r.zone.material_override = _zone_material
	add_child(r.zone)
	r.zone.global_position = r.character.global_position * Vector3(1, 0, 1) + Vector3.UP * 0.03

	r.status.text = ""
	_show_message("%s заморожен!" % r.player.display_name)


## Полоска разморозки над головой (поворачивается к камере в _face_bars).
func _build_bar(r: Racer) -> void:
	r.bar = Node3D.new()
	r.bar.position.y = 2.55
	r.character.add_child(r.bar)
	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(1.3, 0.2)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.05, 0.08, 0.12)
	bg_mat.no_depth_test = true
	bg.material_override = bg_mat
	r.bar.add_child(bg)
	r.bar_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(1.22, 0.13)
	r.bar_fill.mesh = fill_mesh
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color("6fd3ff")
	fill_mat.no_depth_test = true
	fill_mat.render_priority = 1
	r.bar_fill.material_override = fill_mat
	r.bar_fill.position.z = 0.01
	r.bar.add_child(r.bar_fill)
	bg.layers = HUD_LAYER
	r.bar_fill.layers = HUD_LAYER
	_set_unfreeze_bar(r, 0.0, null)


func _set_unfreeze_bar(r: Racer, progress: float, helper: Racer) -> void:
	if r.bar_fill:
		# Полоска видна только пока кто-то размораживает (пустая висела чёрной чертой над льдом).
		r.bar.visible = progress > 0.001
		# Заполнение растёт слева направо.
		var p := clampf(progress, 0.0, 1.0)
		r.bar_fill.scale.x = maxf(p, 0.001)
		r.bar_fill.position.x = -1.22 * (1.0 - p) / 2.0
	_set_hud_bar(r, progress, helper)


## Крупная полоска внизу экрана: «Серёга размораживает Колю».
func _set_hud_bar(r: Racer, progress: float, helper: Racer) -> void:
	var id := r.player.id
	if progress <= 0.0:
		if _hud_bars.has(id):
			(_hud_bars[id]["box"] as Node).queue_free()
			_hud_bars.erase(id)
		return
	if not _hud_bars.has(id):
		var box := VBoxContainer.new()
		var caption := _label("", 26, Color("9fe3ff"))
		box.add_child(caption)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(620, 30)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("6fd3ff")
		fill.set_corner_radius_all(8)
		bar.add_theme_stylebox_override("fill", fill)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.05, 0.08, 0.12, 0.85)
		back.set_corner_radius_all(8)
		bar.add_theme_stylebox_override("background", back)
		box.add_child(bar)
		_hud_bars_box.add_child(box)
		_hud_bars[id] = {"box": box, "bar": bar, "caption": caption}
	var entry: Dictionary = _hud_bars[id]
	(entry["bar"] as ProgressBar).value = progress
	var who := helper.player.display_name if helper else "Никто"
	(entry["caption"] as Label).text = "%s размораживает %s" % [who, r.player.display_name] \
		if helper else "%s оттаивает обратно в лёд..." % r.player.display_name


## Полоски над головами смотрят на камеру.
func _face_bars() -> void:
	for r in _runners():
		if r.bar:
			r.bar.look_at(r.bar.global_position * 2.0 - _camera.global_position)


func _unfreeze(r: Racer, helper: Racer) -> void:
	r.frozen = false
	r.unfreeze_progress = 0.0
	r.immune_left = IMMUNE_TIME
	r.character.input_enabled = true
	r.character.set_tint(Color(0, 0, 0, 0))
	if r.ice:
		var melt := create_tween()
		melt.tween_property(r.ice, "scale", Vector3(1.3, 0.05, 1.3), 0.2)
		melt.tween_callback(r.ice.queue_free)
		r.ice = null
	if r.bar:
		r.bar.queue_free()
		r.bar = null
	_set_hud_bar(r, 0.0, null)
	if r.zone:
		r.zone.queue_free()
		r.zone = null
	r.status.text = ""
	if helper:
		_show_message("%s разморозил %s!" % [helper.player.display_name, r.player.display_name])


func _finish(all_frozen: bool) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	for r in _racers:
		r.character.input_enabled = false
		if r.player.is_bot():
			r.player.bot_input().move = Vector2.ZERO

	var runners := _runners()
	# Досрочная заморозка всех: оставшееся время — водящему.
	if all_frozen:
		for r in runners:
			r.frozen_time += maxf(_time_left, 0.0)
	var scores := _scores()
	var places: Array[PlayerData] = MatchState.turn_order()
	places.sort_custom(func(a: PlayerData, b: PlayerData) -> bool: return scores[a.id] > scores[b.id])

	var lines: PackedStringArray = []
	for i in places.size():
		var reward: int = MatchState.MINIGAME_REWARDS[i] if i < MatchState.MINIGAME_REWARDS.size() else 0
		var p := places[i]
		lines.append("%d. %s — %d очк.  +%d ₽" % [i + 1, p.display_name, scores[p.id], reward])
	var header := "Водящий заморозил всех!" if all_frozen else "Время вышло!"
	_message_label.text = header + "\n" + "\n".join(lines)
	_update_scores()
	await get_tree().create_timer(4.0).timeout
	MatchState.finish_minigame(places)


## Очки: бегущий — секунды на свободе, водящий — среднее время заморозки.
func _scores() -> Dictionary:
	var result := {}
	var runners := _runners()
	var frozen_sum := 0.0
	for r in runners:
		result[r.player.id] = int(r.free_time)
		frozen_sum += r.frozen_time
	result[_chaser.player.id] = int(frozen_sum / maxi(1, runners.size()))
	return result


# ---------------- Боты ----------------

## Бегущий бот: если водящий далеко — идёт размораживать своих, иначе убегает.
func _bot_runner(r: Racer) -> void:
	var bot := r.player.bot_input()
	if r.frozen:
		return
	var pos := r.character.global_position
	var chaser_pos := _chaser.character.global_position
	var chaser_dist := _flat_distance(pos, chaser_pos)
	if chaser_dist < 3.0 and r.sprint.ready():
		bot.press("sprint") # водящий рядом — рывок

	var target: Racer = null
	var target_dist := INF
	for f in _runners():
		if f == r or not f.frozen:
			continue
		var d := _flat_distance(pos, f.character.global_position)
		if d < target_dist:
			target_dist = d
			target = f

	var move := Vector2.ZERO
	if target and chaser_dist > 4.5:
		if target_dist < UNFREEZE_RADIUS * 0.8:
			bot.hold("confirm", true)
		else:
			bot.hold("confirm", false)
			var to := target.character.global_position - pos
			move = Vector2(to.x, to.z).normalized()
	else:
		bot.hold("confirm", false)
		var away := pos - chaser_pos
		move = Vector2(away.x, away.z).normalized()
		# Немного петляем, чтобы не убегать по прямой в угол.
		var wiggle := sin(Time.get_ticks_msec() / 400.0 + r.player.slot * 1.7)
		move += move.orthogonal() * wiggle * 0.6
	# У забора — тянемся к центру.
	var edge := Vector2(pos.x / ARENA_HALF.x, pos.z / ARENA_HALF.y)
	if absf(edge.x) > 0.75 or absf(edge.y) > 0.75:
		move += Vector2(-pos.x, -pos.z).normalized() * 1.3
	bot.move = move.limit_length(1.0)


## Водящий бот: гонится за ближайшим свободным; если долго в зоне — уходит.
func _bot_chaser() -> void:
	var c := _chaser
	var bot := c.player.bot_input()
	var pos := c.character.global_position
	var move := Vector2.ZERO
	if c.zone_time > ZONE_LIMIT * 0.5:
		for f in _runners():
			if f.frozen and _flat_distance(pos, f.character.global_position) < ZONE_RADIUS + 0.5:
				var away := pos - f.character.global_position
				move += Vector2(away.x, away.z).normalized()
	else:
		var best := INF
		for r in _runners():
			if r.frozen or r.immune_left > 0.0 or r.busy:
				continue
			var d := _flat_distance(pos, r.character.global_position)
			if d < best:
				best = d
				var to := r.character.global_position - pos
				move = Vector2(to.x, to.z).normalized()
	bot.move = move.limit_length(1.0)


## Показать лучики у тех, кто сейчас размораживает (и спрятать у остальных).
func _show_alerts(helpers: Array[Racer]) -> void:
	for r in _racers:
		var on := helpers.has(r)
		if on and r.alert == null:
			r.alert = Sprite3D.new()
			r.alert.texture = ALERT
			r.alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			r.alert.pixel_size = 0.0035
			r.alert.no_depth_test = true
			r.alert.shaded = false
			r.alert.layers = HUD_LAYER
			r.alert.position = Vector3(0.55, 2.0, 0) # лучики веером справа над головой
			r.character.add_child(r.alert)
		if r.alert:
			r.alert.visible = on
			if on: # «подпрыгивает», как на картинке
				r.alert.scale = Vector3.ONE * (1.0 + absf(sin(Time.get_ticks_msec() / 120.0)) * 0.2)


## «Прогрев»: лёд, зона и полоска один раз рисуются под землёй в начале раунда, чтобы Godot
## заранее собрал их шейдеры — тогда в момент заморозки игра не подвисает.
func _prewarm_effects() -> void:
	var warm := Node3D.new()
	warm.position = Vector3(0, -3.0, 0) # под землёй: не видно, но рисуется
	add_child(warm)
	warm.add_child(_ice.build())
	var zone := MeshInstance3D.new()
	var zone_mesh := CylinderMesh.new()
	zone_mesh.top_radius = ZONE_RADIUS
	zone_mesh.bottom_radius = ZONE_RADIUS
	zone_mesh.height = 0.02
	zone.mesh = zone_mesh
	zone.material_override = _zone_material
	warm.add_child(zone)
	# Синяя «плёнка» на замороженном и полоска разморозки — те же настройки материалов.
	var tinted := MeshInstance3D.new()
	tinted.mesh = BoxMesh.new()
	var overlay := StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.albedo_color = Color(0.45, 0.75, 1.0, 0.45)
	tinted.material_overlay = overlay
	warm.add_child(tinted)
	await get_tree().create_timer(1.0).timeout
	warm.queue_free()


# ---------------- Площадка ----------------

## Качели и карусель толкают все; «подтвердить» у лесенки — горка, у качелей — сесть.
func _update_playground(delta: float) -> void:
	var characters: Array[PlayerCharacter] = []
	for r in _racers:
		characters.append(r.character)
	_yard.swing.update_swing(delta, characters)
	_yard.carousel.update_spin(delta, characters)
	for r in _racers:
		# Пробел — прыжок, но не там, где он нужен для дела (разморозить, горка, качели).
		r.character.can_jump = not _frozen_near(r) and not _yard.slide.can_ride(r.character) \
			and (r.is_chaser or (_yard.swing.free_seat_near(r.character) < 0
				and _free_bench_near(r) < 0))
		if r.frozen or r.busy or r.player.input == null or not r.character.input_enabled:
			continue
		if not r.player.input.is_just_pressed("confirm") or _frozen_near(r):
			continue
		if _yard.slide.can_ride(r.character):
			_set_busy(r, "НА ГОРКЕ!")
			_yard.slide.ride(r.character)
		elif not r.is_chaser:
			var seat := _yard.swing.free_seat_near(r.character)
			var bench := _free_bench_near(r)
			if seat >= 0:
				_set_busy(r, "НА КАЧЕЛЯХ!")
				_yard.swing.sit(r.character, seat)
			elif bench >= 0:
				_hide_under_bench(r, bench)
	_update_hiding(delta)


## Свободная лавочка рядом с бегущим (-1 — нет).
func _free_bench_near(r: Racer) -> int:
	var bench := _yard.bench_near(r.character.global_position, BENCH_RADIUS)
	for id: int in _hiding:
		if int(_hiding[id]["bench"]) == bench:
			return -1
	return bench


## Залезть под лавочку на 2–10 сек: персонаж лежит под сиденьем вдоль лавочки, неуязвим.
func _hide_under_bench(r: Racer, bench: int) -> void:
	_set_busy(r, "ПОД ЛАВОЧКОЙ!")
	r.character.input_enabled = false
	r.character.set_physics_process(false)
	r.character.velocity = Vector3.ZERO
	var spot := _yard.benches[bench]
	r.character.global_transform = Transform3D(spot.basis * Basis(Vector3.BACK, PI / 2.0),
		spot * Vector3(0.75, 0.22, 0.0))
	_hiding[r.player.id] = {"bench": bench, "left": randf_range(2.0, 10.0), "racer": r}


func _update_hiding(delta: float) -> void:
	for id: int in _hiding.keys():
		var entry: Dictionary = _hiding[id]
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) > 0.0:
			continue
		_hiding.erase(id)
		var r: Racer = entry["racer"]
		var spot := _yard.benches[int(entry["bench"])]
		# Вылезает вперёд, на сторону площадки.
		r.character.global_transform = Transform3D(spot.basis, spot * Vector3(0, 0, 0.8))
		r.character.set_physics_process(true)
		_on_playground_done(r.character)


## Рядом есть замороженный — тогда «подтвердить» значит «размораживать», а не горка/качели.
func _frozen_near(r: Racer) -> bool:
	for f in _runners():
		if f.frozen and _flat_distance(f.character.global_position, r.character.global_position) \
				< UNFREEZE_RADIUS:
			return true
	return false


func _set_busy(r: Racer, text: String) -> void:
	r.busy = true
	if not r.is_chaser:
		r.status.text = text
		r.status.modulate = Color("8fd694")
	if r.player.is_bot():
		r.player.bot_input().move = Vector2.ZERO


func _on_playground_done(character: PlayerCharacter) -> void:
	for r in _racers:
		if r.character != character:
			continue
		r.busy = false
		if not r.is_chaser:
			r.status.text = ""
		if _running and not r.frozen and r.stun_left <= 0.0:
			r.character.input_enabled = true


# ---------------- Туман водящего ----------------

## Если водящий — живой игрок: свой экран с туманом (слева), бегущим — общий экран без тумана.
func _setup_views() -> void:
	_camera.cull_mask &= ~FOG_LAYER
	if _chaser.player.is_bot():
		return
	var fog := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	fog.mesh = plane
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = FOG_SHADER
	_fog_material.set_shader_parameter("radius", FOG_RADIUS)
	# Рисовать после всех прозрачных вещей (лёд, искры), иначе их видно сквозь туман.
	_fog_material.render_priority = 100
	fog.material_override = _fog_material
	fog.layers = FOG_LAYER
	fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fog.position.y = 2.7
	add_child(fog)

	var humans_running := _racers.any(func(r: Racer) -> bool:
		return not r.is_chaser and not r.player.is_bot())
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_chaser_camera = _add_view(layer, Vector2(0, 0), Vector2(0.5 if humans_running else 1.0, 1),
		0xFFFFF & ~HUD_LAYER)
	var caption := _label("Ты водишь — видно только рядом", 28, Color("ff6b5a"))
	caption.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption.offset_top = 70
	(_chaser_camera.get_parent().get_parent() as Control).add_child(caption)
	if humans_running:
		var runners_camera := _add_view(layer, Vector2(0.5, 0), Vector2(1, 1), 0xFFFFF & ~FOG_LAYER)
		_runners_view = runners_camera.get_parent().get_parent() as Control
		runners_camera.look_at_from_position(Vector3(0, 36.0, 22.5), Vector3(0, 0, 0.75))
	_camera.cull_mask = 0 # общий экран полностью закрыт видами
	_update_fog()


## Водящий (живой игрок) не должен знать, что кого-то размораживают: полоски «Серёга
## размораживает Колю» переезжают на половину экрана бегущих, а без неё не показываются.
func _hide_hud_bars_from_chaser() -> void:
	if _chaser_camera == null:
		return # водящий — бот, экран общий
	if _runners_view == null:
		_hud_bars_box.visible = false
		return
	_hud_bars_box.reparent(_runners_view, false)
	_hud_bars_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hud_bars_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud_bars_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud_bars_box.offset_bottom = -150


## Вид в части экрана (anchor_from..anchor_to — доли экрана) со своей камерой.
func _add_view(layer: CanvasLayer, anchor_from: Vector2, anchor_to: Vector2, mask: int) -> Camera3D:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.anchor_left = anchor_from.x
	container.anchor_top = anchor_from.y
	container.anchor_right = anchor_to.x
	container.anchor_bottom = anchor_to.y
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(container)
	var viewport := SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.cull_mask = mask
	viewport.add_child(camera)
	camera.current = true
	var frame := ReferenceRect.new()
	frame.border_color = Color(0, 0, 0)
	frame.border_width = 3
	frame.editor_only = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(frame)
	return camera


## Камера водящего — над ним, дыра в тумане — вокруг него.
func _update_fog() -> void:
	if _chaser_camera == null:
		return
	var pos := _chaser.character.global_position
	_fog_material.set_shader_parameter("center", pos)
	_chaser_camera.look_at_from_position(pos + Vector3(0, 9.0, 6.0), pos + Vector3(0, 0.5, 0))


# ---------------- Отображение ----------------

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _add_chaser_hat(character: PlayerCharacter) -> void:
	var hat := MeshInstance3D.new()
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.0
	hat_mesh.bottom_radius = 0.36
	hat_mesh.height = 0.5
	hat_mesh.radial_segments = 8
	hat.mesh = hat_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d93a2b")
	hat.material_override = mat
	hat.position.y = 1.82
	character.visual.add_child(hat)


func _make_materials() -> void:
	_ice = IceBuilder.new()

	_zone_material = StandardMaterial3D.new()
	_zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_zone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_zone_material.albedo_color = Color(1.0, 0.3, 0.2, 0.22)


func _show_message(text: String) -> void:
	_message_label.text = text
	_clear_message_later()


func _clear_message_later() -> void:
	var text := _message_label.text
	await get_tree().create_timer(1.5).timeout
	if not _finished and _message_label.text == text:
		_message_label.text = ""


func _update_scores() -> void:
	var scores := _scores()
	for r in _racers:
		var role := "водящий" if r.is_chaser else ("лёд" if r.frozen else r.sprint.status())
		(_score_labels[r.player.id] as Label).text = "%s (%s)\n%d очк." % [
			r.player.display_name, role, scores[r.player.id]]


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 24)
	_ui.add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	var title := _label("Морожка", 44, Color("9fe3ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_timer_label = _label("%d" % int(ROUND_TIME), 52, Color.WHITE)
	top.add_child(_timer_label)

	var rules := ("Водящий морозит касанием. Разморозить друга: стой рядом и держи "
		+ "Пробел / Enter / A (полоска внизу).\n"
		+ "Не карауль замороженных: в красной зоне можно быть только 3 сек.")
	column.add_child(_label(rules, 20, Color.WHITE))

	_message_label = _label("", 48, Color.WHITE)
	_message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_message_label)

	_hud_bars_box = VBoxContainer.new()
	_hud_bars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud_bars_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hud_bars_box.add_theme_constant_override("separation", 6)
	column.add_child(_hud_bars_box)
	_hide_hud_bars_from_chaser()

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	for r in _racers:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(240, 0)
		var style := StyleBoxFlat.new()
		style.bg_color = r.player.color.darkened(0.35)
		style.set_corner_radius_all(10)
		style.set_content_margin_all(8)
		if r.is_chaser:
			style.border_color = Color("ff6b5a")
			style.set_border_width_all(3)
		panel.add_theme_stylebox_override("panel", style)
		var label := _label("", 22, Color.WHITE)
		panel.add_child(label)
		row.add_child(panel)
		_score_labels[r.player.id] = label
	_update_scores()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	return label
