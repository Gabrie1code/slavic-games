class_name Apartment
extends Node3D
## Лобби — советская квартира: гостиная и спальня.
##
## Гостиная (по правилам интерьеров: один центр внимания, мягкая мебель смотрит на него,
## ковёр «собирает» зону отдыха, проходы ~90 см, центр комнаты свободен для беготни):
##   у задней стены «стенка» — сервант с хрусталём, телевизор (старт игры), книжная секция с радио;
##   напротив телевизора диван (можно сесть), журнальный столик на ковре, кресло у стены с ковром;
##   окно со шторами и тюлем, гантели, обеденный стол со стульями, торшер, люстра.
## Спальня: шкаф с зеркалом (примерочная и покупки), кровать с ковром над ней, тумбочка с лампой.
## Игровая комната («игра на рубли») — слева от гостиной (дверь в левой стене):
## стол рулетки, игровые автоматы, неон.
##
## Сверху (вид от третьего лица) нет потолка и передних стен — «срез». Потолок и передние стены
## есть только для вида от первого лица: они на отдельном слое FP_ONLY_LAYER.
## Координаты: X вправо, Z к камере. Игровая X −11.5..−6, гостиная X −6..3.1, спальня X 3.1..9.

const DIR := "res://assets/models/apartment/"
const TV_SCENE := preload("res://assets/models/props/soviet_tv.glb")

## Слой видимости: только камеры от первого лица (потолок, передние стены).
const FP_ONLY_LAYER := 1 << 19
## Лампа над столом игры на рубли: отдельный слой, чтобы камера стола могла её не рисовать,
## когда смотрит сверху (иначе абажур закрывает сукно). Остальным видна как FP-only вещь.
const RUBGAME_LAMP_LAYER := 1 << 15
## Слой только для общей камеры сверху (камеры от первого лица его не рисуют): плоская
## картинка за окном, чтобы сверху в проёме не было дыры.
const OVERVIEW_ONLY_LAYER := 1 << 6
## Проём окна в задней стене гостиной: x от, x до, y от, y до (рама модели перекрывает края).
const WINDOW_HOLE := Rect2(0.95, 0.92, 1.4, 1.46)

const WALL_HEIGHT := 3.0
const BACK_Z := -4.0
const LIVING_FRONT_Z := 3.5
const BEDROOM_FRONT_Z := 1.5
const LEFT_X := -6.0
const PARTITION_X := 3.1
const RIGHT_X := 9.0
## Дверной проём между комнатами (по Z).
const DOOR_FROM_Z := -1.8
const DOOR_TO_Z := -0.2
## Игровая комната: левее гостиной, задняя стена ближе. Дверь — в левой стене гостиной.
const RUBGAME_LEFT_X := -11.5
const RUBGAME_BACK_Z := -2.5
const RUBGAME_DOOR_FROM_Z := 1.6
const RUBGAME_DOOR_TO_Z := 3.0

## Важные точки (лобби вешает на них зоны).
const TV_POS := Vector3(-2.6, 0, -3.5)
const TV_ZONE := Vector3(-2.6, 0, -2.35)
const WARDROBE_POS := Vector3(4.6, 0, -3.62)
const WARDROBE_ZONE := Vector3(4.6, 0, -2.5)
const SOFA_POS := Vector3(-2.6, 0, 0.95)
const SOFA_YAW := PI # диван смотрит на телевизор (на −Z)
const RUBGAME_TABLE_POS := Vector3(-8.6, 0, 0.2)
## Где нажимать «сыграть» — перед столом (и вообще рядом со столом, см. лобби).
const RUBGAME_ZONE := Vector3(-7.9, 0, 1.45)
const PHONE_TABLE_POS := Vector3(-5.55, 0, 0.85)
const LAMP_ENERGY := 1.3
const LAMP_BACK := 8.0
const LAMP_FADE := 1.5
const SPAWNS: Array[Vector3] = [
	Vector3(-0.3, 0.3, -1.2), Vector3(0.9, 0.3, -1.2),
	Vector3(-0.3, 0.3, -2.4), Vector3(0.9, 0.3, -2.4),
]

const CRYSTAL := Color(0.75, 0.9, 1.0, 0.6)
const CLAY := Color(0.65, 0.3, 0.15)
const PLANT := Color(0.15, 0.45, 0.15)
const GLASS := Color(0.8, 0.95, 0.9, 0.6)

## Места на диване и в кресле: [{"pos": точка посадки, "yaw": куда смотрит сидящий,
## "approach": где подойти, "name": текст кнопки}].
var seats: Array[Dictionary] = []
## Стол рулетки (крутится сам каждые 20 секунд).
var rubgame_table: RubgameTable
## Граммофон (играет три ноты) и торшер (включается; повалили — гаснет).
var gramophone: Tippable
var floor_lamp: Tippable
## Торшер включён (горит, только пока стоит на месте). Выключили кнопкой — через LAMP_BACK сек
## сам включается и плавно разгорается (как восстанавливается разбитая посуда).
var lamp_on := true
## Тумбочка в спальне: ящик с баллончиком.
var nightstand: Nightstand
## Дисковый телефон (гостиная, у двери в игровую) и кот.
var phone: RotaryPhone
## Туалет (унитаз — toilet_room.toilet).
var toilet_room: ToiletRoom
## Экраны игровых автоматов (кнопкой действия их можно «сломать» на 8 сек).
var arcade_screens: Array[ArcadeScreen] = []
var cat: LobbyCat

var _lamp_light: OmniLight3D
var _lamp_glow: MeshInstance3D
var _lamp_glow_mat: StandardMaterial3D
var _lamp_level := 1.0 # 0 — не горит, 1 — горит в полную силу
var _lamp_back_at := 0.0
## Ночник на тумбочке в спальне: горит всегда; разбили — не светит, пока не восстановится.
var _night_lamp: Breakable
var _night_light: OmniLight3D
var _night_bulb_mat: StandardMaterial3D
var _time := 0.0
## Модель окна гостиной (у неё прячем «небо», чтобы видеть вид за проёмом).
var _last_window: Node3D


func _ready() -> void:
	_build_rooms()
	_build_living_room()
	_build_bedroom()
	_build_rubgame()
	_build_living_extras()
	toilet_room = ToiletRoom.new()
	add_child(toilet_room)
	_build_decor()


# ---------------- Стены и пол ----------------

func _build_rooms() -> void:
	var parquet := _mat(Color("6b4423"), 0.6)
	var bedroom_floor := _mat(Color("7a5a3a"), 0.7)
	var wallpaper := _mat(Color("c9b48a"), 0.9)
	var wallpaper_bed := _mat(Color("a9b896"), 0.9)
	var skirting := _mat(Color("4a2a12"), 0.6)
	var living_w := PARTITION_X - LEFT_X
	var bed_w := RIGHT_X - PARTITION_X
	_solid_box(Vector3(living_w, 0.2, LIVING_FRONT_Z - BACK_Z),
		Vector3((LEFT_X + PARTITION_X) / 2, -0.1, (BACK_Z + LIVING_FRONT_Z) / 2), parquet)
	_solid_box(Vector3(bed_w, 0.2, BEDROOM_FRONT_Z - BACK_Z),
		Vector3((PARTITION_X + RIGHT_X) / 2, -0.1, (BACK_Z + BEDROOM_FRONT_Z) / 2), bedroom_floor)
	# Задняя стена (гостиная и спальня разного цвета) и плинтус.
	# В задней стене гостиной — проём под окном (за ним объёмный вид, см. _build_window_view).
	_wall_with_hole(LEFT_X, PARTITION_X, WINDOW_HOLE, wallpaper)
	_solid_box(Vector3(bed_w, WALL_HEIGHT, 0.2),
		Vector3((PARTITION_X + RIGHT_X) / 2, WALL_HEIGHT / 2, BACK_Z - 0.1), wallpaper_bed)
	_box(Vector3(RIGHT_X - LEFT_X, 0.12, 0.04),
		Vector3((LEFT_X + RIGHT_X) / 2, 0.06, BACK_Z + 0.02), skirting)
	# Боковые стены.
	# Левая стена гостиной — с дверью в игровую (и проём, и стена до неё).
	_solid_box(Vector3(0.2, WALL_HEIGHT, RUBGAME_DOOR_FROM_Z - BACK_Z),
		Vector3(LEFT_X - 0.1, WALL_HEIGHT / 2, (BACK_Z + RUBGAME_DOOR_FROM_Z) / 2), wallpaper)
	_solid_box(Vector3(0.2, WALL_HEIGHT, LIVING_FRONT_Z - RUBGAME_DOOR_TO_Z),
		Vector3(LEFT_X - 0.1, WALL_HEIGHT / 2, (RUBGAME_DOOR_TO_Z + LIVING_FRONT_Z) / 2), wallpaper)
	_box(Vector3(0.2, WALL_HEIGHT - 2.4, RUBGAME_DOOR_TO_Z - RUBGAME_DOOR_FROM_Z),
		Vector3(LEFT_X - 0.1, 2.4 + (WALL_HEIGHT - 2.4) / 2,
		(RUBGAME_DOOR_FROM_Z + RUBGAME_DOOR_TO_Z) / 2), wallpaper)
	_solid_box(Vector3(0.2, WALL_HEIGHT, BEDROOM_FRONT_Z - BACK_Z),
		Vector3(RIGHT_X + 0.1, WALL_HEIGHT / 2, (BACK_Z + BEDROOM_FRONT_Z) / 2), wallpaper_bed)
	# Перегородка с дверным проёмом.
	var partition_h := 2.4
	_solid_box(Vector3(0.16, partition_h, DOOR_FROM_Z - BACK_Z),
		Vector3(PARTITION_X, partition_h / 2, (BACK_Z + DOOR_FROM_Z) / 2), wallpaper)
	_solid_box(Vector3(0.16, partition_h, BEDROOM_FRONT_Z - DOOR_TO_Z),
		Vector3(PARTITION_X, partition_h / 2, (DOOR_TO_Z + BEDROOM_FRONT_Z) / 2), wallpaper)
	# Невидимые стенки спереди, чтобы не уйти из квартиры.
	_invisible_wall(Vector3(living_w, 3, 0.4),
		Vector3((LEFT_X + PARTITION_X) / 2, 1.5, LIVING_FRONT_Z + 0.2))
	_invisible_wall(Vector3(bed_w, 3, 0.4),
		Vector3((PARTITION_X + RIGHT_X) / 2, 1.5, BEDROOM_FRONT_Z + 0.2))
	# Потолок и передние стены — только для вида от первого лица.
	var ceiling := _mat(Color("e8e2d2"), 0.9)
	# Потолок твёрдый для всех видов (сам он виден только от первого лица): с дивана
	# допрыгивали выше потолка, и камера оказывалась над квартирой.
	_invisible_wall(Vector3(RIGHT_X - RUBGAME_LEFT_X, 0.3, LIVING_FRONT_Z - BACK_Z),
		Vector3((RUBGAME_LEFT_X + RIGHT_X) / 2, WALL_HEIGHT + 0.15, (BACK_Z + LIVING_FRONT_Z) / 2))
	_fp_only(_box(Vector3(RIGHT_X - RUBGAME_LEFT_X, 0.1, LIVING_FRONT_Z - BACK_Z),
		Vector3((RUBGAME_LEFT_X + RIGHT_X) / 2, WALL_HEIGHT + 0.05, (BACK_Z + LIVING_FRONT_Z) / 2),
		ceiling))
	_fp_only(_box(Vector3(living_w, WALL_HEIGHT, 0.2),
		Vector3((LEFT_X + PARTITION_X) / 2, WALL_HEIGHT / 2, LIVING_FRONT_Z + 0.1), wallpaper))
	_fp_only(_box(Vector3(bed_w, WALL_HEIGHT, 0.2),
		Vector3((PARTITION_X + RIGHT_X) / 2, WALL_HEIGHT / 2, BEDROOM_FRONT_Z + 0.1), wallpaper_bed))
	# Правее гостиной перед спальней — туалет (ToiletRoom), стена с дверью строится там.
	# Перегородка между комнатами низкая (2.4 м — сверху видно обе комнаты). От первого лица
	# верх перегородки до потолка закрыт по всей длине (раньше закрыт был только проём — дыры).
	_fp_only(_box(Vector3(0.16, WALL_HEIGHT - 2.4, BEDROOM_FRONT_Z - BACK_Z),
		Vector3(PARTITION_X, 2.4 + (WALL_HEIGHT - 2.4) / 2, (BACK_Z + BEDROOM_FRONT_Z) / 2),
		wallpaper))
	# И твёрдый: со шкафа/серванта допрыгивали до верха перегородки и пролетали сквозь неё
	# (камера оказывалась «внутри стены»). То же — над дверью в игровую.
	_invisible_wall(Vector3(0.16, WALL_HEIGHT - 2.4 + 0.3, BEDROOM_FRONT_Z - BACK_Z),
		Vector3(PARTITION_X, 2.4 + (WALL_HEIGHT - 2.4 + 0.3) / 2, (BACK_Z + BEDROOM_FRONT_Z) / 2))
	_invisible_wall(Vector3(0.2, WALL_HEIGHT - 2.4 + 0.3, RUBGAME_DOOR_TO_Z - RUBGAME_DOOR_FROM_Z),
		Vector3(LEFT_X - 0.1, 2.4 + (WALL_HEIGHT - 2.4 + 0.3) / 2,
		(RUBGAME_DOOR_FROM_Z + RUBGAME_DOOR_TO_Z) / 2))


# ---------------- Гостиная ----------------

func _build_living_room() -> void:
	# «Стенка» у задней стены: сервант с хрусталём — телевизор — книжная секция с радио.
	var sideboard_pos := Vector3(-4.85, 0, -3.72)
	_solid(_model("sideboard"), Vector3(2.0, 2.2, 0.5), 1.1, sideboard_pos)
	var shelf_heights := [0.97, 1.365, 1.765]
	for row in shelf_heights.size():
		for i in 4:
			var x := sideboard_pos.x - 0.72 + i * 0.48
			var item := "crystal_vase" if (i + row) % 2 == 0 else "wine_glass"
			# Зона пошире: сервант не даёт подойти вплотную к полке.
			_breakable(item, Vector3(x, shelf_heights[row], sideboard_pos.z - 0.05), [CRYSTAL], 0.6, 0.05)
	var tv := TV_SCENE.instantiate() as Node3D
	tv.scale = Vector3.ONE * 1.3
	tv.add_child(TvScreen.new()) # картинка «▶ ИГРАТЬ» прямо на выпуклом стекле
	_solid(tv, Vector3(1.3, 1.5, 1.0), 0.75, TV_POS)
	var shelf_pos := Vector3(-0.7, 0, -3.75)
	_solid(_model("bookshelf"), Vector3(1.3, 2.3, 0.45), 1.15, shelf_pos)
	# Радио и ряды книг бьются, как хрусталь, и через время появляются снова.
	_breakable("radio", shelf_pos + Vector3(-0.3, 0.935, 0.02),
		[Color("2e1a0f"), Color("bfb8a6"), Color("d9b44a")], 0.55)
	var book_colors := [Color("992018"), Color("1a4080"), Color("2a6a2a"), Color("cc9918"),
		Color("6a2a6a")]
	_breakable("book_row_a", shelf_pos + Vector3(0, 1.43, 0), book_colors, 0.6, 0.06)
	_breakable("book_row_b", shelf_pos + Vector3(0, 1.91, 0), book_colors, 0.6, 0.06)
	_breakable("crystal_vase", shelf_pos + Vector3(0.3, 0.935, 0.0), [CRYSTAL], 0.55, 0.05)

	# Окно со шторами, на подоконнике горшки, под окном гантели.
	var window_pos := Vector3(1.65, 0, BACK_Z + 0.08)
	_last_window = _place(_model("window"), window_pos)
	_build_window_view(window_pos)
	_place(_model("curtains"), window_pos + Vector3(0, 0, 0.12))
	for i in 3:
		var pot := "cactus_pot" if i != 1 else "aloe_pot"
		_breakable(pot, Vector3(window_pos.x - 0.5 + i * 0.5, 0.885, window_pos.z + 0.14),
			[CLAY, PLANT], 0.35)
	_tippable("dumbbell", Vector3(0.34, 0.12, 0.12), 0.06, Vector3(1.2, 0, -3.3), 3.0, 15.0)
	_tippable("dumbbell", Vector3(0.34, 0.12, 0.12), 0.06, Vector3(1.55, 0, -3.15), 3.0, -10.0)

	# Зона отдыха: ковёр, диван напротив телевизора, журнальный столик, кресло, торшер.
	var rug := _place(_model("floor_rug"), Vector3(-2.6, 0.005, -0.2))
	rug.rotation_degrees.y = 0.0
	_solid(_model("sofa"), Vector3(2.4, 0.6, 0.9), 0.3, SOFA_POS, SOFA_YAW)
	for local_x in [-0.55, 0.55]:
		var front := Vector3(0, 0, 1).rotated(Vector3.UP, SOFA_YAW)
		# Высота: верх подушки (~0.59) минус высота таза персонажа (0.55) + запас.
		var seat_pos := SOFA_POS + Vector3(local_x, 0.1, 0.12).rotated(Vector3.UP, SOFA_YAW)
		seats.append({"pos": seat_pos, "yaw": SOFA_YAW + PI, "approach": seat_pos + front * 0.9,
			"name": "Сесть на диван"})
	var table_pos := Vector3(-2.6, 0, -0.25)
	_solid(_model("coffee_table"), Vector3(1.0, 0.5, 0.55), 0.25, table_pos)
	_breakable("crystal_vase", table_pos + Vector3(-0.25, 0.47, 0.0), [CRYSTAL], 0.4, 0.05)
	# Стопки книг везде разные (tools/blender/decor.py): тома с очками, журналы, высокая стопка.
	_breakable("book_stack_tomes", table_pos + Vector3(0.25, 0.47, 0.0),
		[Color("2a6a2a"), Color("333338"), Color("d9a640")], 0.4)
	_solid(_model("armchair"), Vector3(0.9, 0.6, 0.9), 0.3, Vector3(-5.2, 0, -0.3), PI / 2)
	# В кресло тоже можно сесть (лицом в комнату, +X); третий бот садится сюда.
	var chair_pos := Vector3(-5.14, 0.08, -0.3)
	seats.append({"pos": chair_pos, "yaw": PI / 2 + PI, "approach": chair_pos + Vector3(0.9, 0, 0),
		"name": "Сесть в кресло"})
	_place(_model("wall_carpet"), Vector3(LEFT_X + 0.08, 0.85, -0.3)).rotation_degrees.y = 90.0
	floor_lamp = _tippable("floor_lamp", Vector3(0.5, 1.75, 0.5), 0.88, Vector3(-1.0, 0, 1.45), 6.0)
	_build_lamp_light()
	_no_shadow(_place(_model("chandelier"), Vector3(-2.4, 0, -0.6))) # странная тень на полу

	# Обеденный стол у перегородки: варенье, ваза, книги; стулья и табурет падают.
	var dining := Vector3(1.6, 0, 2.0)
	_solid(_model("table"), Vector3(1.4, 0.8, 0.85), 0.4, dining)
	_tippable("chair", Vector3(0.45, 0.95, 0.45), 0.47, dining + Vector3(-0.95, 0, 0), 3.0, 90.0)
	_tippable("chair", Vector3(0.45, 0.95, 0.45), 0.47, dining + Vector3(0, 0, -0.75), 3.0, 0.0)
	_tippable("stool", Vector3(0.36, 0.47, 0.36), 0.24, dining + Vector3(0.95, 0, 0), 2.0)
	_breakable("jar_jam", dining + Vector3(-0.35, 0.78, 0.1), [Color("801010"), GLASS], 0.4)
	# Граммофон: от удара падает со стола и через время сам возвращается (как стулья).
	gramophone = _tippable("gramophone", Vector3(0.36, 0.14, 0.36), 0.07,
		dining + Vector3(0.05, 0.8, -0.05), 2.0, 17.0)
	var books_b := [Color("cc9918"), Color("6a2a6a"), Color("1a4080")]
	_breakable("book_stack_mags", dining + Vector3(0.45, 0.78, 0.15), books_b, 0.4)

	# Банки с заготовками у серванта.
	for i in 3:
		var jar := "jar_pickles" if i % 2 == 0 else "jar_jam"
		var color := Color("5a7a2a") if i % 2 == 0 else Color("801010")
		_breakable(jar, Vector3(-5.6 + i * 0.32, 0, -3.15), [color, GLASS], 0.35)


# ---------------- Спальня ----------------

func _build_bedroom() -> void:
	_solid(_model("wardrobe"), Vector3(1.5, 2.2, 0.6), 1.1, WARDROBE_POS)
	var bed_pos := Vector3(7.8, 0, -2.9)
	_solid(_model("bed"), Vector3(1.1, 0.7, 2.05), 0.35, bed_pos)
	# Ковёр левее кровати на 0.35 м: при ширине 2.6 м иначе заезжает в правую стену.
	# Свой ковёр в спальне (зелёный, с «гёлями») — не такой, как в гостиной.
	_place(_model("wall_carpet_green"), Vector3(bed_pos.x - 0.35, 0.75, BACK_Z + 0.08))
	var stand_pos := Vector3(6.75, 0, -3.65)
	# Тумбочка с ящиком: в ящике баллончик с краской (Nightstand, SprayCan).
	nightstand = Nightstand.new()
	nightstand.position = stand_pos
	add_child(nightstand)
	_night_lamp = _breakable("table_lamp", stand_pos + Vector3(0, 0.6, 0),
		[Color("2a7040"), Color("c0a050")], 0.4)
	_build_night_light()
	_place(_model("floor_rug_oval"), Vector3(6.3, 0.005, -0.8)).rotation_degrees.y = 90.0
	_tippable("dumbbell", Vector3(0.34, 0.12, 0.12), 0.06, Vector3(8.5, 0, 0.6), 3.0, 30.0)
	_tippable("stool", Vector3(0.36, 0.47, 0.36), 0.24, Vector3(8.4, 0, -0.4), 2.0)
	_breakable("book_stack_tall", Vector3(8.4, 0.47, -0.4),
		[Color("992018"), Color("cc9918"), Color("26262e"), Color("4d8c99")], 0.4)
	_no_shadow(_place(_model("chandelier"), Vector3(6.2, 0, -1.4)))


func _process(delta: float) -> void:
	_time += delta
	# Задели торшер (даже чуть сдвинули) — он гаснет, как от кнопки, и загорается только через
	# LAMP_BACK сек после того, как встал на место. Раньше от толчка свет мигал и вспыхивал.
	if not floor_lamp.is_at_home():
		lamp_on = false
		_lamp_back_at = _time + LAMP_BACK
	elif not lamp_on and _time >= _lamp_back_at:
		lamp_on = true
	# Гаснет сразу, разгорается плавно.
	var target := 1.0 if lamp_on else 0.0
	if target < _lamp_level:
		_lamp_level = target
	else:
		_lamp_level = move_toward(_lamp_level, target, delta / LAMP_FADE)
	_lamp_light.light_energy = LAMP_ENERGY * _lamp_level
	_lamp_light.visible = _lamp_level > 0.01
	_lamp_glow_mat.albedo_color = Color(0.3, 0.27, 0.22).lerp(Color(1.0, 0.92, 0.7), _lamp_level)
	var night_lit := not _night_lamp.is_broken()
	_night_light.visible = night_lit
	_night_bulb_mat.albedo_color = Color(1.0, 0.92, 0.7) if night_lit else Color(0.3, 0.27, 0.22)


## Торшер горит в полную силу (только тогда его можно выключить).
func lamp_lit() -> bool:
	return _lamp_level > 0.99


## Выключить торшер кнопкой: гаснет и через LAMP_BACK сек плавно загорается снова.
func turn_off_lamp() -> void:
	lamp_on = false
	_lamp_back_at = _time + LAMP_BACK


## Лампочка под зелёным абажуром ночника.
func _build_night_light() -> void:
	_night_light = OmniLight3D.new()
	_night_light.light_color = Color(1.0, 0.82, 0.55)
	_night_light.light_energy = 0.9
	_night_light.omni_range = 2.6
	_night_light.position = Vector3(0, 0.3, 0)
	_night_lamp.add_child(_night_light)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	bulb.mesh = sphere
	_night_bulb_mat = StandardMaterial3D.new()
	_night_bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb.material_override = _night_bulb_mat
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.position = Vector3(0, 0.29, 0)
	_night_lamp.add_child(bulb)


## Лампочка под абажуром торшера: тёплый свет и светящийся шарик.
func _build_lamp_light() -> void:
	_lamp_light = OmniLight3D.new()
	_lamp_light.light_color = Color(1.0, 0.82, 0.55)
	_lamp_light.light_energy = LAMP_ENERGY
	_lamp_light.omni_range = 4.0
	# Без теней: абажур отбрасывал резкий восьмиугольник света на пол («кривое свечение»).
	_lamp_light.shadow_enabled = false
	_lamp_light.omni_attenuation = 1.5 # мягче к краю
	_lamp_light.position = Vector3(0, 1.4, 0)
	floor_lamp.add_child(_lamp_light)
	_lamp_glow = MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.07
	bulb.height = 0.14
	_lamp_glow.mesh = bulb
	_lamp_glow_mat = StandardMaterial3D.new()
	_lamp_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_glow_mat.albedo_color = Color(1.0, 0.92, 0.7)
	_lamp_glow.material_override = _lamp_glow_mat
	_lamp_glow.position = Vector3(0, 1.45, 0)
	floor_lamp.add_child(_lamp_glow)


# ---------------- Вид из окна ----------------

## Задняя стена с прямоугольным проёмом hole (x, y — от, size — ширина и высота).
func _wall_with_hole(x0: float, x1: float, hole: Rect2, material: Material) -> void:
	var z := BACK_Z - 0.1
	var hx0 := hole.position.x
	var hx1 := hole.end.x
	_solid_box(Vector3(hx0 - x0, WALL_HEIGHT, 0.2), Vector3((x0 + hx0) / 2, WALL_HEIGHT / 2, z),
		material)
	_solid_box(Vector3(x1 - hx1, WALL_HEIGHT, 0.2), Vector3((hx1 + x1) / 2, WALL_HEIGHT / 2, z),
		material)
	_solid_box(Vector3(hole.size.x, hole.position.y, 0.2),
		Vector3((hx0 + hx1) / 2, hole.position.y / 2, z), material)
	var top := WALL_HEIGHT - hole.end.y
	_solid_box(Vector3(hole.size.x, top, 0.2),
		Vector3((hx0 + hx1) / 2, hole.end.y + top / 2, z), material)


## «Объёмный» вид из окна: плоские картинки на разной глубине за проёмом (деревья у дома,
## дома напротив с двором, небо). Ближние при движении сдвигаются сильнее — получается объём.
## Всё это видят только камеры от первого лица; сверху в проёме — плоская картинка.
func _build_window_view(window_pos: Vector3) -> void:
	_hide_window_sky(_last_window)
	var center_x := window_pos.x
	var layers := [
		# [картинка, ширина, высота, низ по Y, глубина за стеной]
		["window_trees", 18.0, 10.0, -6.0, 4.0],
		["window_houses", 56.0, 18.0, -6.0, 28.0],
		["window_sky", 170.0, 85.0, -25.0, 60.0],
	]
	for layer: Array in layers:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(layer[1], layer[2])
		quad.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/window/%s.png" % layer[0])
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if layer[0] != "window_sky":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		quad.material_override = mat
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		quad.layers = FP_ONLY_LAYER
		quad.position = Vector3(center_x, float(layer[3]) + float(layer[2]) / 2.0,
			BACK_Z - 0.2 - float(layer[4]))
		add_child(quad)
	# Земля двора под окнами (между стеной и деревьями видно, если смотреть вниз).
	var ground := _box(Vector3(80, 0.1, 40), Vector3(center_x, -6.05, BACK_Z - 20.2),
		_mat(Color(0.37, 0.5, 0.28), 1.0))
	ground.layers = FP_ONLY_LAYER
	# Сверху (общая камера) — прежняя плоская картинка прямо за проёмом.
	var flat := MeshInstance3D.new()
	var flat_mesh := QuadMesh.new()
	flat_mesh.size = WINDOW_HOLE.size
	flat.mesh = flat_mesh
	var flat_mat := StandardMaterial3D.new()
	flat_mat.albedo_texture = load("res://assets/textures/window_view.png")
	flat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.material_override = flat_mat
	flat.layers = OVERVIEW_ONLY_LAYER
	flat.position = Vector3(center_x, WINDOW_HOLE.get_center().y, BACK_Z - 0.21)
	add_child(flat)


## «Небо» в модели окна (непрозрачная голубая плита) закрывало бы проём — делаем его невидимым.
func _hide_window_sky(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var surface := mesh_instance.mesh.surface_get_material(i)
			if surface and surface.resource_name.begins_with("WindowSky"):
				var clear := StandardMaterial3D.new()
				clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				clear.albedo_color = Color(0, 0, 0, 0)
				mesh_instance.set_surface_override_material(i, clear)
	for child in node.get_children():
		_hide_window_sky(child)


# ---------------- Уют: полки, растения, плакаты, дорожка ----------------

func _build_decor() -> void:
	# Растения (в кадках — твёрдые, обходить).
	var plant_size := Vector3(0.45, 1.0, 0.45)
	_solid(_model("plant_ficus"), plant_size, 0.5, Vector3(-1.65, 0, -3.62))
	_solid(_model("plant_palm"), plant_size, 0.5, Vector3(2.62, 0, -3.6))
	_solid(_model("plant_snake"), plant_size, 0.5, Vector3(-5.6, 0, 3.15))
	_solid(_model("plant_snake"), plant_size, 0.5, Vector3(3.5, 0, -3.7), 0.8)
	_solid(_model("plant_ficus"), plant_size, 0.5, Vector3(8.65, 0, 1.15), 1.3)
	# Настенные полки (задняя сторона модели — к стене; модель смотрит на +Z).
	_place(_model("wall_shelf_books"), Vector3(PARTITION_X - 0.08, 1.55, -3.0)).rotation.y = -PI / 2
	_place(_model("wall_shelf_books"), Vector3(RIGHT_X, 1.5, -0.9)).rotation.y = -PI / 2
	_place(_model("wall_shelf_plants"), Vector3(RIGHT_X, 1.55, 0.5)).rotation.y = -PI / 2
	_place(_model("wall_shelf_plants"), Vector3(PARTITION_X + 0.08, 1.6, -3.0)).rotation.y = PI / 2
	# Плакаты.
	var size := Vector2(0.5, 0.7)
	_poster("home_space", size, Vector3(PARTITION_X - 0.085, 1.65, 0.65), -PI / 2)
	_poster("home_kefir", size, Vector3(LEFT_X + 0.012, 1.65, -2.5), PI / 2)
	_poster("home_calendar", size, Vector3(5.75, 1.6, BACK_Z + 0.012), 0.0)
	_poster("home_hockey", size, Vector3(PARTITION_X + 0.085, 1.6, 0.65), PI / 2)
	# Ковровая дорожка к двери в спальню.
	_place(_model("floor_runner"), Vector3(1.55, 0.004, -1.0))


# ---------------- Телефон, часы, кот ----------------

func _build_living_extras() -> void:
	_solid(_model("phone_table"), Vector3(0.45, 0.6, 0.4), 0.3, PHONE_TABLE_POS, PI / 2)
	phone = RotaryPhone.new()
	phone.position = PHONE_TABLE_POS + Vector3(0, 0.6, 0)
	phone.rotation.y = PI / 2 # лицом в комнату (+X)
	add_child(phone)
	# Часы с кукушкой — на задней стене между книжной секцией и окном.
	var clock := CuckooClock.new()
	clock.position = Vector3(0.2, 1.95, BACK_Z)
	add_child(clock)
	# Кот бродит по всей квартире, лежанка — в спальне.
	cat = LobbyCat.new()
	add_child(cat)


# ---------------- Игровая комната («игра на рубли») ----------------

func _build_rubgame() -> void:
	var carpet := _mat(Color("5a1018"), 0.95)
	var wallpaper := _mat(Color("3a1a2a"), 0.9)
	var width := LEFT_X - RUBGAME_LEFT_X
	var depth := LIVING_FRONT_Z - RUBGAME_BACK_Z
	var center_x := (RUBGAME_LEFT_X + LEFT_X) / 2
	var center_z := (RUBGAME_BACK_Z + LIVING_FRONT_Z) / 2
	_solid_box(Vector3(width, 0.2, depth), Vector3(center_x, -0.1, center_z), carpet)
	# Задняя стена кончается внутри стены гостиной (x до −6.2), а не вплотную к её поверхности:
	# иначе торец совпадает с обоями гостиной и мерцает тёмной полосой.
	var back_w := (LEFT_X - 0.2) - RUBGAME_LEFT_X
	_solid_box(Vector3(back_w, WALL_HEIGHT, 0.2),
		Vector3(RUBGAME_LEFT_X + back_w / 2, WALL_HEIGHT / 2, RUBGAME_BACK_Z - 0.1), wallpaper)
	_solid_box(Vector3(0.2, WALL_HEIGHT, depth),
		Vector3(RUBGAME_LEFT_X - 0.1, WALL_HEIGHT / 2, center_z), wallpaper)
	# Со стороны гостиной стена у двери — своими обоями (игровая — тёмная).
	_box(Vector3(0.02, WALL_HEIGHT, RUBGAME_DOOR_FROM_Z - RUBGAME_BACK_Z),
		Vector3(LEFT_X - 0.21, WALL_HEIGHT / 2, (RUBGAME_BACK_Z + RUBGAME_DOOR_FROM_Z) / 2), wallpaper)
	_invisible_wall(Vector3(width, 3, 0.4), Vector3(center_x, 1.5, LIVING_FRONT_Z + 0.2))
	_fp_only(_box(Vector3(width, WALL_HEIGHT, 0.2),
		Vector3(center_x, WALL_HEIGHT / 2, LIVING_FRONT_Z + 0.1), wallpaper))

	rubgame_table = RubgameTable.new()
	rubgame_table.position = RUBGAME_TABLE_POS
	add_child(rubgame_table)
	# Лампа над сукном — только от первого лица (сверху закрыла бы стол).
	var lamp := _place(_rubgame_model("rubgame_lamp"), RUBGAME_TABLE_POS + Vector3(0.3, 0, 0))
	_set_layers(lamp, RUBGAME_LAMP_LAYER)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.65)
	light.light_energy = 1.6
	light.omni_range = 4.5
	light.position = RUBGAME_TABLE_POS + Vector3(0.3, 1.8, 0)
	add_child(light)

	# Игровые автоматы 90-х: два у задней стены, один у левой. На экранах — спокойные
	# пиксельные «демо-игры» (блоки, космос, змейка).
	var arcades := [
		[Vector3(-10.9, 0, RUBGAME_BACK_Z + 0.4), 0.0],
		[Vector3(-10.1, 0, RUBGAME_BACK_Z + 0.4), 0.0],
		[Vector3(RUBGAME_LEFT_X + 0.4, 0, 2.3), PI / 2],
	]
	for i in arcades.size():
		var cabinet := _solid(_rubgame_model("arcade_cabinet"), Vector3(0.7, 1.7, 0.6), 0.85,
			arcades[i][0], arcades[i][1])
		var screen := ArcadeScreen.new().setup(i, Vector2(0.48, 0.38))
		screen.position = Vector3(0, 1.3, 0.334) # перед экраном модели
		cabinet.add_child(screen)
		arcade_screens.append(screen)

	# Неоновые вывески: в игровой и над дверью со стороны гостиной.
	# Внутри комнаты вместо надписи — ретро-постеры игровых автоматов 80-х.
	var poster_size := Vector2(0.75, 1.12)
	_poster("poster_star_flight", poster_size, Vector3(-8.7, 1.75, RUBGAME_BACK_Z + 0.012), 0.0)
	_poster("poster_race", poster_size, Vector3(-7.3, 1.75, RUBGAME_BACK_Z + 0.012), 0.0)
	_poster("poster_sub_hunt", poster_size, Vector3(RUBGAME_LEFT_X + 0.012, 1.7, 0.6), PI / 2)
	_poster("poster_air_battle", poster_size, Vector3(LEFT_X - 0.232, 1.7, -1.0), -PI / 2)
	var door_z := (RUBGAME_DOOR_FROM_Z + RUBGAME_DOOR_TO_Z) / 2
	_neon("ИГРА\nНА РУБЛИ", Vector3(LEFT_X + 0.02, 2.7, door_z), PI / 2, 36)


## Постер на стене (картинка из tools/textures/posters.py), освещается как стена.
func _poster(poster_name: String, size: Vector2, pos: Vector3, yaw: float) -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	var poster_mat := StandardMaterial3D.new()
	poster_mat.albedo_texture = load("res://assets/textures/posters/%s.png" % poster_name)
	poster_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR # скотч по углам
	poster_mat.roughness = 0.85
	poster_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	quad.material_override = poster_mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = pos
	quad.rotation.y = yaw
	add_child(quad)


func _neon(text: String, pos: Vector3, yaw: float, font_size: int) -> void:
	var sign_label := Label3D.new()
	sign_label.text = text
	sign_label.font_size = font_size
	sign_label.outline_size = font_size / 5
	sign_label.modulate = Color(1.0, 0.35, 0.75)
	sign_label.outline_modulate = Color(0.45, 0.0, 0.3)
	sign_label.position = pos
	sign_label.rotation.y = yaw
	add_child(sign_label)


func _rubgame_model(model_name: String) -> Node3D:
	return (load("res://assets/models/rubgame/" + model_name + ".glb") as PackedScene) \
		.instantiate() as Node3D


## Вещь не отбрасывает тень (люстры: их тень от солнца ложилась на пол странным пятном).
func _no_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadow(child)


## Задать слой видимости всем мешам внутри узла.
func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)


# ---------------- Помощники ----------------

func _model(model_name: String) -> Node3D:
	return (load(DIR + model_name + ".glb") as PackedScene).instantiate() as Node3D


func _place(node: Node3D, pos: Vector3) -> Node3D:
	add_child(node)
	node.position = pos
	return node


## Неподвижная мебель: модель + коробка столкновений.
func _solid(model: Node3D, size: Vector3, center_y: float, pos: Vector3,
		yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.add_child(model)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = center_y
	body.add_child(shape)
	add_child(body)
	body.position = pos
	body.rotation.y = yaw
	return body


## Видно только от первого лица (потолок, передние стены).
func _fp_only(node: MeshInstance3D) -> void:
	node.layers = FP_ONLY_LAYER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _breakable(model_name: String, pos: Vector3, colors: Array, reach: float,
		shard_size: float = 0.07) -> Breakable:
	var item := Breakable.new()
	item.position = pos
	add_child(item)
	var typed_colors: Array[Color] = []
	typed_colors.assign(colors)
	item.setup(load(DIR + model_name + ".glb") as PackedScene, typed_colors, reach, shard_size)
	return item


## Поворот задаём до добавления в сцену: Tippable запоминает «дом» при появлении.
func _tippable(model_name: String, size: Vector3, center_y: float, pos: Vector3,
		body_mass: float, yaw_degrees: float = 0.0) -> Tippable:
	var body := Tippable.new()
	body.setup(load(DIR + model_name + ".glb") as PackedScene, size, center_y, body_mass)
	body.position = pos
	body.rotation_degrees.y = yaw_degrees
	add_child(body)
	return body


func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	add_child(mesh_instance)
	return mesh_instance


func _solid_box(size: Vector3, pos: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)


func _invisible_wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m
