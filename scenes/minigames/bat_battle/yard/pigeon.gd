class_name YardPigeon
extends Node3D
## Голубь на краю крыши. Сидит, клюёт, иногда сам улетает; если рядом боец — улетает сразу.
## Улетев, сообщает об этом (flown), и двор через время сажает нового голубя в другое место.

signal flown(pigeon: YardPigeon)

const SCENE := preload("res://assets/models/courtyard/pigeon.glb")
const SCARE_DISTANCE := 2.2
const FLY_TIME := 2.6

var flying := false
## «Местный» голубь: сидит на месте, не пугается и не улетает, только время от времени машет
## крыльями (на краю открытого мусорного бака).
var resident := false

var _body: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _time := 0.0
var _peck := 0.0
var _flap := 0.0


func _ready() -> void:
	var model := SCENE.instantiate()
	add_child(model)
	_body = model.find_child("PigeonBody", true, false)
	_wing_l = model.find_child("WingL", true, false)
	_wing_r = model.find_child("WingR", true, false)
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	if flying:
		# Взмахи: крылья раскрыты в стороны и машут.
		var flap := 1.25 + sin(_time * 28.0) * 0.55
		_wing_l.rotation.z = -flap
		_wing_r.rotation.z = flap
		return
	if resident:
		_resident_flap(delta)
	# Сидит: иногда клюёт (наклон вперёд) и крутит головой.
	_peck = maxf(0.0, _peck - delta)
	if _peck == 0.0 and randf() < delta * 0.4:
		_peck = 0.4
	_body.rotation.x = -0.5 * sin(_peck / 0.4 * PI) if _peck > 0.0 else 0.0
	rotation.y += sin(_time * 0.7) * delta * 0.3


## Улететь от точки from (наружу и вверх), затем исчезнуть.
func fly_away(from: Vector3) -> void:
	if flying or resident:
		return
	flying = true
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	look_at(global_position + away, Vector3.UP)
	var target := global_position + away * 14.0 + Vector3.UP * randf_range(6.0, 10.0)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, FLY_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		flown.emit(self)
		queue_free())


## Прилететь издалека и сесть в точку spot. far — откуда прилетает (направление по земле;
## по умолчанию с −Z мира; двор за окном кухни развёрнут — передаёт своё «вдаль»).
func land_at(spot: Vector3, far: Vector3 = Vector3.FORWARD) -> void:
	flying = true
	var side := far.cross(Vector3.UP).normalized()
	var start := spot + side * randf_range(-10, 10) + Vector3.UP * 9.0 + far * randf_range(6, 12)
	global_position = start
	look_at(Vector3(spot.x, start.y, spot.z), Vector3.UP)
	var tween := create_tween()
	tween.tween_property(self, "global_position", spot, FLY_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		flying = false
		_wing_l.rotation.z = 0.0
		_wing_r.rotation.z = 0.0
		rotation = Vector3(0, randf() * TAU, 0))


## Местный голубь: раз в несколько секунд хлопает крыльями ~1 с (раскрыл, помахал, сложил).
func _resident_flap(delta: float) -> void:
	_flap = maxf(0.0, _flap - delta)
	if _flap == 0.0 and randf() < delta * 0.35:
		_flap = 1.1
	var open := sin(_flap / 1.1 * PI) if _flap > 0.0 else 0.0
	var wave := (0.8 + sin(_time * 24.0) * 0.45) * open
	_wing_l.rotation.z = -wave
	_wing_r.rotation.z = wave
