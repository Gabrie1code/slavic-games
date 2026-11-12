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

enum Slot { HAT, FACE, JACKET, PANTS, SHOES, NECK }

const SLOT_NAMES := {
	Slot.HAT: "Шапка",
	Slot.FACE: "Лицо",
	Slot.JACKET: "Верх",
	Slot.PANTS: "Штаны",
	Slot.SHOES: "Обувь",
	Slot.NECK: "Шея / спина",
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
}


## Все вещи слота (id), в порядке каталога.
static func items_for_slot(slot: Slot) -> Array[String]:
	var result: Array[String] = []
	for id: String in ITEMS:
		if ITEMS[id]["slot"] == slot:
			result.append(id)
	return result


static func item_name(id: String) -> String:
	return ITEMS[id]["name"] if ITEMS.has(id) else "Ничего"


static func price(id: String) -> int:
	return ITEMS[id]["price"] if ITEMS.has(id) else 0


static func is_free(id: String) -> bool:
	return id == "" or price(id) == 0


static func load_item(id: String) -> PackedScene:
	return load(DIR + id + ".glb") as PackedScene


## Случайный наряд (для ботов): в каждом слоте вещь или ничего.
static func random_outfit() -> Dictionary:
	var outfit := {}
	for slot: Slot in SLOT_NAMES:
		var options := items_for_slot(slot)
		if not options.is_empty() and randf() < 0.6:
			outfit[slot] = options.pick_random()
	return outfit
