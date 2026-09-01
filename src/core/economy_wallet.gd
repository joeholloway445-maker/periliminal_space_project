extends Node
## Six currencies. Do not invent a seventh.
## coins · chips · fragments · tokens · charges · prestige

signal changed(currency: String, amount: int)

var coins: int = 120
var chips: int = 0
var fragments: int = 0
var tokens: int = 0
var charges: int = 3
var prestige: int = 0

func _ready() -> void:
	_load()

func all() -> Dictionary:
	return {
		"coins": coins, "chips": chips, "fragments": fragments,
		"tokens": tokens, "charges": charges, "prestige": prestige,
	}

func get_amount(currency: String) -> int:
	return int(all().get(currency, 0))

func add(currency: String, amount: int) -> bool:
	if not all().has(currency):
		return false
	set(currency, maxi(0, get_amount(currency) + amount))
	changed.emit(currency, get_amount(currency))
	_save()
	return true

func spend(currency: String, amount: int) -> bool:
	if get_amount(currency) < amount:
		return false
	return add(currency, -amount)

func coins_to_chips(n: int) -> bool:
	if n <= 0:
		return false
	if not spend("coins", n):
		return false
	return add("chips", n)

func wipe_except_prestige() -> void:
	coins = 0
	chips = 0
	fragments = 0
	tokens = 0
	charges = 0
	_save()
	changed.emit("prestige", prestige)

func _save() -> void:
	var f := FileAccess.open("user://wallet.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all()))

func _load() -> void:
	if not FileAccess.file_exists("user://wallet.json"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://wallet.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	coins = int(d.get("coins", coins))
	chips = int(d.get("chips", chips))
	fragments = int(d.get("fragments", fragments))
	tokens = int(d.get("tokens", tokens))
	charges = int(d.get("charges", charges))
	prestige = int(d.get("prestige", prestige))
