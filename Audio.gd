extends Node
## SFX pool + looping chiptune BGM. All streams procedural (res://audio/*.wav).

var _players := {}
var _bgm: AudioStreamPlayer
var _enabled := true


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	for key in ["jump", "land", "coin", "fall", "finish", "bounce", "checkpoint"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://audio/%s.wav" % key)
		p.volume_db = -5.0
		add_child(p)
		_players[key] = p
	_bgm = AudioStreamPlayer.new()
	_bgm.stream = load("res://audio/bgm.wav")
	_bgm.volume_db = -13.0
	_bgm.finished.connect(_on_bgm_finished)
	add_child(_bgm)


func play(key: String) -> void:
	if not _enabled:
		return
	var p: AudioStreamPlayer = _players.get(key)
	if p:
		p.play()


func start_bgm() -> void:
	if _enabled and not _bgm.playing:
		_bgm.play()


func stop_bgm() -> void:
	if _bgm:
		_bgm.stop()


func _on_bgm_finished() -> void:
	if _enabled:
		_bgm.play()
