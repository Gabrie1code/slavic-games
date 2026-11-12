class_name IceBuilder
extends RefCounted
## Ледяная глыба для «Морожки» (вынесено из freeze_tag.gd): прозрачная шестигранная призма
## во весь рост, светлые рёбра, матовая крышка, кристаллы у основания, снежинки.
## Материалы создаются один раз в конструкторе и общие для всех глыб.

## Радиус и высота глыбы (персонаж целиком внутри).
const ICE_RADIUS := 0.78
const ICE_HEIGHT := 2.25
const SNOWFLAKE := preload("res://assets/textures/fx/snowflake.png")

var ice_material: StandardMaterial3D
var core_material: StandardMaterial3D
var edge_material: StandardMaterial3D
var shard_material: StandardMaterial3D
var flake_material: StandardMaterial3D


func _init() -> void:
	ice_material = StandardMaterial3D.new()
	ice_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_material.albedo_color = Color(0.6, 0.86, 1.0, 0.42)
	ice_material.roughness = 0.05
	ice_material.metallic_specular = 1.0
	ice_material.rim_enabled = true
	ice_material.rim = 1.0
	ice_material.rim_tint = 0.2
	ice_material.emission_enabled = true
	ice_material.emission = Color(0.35, 0.65, 0.95)
	ice_material.emission_energy_multiplier = 0.35
	core_material = StandardMaterial3D.new()
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.albedo_color = Color(0.92, 0.97, 1.0, 0.25)
	core_material.emission_enabled = true
	core_material.emission = Color(0.7, 0.85, 1.0)
	core_material.emission_energy_multiplier = 0.4
	ice_material.cull_mode = BaseMaterial3D.CULL_DISABLED # видны и дальние грани — «объём»
	ice_material.albedo_color = Color(0.62, 0.86, 1.0, 0.24)
	core_material.albedo_color = Color(0.92, 0.97, 1.0, 0.55)
	edge_material = StandardMaterial3D.new()
	edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	edge_material.albedo_color = Color(0.9, 0.97, 1.0, 0.85)
	shard_material = StandardMaterial3D.new()
	shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_material.albedo_color = Color(0.75, 0.93, 1.0, 0.75)
	shard_material.roughness = 0.05
	shard_material.emission_enabled = true
	shard_material.emission = Color(0.45, 0.75, 1.0)
	shard_material.emission_energy_multiplier = 0.5
	flake_material = StandardMaterial3D.new()
	flake_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake_material.albedo_texture = SNOWFLAKE
	flake_material.vertex_color_use_as_albedo = true


## Ледяная глыба как на картинке режима: высокая прозрачная шестигранная призма во весь рост
## (персонаж внутри хорошо виден и подкрашен синим), яркие светлые рёбра, матовая крышка,
## гроздь кристаллов у основания и кружащиеся снежинки.
func build() -> Node3D:
	var root := Node3D.new()
	var block := MeshInstance3D.new()
	var block_mesh := CylinderMesh.new()
	block_mesh.top_radius = ICE_RADIUS
	block_mesh.bottom_radius = ICE_RADIUS
	block_mesh.height = ICE_HEIGHT
	block_mesh.radial_segments = 6
	block_mesh.rings = 1
	block.mesh = block_mesh
	block.material_override = ice_material
	block.position.y = ICE_HEIGHT / 2.0
	root.add_child(block)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = ICE_RADIUS * 0.97
	cap_mesh.bottom_radius = ICE_RADIUS * 0.97
	cap_mesh.height = 0.04
	cap_mesh.radial_segments = 6
	cap.mesh = cap_mesh
	cap.material_override = core_material
	cap.position.y = ICE_HEIGHT - 0.02
	root.add_child(cap)
	# Светлые рёбра: 6 вертикальных и по 6 по верхнему и нижнему краю.
	for i in 6:
		var a := TAU * i / 6.0
		var corner := Vector3(sin(a), 0.0, cos(a)) * ICE_RADIUS
		var next := Vector3(sin(a + TAU / 6.0), 0.0, cos(a + TAU / 6.0)) * ICE_RADIUS
		root.add_child(_ice_edge(corner, corner + Vector3.UP * ICE_HEIGHT))
		for y: float in [0.02, ICE_HEIGHT]:
			root.add_child(_ice_edge(corner + Vector3.UP * y, next + Vector3.UP * y))
	# Кристаллы у основания: гроздьями, наружу и вверх.
	for i in 14:
		var shard := MeshInstance3D.new()
		var shard_mesh := CylinderMesh.new()
		shard_mesh.top_radius = 0.0
		shard_mesh.bottom_radius = randf_range(0.07, 0.15)
		shard_mesh.height = randf_range(0.3, 0.75)
		shard_mesh.radial_segments = 6
		shard.mesh = shard_mesh
		shard.material_override = shard_material
		var a := TAU * i / 14.0 + randf_range(-0.15, 0.15)
		var dist := ICE_RADIUS + randf_range(-0.05, 0.12)
		shard.position = Vector3(sin(a) * dist, shard_mesh.height * 0.3, cos(a) * dist)
		var tilt := randf_range(0.35, 0.8)
		shard.rotation = Vector3(cos(a) * tilt, randf() * TAU, -sin(a) * tilt)
		root.add_child(shard)
	root.add_child(_snowflakes())
	return root


## Светлое ребро льда между точками a и b.
func _ice_edge(a: Vector3, b: Vector3) -> MeshInstance3D:
	var edge := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.045, 0.045, a.distance_to(b))
	edge.mesh = mesh
	edge.material_override = edge_material
	edge.position = (a + b) / 2.0
	var dir := (b - a).normalized()
	var up := Vector3.RIGHT if absf(dir.y) > 0.9 else Vector3.UP
	edge.basis = Basis.looking_at(dir, up)
	return edge


## Снежинки, медленно кружащие вокруг глыбы. CPU-частицы: в отличие от GPU-частиц им не нужно
## собирать шейдер в момент заморозки (из-за этого раньше игра на миг подвисала).
func _snowflakes() -> CPUParticles3D:
	var flakes := CPUParticles3D.new()
	flakes.amount = 10
	flakes.lifetime = 2.2
	flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flakes.emission_box_extents = Vector3(ICE_RADIUS + 0.15, ICE_HEIGHT / 2.0, ICE_RADIUS + 0.15)
	flakes.gravity = Vector3(0, 0.12, 0)
	flakes.initial_velocity_min = 0.05
	flakes.initial_velocity_max = 0.2
	flakes.scale_amount_min = 0.6
	flakes.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	flakes.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	quad.material = flake_material
	flakes.mesh = quad
	flakes.position.y = ICE_HEIGHT / 2.0
	return flakes
