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
const DRUNK_TIME := 15.0
const VOMIT_COUNT := 5
## 5 глотков за BLUR_WINDOW сек — сильное опьянение: размытие и двоение на BLUR_TIME сек.
const BLUR_COUNT := 5
const BLUR_WINDOW := 25.0
const BLUR_TIME := 12.5
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
## PlayerData.id -> камера от первого лица (для своей струи «из-за экрана»).
var _cams: Dictionary = {}


func _init(room: KitchenRoom, chars: Dictionary, apartment: Node) -> void:
	kitchen = room
	characters = chars
	world = apartment


func holds(p: PlayerData) -> bool:
	if _held.has(p.id) and not is_instance_valid(_held[p.id]):
		_held.erase(p.id)
	return _held.has(p.id)


## Бутылка рядом, на которую смотрит игрок: на столе или брошенная на полу (null — нет).
## Рука свободна — проверяет вызывающий.
func _reachable(p: PlayerData) -> KitchenBottle:
	if not characters.has(p.id):
		return null
	var character := characters[p.id] as Node3D
	for node in character.get_tree().get_nodes_in_group("kitchen_bottle"):
		var bottle := node as KitchenBottle
		if bottle == null or bottle.state == KitchenBottle.State.HELD or bottle.is_queued_for_deletion():
			continue
		var to := bottle.global_position - character.global_position
		if Vector2(to.x, to.z).length() < REACH \
				and LobbyGadgets.facing(character, bottle.global_position):
			return bottle
	return null


func can_take(p: PlayerData) -> bool:
	return _reachable(p) != null


func take_hint(p: PlayerData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var bottle := _reachable(p)
	if bottle:
		var text := "Взять бутылку" if bottle == kitchen.bottle else "Подобрать бутылку"
		result.append(LobbyGadgets.entry(LobbyGadgets.attack_key(p), text))
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
	var bottle := _reachable(p)
	if bottle == null:
		return false
	if bottle == kitchen.bottle:
		kitchen.take_bottle() # со стола — через 20 сек там появится новая
	_held[p.id] = bottle
	bottle.hold(p, characters[p.id])
	return true


## Каждый кадр у держащего: вид в кадре, ЛКМ — выпить, G — бросить.
func process(p: PlayerData, camera: Camera3D) -> void:
	var bottle: KitchenBottle = _held[p.id]
	var character: PlayerCharacter = characters[p.id]
	_cams[p.id] = camera
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
	var heavy := 0
	for t in sips:
		if now - t <= DRUNK_WINDOW:
			recent += 1
		if now - t <= BLUR_WINDOW:
			heavy += 1
	if sips.size() > VOMIT_COUNT:
		_sips.erase(p.id)
		character.drunk_left = 0.0 # после рвоты — больше никаких эффектов
		character.blur_left = 0.0
		if holds(p):
			var bottle: KitchenBottle = _held[p.id]
			_let_go(p)
			bottle.vanish(character)
		var cam: Camera3D = _cams.get(p.id) if is_instance_valid(_cams.get(p.id)) else null
		VomitFx.play(character, world as Node3D, cam, 1 << (p.slot + 10))
	elif heavy >= BLUR_COUNT:
		character.drunk_left = maxf(character.drunk_left, DRUNK_TIME)
		character.blur_left = maxf(character.blur_left, BLUR_TIME)
	elif recent > DRUNK_COUNT:
		character.drunk_left = maxf(character.drunk_left, DRUNK_TIME)


func _let_go(p: PlayerData) -> void:
	_held.erase(p.id)
	if is_instance_valid(_views.get(p.id)):
		(_views[p.id] as Node).queue_free()
	_views.erase(p.id)
