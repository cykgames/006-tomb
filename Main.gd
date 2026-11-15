extends Node3D
## Root orchestrator: wires level/player/HUD/camera/audio, finish flow,
## star rating (clear / all coins / under par), progress, coin burst.

var _coin_burst: CPUParticles3D
var _finished_handled := false

@onready var level: Node3D = $LevelGen
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var cam: Camera3D = $CameraRig
@onready var audio: Node = $Audio


func _ready() -> void:
	player.position = level.spawn_point
	cam.snap()
	hud.set_level_info(level.cfg["name"], level.coin_total)
	level.finished.connect(_on_finished)
	level.coin_taken.connect(_on_coin_taken)
	level.relic_taken.connect(_on_relic_taken)
	player.jumped.connect(_on_jumped)
	player.double_jumped.connect(_on_double_jumped)
	player.landed.connect(_on_landed)
	player.fell.connect(_on_fell)
	player.bounced.connect(_on_bounced)
	player.checkpoint_reached.connect(_on_checkpoint)
	hud.run_started.connect(_on_run_started)
	_build_coin_burst()


func _build_coin_burst() -> void:
	_coin_burst = CPUParticles3D.new()
	_coin_burst.emitting = false
	_coin_burst.one_shot = true
	_coin_burst.amount = 12
	_coin_burst.lifetime = 0.5
	_coin_burst.explosiveness = 1.0
	_coin_burst.direction = Vector3(0, 1, 0)
	_coin_burst.spread = 180.0
	_coin_burst.initial_velocity_min = 2.0
	_coin_burst.initial_velocity_max = 4.0
	_coin_burst.gravity = Vector3(0, -4, 0)
	_coin_burst.scale_amount_min = 0.06
	_coin_burst.scale_amount_max = 0.12
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.1, 0.1)
	_coin_burst.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.45, 0.05)
	_coin_burst.material_override = mat
	add_child(_coin_burst)


func _process(_delta: float) -> void:
	# Headless safety: never hang forever on a level.
	if Game.headless and hud.time > 180.0:
		print("TIMEOUT level=", Game.level_index, " pos=", player.position)
		get_tree().quit(1)


func _vibrate(ms: int) -> void:
	if not Game.headless:
		Input.vibrate_handheld(ms)


func _on_run_started() -> void:
	audio.start_bgm()


func _on_jumped() -> void:
	audio.play("jump")


func _on_double_jumped() -> void:
	audio.play("jump")
	cam.add_trauma(0.06)


func _on_landed() -> void:
	audio.play("land")
	cam.add_trauma(0.12)
	_vibrate(20)


func _on_bounced() -> void:
	audio.play("bounce")
	cam.add_trauma(0.2)
	_vibrate(35)


func _on_checkpoint(pos: Vector3) -> void:
	audio.play("checkpoint")
	level.activate_flag(pos)
	hud.toast("CHECKPOINT!")
	_vibrate(25)


func _on_fell() -> void:
	audio.play("fall")
	cam.add_trauma(0.5)
	cam.snap()
	hud.flash_red()
	_vibrate(80)


func _on_coin_taken(pos: Vector3) -> void:
	hud.add_coin()
	audio.play("coin")
	_coin_burst.global_position = pos
	_coin_burst.restart()
	_vibrate(15)


func _on_relic_taken(pos: Vector3) -> void:
	hud.add_relic()
	hud.toast("RELIC FOUND! (%d/%d)" % [Game.relic_count(), Game.RELICS_NEEDED])
	audio.play("coin")
	_coin_burst.global_position = pos
	_coin_burst.restart()
	_vibrate(30)


func _on_finished(t: float) -> void:
	if _finished_handled:
		return
	_finished_handled = true
	player.win()
	var pfalls: int = hud.falls
	var pcoins: int = hud.coins
	var total: int = level.coin_total
	var par: float = level.cfg["par"]
	# Stars: clear = 1, all coins = +1, under par = +1.
	var stars := 1
	if total > 0 and pcoins >= total:
		stars += 1
	if t <= par:
		stars += 1
	var improved := Game.save_level_result(Game.level_index, t, stars, pcoins)
	var best := Game.best_for(Game.level_index)
	var is_last := Game.level_index >= Game.LEVEL_COUNT - 1
	hud.show_finish(stars, t, pcoins, pfalls, best, is_last, improved)
	audio.play("finish")
	_vibrate(40)
	if Game.headless:
		print("FINAL level=", Game.level_index, " name=", level.cfg["name"], " time=", snappedf(t, 0.01), " falls=", pfalls, " coins=", pcoins, "/", total, " stars=", stars, " relics=", Game.relic_count())
		if not is_last:
			Game.level_index += 1
			get_tree().reload_current_scene.call_deferred()
		else:
			print("ALL_LEVELS_DONE")
			get_tree().quit.call_deferred()
