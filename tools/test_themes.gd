extends Node

## Headless data assertions for the 006 theme rotation (fun-review H2: all 6
## chambers used world=0/TOMB while 4 themes were defined). Verifies each
## chamber's world index maps to the intended theme and that all 4 themes
## are used. Theme rendering is data-driven (LevelGen._ready selects
## THEMES[world]; colors/sky/sun all read theme), so this pins the rotation.
##
## Run: godot --headless --path . res://tools/test_themes.tscn

const LG = preload("res://LevelGen.gd")

func _ready():
	var expect = ["TOMB", "CANYON", "FROST", "VOLCANO", "FROST", "VOLCANO"]
	var ok = true
	var used = {}
	for i in range(LG.LEVELS.size()):
		var w = int(LG.LEVELS[i]["world"])
		var tname = String(LG.THEMES[w]["name"])
		used[tname] = true
		var good = (i < expect.size() and tname == expect[i])
		ok = ok and good
		print("  chamber %d (%s) world=%d theme=%s %s" % [
			i, LG.LEVELS[i]["name"], w, tname, "ok" if good else "FAIL"])
	var all_four = used.size() == 4
	ok = ok and all_four
	print("  distinct themes used=%d %s" % [used.size(), "ok" if all_four else "FAIL"])
	print("TEST_THEMES PASS" if ok else "TEST_THEMES FAIL")
	get_tree().quit(0 if ok else 1)
