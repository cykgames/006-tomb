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
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 36)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Center the whole menu vertically so portrait screens do not leave a
	# huge dead zone under the content.
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Prominent title panel (the menu is the root scene, so this header is
	# the landmark element instead of a back button).
	var header := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.10, 0.08, 0.05, 0.95)
	hsb.border_color = WORLD_COLORS[0]
	hsb.set_border_width_all(4)
	hsb.set_corner_radius_all(18)
	hsb.set_content_margin_all(24)
	header.add_theme_stylebox_override("panel", hsb)
	vbox.add_child(header)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	header.add_child(hv)
	var title := _mk_label("TOMB EXPLORER", 88, Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(title)
	var sub := _mk_label("%d CHAMBERS · STARS %d/%d · RELICS %d/%d" % [Game.LEVEL_COUNT, Game.total_stars(), Game.LEVEL_COUNT * 3, Game.relic_count(), Game.RELICS_NEEDED], 32, Color(1.0, 0.85, 0.2))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(sub)
	var hint := _mk_label("CLIMB LEDGES · DODGE TRAPS · PULL LEVERS · FIND 3 RELICS", 24, Color(0.7, 0.75, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	for w in range(Game.WORLD_COUNT):
		var wl := _mk_label("DEPTH %d · %s" % [w + 1, WORLD_NAMES[w]], 42, WORLD_COLORS[w])
		vbox.add_child(wl)
		# 2-column grid wraps all 6 chambers inside the portrait width; the
		# old single HBox row overflowed and clipped chambers 1-5 / 1-6.
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 28)
		grid.add_theme_constant_override("v_separation", 28)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(grid)
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
			b.add_theme_font_size_override("font_size", 34)
			b.custom_minimum_size = Vector2(400, 300)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
			grid.add_child(b)

	# Author / attribution footer on the title screen. The headless regression
	# bot skips this scene (goes straight to Main.tscn), so this never affects
	# automated tests. Keep the author tag in sync with README.md / CREDITS.md.
	var credit := _mk_label("by cykbot7 · cykgames · Godot 4.7.2 · MIT", 20, Color(0.55, 0.60, 0.70))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(credit)


func _on_level_pressed(idx: int) -> void:
	Game.level_index = idx
	get_tree().change_scene_to_file("res://Main.tscn")
