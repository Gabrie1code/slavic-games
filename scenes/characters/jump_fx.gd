class_name JumpFx
extends RefCounted
## Звуки и пыль прыжка (без файлов: звук собирается в коде, как ноты граммофона в Tune).
## «Хоп» — короткий тон вверх при толчке, «тук» — мягкий низкий удар при приземлении.

const RATE := 22050
const HOP_DB := -20.0
const LAND_DB := -16.0

static var _hop: AudioStreamWAV
static var _land: AudioStreamWAV


## Сыграть звук рядом с персонажем (обычный, не 3D: в лобби у игроков свои экраны без 3D-звука).
static func play(owner: Node, landing: bool, strength: float = 1.0) -> void:
	if _hop == null:
		_hop = _make(0.09, 260.0, 520.0, 0.0)
		_land = _make(0.12, 140.0, 55.0, 0.35)
	var player := AudioStreamPlayer.new()
	player.stream = _land if landing else _hop
	player.volume_db = (LAND_DB if landing else HOP_DB) + linear_to_db(clampf(strength, 0.3, 1.0))
	player.pitch_scale = randf_range(0.92, 1.08)
	owner.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


## Облачко пыли у ног: кольцо серых пушинок разлетается в стороны и тает.
static func dust(owner: Node3D, strength: float) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = int(lerpf(6.0, 16.0, clampf(strength, 0.0, 1.0)))
	puff.lifetime = 0.45
	puff.explosiveness = 1.0
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	puff.emission_ring_axis = Vector3.UP
	puff.emission_ring_radius = 0.22
	puff.emission_ring_inner_radius = 0.15
	puff.emission_ring_height = 0.0
	puff.direction = Vector3(1, 0.25, 0)
	puff.spread = 180.0
	puff.flatness = 0.85
	puff.gravity = Vector3(0, 0.3, 0)
	puff.initial_velocity_min = 0.6
	puff.initial_velocity_max = 1.2 + strength
	puff.damping_min = 3.0
	puff.damping_max = 4.0
	puff.scale_amount_min = 0.7
	puff.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	puff.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.82, 0.76, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	puff.mesh = mesh
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var world := owner.get_tree().current_scene
	world.add_child(puff)
	puff.global_position = owner.global_position + Vector3.UP * 0.04
	puff.emitting = true
	puff.finished.connect(puff.queue_free)


## Короткий тон, частота плавно меняется от f0 до f1; noise — доля «шороха» (для удара).
static func _make(length: float, f0: float, f1: float, noise: float) -> AudioStreamWAV:
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var k := t / length
		phase += TAU * lerpf(f0, f1, k) / RATE
		var envelope := minf(1.0, t * 300.0) * pow(1.0 - k, 2.0)
		var value := (sin(phase) * (1.0 - noise) + (randf() - 0.5) * 2.0 * noise) * envelope * 0.6
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
