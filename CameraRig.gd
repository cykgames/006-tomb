extends Camera3D
## Fixed 3/4 view: diagonal offset, orientation never rotates (classic obby
## feel). Smooth follow + trauma shake. Player maps the joystick relative to
## this camera, so the fixed yaw keeps controls stable.

var target: Node3D
var trauma := 0.0
var _look := Vector3.ZERO
var _initialized := false

const OFFSET := Vector3(2.4, 8.0, 1.3)
const LOOK_AHEAD := Vector3(0, 0.5, -1.03)
const FOLLOW_K := 5.0

## View modes (user request 2026-11-19): 0 = legacy overhead rig, 1..3 = low
## chase cam at exactly 30deg pitch, placed at the player's 6 / 5 / 7 o'clock
## (directly behind / behind-right / behind-left). Static so the choice
## survives scene reloads. Default (user request 2026-11-20): start at 6H
## (mode 1, directly behind, 30deg pitch) on device; headless harnesses keep
## mode 0 so test framing stays bit-identical. Static init runs once per
## process before any _ready(), so HUD chip and rig agree on the initial mode.
static var view_mode := _default_view_mode()


static func _default_view_mode() -> int:
	return 0 if DisplayServer.get_name() == "headless" else 1

const CHASE_PITCH_DEG := 30.0
const CHASE_DIST := 6.0      # horizontal distance from the player
const CHASE_LOOK_H := 0.9    # aim at chest/head height
# Clock angles clockwise from 12 o'clock; the player faces -Z (12 o'clock).
const CHASE_CLOCK_DEG := [180.0, 150.0, 210.0]  # modes 1,2,3 = 6,5,7


func cycle_view() -> void:
	view_mode = (view_mode + 1) % 4
	snap()


func _view_offset() -> Vector3:
	if view_mode == 0:
		return OFFSET
	var a := deg_to_rad(CHASE_CLOCK_DEG[view_mode - 1])
	var dir := Vector3(sin(a), 0.0, -cos(a))
	var h := CHASE_LOOK_H + CHASE_DIST * tan(deg_to_rad(CHASE_PITCH_DEG))
	return dir * CHASE_DIST + Vector3(0.0, h, 0.0)


func _view_look() -> Vector3:
	if view_mode == 0:
		return LOOK_AHEAD
	return Vector3(0.0, CHASE_LOOK_H, 0.0)


## Low chase cams can sit inside walls/pads: ray from the look point to the
## desired camera pos and pull in front of the first hit. Mode 0 (high rig)
## is untouched so harness framing stays bit-identical.
func _occlude(desired: Vector3, tp: Vector3) -> Vector3:
	if view_mode == 0:
		return desired
	var sp := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(tp + _view_look(), desired)
	if target is CollisionObject3D:
		q.exclude = [target.get_rid()]
	var hit := sp.intersect_ray(q)
	if hit.is_empty():
		return desired
	return hit.position + hit.normal * 0.25


func _ready() -> void:
	target = get_parent().get_node("Player")
	snap()


func snap() -> void:
	if target == null:
		return
	global_position = _occlude(target.global_position + _view_offset(), target.global_position)
	_look = target.global_position + _view_look()
	look_at(_look, Vector3.UP)
	_initialized = true


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func _process(delta: float) -> void:
	if target == null or not _initialized:
		return
	var tp := target.global_position
	var desired := _occlude(tp + _view_offset(), tp)
	var k := 1.0 - exp(-delta * FOLLOW_K)
	global_position = global_position.lerp(desired, k)
	_look = _look.lerp(tp + _view_look(), k)
	look_at(_look, Vector3.UP)
	trauma = maxf(0.0, trauma - delta * 2.2)
	if trauma > 0.0:
		var s := trauma * trauma * 0.22
		h_offset = randf_range(-s, s)
		v_offset = randf_range(-s, s)
	else:
		h_offset = 0.0
		v_offset = 0.0
