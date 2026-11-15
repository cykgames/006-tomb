extends Node
## Autoload singleton: level index, progress (user://progress.json), unlocks.
## 006-tomb: 6 chambers in one tomb. Sequential unlock; 3 relics gate the
## treasure finale. Relics persist across chambers in progress["relics"].

const SAVE_PATH := "user://progress.json"
const LEVEL_COUNT := 6
const WORLD_COUNT := 1
const PER_WORLD := 6
const RELICS_NEEDED := 3

var level_index := 0
var headless := false
var progress := {}


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	load_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		progress = data


func best_for(idx: int) -> Dictionary:
	var r = progress.get(str(idx), {})
	return r if r is Dictionary else {}


func stars_for(idx: int) -> int:
	return int(best_for(idx).get("stars", 0))


func is_unlocked(idx: int) -> bool:
	if idx <= 0:
		return true
	return stars_for(idx - 1) >= 1


func total_stars() -> int:
	var n := 0
	for i in range(LEVEL_COUNT):
		n += stars_for(i)
	return n


## Relics collected across the tomb (distinct ids, persisted).
func relics() -> Array:
	var r = progress.get("relics", [])
	return r if r is Array else []


func relic_count() -> int:
	return relics().size()


func add_relic(id: String) -> bool:
	var r := relics()
	if r.has(id):
		return false
	r.append(id)
	progress["relics"] = r
	_save()
	return true


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress))


## Store the best result per level (max stars, min time, max coins).
## Returns true if anything improved.
func save_level_result(idx: int, time: float, stars: int, coins: int) -> bool:
	var key := str(idx)
	var prev := best_for(idx)
	var improved := false
	var entry := {
		"stars": maxi(stars, int(prev.get("stars", 0))),
		"time": minf(time, float(prev.get("time", 1e9))),
		"coins": maxi(coins, int(prev.get("coins", 0))),
	}
	if prev.is_empty() or entry["stars"] > int(prev.get("stars", 0)) \
			or entry["time"] < float(prev.get("time", 1e9)) \
			or entry["coins"] > int(prev.get("coins", 0)):
		improved = true
	progress[key] = entry
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress))
	return improved
