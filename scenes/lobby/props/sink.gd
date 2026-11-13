class_name Sink
extends StaticBody3D
## Рукомойник в туалете. «Подтвердить» у кранов (каждый игрок — раз в COOLDOWN сек):
## вентили понемногу крутятся (горячая + холодная = тёплая), из крана вниз бьёт струя, чаша
## наполняется — и с персонажа смывается краска из баллончика. Потом краны закрываются,
## вода уходит в слив. Модель — tools/blender/sink.py (SinkBody, TapHot, TapCold, SinkWater).

const MODEL := preload("res://assets/models/apartment/sink.glb")
const COOLDOWN := 15.0
## Носик крана и уровни воды (в координатах раковины).
const NOZZLE := Vector3(0, 0.985, 0.175)
const WATER_LOW := 0.768
const WATER_HIGH := 0.85
## Вода в воронке шире, чем выше уровень (дно — 0.07 м, у края — 0.2 м).
const WATER_WIDE := 2.4
## Где встаёт моющий руки (перед раковиной).
const STAND := Vector3(0, 0, 0.75)
## Губка лежит на краю раковины; взяли и не вернули — новая появится через SPONGE_BACK сек.
const SPONGE_SPOT := Vector3(-0.17, 0.882, 0.33)
const SPONGE_BACK := 15.0

var busy := false
## Губка на раковине (null — её взяли).
var sponge: Sponge

var _tap_hot: Node3D
var _tap_cold: Node3D
var _water: Node3D
var _stream: MeshInstance3D
var _stream_mesh: CylinderMesh
## Когда каждому игроку снова можно: PlayerData.id -> время (сек, Time.get_ticks_msec).
var _ready_at: Dictionary = {}


func _ready() -> void:
	var model := MODEL.instantiate() as Node3D
	add_child(model)
	_tap_hot = model.find_child("TapHot", true, false) as Node3D
	_tap_cold = model.find_child("TapCold", true, false) as Node3D
	_water = model.find_child("SinkWater", true, false) as Node3D
	_water.visible = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.52, 0.88, 0.42)
	shape.shape = box
	shape.position = Vector3(0, 0.44, 0.21)
	add_child(shape)
	_stream = MeshInstance3D.new()
	_stream_mesh = CylinderMesh.new()
	_stream_mesh.top_radius = 0.006
	_stream_mesh.bottom_radius = 0.009
	_stream_mesh.radial_segments = 8
	_stream.mesh = _stream_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.88, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	_stream.material_override = mat
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stream.visible = false
	add_child(_stream)
	_restock_sponge()


func _process(_delta: float) -> void:
	if _stream.visible:
		# Струя — от носика до воды (вода поднимается — струя короче).
		var bottom := _water.position.y if _water.visible else WATER_LOW
		var length := maxf(0.01, NOZZLE.y - bottom)
		_stream_mesh.height = length
		_stream.position = Vector3(NOZZLE.x, NOZZLE.y - length / 2.0, NOZZLE.z)
		_stream.scale.x = 1.0 + sin(Time.get_ticks_msec() * 0.05) * 0.1 # чуть дрожит


func can_use(p: PlayerData) -> bool:
	return not busy and cooldown_left(p) <= 0.0


func cooldown_left(p: PlayerData) -> float:
	return maxf(0.0, float(_ready_at.get(p.id, 0.0)) - Time.get_ticks_msec() / 1000.0)


## Взять губку с раковины (через SPONGE_BACK сек на её месте появится новая, если не вернут).
func take_sponge() -> Sponge:
	var taken := sponge
	sponge = null
	if taken:
		get_tree().create_timer(SPONGE_BACK).timeout.connect(_restock_sponge)
	return taken


## Положить губку обратно (если место свободно).
func return_sponge(item: Sponge) -> bool:
	if sponge != null:
		return false
	sponge = item
	item.store_in(self, SPONGE_SPOT)
	return true


func _restock_sponge() -> void:
	if sponge != null:
		return # вернули сами
	sponge = Sponge.new()
	add_child(sponge)
	sponge.store_in(self, SPONGE_SPOT)


## Куда смотреть/подходить (перед кранами).
func front_point() -> Vector3:
	return to_global(Vector3(0, 0.9, 0.3))


func stand_point() -> Vector3:
	return to_global(STAND)


## Помыть руки: краны, струя, вода; на середине — краска с персонажа смывается.
func use(p: PlayerData, character: PlayerCharacter) -> void:
	if not can_use(p):
		return
	busy = true
	_ready_at[p.id] = Time.get_ticks_msec() / 1000.0 + COOLDOWN
	if character:
		character.set_arm_pose(0.2, 1.1, 0.25) # руки под кран
	_water.position.y = WATER_LOW
	_water.scale = Vector3.ONE
	_water.visible = true
	var tween := create_tween()
	# Открыть понемногу оба вентиля — горячий и холодный (вода тёплая).
	tween.tween_property(_tap_hot, "rotation:y", -2.2, 1.0).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_tap_cold, "rotation:y", 1.5, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _stream.visible = true)
	# Чаша наполняется; с персонажа смывается краска.
	tween.tween_property(_water, "position:y", WATER_HIGH, 2.6)
	tween.parallel().tween_property(_water, "scale", Vector3(WATER_WIDE, 1, WATER_WIDE), 2.6)
	tween.parallel().tween_callback(func() -> void:
		if is_instance_valid(character):
			SprayCan.clear_paint(character)).set_delay(1.2)
	# Закрыть краны, вода уходит в слив.
	tween.tween_callback(func() -> void: _stream.visible = false)
	tween.tween_property(_tap_hot, "rotation:y", 0.0, 0.7)
	tween.parallel().tween_property(_tap_cold, "rotation:y", 0.0, 0.7)
	tween.parallel().tween_property(_water, "position:y", WATER_LOW, 1.4)
	tween.parallel().tween_property(_water, "scale", Vector3.ONE, 1.4)
	tween.tween_callback(func() -> void:
		_water.visible = false
		busy = false
		if is_instance_valid(character):
			character.set_arm_angle(PlayerCharacter.ARM_DOWN, 0.25))
