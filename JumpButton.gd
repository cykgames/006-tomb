class_name JumpButton
extends Button
## Jump key with an enlarged circular hit area. The drawn key is a disc of
## radius Joystick.RADIUS; the effective touch radius is 1.5x that, so taps
## just outside the graphic still register (user request). _has_point is the
## engine's hit-test hook and is honored even outside the control's rect.
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= Joystick.RADIUS * 1.5
