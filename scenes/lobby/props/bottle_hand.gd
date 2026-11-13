class_name BottleHand
extends RefCounted
## Бутылка в руке у игроков лобби (вынесено из LobbyGadgets): взять со стола (ЛКМ рядом),
## выпить (ЛКМ, раз в COOLDOWN сек), бросить (G), вид «в кадре» у держащего.
## Больше DRUNK_COUNT глотков за DRUNK_WINDOW сек — опьянение (шатает, камера плывёт, ведёт
## в сторону) на DRUNK_TIME сек. Больше VOMIT_COUNT за VOMIT_WINDOW — рвота (VomitFx), бутылка
## пропадает, опьянение проходит и счёт начинается заново.

const REACH := 1.0
const COOLDOWN := 4.0
const DRUNK_COUNT := 3
const DRUNK_WINDOW := 20.0
const DRUNK_TIME := 30.0
const VOMIT_COUNT := 5
const VOMIT_WINDOW := 30.0

var kitchen: KitchenRoom
var characters: Dictionary
var world: Node
## PlayerData.id -> KitchenBottle в руке; и вид «в кадре».
var _held: Dictionary = {}
var _views: Dictionary = {}
## PlayerData.id -> когда снова можно пить (сек) / времена глотков (Array[float]).
var _ready_at: Dictionary = {}
var _sips: Dictionary = {}


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
	var wait := _cooldown_left(p)
	var text := "Выпить" if wait <= 0.0 or bottle.drinking else "Выпить (через %d с)" % ceili(wait)
	var result: Array[Dictionary] = [
		LobbyGadgets.entry(LobbyGadgets.attack_key(p), text, bottle.drinking or wait > 0.0),
		LobbyGadgets.entry(LobbyGadgets.drop_key(p), "Выбросить бутылку на пол", bottle.drinking)]
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
	if p.input.is_just_pressed("attack") and not bottle.drinking and _cooldown_left(p) <= 0.0:
		_ready_at[p.id] = _now() + COOLDOWN
		bottle.drink(character, view, _after_sip.bind(p))
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


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _cooldown_left(p: PlayerData) -> float:
	return maxf(0.0, float(_ready_at.get(p.id, 0.0)) - _now())


## Допил глоток: считаем глотки за последние VOMIT_WINDOW сек — опьянение или рвота.
func _after_sip(p: PlayerData) -> void:
	if not characters.has(p.id):
		return
	var character: PlayerCharacter = characters[p.id]
	var now := _now()
	var sips: Array[float] = []
	for t: float in _sips.get(p.id, []):
		if now - t <= VOMIT_WINDOW:
			sips.append(t)
	sips.append(now)
	_sips[p.id] = sips
	var recent := 0
	for t in sips:
		if now - t <= DRUNK_WINDOW:
			recent += 1
	if sips.size() > VOMIT_COUNT:
		_sips.erase(p.id)
		character.drunk_left = 0.0 # после рвоты — больше никаких эффектов
		if holds(p):
			var bottle: KitchenBottle = _held[p.id]
			_let_go(p)
			bottle.vanish(character)
		VomitFx.play(character, world as Node3D)
	elif recent > DRUNK_COUNT:
		character.drunk_left = maxf(character.drunk_left, DRUNK_TIME)


func _let_go(p: PlayerData) -> void:
	_held.erase(p.id)
	if is_instance_valid(_views.get(p.id)):
		(_views[p.id] as Node).queue_free()
	_views.erase(p.id)
