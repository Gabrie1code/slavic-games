class_name RainWeather
extends Node3D
## Дождь во дворе «Морожки» — только картинка (на игру не влияет): капли падают сверху над всем
## двором, на земле лужи в случайных местах, небо и облака серые, свет тусклее, иногда молния
## (вспышка неба и света + ломаная светящаяся линия вдали).

const DROPS := 7000
## Над какой областью идёт дождь (половины размеров по X и Z) и с какой высоты.
const AREA := Vector2(46, 34)
const HEIGHT := 22.0
const PUDDLES := 16
## Небо в дождь (верх и горизонт градиента) и при вспышке молнии.
const SKY_RAIN := Color(0.3, 0.33, 0.38)
const HORIZON_RAIN := Color(0.44, 0.47, 0.52)
const SKY_FLASH := Color(0.82, 0.86, 0.95)
const CLOUD_RAIN := Color(0.42, 0.44, 0.5)
## Пауза между молниями (сек): случайно в этих пределах.
const LIGHTNING_GAP := Vector2(6.0, 14.0)

var _env: Environment
## Градиент неба двора (ProceduralSkyMaterial; null — небо одним цветом).
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _sun_energy := 1.0
var _next_flash := 0.0


## env — окружение двора (заменяется копией: иначе серое небо осталось бы и у следующего раунда),
## sun — солнце сцены, yard — двор (у него облака).
func start(world_env: WorldEnvironment, sun: DirectionalLight3D, yard: FreezeYard) -> void:
	_env = world_env.environment.duplicate() as Environment
	world_env.environment = _env
	_env.background_color = HORIZON_RAIN
	if _env.sky and _env.sky.sky_material is ProceduralSkyMaterial:
		_env.sky = _env.sky.duplicate(true) as Sky
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
		_sky.sun_angle_max = 0.0 # солнца за тучами не видно
	_env.ambient_light_energy *= 0.65
	_sun = sun
	_sun.light_energy *= 0.4
	_sun.light_color = Color(0.78, 0.82, 0.92)
	_sun_energy = _sun.light_energy
	_set_flash(0.0) # серое небо — только после того, как запомнили солнце (оно тоже в _set_flash)
	yard.tint_clouds(CLOUD_RAIN)
	yard.smoke.tint = Color(0.55, 0.56, 0.6)
	_build_drops()
	_build_puddles()
	_next_flash = randf_range(LIGHTNING_GAP.x * 0.5, LIGHTNING_GAP.y * 0.5)


func _process(delta: float) -> void:
	if _env == null:
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(LIGHTNING_GAP.x, LIGHTNING_GAP.y)
		_lightning()


func _build_drops() -> void:
	var rain := GPUParticles3D.new()
	rain.amount = DROPS
	rain.lifetime = 1.15
	rain.preprocess = 1.2
	rain.position.y = HEIGHT
	rain.visibility_aabb = AABB(Vector3(-AREA.x - 5, -HEIGHT - 2, -AREA.y - 5),
		Vector3(AREA.x * 2 + 10, HEIGHT + 6, AREA.y * 2 + 10))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(AREA.x, 0.5, AREA.y)
	process.direction = Vector3(0.08, -1, 0)
	process.spread = 2.0
	process.initial_velocity_min = 19.0
	process.initial_velocity_max = 23.0
	process.gravity = Vector3(0, -9.8, 0)
	rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.018, 0.5, 0.018)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.83, 0.92, 0.45)
	drop.material = mat
	rain.draw_pass_1 = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)


## Лужи: тёмные блестящие пятна разного размера и формы на земле (на площадке и вокруг).
func _build_puddles() -> void:
	var mat := StandardMaterial3D.new()
	# Мокрый асфальт, а не зеркало: не «металл» (иначе у водящего, где небо затемнено, лужи
	# отражали черноту и были чёрными дырами).
	mat.albedo_color = Color(0.36, 0.4, 0.46, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.0
	mat.roughness = 0.15
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.004
	mesh.radial_segments = 20
	mesh.rings = 1
	for i in PUDDLES:
		var puddle := MeshInstance3D.new()
		puddle.mesh = mesh
		puddle.material_override = mat
		puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r := randf_range(0.5, 1.6)
		puddle.scale = Vector3(r, 1.0, r * randf_range(0.45, 0.9))
		puddle.rotation.y = randf() * TAU
		puddle.position = Vector3(randf_range(-28, 28), 0.032, randf_range(-20, 20))
		add_child(puddle)


## Молния: небо и свет вспыхивают дважды, вдали на миг — ломаная светящаяся линия.
func _lightning() -> void:
	var bolt := _make_bolt()
	add_child(bolt)
	var tween := create_tween()
	for flash: float in [1.0, 0.6]:
		tween.tween_callback(_set_flash.bind(flash))
		tween.tween_interval(0.07)
		tween.tween_callback(_set_flash.bind(0.0))
		tween.tween_interval(0.09)
	tween.tween_callback(bolt.queue_free)


func _set_flash(amount: float) -> void:
	_env.background_color = HORIZON_RAIN.lerp(SKY_FLASH, amount)
	if _sky:
		_sky.sky_top_color = SKY_RAIN.lerp(SKY_FLASH, amount)
		_sky.sky_horizon_color = HORIZON_RAIN.lerp(SKY_FLASH, amount)
		_sky.ground_horizon_color = _sky.sky_horizon_color
	_sun.light_energy = _sun_energy * (1.0 + amount * 4.0)


## Ломаная линия молнии из тонких светящихся отрезков: от облаков к земле, в 200–300 м.
func _make_bolt() -> Node3D:
	var root := Node3D.new()
	var angle := randf() * TAU
	var dist := randf_range(200.0, 300.0)
	var point := Vector3(cos(angle) * dist, 150.0, sin(angle) * dist)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.93, 1.0)
	var side := Vector3(-sin(angle), 0, cos(angle)) # вбок от взгляда из двора
	while point.y > 0.0:
		var next := point + Vector3(0, -randf_range(12.0, 22.0), 0) + side * randf_range(-9.0, 9.0)
		next.y = maxf(next.y, 0.0)
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 1.2, point.distance_to(next))
		piece.mesh = box
		piece.material_override = mat
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(piece)
		piece.transform = Transform3D(Basis.looking_at(next - point, Vector3.RIGHT), (point + next) / 2.0)
		point = next
	return root
