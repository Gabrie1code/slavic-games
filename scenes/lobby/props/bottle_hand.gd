class_name BottleHand
extends RefCounted
## Бутылка в руке у игроков лобби (вынесено из LobbyGadgets): взять со стола (ЛКМ рядом),
## выпить (ЛКМ), бросить (G), вид «в кадре» у держащего.

const REACH := 1.0

var kitchen: KitchenRoom
var characters: Dictionary
var world: Node
## PlayerData.id -> KitchenBottle в руке; и вид «в кадре».
var _held: Dictionary = {}
var _views: Dictionary = {}


func _init(room: KitchenRoom, chars: Dictionary, apartment: Node) -> void:
	kitchen = room
	characters = chars
	world = apartment


func holds(p: PlayerData) -> bool:
	if _held.has(p.id) and not is_instance_valid(_held[p.id]):
		_held.erase(p.id)
	return _held.has(p.id)


## Бутылка на столе рядом, на которую смотрит игрок (рука свободна — проверяет вызывающий).
func can_take(p: PlayerData) -> bool:
	var bottle := kitchen.bottle
	if bottle == null or not characters.has(p.id):
		return false
	var character := characters[p.id] as Node3D
	var to := bottle.global_position - character.global_position
	return Vector2(to.x, to.z).length() < REACH \
		and LobbyGadgets.facing(character, bottle.global_position)


func take_hint(p: PlayerData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if can_take(p):
		result.append(LobbyGadgets.entry(LobbyGadgets.attack_key(p), "Взять бутылку"))
	return result


func hint(p: PlayerData) -> Array[Dictionary]:
	var bottle: KitchenBottle = _held[p.id]
	var result: Array[Dictionary] = [
		LobbyGadgets.entry(LobbyGadgets.attack_key(p), "Выпить", bottle.drinking),
		LobbyGadgets.entry(LobbyGadgets.drop_key(p), "Бросить бутылку")]
	return result


## ЛКМ со свободной рукой у стола — взять бутылку. true — взял.
func try_take(p: PlayerData) -> bool:
	if not can_take(p):
		return false
	var bottle := kitchen.take_bottle()
	_held[p.id] = bottle
	bottle.hold(p, characters[p.id])
	return true


## Каждый кадр у держащего: вид в кадре, ЛКМ — выпить, G — бросить.
func process(p: PlayerData, camera: Camera3D) -> void:
	var bottle: KitchenBottle = _held[p.id]
	var character: PlayerCharacter = characters[p.id]
	var view: Node3D = _views.get(p.id) if is_instance_valid(_views.get(p.id)) else null
	if camera and view == null:
		view = HandHold.make_view(KitchenBottle.make_model(), 1 << (p.slot + 10),
			Vector3(0.24, -0.38, -0.45), Vector3(0.1, 0.3, -0.1), 1.0)
		camera.add_child(view)
		_views[p.id] = view
	if p.input.is_just_pressed("attack"):
		bottle.drink(character, view)
	if p.input.is_just_pressed("drop") and not bottle.drinking:
		_let_go(p)
		bottle.throw(character, world, LobbyGadgets.look_dir(character, camera))


## Игрок ушёл из лобби — бутылка падает под ноги.
func release(p: PlayerData) -> void:
	if not holds(p):
		return
	var bottle: KitchenBottle = _held[p.id]
	_let_go(p)
	if characters.has(p.id):
		bottle.throw(characters[p.id], world, Vector3.ZERO)


func _let_go(p: PlayerData) -> void:
	_held.erase(p.id)
	if is_instance_valid(_views.get(p.id)):
		(_views[p.id] as Node).queue_free()
	_views.erase(p.id)
