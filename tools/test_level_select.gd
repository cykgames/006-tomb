extends Node
## Headless portrait layout smoke test for LevelSelect (no device needed).
## Forces a 1080x2400 portrait window, builds the menu UI explicitly (the
## normal _ready skips it in headless), then asserts every button is fully
## on-screen, >=120 screen px tall, and content covers >=45% of the height.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/test_level_select.tscn

const EXPECT_COUNT := 6

var _fails := 0


func _expect(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("LAYOUT_FAIL: ", what)


func _ready() -> void:
	get_window().size = Vector2i(1080, 2400)
	# Attach the script AFTER tree entry so the headless scene-skip in
	# LevelSelect._ready never runs; we drive _build_ui ourselves.
	var sel := Control.new()
	add_child(sel)
	sel.set_script(load("res://LevelSelect.gd"))
	sel.set_anchors_preset(Control.PRESET_FULL_RECT)
	sel._build_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	var vr := get_viewport().get_visible_rect().size
	var scale_x := 1080.0 / vr.x
	var buttons: Array = []
	var labels: Array = []
	_collect(sel, buttons, labels)
	_expect(buttons.size() == EXPECT_COUNT, "button count %d != %d" % [buttons.size(), EXPECT_COUNT])
	var union := Rect2()
	var first := true
	for b in buttons:
		var r: Rect2 = b.get_global_rect()
		var tag: String = b.text.split("\n")[0]
		_expect(r.position.x >= -0.5 and r.end.x <= vr.x + 0.5, "button %s inside width (%s)" % [tag, r])
		_expect(r.position.y >= -0.5 and r.end.y <= vr.y + 0.5, "button %s inside height (%s)" % [tag, r])
		_expect(r.size.y * scale_x >= 120.0, "button %s >=120px tall (%.0f)" % [tag, r.size.y * scale_x])
	for c in buttons + labels:
		var r2: Rect2 = c.get_global_rect()
		union = r2 if first else union.merge(r2)
		first = false
	var coverage := union.size.y / vr.y
	_expect(coverage >= 0.45, "content coverage %.2f >= 0.45" % coverage)
	print("CANVAS=", vr, " BUTTONS=", buttons.size(), " COVERAGE=", snappedf(coverage, 0.01))
	if _fails == 0:
		print("LEVEL_SELECT_LAYOUT_PASS")
	else:
		print("LEVEL_SELECT_LAYOUT_FAIL count=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _collect(n: Node, buttons: Array, labels: Array) -> void:
	if n is Button:
		buttons.append(n)
	elif n is Label:
		labels.append(n)
	for c in n.get_children():
		_collect(c, buttons, labels)
