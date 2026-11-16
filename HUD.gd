extends CanvasLayer
## Obby HUD: timer/coins/falls/level, anchored joystick + jump button,
## start/pause/finish panels, star rating, best record, checkpoint toast,
## red fall flash. All UI built in code (parkour-proven layout).

signal run_started

var time := 0.0
var falls := 0
var coins := 0
var running := false
var started := false
var finished := false
var paused := false
var _is_last := false
var _coin_total := 0
var _tick := 0

var _level_label: Label
var _time_label: Label
var _coin_label: Label
var _relic_label: Label
var _fall_label: Label
var _msg_label: Label
var _star_label: Label
var _best_label: Label
var _toast_label: Label
var _center_button: Button
var _restart_button: Button
var _exit_button: Button
var _jump_button: Button
var _pause_button: Button
var _pause_panel: ColorRect
var _flash: ColorRect
var _joy: Joystick
var _start_banner: PanelContainer

@onready var player: CharacterBody3D = get_parent().get_node("Player")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if DisplayServer.get_name() == "headless":
		start_run()
	else:
		# Single entry gate: tapping a level in the select screen loads this
		# scene and the run auto-starts after a short non-blocking banner.
		# Stick/jump input starts it even earlier (see _on_stick_pressed).
		get_tree().create_timer(1.5).timeout.connect(start_run)


func _mk_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _mk_button(text: String, size: int) -> Button:
	var b := Button.new()
	_style_button(b, text, size)
	return b


func _style_button(b: Button, text: String, fsize: int) -> void:
	b.text = text
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	b.add_theme_constant_override("outline_size", 3)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.16, 0.82)
	sb.border_color = Color(0.85, 0.92, 1.0, 0.5)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(14)
	b.add_theme_stylebox_override("normal", sb)
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = Color(0.10, 0.34, 0.72, 0.95)
	sbp.border_color = Color(1, 1, 1, 0.85)
	sbp.set_border_width_all(3)
	sbp.set_corner_radius_all(20)
	sbp.set_content_margin_all(14)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover", sbp)


func _centered(ctrl: Control, top: float, bottom: float, half_w: float = 320.0) -> void:
	ctrl.set_anchors_preset(Control.PRESET_CENTER)
	ctrl.offset_left = -half_w
	ctrl.offset_right = half_w
	ctrl.offset_top = top
	ctrl.offset_bottom = bottom


func _build_ui() -> void:
	var topbg := ColorRect.new()
	topbg.color = Color(0, 0, 0, 0.35)
	topbg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topbg.offset_bottom = 64.0
	topbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(topbg)
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 18.0
	bar.offset_right = -18.0
	bar.offset_top = 6.0
	bar.offset_bottom = 60.0
	bar.add_theme_constant_override("separation", 26)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)
	_level_label = _mk_label("1-1", 28)
	_time_label = _mk_label("TIME 000.0", 30)
	_coin_label = _mk_label("COIN 0/0", 30)
	_relic_label = _mk_label("RELIC 0/3", 30)
	_relic_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_fall_label = _mk_label("FALLS 0", 30)
	bar.add_child(_level_label)
	bar.add_child(_time_label)
	bar.add_child(_coin_label)
	bar.add_child(_relic_label)
	bar.add_child(_fall_label)
	_pause_button = _mk_button("II", 30)
	_pause_button.custom_minimum_size = Vector2(76, 56)
	_pause_button.pressed.connect(toggle_pause)
	bar.add_child(_pause_button)

	# Anchored joystick (bottom-left): full Vector2, both axes consumed by
	# the obby player. Disc stays near home; finger tracked anywhere.
	_joy = Joystick.new()
	_joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy.offset_left = 0.0
	_joy.offset_right = 600.0
	_joy.offset_top = -480.0
	_joy.offset_bottom = 0.0
	_joy.home_center = Vector2(190, 250)
	_joy.activated.connect(_on_stick_pressed)
	add_child(_joy)

	_msg_label = _mk_label("", 52)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centered(_msg_label, -170, -100)
	add_child(_msg_label)
	_star_label = _mk_label("", 62)
	_star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_star_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_centered(_star_label, -85, -10)
	_star_label.visible = false
	add_child(_star_label)
	_best_label = _mk_label("", 28)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centered(_best_label, 0, 40)
	_best_label.visible = false
	add_child(_best_label)
	_center_button = _mk_button("START", 60)
	_centered(_center_button, 56, 196, 380)
	_center_button.pressed.connect(_on_center_pressed)
	# Hidden until the finish panel reuses it (NEXT LEVEL / LEVEL SELECT).
	_center_button.visible = false
	add_child(_center_button)
	_restart_button = _mk_button("RESTART", 46)
	_centered(_restart_button, 216, 336, 185)
	_restart_button.offset_left -= 195
	_restart_button.offset_right -= 195
	_restart_button.pressed.connect(_on_restart_pressed)
	_restart_button.visible = false
	add_child(_restart_button)
	_exit_button = _mk_button("LEVELS", 46)
	_centered(_exit_button, 216, 336, 185)
	_exit_button.offset_left += 195
	_exit_button.offset_right += 195
	_exit_button.pressed.connect(_on_exit_pressed)
	_exit_button.visible = false
	add_child(_exit_button)

	# Checkpoint toast (fades, never blocks input).
	_toast_label = _mk_label("", 36)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_centered(_toast_label, -260, -210)
	_toast_label.visible = false
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_label)

	# Jump key: same footprint as the joystick disc, 1.5x effective radius.
	_jump_button = JumpButton.new()
	_style_button(_jump_button, "J", 96)
	var jd := Joystick.RADIUS * 2.0
	_jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_jump_button.offset_left = -jd - 30; _jump_button.offset_right = -30
	_jump_button.offset_top = -jd - 22; _jump_button.offset_bottom = -22
	for sn in ["normal", "pressed", "hover"]:
		var sb: StyleBoxFlat = _jump_button.get_theme_stylebox(sn)
		sb.set_corner_radius_all(int(Joystick.RADIUS))
		sb.set_border_width_all(4)
	_jump_button.button_down.connect(_on_jump_down); _jump_button.button_up.connect(_on_jump_up)
	add_child(_jump_button)

	_flash = ColorRect.new()
	_flash.color = Color(1, 0.1, 0.1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_pause_panel = ColorRect.new()
	_pause_panel.color = Color(0, 0, 0, 0.6)
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	add_child(_pause_panel)
	var pv := VBoxContainer.new()
	pv.set_anchors_preset(Control.PRESET_CENTER)
	pv.offset_left = -190; pv.offset_right = 190
	pv.offset_top = -150; pv.offset_bottom = 150
	pv.add_theme_constant_override("separation", 20)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_panel.add_child(pv)
	var pl := _mk_label("PAUSED", 48)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pl)
	var resume := _mk_button("RESUME", 40)
	resume.pressed.connect(toggle_pause)
	pv.add_child(resume)
	var prestart := _mk_button("RESTART", 36)
	prestart.pressed.connect(_on_restart_pressed)
	pv.add_child(prestart)
	var plevels := _mk_button("LEVELS", 36)
	plevels.pressed.connect(_on_exit_pressed)
	pv.add_child(plevels)

	# Start banner: bottom strip above the touch controls, never covers the
	# character (screen center). Input passes through; the run auto-starts
	# 1.5s after load, or immediately on stick/jump input.
	_start_banner = PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.05, 0.08, 0.14, 0.85)
	bsb.border_color = Color(1.0, 0.85, 0.2, 0.9)
	bsb.set_border_width_all(3)
	bsb.set_corner_radius_all(16)
	bsb.set_content_margin_all(16)
	_start_banner.add_theme_stylebox_override("panel", bsb)
	_start_banner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_start_banner.offset_left = 60.0
	_start_banner.offset_right = -60.0
	_start_banner.offset_top = -640.0
	_start_banner.offset_bottom = -520.0
	_start_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := _mk_label("GET READY!  STICK: MOVE · J: JUMP", 34)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_banner.add_child(bl)
	add_child(_start_banner)


func msg_label_set(text: String) -> void:
	_msg_label.text = text
	_msg_label.visible = true


func set_level_info(lname: String, coin_total: int) -> void:
	_coin_total = coin_total
	var w := Game.level_index / Game.PER_WORLD + 1
	var n := Game.level_index % Game.PER_WORLD + 1
	_level_label.text = "%d-%d %s" % [w, n, lname]
	_coin_label.text = "COIN 0/%d" % coin_total
	_relic_label.text = "RELIC %d/%d" % [Game.relic_count(), Game.RELICS_NEEDED]


func toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _toast_label.visible = false)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
	player.input_dir = _joy.output
	if running:
		time += delta
		_time_label.text = "TIME %05.1f" % time
	_tick += 1
	if DisplayServer.get_name() == "headless" and _tick % 600 == 0:
		print("HUDREPORT level=", Game.level_index, " time=", snappedf(time, 0.1), " falls=", falls, " coins=", coins, " relics=", Game.relic_count(), " pos=", player.position)


## Joystick touch routing (parkour-proven): disc is MOUSE_FILTER_IGNORE, the
## finger is tracked ANYWHERE on screen; JumpButton is real GUI so it never
## reaches here. emulate_touch_from_mouse makes this work on desktop too.
func _unhandled_input(event: InputEvent) -> void:
	if paused or finished:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		var lp := _joy.get_global_transform_with_canvas().affine_inverse() * touch.position
		if touch.pressed:
			if _joy.touch_index() == -1 and _joy.can_activate(lp):
				_joy.press_at(lp, touch.index)
		elif touch.index == _joy.touch_index():
			_joy.release_touch()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _joy.touch_index():
		var lp := _joy.get_global_transform_with_canvas().affine_inverse() * drag.position
		_joy.drag_to(lp)


func get_time() -> float:
	return time


func add_fall() -> void:
	falls += 1
	_fall_label.text = "FALLS %d" % falls


func add_coin() -> void:
	coins += 1
	_coin_label.text = "COIN %d/%d" % [coins, _coin_total]


func add_relic() -> void:
	_relic_label.text = "RELIC %d/%d" % [Game.relic_count(), Game.RELICS_NEEDED]


func flash_red() -> void:
	_flash.color = Color(1, 0.1, 0.1, 0.45)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.4)


func start_run() -> void:
	if started:
		return
	started = true
	running = true
	player.started = true
	_msg_label.visible = false
	_center_button.visible = false
	_start_banner.visible = false
	toast("GO!")
	run_started.emit()


func toggle_pause() -> void:
	if not started or finished:
		return
	paused = not paused
	get_tree().paused = paused
	_pause_panel.visible = paused
	running = not paused
	if paused:
		_joy.force_release()


func show_finish(stars: int, t: float, pcoins: int, pfalls: int, best: Dictionary, is_last: bool, improved: bool) -> void:
	finished = true
	running = false
	_is_last = is_last
	msg_label_set("LEVEL CLEAR!")
	_star_label.text = "*".repeat(stars) + "-".repeat(3 - stars)
	_star_label.visible = true
	var bt := ""
	if improved:
		bt = "NEW RECORD!  "
	if not best.is_empty():
		bt += "BEST %05.1fs" % float(best.get("time", 0.0))
	_best_label.text = bt
	_best_label.visible = true
	_center_button.text = "LEVEL SELECT" if is_last else "NEXT LEVEL"
	_center_button.visible = true
	_restart_button.visible = true
	_exit_button.visible = true
	_joy.visible = false
	_jump_button.visible = false


func _on_center_pressed() -> void:
	if finished:
		if _is_last:
			_go_levels()
		else:
			Game.level_index += 1
			_reload()
	elif not started:
		start_run()


func _on_restart_pressed() -> void:
	_reload()


func _on_exit_pressed() -> void:
	_go_levels()


func _go_levels() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://LevelSelect.tscn")


func _reload() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_stick_pressed() -> void:
	if not started:
		start_run()


func _on_jump_down() -> void:
	if not started:
		start_run()
	Input.action_press("jump")


func _on_jump_up() -> void:
	Input.action_release("jump")
