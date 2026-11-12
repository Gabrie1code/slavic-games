class_name PlayerStats
extends RefCounted
## Счёт игрока в текущей партии.

## Рубли: валюта доски.
var coins: int = 0
## «Дефицит»: главный трофей. У кого больше всего — тот победил.
var deficit: int = 0
## Номер клетки, на которой стоит фишка игрока.
var space_index: int = 0
