extends Camera3D
## Fixed 3/4 view: diagonal offset, orientation never rotates (classic obby
## feel). Smooth follow + trauma shake. Player maps the joystick relative to
## this camera, so the fixed yaw keeps controls stable.

var target: Node3D
var trauma := 0.0
var _look := Vector3.ZERO
var _initialized := false

const OFFSET := Vector3(6.5, 9.0, 6.5)
const LOOK_AHEAD := Vector3(0, 0.8, 0)
const FOLLOW_K := 5.0


func _ready() -> void:
	target = get_parent().get_node("Player")
	snap()


func snap() -> void:
	if target == null:
		return
	global_position = target.global_position + OFFSET
	_look = target.global_position + LOOK_AHEAD
	look_at(_look, Vector3.UP)
	_initialized = true


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func _process(delta: float) -> void:
	if target == null or not _initialized:
		return
	var tp := target.global_position
	var desired := tp + OFFSET
	var k := 1.0 - exp(-delta * FOLLOW_K)
	global_position = global_position.lerp(desired, k)
	_look = _look.lerp(tp + LOOK_AHEAD, k)
	look_at(_look, Vector3.UP)
	trauma = maxf(0.0, trauma - delta * 2.2)
	if trauma > 0.0:
		var s := trauma * trauma * 0.22
		h_offset = randf_range(-s, s)
		v_offset = randf_range(-s, s)
	else:
		h_offset = 0.0
		v_offset = 0.0
