class_name Cosmetics
extends RefCounted
## Каталог одежды персонажа.
##
## Каждая вещь — .glb из tools/blender/character.py (имя файла = id вещи).
## В нём куски с именами частей тела (Head, Torso, ArmL, ArmR, LegL, LegR).
## Материал "Primary" красится в цвет игрока.
##
## Как открываются вещи:
##   price = 0  — доступна сразу;
##   price > 0  — покупается на рынке за рубли из кошелька;
##   (позже) "achievement": id — открывается за достижение.
## Чтобы добавить вещь: сделать её в Blender-скрипте и дописать сюда одну строку.

## MOUTH — в конце, чтобы номера старых слотов в сохранённых профилях не сдвинулись.
enum Slot { HAT, FACE, JACKET, PANTS, SHOES, NECK, MOUTH }

const SLOT_NAMES := {
	Slot.HAT: "Шапка",
	Slot.FACE: "Лицо",
	Slot.JACKET: "Верх",
	Slot.PANTS: "Штаны",
	Slot.SHOES: "Обувь",
	Slot.NECK: "Шея / спина",
	Slot.MOUTH: "Рот",
}

## Слоты, где всегда что-то надето (без «Ничего»): если в наряде пусто — эта вещь.
const DEFAULTS := {
	Slot.MOUTH: "mouth_line",
}

const DIR := "res://assets/models/character/cosmetics/"

## id вещи -> слот, название, цена в рублях (0 = бесплатно).
const ITEMS := {
	# Шапки
	"hat_kepka": {"slot": Slot.HAT, "name": "Кепарик", "price": 0},
	"hat_petushok": {"slot": Slot.HAT, "name": "Шапка-«петушок»", "price": 0},
	"hat_panama": {"slot": Slot.HAT, "name": "Панама", "price": 0},
	"hat_pompom": {"slot": Slot.HAT, "name": "Шапка с помпоном", "price": 0},
	"hat_pilotka": {"slot": Slot.HAT, "name": "Пилотка", "price": 100},
	"hat_tubeteika": {"slot": Slot.HAT, "name": "Тюбетейка", "price": 100},
	"hat_hardhat": {"slot": Slot.HAT, "name": "Каска строителя", "price": 100},
	"hat_fedora": {"slot": Slot.HAT, "name": "Фетровая шляпа", "price": 150},
	"hat_ushanka": {"slot": Slot.HAT, "name": "Ушанка", "price": 250},
	# Лицо
	"face_mustache": {"slot": Slot.FACE, "name": "Усы", "price": 0},
	"face_unibrow": {"slot": Slot.FACE, "name": "Монобровь", "price": 0},
	"face_plaster": {"slot": Slot.FACE, "name": "Пластырь", "price": 0},
	"face_bruise": {"slot": Slot.FACE, "name": "Фингал", "price": 0},
	"face_beard": {"slot": Slot.FACE, "name": "Борода-лопата", "price": 150},
	"face_welder_mask": {"slot": Slot.FACE, "name": "Маска сварщика", "price": 250},
	"face_gas_mask": {"slot": Slot.FACE, "name": "Противогаз", "price": 200},
	# Маска водящего в «Морожке»: в шкафу её нет (hidden), надевается только на раунд.
	"face_hockey_mask": {"slot": Slot.FACE, "name": "Хоккейная маска", "price": 0, "hidden": true},
	# Рот (рта у базовой головы нет — он всегда из этого слота, по умолчанию «Обычный»)
	"mouth_line": {"slot": Slot.MOUTH, "name": "Обычный", "price": 0},
	"mouth_o": {"slot": Slot.MOUTH, "name": "Удивлённый «О»", "price": 0},
	"mouth_sad": {"slot": Slot.MOUTH, "name": "Грустный", "price": 0},
	# Верх
	"jacket_abibas": {"slot": Slot.JACKET, "name": "Олимпийка «Абибас»", "price": 0},
	"jacket_alkogolichka": {"slot": Slot.JACKET, "name": "Майка-алкоголичка", "price": 0},
	"jacket_pioneer": {"slot": Slot.JACKET, "name": "Пионерская рубашка", "price": 0},
	"jacket_granny": {"slot": Slot.JACKET, "name": "Бабушкина кофта", "price": 100},
	"jacket_varenka": {"slot": Slot.JACKET, "name": "Джинсовка-варёнка", "price": 150},
	"jacket_seller_robe": {"slot": Slot.JACKET, "name": "Халат продавщицы", "price": 150},
	"jacket_dutik": {"slot": Slot.JACKET, "name": "Пуховик-«дутик»", "price": 200},
	"jacket_kosuha": {"slot": Slot.JACKET, "name": "Кожанка-косуха", "price": 300},
	"jacket_blazer": {"slot": Slot.JACKET, "name": "Малиновый пиджак", "price": 300},
	# Штаны
	"pants_abibas": {"slot": Slot.PANTS, "name": "Треники «Абибас»", "price": 0},
	"pants_school": {"slot": Slot.PANTS, "name": "Брюки со стрелками", "price": 0},
	"pants_pe_shorts": {"slot": Slot.PANTS, "name": "Шорты физрука", "price": 0},
	"pants_sharovary": {"slot": Slot.PANTS, "name": "Шаровары", "price": 100},
	"pants_family": {"slot": Slot.PANTS, "name": "Семейники в горошек", "price": 100},
	"pants_klesh": {"slot": Slot.PANTS, "name": "Брюки клёш", "price": 150},
	"pants_camo": {"slot": Slot.PANTS, "name": "Камуфляж", "price": 150},
	"pants_overalls": {"slot": Slot.PANTS, "name": "Рабочий комбинезон", "price": 200},
	# Обувь
	"shoes_kedy": {"slot": Slot.SHOES, "name": "Кеды", "price": 0},
	"shoes_galoshi": {"slot": Slot.SHOES, "name": "Галоши", "price": 0},
	"shoes_slippers": {"slot": Slot.SHOES, "name": "Шлёпанцы с носками", "price": 0},
	"shoes_valenki": {"slot": Slot.SHOES, "name": "Валенки", "price": 100},
	"shoes_rubber_boots": {"slot": Slot.SHOES, "name": "Резиновые сапоги", "price": 100},
	"shoes_platform": {"slot": Slot.SHOES, "name": "Туфли на платформе", "price": 200},
	"shoes_pumba": {"slot": Slot.SHOES, "name": "Кроссовки «Пумба»", "price": 250},
	# Шея и спина
	"back_ranets": {"slot": Slot.NECK, "name": "Школьный ранец", "price": 100},
	"back_bag": {"slot": Slot.NECK, "name": "Челночная сумка", "price": 200},
	"back_guitar": {"slot": Slot.NECK, "name": "Гитара", "price": 300},
	"neck_gold_chain": {"slot": Slot.NECK, "name": "Золотая цепь", "price": 400},
	# Новые: очки, бабушка, футбол, гопник
	"face_sunglasses": {"slot": Slot.FACE, "name": "Тёмные очки", "price": 150},
	"face_round_glasses": {"slot": Slot.FACE, "name": "Круглые очки", "price": 50},
	"hat_headscarf": {"slot": Slot.HAT, "name": "Платок в цветочек", "price": 0},
	# Платье длинное: занимает и верх, и штаны (covers).
	"jacket_dress": {
		"slot": Slot.JACKET, "name": "Платье в цветочек", "price": 150, "covers": [Slot.PANTS],
	},
	"shoes_boty": {"slot": Slot.SHOES, "name": "Боты «прощай, молодость»", "price": 50},
	# Номер на спине ставит игра: номер игрока (слот + 1).
	"jacket_football": {
		"slot": Slot.JACKET, "name": "Футболка с номером", "price": 100, "number": true,
	},
	"pants_football": {"slot": Slot.PANTS, "name": "Футбольные шорты", "price": 0},
	"shoes_bootsy": {"slot": Slot.SHOES, "name": "Бутсы с гетрами", "price": 150},
	"jacket_abibas_open": {"slot": Slot.JACKET, "name": "Олимпийка нараспашку", "price": 150},
	"pants_jeans": {"slot": Slot.PANTS, "name": "Джинсы-варёнки", "price": 100},
}


## Все вещи слота (id), в порядке каталога.
static func items_for_slot(slot: Slot) -> Array[String]:
	var result: Array[String] = []
	for id: String in ITEMS:
		if ITEMS[id]["slot"] == slot and not ITEMS[id].get("hidden", false):
			result.append(id)
	return result


## Вещь по умолчанию для слота («» — у слота можно ничего не надевать).
static func default_item(slot: int) -> String:
	return DEFAULTS.get(slot, "")


## Что на самом деле надето в слоте (с учётом вещи по умолчанию).
static func worn(outfit: Dictionary, slot: int) -> String:
	var id: String = outfit.get(slot, "")
	return id if id != "" else default_item(slot)


static func item_name(id: String) -> String:
	return ITEMS[id]["name"] if ITEMS.has(id) else "Ничего"


static func price(id: String) -> int:
	return ITEMS[id]["price"] if ITEMS.has(id) else 0


static func is_free(id: String) -> bool:
	return id == "" or price(id) == 0


## Какие ещё слоты занимает вещь (платье — и штаны). Пусто для обычных вещей.
static func covers(id: String) -> Array:
	return ITEMS[id].get("covers", []) if ITEMS.has(id) else []


## Какая вещь из наряда занимает слот, хотя надета в другой (платье — штаны).
## "" — никакая.
static func covered_by(outfit: Dictionary, slot: int) -> String:
	for other: int in outfit:
		if other != slot and covers(outfit[other]).has(slot):
			return outfit[other]
	return ""


## Надеть вещь в наряд с учётом «занятых» слотов: платье снимает штаны, штаны — платье.
## Возвращает слоты, которые пришлось освободить.
static func equip(outfit: Dictionary, slot: int, id: String) -> Array[int]:
	var cleared: Array[int] = []
	if id == "":
		outfit.erase(slot)
		return cleared
	outfit[slot] = id
	for covered: int in covers(id):
		if outfit.has(covered):
			outfit.erase(covered)
			cleared.append(covered)
	var blocker := covered_by(outfit, slot)
	if blocker != "":
		for other: int in outfit.keys():
			if outfit[other] == blocker:
				outfit.erase(other)
				cleared.append(other)
	return cleared


static func load_item(id: String) -> PackedScene:
	return load(DIR + id + ".glb") as PackedScene


## Случайный наряд (для ботов): в каждом слоте вещь или ничего.
static func random_outfit() -> Dictionary:
	var outfit := {}
	for slot: Slot in SLOT_NAMES:
		var options := items_for_slot(slot)
		if not options.is_empty() and randf() < 0.6:
			equip(outfit, slot, options.pick_random())
	return outfit
