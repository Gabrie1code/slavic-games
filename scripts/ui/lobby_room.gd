class_name LobbyRoom
extends Control
## Экран одного игрока поверх лобби (примерочная, стол игры на рубли). Лобби делит экран
## между открытыми окнами по слотам игроков и закрывает окно по сигналу closed.

signal closed(player: PlayerData)

var player: PlayerData


## Закрыть окно.
func close() -> void:
	closed.emit(player)


## Обновить надписи (например, после пополнения кошелька).
func refresh() -> void:
	pass
