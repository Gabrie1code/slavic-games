class_name GroundGlow
extends MeshInstance3D
## Мягкое свечение на полу: круг, яркий в середине и плавно тающий к краю, слегка «дышит».
## Показывает место, куда можно подойти (зоны лобби), или вещь, которую можно подобрать
## (бусты в «Битве на битах»).

const PULSE_SPEED := 2.2

var _mat: StandardMaterial3D
var _alpha := 0.45
var _time := 0.0


## color — цвет свечения, radius — радиус круга (м), alpha — яркость в центре.
func setup(color: Color, radius: float, alpha: float = 0.45) -> GroundGlow:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	mesh = plane
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.45, Color(1, 1, 1, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = texture
	_mat.albedo_color = Color(color, alpha)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD # светится, а не закрашивает пол
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_alpha = alpha
	_time = randf() * TAU
	return self


func _process(delta: float) -> void:
	_time += delta * PULSE_SPEED
	_mat.albedo_color.a = _alpha * (0.75 + 0.25 * sin(_time))
