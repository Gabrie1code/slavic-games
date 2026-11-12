class_name Cosmetics
extends RefCounted
## Каталог одежды персонажа.
##
## Каждая вещь — .glb из tools/blender/character.py (имя файла = id вещи).
## В нём куски с именами частей тела
## (Head, Torso, ArmL, ArmR, LegL, LegR). Материал "Primary" красится в цвет игрока.
## Чтобы добавить вещь: сделать её в Blender-скрипте и дописать сюда одну строку.

enum Slot { HAT, JACKET, PANTS, SHOES, ACCESSORY }

const SLOT_NAMES := {
	Slot.HAT: "Шапка",
	Slot.JACKET: "Куртка",
	Slot.PANTS: "Штаны",
	Slot.SHOES: "Обувь",
	Slot.ACCESSORY: "Аксессуар",
}

const DIR := "res://assets/models/character/cosmetics/"

## id вещи -> слот и название. Модель: DIR + id + ".glb".
const ITEMS := {
	"hat_kepka": {"slot": Slot.HAT, "name": "Кепарик"},
	"hat_ushanka": {"slot": Slot.HAT, "name": "Ушанка"},
	"jacket_abibas": {"slot": Slot.JACKET, "name": "Олимпийка «Абибас»"},
	"pants_abibas": {"slot": Slot.PANTS, "name": "Треники «Абибас»"},
	"shoes_kedy": {"slot": Slot.SHOES, "name": "Кеды"},
	"acc_glasses_drops": {"slot": Slot.ACCESSORY, "name": "Очки-капельки"},
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


static func load_item(id: String) -> PackedScene:
	return load(DIR + id + ".glb") as PackedScene


## Случайный наряд (для ботов): в каждом слоте вещь или ничего.
static func random_outfit() -> Dictionary:
	var outfit := {}
	for slot: Slot in SLOT_NAMES:
		var options := items_for_slot(slot)
		if not options.is_empty() and randf() < 0.7:
			outfit[slot] = options.pick_random()
	return outfit
