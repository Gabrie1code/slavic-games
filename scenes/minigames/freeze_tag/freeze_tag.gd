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

const CHARACTER_SCENE := preload("res://scenes/characters/test_character.tscn")

const ROUND_TIME := 90.0
const RUNNER_SPEED := 6.0
const CHASER_SPEED := 6.6
## Водящий «считает до трёх»: стоит на месте после старта.
const CHASER_HEAD_START := 2.0
const TOUCH_DISTANCE := 1.1
const UNFREEZE_RADIUS := 1.7
const UNFREEZE_TIME := 2.0
## После разморозки нельзя сразу заморозить снова.
const IMMUNE_TIME := 1.5
const ZONE_RADIUS := 3.0
const ZONE_LIMIT := 3.0
const ZONE_PUSH := 13.0
const STUN_TIME := 1.0
## Арена: прямоугольник внутри забора.
const ARENA_HALF := Vector2(10.5, 6.5)
const RUNNER_SPAWNS: Array[Vector3] = [
	Vector3(-8.5, 0.3, -4.5), Vector3(8.5, 0.3, -4.5), Vector3(-8.5, 0.3, 4.5), Vector3(8.5, 0.3, 4.5),
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

var _ice_material: StandardMaterial3D
var _ice_core_material: StandardMaterial3D
var _shard_material: StandardMaterial3D
## Крупные полоски разморозки внизу экрана: PlayerData.id -> {"box", "bar"}.
var _hud_bars: Dictionary = {}
var _hud_bars_box: VBoxContainer
var _zone_material: StandardMaterial3D

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
	_camera.look_at_from_position(Vector3(0, 17.0, 12.5), Vector3(0, 0, 0.8))
	_make_materials()
	_spawn_racers()
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
		r.character.can_jump = false # кнопка подтверждения = разморозка
		r.character.input_enabled = false # включим после отсчёта
		r.character.speed = CHASER_SPEED if r.is_chaser else RUNNER_SPEED
		_racers_root.add_child(r.character)

		r.status = Label3D.new()
		r.status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		r.status.no_depth_test = true
		r.status.font_size = 40
		r.status.outline_size = 10
		r.status.position.y = 2.5
		r.character.add_child(r.status)

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
			_bot_runner(r)
	if _chaser.player.is_bot():
		_bot_chaser()

	_update_chaser(delta)
	_update_unfreezing(delta)
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
		if r.frozen or r.immune_left > 0.0:
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
	for f in _runners():
		if not f.frozen:
			continue
		var helper: Racer = null
		for r in _runners():
			if r.frozen or r == f or r.player.input == null:
				continue
			var d := _flat_distance(r.character.global_position, f.character.global_position)
			if d < UNFREEZE_RADIUS and r.player.input.is_pressed("confirm"):
				helper = r
				break
		if helper:
			f.unfreeze_progress += delta
		else:
			f.unfreeze_progress = maxf(0.0, f.unfreeze_progress - delta * 0.5)
		if f.unfreeze_progress >= UNFREEZE_TIME:
			_unfreeze(f, helper)
		else:
			_set_unfreeze_bar(f, f.unfreeze_progress / UNFREEZE_TIME, helper)


func _freeze(r: Racer) -> void:
	r.frozen = true
	r.unfreeze_progress = 0.0
	r.character.input_enabled = false
	r.character.velocity = Vector3.ZERO
	if r.player.is_bot():
		r.player.bot_input().move = Vector2.ZERO
		r.player.bot_input().hold("confirm", false)

	r.ice = _build_ice()
	r.character.add_child(r.ice)
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


## Ледяная глыба: шестигранник, светлая сердцевина, кристаллы у основания и искры.
func _build_ice() -> Node3D:
	var root := Node3D.new()
	var block := MeshInstance3D.new()
	var block_mesh := CylinderMesh.new()
	block_mesh.top_radius = 0.6
	block_mesh.bottom_radius = 0.72
	block_mesh.height = 2.0
	block_mesh.radial_segments = 6
	block_mesh.rings = 1
	block.mesh = block_mesh
	block.material_override = _ice_material
	block.position.y = 1.0
	root.add_child(block)
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.35
	core_mesh.bottom_radius = 0.45
	core_mesh.height = 1.7
	core_mesh.radial_segments = 6
	core.mesh = core_mesh
	core.material_override = _ice_core_material
	core.position.y = 0.9
	core.rotation.y = PI / 6.0
	root.add_child(core)
	for i in 9:
		var shard := MeshInstance3D.new()
		var shard_mesh := CylinderMesh.new()
		shard_mesh.top_radius = 0.0
		shard_mesh.bottom_radius = randf_range(0.08, 0.16)
		shard_mesh.height = randf_range(0.35, 0.8)
		shard_mesh.radial_segments = 4
		shard.mesh = shard_mesh
		shard.material_override = _shard_material
		var a := TAU * i / 9.0 + randf_range(-0.2, 0.2)
		shard.position = Vector3(cos(a) * 0.72, shard_mesh.height * 0.35, sin(a) * 0.72)
		shard.rotation = Vector3(sin(a) * 0.5, randf() * TAU, -cos(a) * 0.5)
		root.add_child(shard)
	var sparkles := GPUParticles3D.new()
	sparkles.amount = 14
	sparkles.lifetime = 1.4
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.8
	process.gravity = Vector3(0, 0.4, 0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	sparkles.process_material = process
	var spark := QuadMesh.new()
	spark.size = Vector2(0.07, 0.07)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_mat.albedo_color = Color(0.9, 0.97, 1.0)
	spark.material = spark_mat
	sparkles.draw_pass_1 = spark
	sparkles.position.y = 1.0
	root.add_child(sparkles)
	return root


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
	_set_unfreeze_bar(r, 0.0, null)


func _set_unfreeze_bar(r: Racer, progress: float, helper: Racer) -> void:
	if r.bar_fill:
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
			if r.frozen or r.immune_left > 0.0:
				continue
			var d := _flat_distance(pos, r.character.global_position)
			if d < best:
				best = d
				var to := r.character.global_position - pos
				move = Vector2(to.x, to.z).normalized()
	bot.move = move.limit_length(1.0)


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
	_ice_material = StandardMaterial3D.new()
	_ice_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ice_material.albedo_color = Color(0.6, 0.86, 1.0, 0.42)
	_ice_material.roughness = 0.05
	_ice_material.metallic_specular = 1.0
	_ice_material.rim_enabled = true
	_ice_material.rim = 1.0
	_ice_material.rim_tint = 0.2
	_ice_material.emission_enabled = true
	_ice_material.emission = Color(0.35, 0.65, 0.95)
	_ice_material.emission_energy_multiplier = 0.35
	_ice_core_material = StandardMaterial3D.new()
	_ice_core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ice_core_material.albedo_color = Color(0.92, 0.97, 1.0, 0.25)
	_ice_core_material.emission_enabled = true
	_ice_core_material.emission = Color(0.7, 0.85, 1.0)
	_ice_core_material.emission_energy_multiplier = 0.4
	_shard_material = StandardMaterial3D.new()
	_shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shard_material.albedo_color = Color(0.75, 0.93, 1.0, 0.75)
	_shard_material.roughness = 0.05
	_shard_material.emission_enabled = true
	_shard_material.emission = Color(0.45, 0.75, 1.0)
	_shard_material.emission_energy_multiplier = 0.5

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
		var role := "водящий" if r.is_chaser else ("лёд" if r.frozen else "бегает")
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
