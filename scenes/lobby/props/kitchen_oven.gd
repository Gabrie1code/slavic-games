class_name KitchenOven
extends HingedProp
## Духовка газовой плиты: дверца откидывается вниз на 50° (петля снизу), внутри загорается свет —
## видно запечённую курицу на стеклянном блюде (часть модели плиты, не трогается).
## Закрывается рукой. Узел — дочерний у плиты, в её начале координат (плита смотрит на +Z).
## Модели — tools/blender/kitchen.py (kitchen_stove, kitchen_oven_door).

const DOOR := preload("res://assets/models/kitchen/kitchen_oven_door.glb")
## Петля дверцы: нижний передний край проёма духовки (в координатах плиты).
const HINGE := Vector3(0.0, 0.165, 0.3)

var _light: OmniLight3D
var _bulb_mat: StandardMaterial3D


func _ready() -> void:
	door = DOOR.instantiate() as Node3D
	door.position = HINGE
	add_child(door)
	swing_x = true
	open_angle = deg_to_rad(50.0) # не до конца, под углом — как у старых плит
	open_text = "Открыть духовку"
	close_text = "Закрыть духовку"
	front_offset = Vector3(0.0, 0.4, 0.75)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.78, 0.45)
	_light.light_energy = 1.2
	_light.omni_range = 0.8
	_light.position = Vector3(0.0, 0.58, 0.0)
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
	_bulb_mat.albedo_color = LobbyLamp.BULB_OFF.lerp(LobbyLamp.BULB_ON, amount)
