# SLAVIC GAMES: заметки для разработки

Party-игра на Godot 4.7 (GDScript), стилизованный low-poly, сеттинг 90-х и СССР. Владелец проекта новичок в разработке: объяснять просто, по-русски.

## Правила кода
- GDScript со статической типизацией (`var x: int`, `-> void`), отступы табами.
- Комментарии и строки интерфейса на русском.
- Перед коммитом: `gdparse` и `gdlint` из gdtoolkit 4 по всем `.gd`.
- Сцены `.tscn` можно писать вручную, но держать их простыми; сложную сборку UI делать в коде.

## Архитектура
- `PlayerManager` (autoload): список `PlayerData`, вход/выход, слоты. Максимум 4 игрока.
- `MatchState` (autoload): состояние партии (раунды, рубли, дефицит, позиции), живёт между сценами.
  Мини-игра по окончании вызывает `MatchState.finish_minigame(places)`.
- Мини-игры: `scenes/minigames/<name>/`, список в `MatchState.MINIGAMES`, дизайн в `docs/MINIGAMES.md`.
- Ввод: у каждого локального игрока свои действия `pN_<action>` (см. `InputSetup`),
  читать только через `player.input` (`PlayerInput`), никогда не через общие действия.
- **Готовность к сети:** `PlayerData` хранит только сериализуемые данные (+ `peer_id`).
  Игровая логика не должна зависеть от того, локальный игрок или сетевой.
- Смена сцен только через `SceneManager.change_scene()`.
- **Боты:** `PlayerData.DeviceKind.BOT`, ввод — `BotInput` (наследник `PlayerInput`, «виртуальный геймпад»).
  Мини-игра управляет ботом через `p.bot_input().move / press() / hold()`, а читает ввод
  одинаково для всех через `p.input`. Боты удаляются при возврате в лобби.
- Осторожно с `:=` при обходе нетипизированных массивов (`.duplicate()`, `.filter()`, `.values()`):
  Godot не выведет тип и не запустит скрипт. Копировать в типизированную переменную.

## Персонаж и одежда
- `PlayerCharacter` (scenes/characters/test_character.*): модель `character_base.glb` из частей
  Torso/Head/ArmL/ArmR/LegL/LegR, точка поворота в суставе; анимация в `_process` кодом.
- Одежда: `Cosmetics.ITEMS` (scripts/core/cosmetics.gd), модели `assets/models/character/cosmetics/<id>.glb`.
  Куски с именами частей тела кладутся внутрь частей. Материал `Primary` = цвет игрока.
- Слоты: HAT, FACE, JACKET, PANTS, SHOES, NECK. Цена вещи `price` (0 = бесплатно), каталог и цены — docs/COSMETICS.md.
- Профиль по `device_key()` в `user://profile.cfg`: наряд, кошелёк (рубли из партий), купленные вещи.
  API: `PlayerManager.wallet / add_to_wallet / owns / buy / save_outfit / load_outfit`.
- Цвет: палитра `PlayerManager.COLORS`, у игрока `color_index`; один цвет — один игрок
  (`color_owner`, `set_color`). Любимый цвет хранится в профиле.

## Лобби — советская квартира
- `Apartment` (scenes/lobby/apartment.gd) строит гостиную и спальню кодом из моделей `assets/models/apartment/`.
  Точки зон: `TV_ZONE` (старт), `WARDROBE_ZONE` (примерочная), `SEATS` (диван), `SPAWNS`.
- `Breakable` — ломается от касания игрока и восстанавливается; `Tippable` — RigidBody, падает и
  возвращается на место. Осколки на слое 2 (не мешают игрокам).
- Персонаж толкает RigidBody (`_push_bodies`), умеет `sit_at()` / `stand_up()`.

## Модели
Генерируются скриптами в `tools/blender/` (модуль `bpy` 4.2, Python 3.11), экспорт в `assets/models/`.
