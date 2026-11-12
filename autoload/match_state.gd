extends Node
## Состояние текущей партии (автозагрузка MatchState).
##
## Живёт между сценами: доска → мини-игра → доска → ... → итоги.
## Хранит только данные, без визуала, чтобы позже синхронизировать по сети.

const DEFICIT_PRICE := 20
const START_COINS := 10
## Награда за места в мини-игре: 1-е, 2-е, 3-е, 4-е.
const MINIGAME_REWARDS: Array[int] = [10, 5, 3, 1]

const SCENE_LOBBY := "res://scenes/lobby/local_lobby.tscn"
const SCENE_BOARD := "res://scenes/board/board_game.tscn"
const SCENE_RESULTS := "res://scenes/results/results.tscn"
const SCENE_ROULETTE := "res://scenes/roulette/minigame_roulette.tscn"

## Все мини-игры: сцена, название, подпись и цвет карточки в рулетке.
const MINIGAMES: Array[Dictionary] = [
	{
		"scene": "res://scenes/minigames/sausage_queue/sausage_queue.tscn",
		"title": "Очередь\nза колбасой",
		"tagline": "Реакция",
		"color": Color("8c1c13"),
	},
	{
		"scene": "res://scenes/minigames/bat_battle/bat_battle.tscn",
		"title": "Битва\nна битах",
		"tagline": "Все против всех",
		"color": Color("2f5f8a"),
	},
	{
		"scene": "res://scenes/minigames/freeze_tag/freeze_tag.tscn",
		"title": "Морожка",
		"tagline": "Догонялки\n1 водящий против всех",
		"color": Color("2a8fa8"),
	},
]

var in_progress := false
var rounds_total := 5
var current_round := 1
## Чей ход в текущем раунде (индекс в turn_order()).
var turn_index := 0
## Номер клетки, рядом с которой стоит ларёк «Дефицит». -1 = ещё не выбран.
var deficit_space := -1
## PlayerData.id -> PlayerStats
var stats: Dictionary = {}
## Индексы мини-игр (в MINIGAMES), которые уже были в этой партии.
var played_minigames: Array[int] = []


func start_new_match(rounds: int) -> void:
	in_progress = true
	rounds_total = rounds
	current_round = 1
	turn_index = 0
	deficit_space = -1
	stats.clear()
	played_minigames.clear()
	for p in PlayerManager.players:
		var s := PlayerStats.new()
		s.coins = START_COINS
		stats[p.id] = s


func end_match() -> void:
	in_progress = false
	stats.clear()


func get_stats(p: PlayerData) -> PlayerStats:
	return stats.get(p.id) as PlayerStats


## Меняет рубли игрока (не уходит в минус). Возвращает реальное изменение.
func add_coins(p: PlayerData, amount: int) -> int:
	var s := get_stats(p)
	var before := s.coins
	s.coins = maxi(0, s.coins + amount)
	return s.coins - before


## Порядок ходов: по слотам игроков.
func turn_order() -> Array[PlayerData]:
	var order: Array[PlayerData] = PlayerManager.players.duplicate()
	order.sort_custom(func(a: PlayerData, b: PlayerData) -> bool: return a.slot < b.slot)
	return order


## Таблица мест: больше дефицита → выше, при равенстве — больше рублей.
func standings() -> Array[PlayerData]:
	var order := turn_order()
	order.sort_custom(func(a: PlayerData, b: PlayerData) -> bool:
		var sa := get_stats(a)
		var sb := get_stats(b)
		if sa.deficit != sb.deficit:
			return sa.deficit > sb.deficit
		return sa.coins > sb.coins)
	return order


## Выбирает следующую мини-игру: только из ещё не сыгранных.
## Когда сыграны все — круг начинается заново. Возвращает индекс в MINIGAMES.
func pick_next_minigame() -> int:
	var available: Array[int] = []
	for i in MINIGAMES.size():
		if not played_minigames.has(i):
			available.append(i)
	if available.is_empty():
		played_minigames.clear()
		available.assign(range(MINIGAMES.size()))
	var picked: int = available.pick_random()
	played_minigames.append(picked)
	return picked


## Мини-игра закончилась: раздаём награды и решаем, куда идти дальше.
## places — игроки от первого места к последнему.
func finish_minigame(places: Array[PlayerData]) -> void:
	for i in places.size():
		var reward: int = MINIGAME_REWARDS[i] if i < MINIGAME_REWARDS.size() else 0
		add_coins(places[i], reward)
	current_round += 1
	turn_index = 0
	if current_round > rounds_total:
		SceneManager.change_scene(SCENE_RESULTS)
	else:
		SceneManager.change_scene(SCENE_BOARD)


## Прервать партию и вернуться в лобби (Esc).
func abort_to_lobby() -> void:
	end_match()
	SceneManager.change_scene(SCENE_LOBBY)
