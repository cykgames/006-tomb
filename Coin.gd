extends Area3D
## Spinning gold coin. Emits collected(global_pos) once when player touches it.

signal collected(pos: Vector3)

var _taken := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not _taken:
		rotate_y(delta * 3.2)


func _on_body_entered(body: Node3D) -> void:
	if _taken:
		return
	if body.is_in_group("player"):
		_taken = true
		collected.emit(global_position)
		visible = false
		set_deferred("monitoring", false)
