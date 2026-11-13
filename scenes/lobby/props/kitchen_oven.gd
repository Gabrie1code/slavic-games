class_name KitchenOven
extends HingedProp
## Духовка газовой плиты: дверца откидывается вниз на 12.5° (петля снизу), внутри загорается свет —
## видно запечённую курицу на стеклянном блюде (часть модели плиты, не трогается).
## Закрывается рукой или сама через 15 сек. Узел — дочерний у плиты, в её начале координат
## (плита смотрит на +Z).
## Модели — tools/blender/kitchen.py (kitchen_stove, kitchen_oven_door).

const DOOR := preload("res://assets/models/kitchen/kitchen_oven_door.glb")
## Петля дверцы: нижний передний край проёма духовки (в координатах плиты).
const HINGE := Vector3(0.0, 0.165, 0.305)

var _light: OmniLight3D
var _bulb_mat: StandardMaterial3D


func _ready() -> void:
	door = DOOR.instantiate() as Node3D
	door.position = HINGE
	add_child(door)
	swing_x = true
	open_time = 15.0 # сама закрывается через 15 сек, как шкафчик
	cooldown = 2.0 # открыть/закрыть — не чаще раза в 2 сек
	open_angle = deg_to_rad(12.5) # чуть приоткрыта — как у старых плит
	open_text = "Открыть духовку"
	close_text = "Закрыть духовку"
	front_offset = Vector3(0.0, 0.4, 0.75)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.25) # тёплый оранжевый, как в настоящей духовке
	# Светит только внутри: небольшой радиус и тени — стенки духовки не пускают свет наружу
	# (раньше светилась вся плита снаружи).
	_light.light_energy = 1.2
	_light.omni_range = 0.42
	_light.shadow_enabled = true
	_light.position = Vector3(0.0, 0.5, 0.0)
	_light.visible = false
	add_child(_light)
	# Лампочка в духовке (материал OvenBulb модели плиты) горит, только пока дверца открыта.
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bulb_mat.albedo_color = LobbyLamp.BULB_OFF
	for node in get_parent().find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var surface := mesh_instance.mesh.surface_get_material(i)
			if surface and surface.resource_name.begins_with("OvenBulb"):
				mesh_instance.set_surface_override_material(i, _bulb_mat)


## Свет внутри плавно разгорается, пока дверца открывается.
func _door_moved(amount: float) -> void:
	_light.visible = amount > 0.02
	_light.light_energy = 1.2 * amount
	_bulb_mat.albedo_color = LobbyLamp.BULB_OFF.lerp(Color(1.0, 0.72, 0.35), amount)
