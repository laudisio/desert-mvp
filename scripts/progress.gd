class_name Progress
extends Node
## Money, mission progress, garage upgrades and the owned business, persisted to `save_path`.

signal changed
signal income(amount: int)

const ORDER := ["armor", "engine", "nitro", "lab", "wash"]
const ITEMS := {
    "armor": {"name": "Blindagem do trailer", "costs": [2000, 4000, 7000],
        "desc": ["Batidas tiram 25% menos", "Batidas tiram 45% menos", "Batidas tiram 60% menos"]},
    "engine": {"name": "Motor (sedan e trailer)", "costs": [2000, 4000, 7000],
        "desc": ["+15% de força, +11 km/h", "+30% de força, +22 km/h", "+45% de força, +32 km/h"]},
    "nitro": {"name": "Nitro (Shift dirigindo)", "costs": [3000, 5000, 8000],
        "desc": ["3 s de turbo", "5 s de turbo", "7 s de turbo"]},
    "lab": {"name": "Equipamento do laboratório", "costs": [2500, 5000, 8000],
        "desc": ["Faixa verde 20% maior", "Faixa 40% maior, ponteiro mais lento", "Faixa 60% maior, ponteiro bem lento"]},
    "wash": {"name": "Lava-rápido (renda passiva)", "costs": [12000, 20000],
        "desc": ["Comprar: rende $ 250 por minuto", "Ampliar: rende $ 600 por minuto"]},
}
const ARMOR := [1.0, 0.75, 0.55, 0.4]
const ENGINE_POWER := [1.0, 1.15, 1.3, 1.45]
const ENGINE_SPEED := [0.0, 3.0, 6.0, 9.0]
const NITRO_CAP := [0.0, 3.0, 5.0, 7.0]
const LAB_ZONE := [1.0, 1.2, 1.4, 1.6]
const LAB_SPEED := [1.0, 0.92, 0.84, 0.76]
const WASH_INCOME := [0, 250, 600]
const INCOME_PERIOD := 60.0

var money := 0
var chapter := 0
var replay := false
var levels := {}
var save_path := "user://save.json"
var income_t := 0.0


func _init() -> void:
    for id in ORDER:
        levels[id] = 0


func level(id: String) -> int:
    return levels[id]


func max_level(id: String) -> int:
    return ITEMS[id].costs.size()


func cost(id: String) -> int:
    var lv := level(id)
    return -1 if lv >= max_level(id) else ITEMS[id].costs[lv]


func buy(id: String) -> bool:
    var c := cost(id)
    if c < 0 or money < c:
        return false
    money -= c
    levels[id] += 1
    save()
    changed.emit()
    return true


func save() -> void:
    var f := FileAccess.open(save_path, FileAccess.WRITE)
    if f == null:
        push_warning("Não foi possível salvar em %s" % save_path)
        return
    f.store_string(JSON.stringify({"version": 1, "money": money, "chapter": chapter, "replay": replay, "levels": levels}))


func load_game() -> bool:
    if not FileAccess.file_exists(save_path):
        return false
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
    if typeof(data) != TYPE_DICTIONARY:
        return false
    money = int(data.get("money", 0))
    chapter = int(data.get("chapter", 0))
    replay = bool(data.get("replay", false))
    var lv: Variant = data.get("levels", {})
    if typeof(lv) == TYPE_DICTIONARY:
        for id in ORDER:
            levels[id] = clampi(int(lv.get(id, 0)), 0, max_level(id))
    changed.emit()
    return true


func reset() -> void:
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
    money = 0
    chapter = 0
    replay = false
    for id in ORDER:
        levels[id] = 0
    changed.emit()


func _process(delta: float) -> void:
    var lv := level("wash")
    if lv == 0:
        return
    income_t += delta
    if income_t >= INCOME_PERIOD:
        income_t -= INCOME_PERIOD
        money += WASH_INCOME[lv]
        save()
        income.emit(WASH_INCOME[lv])
