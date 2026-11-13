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
## Выключатели люстр — на перегородке у двери в спальню (со стороны гостиной и спальни).
const LIVING_SWITCH := Vector3(PARTITION_X - 0.09, 1.25, 0.15)
const BEDROOM_SWITCH := Vector3(PARTITION_X + 0.09, 1.25, 0.15)
## Выключатель лампы над игровым столом: в игровой, справа от двери в гостиную.
const RUBGAME_SWITCH := Vector3(LEFT_X - 0.23, 1.25, 3.25)
const SPAWNS: Array[Vector3] = [
	Vector3(-0.3, 0.3, -1.2), Vector3(0.9, 0.3, -1.2),
	Vector3(-0.3, 0.3, -2.4), Vector3(0.9, 0.3, -2.4),
]

const CRYSTAL := Color(0.75, 0.9, 1.0, 0.6)
const PORCELAIN := Color(0.95, 0.95, 0.93)
const COBALT := Color(0.1, 0.2, 0.6)
const CLAY := Color(0.65, 0.3, 0.15)
const PLANT := Color(0.15, 0.45, 0.15)
const GLASS := Color(0.8, 0.95, 0.9, 0.6)

## Места на диване и в кресле: [{"pos": точка посадки, "yaw": куда смотрит сидящий,
## "approach": где подойти, "name": текст кнопки}].
var seats: Array[Dictionary] = []
## Стол рулетки (крутится сам каждые 20 секунд).
var rubgame_table: RubgameTable
## Граммофон (играет три ноты) и торшер (повалили — гаснет).
var gramophone: Tippable
var floor_lamp: Tippable
## Свет зависит от времени суток (LobbyLamp): днём не горит, вечером горит; кнопкой — наоборот
## на 20 сек. Торшер, ночник и люстры (у люстр и лампы игровой — выключатели на стене:
## {"lamp", "switch", "normal" — куда смотрит клавиша, "always_on"}).
var floor_lamp_light: LobbyLamp
var night_lamp_light: LobbyLamp
var chandeliers: Array[Dictionary] = []
var window_view: WindowView
## Сервант: стеклянные дверцы и тумба с молотком.
var sideboard: SideboardCabinet
## Стёкла окна гостиной (бьются молотком).
var window_glass: WindowGlass
## Тумбочка в спальне: ящик с баллончиком.
var nightstand: Nightstand
## Дисковый телефон (гостиная, у двери в игровую) и кот.
var phone: RotaryPhone
## Туалет (унитаз — toilet_room.toilet).
var toilet_room: ToiletRoom
## Экраны игровых автоматов (кнопкой действия их можно «сломать» на 8 сек).
var arcade_screens: Array[ArcadeScreen] = []
var cat: LobbyCat
## Пульт от телевизора (лежит на диване, его можно взять и бросить).
var tv_remote: TvRemote
## Музыка радио на полке (кнопкой включить / выключить).
var radio_music: RadioMusic

## Ночник на тумбочке в спальне; разбили — не светит, пока не восстановится.
var night_lamp: Breakable
var _night_bulb: MeshInstance3D
## Солнце в комнате (DirectionalLight лобби): вечером слабее, чтобы был виден свет ламп.
## Висящее под потолком (копии для вида сверху): {"node", "pos"} — прозрачнеют над персонажем.
var _hanging_top: Array[Dictionary] = []
var _sun: DirectionalLight3D
## Текстура мягкой тени под мебелью (одна на всю квартиру).
var _shadow_tex: GradientTexture2D
var _sun_energy := 1.0
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
	var sideboard_pos := Vector3(-4.85, 0, -3.68) # не влезает в плинтус и стену
	_solid(_model("sideboard"), Vector3(2.0, 2.2, 0.5), 1.1, sideboard_pos)
	# Стеклянные дверцы наверху и правая дверца тумбы с молотком внутри (SideboardCabinet).
	sideboard = SideboardCabinet.new()
	sideboard.position = sideboard_pos
	add_child(sideboard)
	# В серванте — фарфоровый сервиз (белый с кобальтом и золотом), бьётся по одной вещи.
	var shelf_heights := [0.97, 1.365, 1.765]
	var china_rows := [
		["china_teapot", "china_cup", "china_plate", "china_cup"],
		["china_plate", "china_sugar", "china_cup", "china_plate"],
		["china_cup", "china_plate", "china_cup", "china_teapot"],
	]
	for row in shelf_heights.size():
		for i in 4:
			var x := sideboard_pos.x - 0.72 + i * 0.48
			var china := _breakable(china_rows[row][i],
				Vector3(x, shelf_heights[row], sideboard_pos.z - 0.05), [PORCELAIN, COBALT], 0.6, 0.04)
			# За целым стеклом посуду не разбить — ни рукой, ни молотком (сначала стекло).
			var pane := 0 if i < 2 else 1
			china.guard = func() -> bool: return sideboard.pane_broken(pane)
	# На серванте: плюшевый мишка в левом углу и часы с настоящим временем по центру.
	var bear := _place(_model("teddy_bear"), Vector3(sideboard_pos.x - 0.75, 2.2, sideboard_pos.z))
	bear.rotation.y = 0.35
	var clock := TableClock.new()
	clock.position = Vector3(sideboard_pos.x, 2.2, sideboard_pos.z - 0.03)
	add_child(clock)
	var tv := TV_SCENE.instantiate() as Node3D
	tv.scale = Vector3.ONE * 1.3
	tv.add_child(TvScreen.new()) # картинка «▶ ИГРАТЬ» прямо на выпуклом стекле
	_solid(tv, Vector3(1.3, 1.5, 1.0), 0.75, TV_POS)
	# Задняя стенка шкафа — в 7 см от стены (раньше влезала в плинтус и мерцала со стеной).
	var shelf_pos := Vector3(-0.7, 0, -3.7)
	_solid(_model("bookshelf"), Vector3(1.3, 2.3, 0.45), 1.15, shelf_pos)
	# Радио и ряды книг бьются, как хрусталь, и через время появляются снова.
	var radio := _breakable("radio", shelf_pos + Vector3(-0.3, 0.935, 0.02),
		[Color("2e1a0f"), Color("bfb8a6"), Color("d9b44a")], 0.55)
	_radio_music(radio)
	var book_colors := [Color("992018"), Color("1a4080"), Color("2a6a2a"), Color("cc9918"),
		Color("6a2a6a")]
	_breakable("book_row_a", shelf_pos + Vector3(0, 1.43, 0), book_colors, 0.6, 0.06)
	_breakable("book_row_b", shelf_pos + Vector3(0, 1.91, 0), book_colors, 0.6, 0.06)
	_breakable("crystal_vase", shelf_pos + Vector3(0.3, 0.935, 0.0), [CRYSTAL], 0.55, 0.05)

	# Окно со шторами, на подоконнике горшки, под окном гантели.
	var window_pos := Vector3(1.65, 0, BACK_Z + 0.08)
	_last_window = _place(_model("window"), window_pos)
	window_glass = WindowGlass.new()
	window_glass.position = window_pos
	add_child(window_glass)
	_build_window_view(window_pos)
	_place(_model("curtains"), window_pos + Vector3(0, 0, 0.12))
	# Подоконник и батарея твёрдые: на подоконник можно запрыгнуть (раньше проваливались сквозь).
	_invisible_wall(Vector3(1.7, 0.05, 0.32), window_pos + Vector3(0, 0.86, 0.14))
	_invisible_wall(Vector3(1.0, 0.5, 0.1), window_pos + Vector3(0, 0.45, 0.05))
	# На подоконнике один кактус (три горшка закрывали вид за окном).
	_breakable("cactus_pot", Vector3(window_pos.x - 0.5, 0.885, window_pos.z + 0.14),
		[CLAY, PLANT], 0.35)
	_tippable("dumbbell", Vector3(0.34, 0.104, 0.12), 0.052, Vector3(1.2, 0, -3.3), 3.0, 15.0)
	_tippable("dumbbell", Vector3(0.34, 0.104, 0.12), 0.052, Vector3(1.55, 0, -3.15), 3.0, -10.0)

	# Зона отдыха: ковёр, диван напротив телевизора, журнальный столик, кресло, торшер.
	_rug_floor(_place(_model("floor_rug"), Vector3(-2.6, 0.005, -0.2)))
	_solid(_model("sofa"), Vector3(2.4, 0.6, 0.9), 0.3, SOFA_POS, SOFA_YAW)
	for local_x in [-0.55, 0.55]:
		var front := Vector3(0, 0, 1).rotated(Vector3.UP, SOFA_YAW)
		# Высота: верх подушки (~0.59) минус высота таза персонажа (0.55) + запас.
		var seat_pos := SOFA_POS + Vector3(local_x, 0.1, 0.12).rotated(Vector3.UP, SOFA_YAW)
		seats.append({"pos": seat_pos, "yaw": SOFA_YAW + PI, "approach": seat_pos + front * 0.9,
			"name": "Сесть на диван"})
	# Пульт — в углу дивана у подлокотника (слева, если стоять лицом к дивану), вдоль сиденья:
	# перпендикулярно стене с телевизором.
	tv_remote = TvRemote.new()
	tv_remote.home_position = SOFA_POS + Vector3(-0.85, 0.6, 0.12).rotated(Vector3.UP, SOFA_YAW)
	tv_remote.home_yaw = 0.0
	tv_remote.set_meta("home_parent", self)
	add_child(tv_remote)
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
	_chandelier(Vector3(-2.4, 0, -0.6), LIVING_SWITCH, -PI / 2)

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
	# Над кроватью — ковёр-гобелен «Олени у озера» (tools/textures/carpet_deer.py).
	_tapestry(Vector3(bed_pos.x - 0.35, 1.6, BACK_Z + 0.03), Vector2(2.6, 1.7))
	var stand_pos := Vector3(6.75, 0, -3.65)
	# Тумбочка с ящиком: в ящике баллончик с краской (Nightstand, SprayCan).
	nightstand = Nightstand.new()
	nightstand.position = stand_pos
	add_child(nightstand)
	night_lamp = _breakable("table_lamp", stand_pos + Vector3(0, 0.6, 0),
		[Color("2a7040"), Color("c0a050")], 0.4)
	_build_night_light()
	var oval := _place(_model("floor_rug_oval"), Vector3(6.3, 0.005, -0.8))
	oval.rotation_degrees.y = 90.0
	_rug_floor(oval)
	_tippable("dumbbell", Vector3(0.34, 0.104, 0.12), 0.052, Vector3(8.5, 0, 0.6), 3.0, 30.0)
	var stool := _tippable("stool", Vector3(0.36, 0.47, 0.36), 0.24, Vector3(8.4, 0, -0.4), 2.0)
	# Книги на табурете — каждая со своей физикой: сбили табурет — книги падают на пол.
	var pile := BookPile.new()
	pile.position = Vector3(8.4, 0.475, -0.4)
	add_child(pile)
	pile.build(6, stool)
	_chandelier(Vector3(6.2, 0, -1.4), BEDROOM_SWITCH, PI / 2)


func _process(delta: float) -> void:
	_time += delta
	var dark := window_view.is_dark()
	# Торшер горит, только пока стоит на месте; ночник — пока не разбит.
	floor_lamp_light.update(delta, dark, floor_lamp.is_at_home())
	var night_ok := not night_lamp.is_broken()
	night_lamp_light.update(delta, dark, night_ok)
	_night_bulb.visible = night_ok # разбитый — без «висящей в воздухе» лампочки
	for chandelier in chandeliers:
		(chandelier["lamp"] as LobbyLamp).update(delta, dark or chandelier["always_on"], true)
	_fade_hanging(delta)
	# Солнце в комнате вечером и ночью слабее (но не до темноты — играть должно быть видно).
	if _sun == null:
		_sun = get_parent().get_node_or_null("Sun") as DirectionalLight3D
		_sun_energy = _sun.light_energy if _sun else 1.0
	if _sun:
		_sun.light_energy = _sun_energy * lerpf(0.4, 1.0, window_view.daylight())


## Лампочка под зелёным абажуром ночника.
func _build_night_light() -> void:
	var light := _warm_light(0.9, 2.6, Vector3(0, 0.3, 0))
	night_lamp.add_child(light)
	var bulb_mat := _bulb_mat()
	_night_bulb = _bulb(0.04, Vector3(0, 0.29, 0), bulb_mat)
	night_lamp.add_child(_night_bulb)
	night_lamp_light = LobbyLamp.new(light, bulb_mat)


## Лампочка под абажуром торшера: тёплый свет и светящийся шарик.
func _build_lamp_light() -> void:
	# Без теней: абажур отбрасывал резкий восьмиугольник света на пол («кривое свечение»).
	var light := _warm_light(LAMP_ENERGY, 4.0, Vector3(0, 1.5, 0))
	light.omni_attenuation = 1.5 # мягче к краю
	floor_lamp.add_child(light)
	var bulb_mat := _bulb_mat()
	floor_lamp.add_child(_bulb(0.06, Vector3(0, 1.58, 0), bulb_mat)) # в патроне под абажуром
	floor_lamp_light = LobbyLamp.new(light, bulb_mat)


## Люстра под потолком со своим светом и выключатель на стене (yaw — куда смотрит выключатель).
## Люстр две копии: для глаз игроков (всегда видна) и для вида сверху — та плавно исчезает,
## когда под ней персонаж (иначе люстра закрывает его сверху).
func _chandelier(pos: Vector3, switch_pos: Vector3, switch_yaw: float) -> void:
	var light := _warm_light(1.4, 5.5, pos + Vector3(0, 2.3, 0))
	add_child(light)
	var bulb_mat := _bulb_mat()
	for layer in [FP_ONLY_LAYER, OVERVIEW_ONLY_LAYER]:
		var hang := Node3D.new()
		add_child(hang)
		var model := _place(_model("chandelier"), pos)
		_no_shadow(model) # странная тень на полу
		model.reparent(hang)
		hang.add_child(_bulb(0.06, pos + Vector3(0, 2.38, 0), bulb_mat))
		_set_layers(hang, layer)
		if layer == OVERVIEW_ONLY_LAYER:
			_hanging_top.append({"node": hang, "pos": pos})
	_add_switch(LobbyLamp.new(light, bulb_mat), switch_pos, switch_yaw, false)


## Выключатель на стене (клавиша смотрит по yaw) для светильника lamp. always_on — горит и
## днём (лампа над игровым столом): кнопкой гасится, а не включается.
## В списке хранится и «лицо» выключателя: щёлкает только тот, кто стоит перед ним —
## выключатели гостиной и спальни висят спинами друг к другу на одной перегородке.
func _add_switch(lamp: LobbyLamp, switch_pos: Vector3, yaw: float, always_on: bool) -> void:
	var plate := _box(Vector3(0.08, 0.12, 0.02), Vector3.ZERO, _mat(Color("efe6d2"), 0.5))
	var key := _box(Vector3(0.03, 0.05, 0.015), Vector3(0, 0, 0.015), _mat(Color("d9cfb8"), 0.5))
	key.reparent(plate, false)
	plate.position = switch_pos
	plate.rotation.y = yaw
	chandeliers.append({"lamp": lamp, "switch": switch_pos,
		"normal": Vector3(sin(yaw), 0.0, cos(yaw)), "always_on": always_on})


## Вид сверху: люстра плавно исчезает, когда кто-то рядом под ней (ближе ~2 м), и возвращается.
func _fade_hanging(delta: float) -> void:
	var people := get_tree().get_nodes_in_group("lobby_character")
	for item in _hanging_top:
		var pos: Vector3 = item["pos"]
		var nearest := INF
		for node in people:
			var person := node as Node3D
			nearest = minf(nearest, Vector2(person.global_position.x - pos.x,
				person.global_position.z - pos.z).length())
		var hang: Node3D = item["node"]
		var target := 1.0 - smoothstep(1.2, 2.4, nearest) # 1 — совсем прозрачная
		var now: float = hang.get_meta("fade", 0.0)
		now = move_toward(now, target, delta * 3.0)
		if is_equal_approx(now, float(hang.get_meta("fade", 0.0))):
			continue
		hang.set_meta("fade", now)
		hang.visible = now < 0.99
		for mesh in hang.find_children("*", "GeometryInstance3D", true, false):
			(mesh as GeometryInstance3D).transparency = now


func _warm_light(energy: float, light_range: float, pos: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	light.position = pos
	return light


func _bulb_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## Светящаяся лампочка-шарик (цвет — от LobbyLamp: горит / не горит).
func _bulb(radius: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	bulb.mesh = sphere
	bulb.material_override = mat
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.position = pos
	return bulb


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


## «Объёмный» вид из окна: настоящий двор за проёмом (WindowView). Его видят только камеры
## от первого лица; сверху в проёме — плоская картинка.
func _build_window_view(window_pos: Vector3) -> void:
	_hide_window_sky(_last_window)
	var center_x := window_pos.x
	# Двор за окном: небо, газон, тропинка, 3D-хрущёвки, деревья, кусты, голуби (WindowView).
	var outside := WindowView.new()
	outside.position = Vector3(center_x, 0, BACK_Z - 0.2)
	add_child(outside)
	window_view = outside
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
	# Фикус — у левой стены рядом с креслом (между телевизором и шкафом он влезал в мебель).
	_solid(_model("plant_ficus"), plant_size, 0.5, Vector3(-5.5, 0, -1.55))
	# Пальма — чуть вперёд от угла (в углу листья влезали в штору).
	_solid(_model("plant_palm"), plant_size, 0.5, Vector3(2.55, 0, -3.05))
	_solid(_model("plant_snake"), plant_size, 0.5, Vector3(-5.6, 0, 3.15))
	_solid(_model("plant_snake"), plant_size, 0.5, Vector3(3.5, 0, -3.7), 0.8)
	_solid(_model("plant_ficus"), plant_size, 0.5, Vector3(8.65, 0, 1.15), 1.3)
	# Настенные полки (задняя сторона модели — к стене; модель смотрит на +Z).
	# Вещи на полках — отдельные, бьются как хрусталь (и через время появляются снова).
	var book_shelf := [
		["shelf_books", -0.28, 0.1, [Color("992018"), Color("1a4080"), Color("cc9918")]],
		["shelf_matryoshka", 0.13, 0.1, [Color("cc1a14"), Color("e6c040")]],
		["shelf_elephant", 0.36, 0.1, [Color("ebebe6")]],
	]
	var plant_shelf := [
		["shelf_plant", -0.28, 0.11, [Color("a64d26"), Color("408c33")]],
		["shelf_jar", -0.02, 0.1, [GLASS, Color("cc1a14")]],
		["shelf_cactus", 0.2, 0.11, [Color("a64d26"), Color("26592a")]],
	]
	_wall_shelf(Vector3(PARTITION_X - 0.08, 1.55, -3.0), -PI / 2, book_shelf)
	_wall_shelf(Vector3(RIGHT_X, 1.5, -0.9), -PI / 2, book_shelf)
	_wall_shelf(Vector3(RIGHT_X, 1.55, 0.5), -PI / 2, plant_shelf)
	_wall_shelf(Vector3(PARTITION_X + 0.08, 1.6, -3.0), PI / 2, plant_shelf)
	# Плакаты.
	var size := Vector2(0.5, 0.7)
	_poster("home_space", size, Vector3(PARTITION_X - 0.085, 1.65, 0.65), -PI / 2)
	_poster("home_kefir", size, Vector3(LEFT_X + 0.012, 1.65, -2.65), PI / 2)
	_poster("home_calendar", size, Vector3(5.75, 1.6, BACK_Z + 0.012), 0.0)
	_poster("home_hockey", size, Vector3(PARTITION_X + 0.085, 1.6, 0.65), PI / 2)
	# Ковровая дорожка к двери в спальню (заходить в спальню не стала — владельцу не понравилось).
	_rug_floor(_place(_model("floor_runner"), Vector3(1.55, 0.004, -1.0)))


## Радио играет спокойную фоновую музыку (своя, без слов — tools/audio/radio_music.py).
## Разбили — замолкает; через 5 сек радио появляется снова и опять играет.
func _radio_music(radio: Breakable) -> void:
	radio.respawn_time = 5.0
	radio_music = RadioMusic.new(radio)
	add_child(radio_music)


## Ковёр-картина на стене: тонкая основа и картинка спереди, снизу — бахрома.
func _tapestry(center: Vector3, size: Vector2) -> void:
	_box(Vector3(size.x, size.y, 0.02), center, _mat(Color("5a1612"), 0.95))
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size - Vector2(0.02, 0.02)
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/carpet_deer.png")
	mat.roughness = 0.95
	quad.material_override = mat
	quad.position = center + Vector3(0, 0, 0.011)
	add_child(quad)
	var fringe := _mat(Color("dcc896"), 0.9)
	for i in 13:
		var x := center.x - size.x / 2.0 + 0.1 + i * (size.x - 0.2) / 12.0
		_box(Vector3(0.03, 0.08, 0.01), Vector3(x, center.y - size.y / 2.0 - 0.04, center.z), fringe)


## Настенная полка: пустая полка-модель и вещи на ней (Breakable). items — [[модель, x, z, цвета
## осколков], …] в координатах полки (вдоль полки — x, от стены — z).
func _wall_shelf(pos: Vector3, yaw: float, items: Array) -> void:
	_place(_model("wall_shelf"), pos).rotation.y = yaw
	for item: Array in items:
		var local := Vector3(item[1], 0.03, item[2]).rotated(Vector3.UP, yaw)
		var thing := _breakable(item[0], pos + local, item[3], 0.12, 0.03)
		thing.rotation.y = yaw


# ---------------- Телефон, часы, кот ----------------

func _build_living_extras() -> void:
	_solid(_model("phone_table"), Vector3(0.45, 0.6, 0.4), 0.3, PHONE_TABLE_POS, PI / 2)
	phone = RotaryPhone.new()
	phone.position = PHONE_TABLE_POS + Vector3(0, 0.6, 0)
	phone.rotation.y = PI / 2 # лицом в комнату (+X)
	add_child(phone)
	# Часы с кукушкой — на задней стене между книжной секцией и окном.
	var clock := CuckooClock.new()
	clock.position = Vector3(0.3, 1.95, BACK_Z) # по центру между книжной секцией и шторой
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
	# И справа от двери, и над ней — тоже тёмные (там просвечивали светлые обои гостиной).
	_box(Vector3(0.02, WALL_HEIGHT, LIVING_FRONT_Z - RUBGAME_DOOR_TO_Z),
		Vector3(LEFT_X - 0.21, WALL_HEIGHT / 2, (RUBGAME_DOOR_TO_Z + LIVING_FRONT_Z) / 2), wallpaper)
	_box(Vector3(0.02, WALL_HEIGHT - 2.4, RUBGAME_DOOR_TO_Z - RUBGAME_DOOR_FROM_Z),
		Vector3(LEFT_X - 0.21, 2.4 + (WALL_HEIGHT - 2.4) / 2,
		(RUBGAME_DOOR_FROM_Z + RUBGAME_DOOR_TO_Z) / 2), wallpaper)
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
	# Выключатель справа от двери в гостиную (со стороны игровой).
	# Светящийся низ абажура гаснет вместе с лампой: свой материал вместо светящегося из модели.
	var bulb_mat := _bulb_mat()
	for mesh in lamp.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var surface := mesh_instance.mesh.surface_get_material(i)
			if surface and surface.resource_name.begins_with("RubgameBulb"):
				mesh_instance.set_surface_override_material(i, bulb_mat)
	_add_switch(LobbyLamp.new(light, bulb_mat), RUBGAME_SWITCH, -PI / 2, true)

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
	if pos.y < 0.01:
		body.add_child(_contact_shadow(Vector2(size.x, size.z)))
	return body


## Ковёр твёрдый: невидимая форма столкновений по самой модели (выпуклая оболочка — у
## овального половика тоже овал). Иначе упавшие вещи (пульт, баллончик, книги) лежали на полу
## под ковром — «тонули» в нём. Игрок заходит на ковёр (3 см) без помех: капсула персонажа
## перекатывается через край.
func _rug_floor(rug: Node3D) -> void:
	var body := StaticBody3D.new()
	rug.add_child(body)
	for node in rug.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var shape := CollisionShape3D.new()
		shape.shape = mesh_instance.mesh.create_convex_shape(true, true)
		body.add_child(shape)
		shape.global_transform = mesh_instance.global_transform


## Мягкая тень-пятно под мебелью на полу (на ковре тоже): без неё диван и кресло казались
## висящими в воздухе — общий свет теней под ними почти не даёт. Только для слоя 1 (пол,
## ковры, мебель): на игроков не ложится.
func _contact_shadow(footprint: Vector2) -> Decal:
	if _shadow_tex == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0, 0, 0, 0.6))
		gradient.set_color(1, Color(0, 0, 0, 0.0))
		gradient.add_point(0.55, Color(0, 0, 0, 0.5))
		gradient.add_point(0.8, Color(0, 0, 0, 0.18))
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.gradient = gradient
		_shadow_tex.fill = GradientTexture2D.FILL_SQUARE
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		_shadow_tex.width = 64
		_shadow_tex.height = 64
	var decal := Decal.new()
	decal.texture_albedo = _shadow_tex
	# Тень выходит из-под мебели на ~35 см с каждой стороны и мягко тает: раньше выходила
	# на 6–7 см и почти вся пряталась под самим диваном — сбоку её не было видно.
	decal.size = Vector3(footprint.x + 0.7, 0.24, footprint.y + 0.7)
	decal.position.y = 0.06 # от −0.06 до 0.18: пол, ковёр и низ ножек
	decal.cull_mask = 1
	decal.upper_fade = 0.6 # к верху ножек тень сходит на нет
	return decal


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
