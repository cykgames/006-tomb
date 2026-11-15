class_name Joystick
extends Control
## Anchored virtual joystick disc. HUD drives it from _unhandled_input so the
## finger is tracked ANYWHERE on screen and never lost when it leaves the zone.
## Touch in the bottom-left zone (or within GRAB_RADIUS of the disc) grabs it;
## drag to steer, release to spring back home.
## The disc STAYS near home_center -- it does NOT chase the finger. While the
## finger is within knob reach the knob tracks it 1:1; beyond reach the knob
## pins at the rim pointing at the finger (full magnitude, so steering still
## works when the thumb accidentally leaves the pad) and the disc leans toward
## the finger by at most MAX_DRIFT (a small offset, never roaming the screen).
## Output is a FULL Vector2 (-1..1 per axis, radial deadzone):
##   x = strafe (consumed by Player.input_dir.x today)
##   y = reserved for a future forward/back axis (not consumed yet)
## so the same pad can later become a 4-way stick without input rework.

signal activated
signal released

const RADIUS := 165.0
const KNOB_RADIUS := 72.0
const KNOB_MAX := 108.0
const DEADZONE := 0.12
## Effective grab radius = 1.5x the drawn disc: control works even when the
## finger is outside the graphic (user request).
const GRAB_RADIUS := RADIUS * 1.5
## The disc is anchored near home. When the thumb outruns the knob's reach the
## disc may lean toward it, but only up to this small offset -- it never chases
## the finger across the screen (user: a little drift is fine, roaming is not).
const MAX_DRIFT := RADIUS * 0.30

var output := Vector2.ZERO
var active := false
var home_center := Vector2(190, 250)
var _center := Vector2(190, 250)
var _knob := Vector2.ZERO
var _touch := -1


func _ready() -> void:
	# Pure drawing surface; HUD owns touch routing via _unhandled_input so the
	# stick keeps following the finger even far outside this control's rect.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center = home_center


## Pure mapping knob-offset -> normalized output (radial deadzone + rescale).
static func compute_output(d: Vector2) -> Vector2:
	var mag := d.length() / KNOB_MAX
	if mag <= DEADZONE:
		return Vector2.ZERO
	var m := clampf((mag - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
	return d.normalized() * m


func touch_index() -> int:
	return _touch


func center() -> Vector2:
	return _center


## True if a press at local point p should grab the stick: inside the
## bottom-left zone, or within the 1.5x effective radius of the disc.
func can_activate(p: Vector2) -> bool:
	var zone := Rect2(Vector2.ZERO, size)
	return zone.has_point(p) or p.distance_to(_center) <= GRAB_RADIUS


func press_at(p: Vector2, index: int) -> void:
	_touch = index
	active = true
	_steer(p)
	activated.emit()
	queue_redraw()


func drag_to(p: Vector2) -> void:
	if not active:
		return
	_steer(p)
	queue_redraw()


## Anchored steering. Within knob reach the disc sits at home and the knob
## tracks the finger 1:1. Beyond reach the knob pins at the rim pointing at the
## finger (full magnitude -- control never drops when the thumb leaves the pad)
## and the disc leans toward the finger by at most MAX_DRIFT, staying near home
## instead of roaming after it.
func _steer(p: Vector2) -> void:
	var d := p - home_center
	var dist := d.length()
	if dist <= KNOB_MAX:
		_center = home_center
		_knob = d
	else:
		var dir := d / dist
		var drift := minf(dist - KNOB_MAX, MAX_DRIFT)
		_center = home_center + dir * drift
		_knob = dir * KNOB_MAX
	output = compute_output(_knob)


func force_release() -> void:
	if _touch != -1 or active:
		_release()


func release_touch() -> void:
	_release()


func _release() -> void:
	_touch = -1
	active = false
	output = Vector2.ZERO
	released.emit()
	queue_redraw()


func _process(delta: float) -> void:
	if active:
		return
	var moved := false
	if _knob.length() > 0.5:
		_knob = _knob.move_toward(Vector2.ZERO, delta * 900.0)
		moved = true
	elif _knob != Vector2.ZERO:
		_knob = Vector2.ZERO
		moved = true
	if _center.distance_to(home_center) > 0.5:
		_center = _center.move_toward(home_center, delta * 1200.0)
		moved = true
	elif _center != home_center:
		_center = home_center
		moved = true
	if moved:
		queue_redraw()


func _arrow(c: Vector2, dir: Vector2, col: Color) -> void:
	var tip := c + dir * (RADIUS - 26.0)
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		tip,
		tip - dir * 22.0 + side * 16.0,
		tip - dir * 22.0 - side * 16.0,
	])
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var c := _center
	var base_a := 0.82 if active else 0.55
	var rim_a := 0.9 if active else 0.45
	# Deep navy disc + light rim (matches HUD v2 dark buttons).
	draw_circle(c, RADIUS, Color(0.07, 0.10, 0.16, base_a))
	draw_arc(c, RADIUS - 2.0, 0.0, TAU, 64, Color(0.85, 0.92, 1.0, rim_a), 4.0, true)
	# Travel guide ring.
	draw_arc(c, KNOB_MAX, 0.0, TAU, 48, Color(1, 1, 1, 0.10), 2.0, true)
	# Axis hints: E/W bright (strafe live now), N/S dim (future axes).
	_arrow(c, Vector2.RIGHT, Color(1, 1, 1, 0.85))
	_arrow(c, Vector2.LEFT, Color(1, 1, 1, 0.85))
	_arrow(c, Vector2.UP, Color(1, 1, 1, 0.28))
	_arrow(c, Vector2.DOWN, Color(1, 1, 1, 0.28))
	# Knob: electric blue while held, slate at rest.
	var kc := c + _knob
	var knob_col := Color(0.10, 0.34, 0.72, 0.95) if active else Color(0.16, 0.22, 0.34, 0.90)
	var knob_rim := 0.85 if active else 0.50
	draw_circle(kc, KNOB_RADIUS, knob_col)
	draw_arc(kc, KNOB_RADIUS - 2.0, 0.0, TAU, 48, Color(1, 1, 1, knob_rim), 3.0, true)
	draw_circle(kc - Vector2(18, 20), 14.0, Color(1, 1, 1, 0.18))
