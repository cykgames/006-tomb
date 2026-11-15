extends Control
## Level select: 6 tomb chambers, stars, sequential unlock, total stars.
## All UI built in code. Tap an unlocked chamber -> Main.tscn.

const WORLD_NAMES := ["THE TOMB"]
const WORLD_COLORS := [Color(0.85, 0.68, 0.38)]


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file.call_deferred("res://Main.tscn")
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _mk_label(text: String, size: int, color: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 26)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var title := _mk_label("TOMB EXPLORER", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var sub := _mk_label("%d CHAMBERS · STARS %d/%d · RELICS %d/%d" % [Game.LEVEL_COUNT, Game.total_stars(), Game.LEVEL_COUNT * 3, Game.relic_count(), Game.RELICS_NEEDED], 30, Color(1.0, 0.85, 0.2))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	var hint := _mk_label("CLIMB LEDGES · DODGE TRAPS · PULL LEVERS · FIND 3 RELICS", 22, Color(0.7, 0.75, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	for w in range(Game.WORLD_COUNT):
		var wl := _mk_label("DEPTH %d · %s" % [w + 1, WORLD_NAMES[w]], 36, WORLD_COLORS[w])
		vbox.add_child(wl)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(row)
		for i in range(Game.PER_WORLD):
			var idx := w * Game.PER_WORLD + i
			var unlocked := Game.is_unlocked(idx)
			var stars := Game.stars_for(idx)
			var b := Button.new()
			var lname: String = LevelGen.LEVELS[idx]["name"]
			if unlocked:
				var star_text := "*".repeat(stars) + "-".repeat(3 - stars)
				b.text = "%d-%d\n%s\n%s" % [w + 1, i + 1, lname, star_text]
			else:
				b.text = "%d-%d\nLOCKED" % [w + 1, i + 1]
			b.add_theme_font_size_override("font_size", 26)
			b.custom_minimum_size = Vector2(260, 150)
			b.disabled = not unlocked
			var sb := StyleBoxFlat.new()
			if unlocked:
				sb.bg_color = Color(0.09, 0.14, 0.24, 0.95)
				sb.border_color = WORLD_COLORS[w]
			else:
				sb.bg_color = Color(0.10, 0.11, 0.14, 0.9)
				sb.border_color = Color(0.3, 0.32, 0.38)
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(16)
			sb.set_content_margin_all(10)
			b.add_theme_stylebox_override("normal", sb)
			var sbp := StyleBoxFlat.new()
			sbp.bg_color = Color(0.12, 0.30, 0.62, 0.95)
			sbp.border_color = Color(1, 1, 1, 0.9)
			sbp.set_border_width_all(3)
			sbp.set_corner_radius_all(16)
			sbp.set_content_margin_all(10)
			b.add_theme_stylebox_override("pressed", sbp)
			b.add_theme_stylebox_override("hover", sbp)
			b.add_theme_stylebox_override("disabled", sb)
			b.add_theme_color_override("font_color", Color(1, 1, 1) if unlocked else Color(0.45, 0.47, 0.52))
			b.add_theme_color_override("font_disabled_color", Color(0.45, 0.47, 0.52))
			b.pressed.connect(_on_level_pressed.bind(idx))
			row.add_child(b)


func _on_level_pressed(idx: int) -> void:
	Game.level_index = idx
	get_tree().change_scene_to_file("res://Main.tscn")
