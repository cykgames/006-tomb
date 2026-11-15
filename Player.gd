extends CharacterBody3D
## Obby player: omnidirectional camera-relative movement (joystick Vector2,
## x AND y consumed), double jump, coyote time + jump buffer, ice sliding,
## bounce pads, checkpoint respawn (grounded proximity only -- W7 lesson).
## Block character + procedural run/jump animation + squash&stretch in code;
## optional glTF character at res://assets/character.glb replaces the boxes.
## Headless: waypoint-following bot (level.nav) for regression runs.

const SPEED := 6.0
const GRAVITY := 22.0
const JUMP_VELOCITY := 8.5
const DOUBLE_JUMP_VELOCITY := 8.0
const ACCEL := 40.0
const AIR_ACCEL := 22.0
const FRICTION := 46.0
const ICE_ACCEL := 6.0
const ICE_FRICTION := 1.2
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const BOUNCE_VELOCITY := 13.0

signal jumped
signal double_jumped
signal landed
signal fell
signal bounced
signal checkpoint_reached(pos: Vector3)

## Analog stick input from the HUD joystick: x = right, y = down (screen).
var input_dir := Vector2.ZERO
var started := false
var autopilot := false
var _coyote := 0.0
var _buffer := 0.0
var _jumps_left := 2
var _dead := false
var _last_checkpoint := Vector3.ZERO
var _on_ice := false
var _squash := 0.0
var _anim_t := 0.0
var _facing := 0.0
# Headless bot state
var _nav_idx := 0
var _ap_dir := Vector3.ZERO
var _stuck_t := 0.0
# Ledge mantle (auto pull-up when touching a marked ledge)
var _mantle_target: Variant = null
var _mantle_from := Vector3.ZERO
var _mantle_t := 0.0

@onready var level: Node3D = get_parent().get_node("LevelGen")
@onready var hud: CanvasLayer = get_parent().get_node("HUD")

var _visual: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _dust: CPUParticles3D
var _gltf_anim: AnimationPlayer
var _gltf_mode := false


func _ready() -> void:
	add_to_group("player")
	autopilot = DisplayServer.get_name() == "headless"
	started = autopilot
	position = level.spawn_point
	_last_checkpoint = level.spawn_point
	_build_visual()
	_build_dust()


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	return mi


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	if ResourceLoader.exists("res://assets/character.glb"):
		var scene: PackedScene = load("res://assets/character.glb")
		if scene != null:
			var inst := scene.instantiate()
			inst.scale = Vector3(1.4, 1.4, 1.4)
			_visual.add_child(inst)
			_gltf_anim = _find_anim_player(inst)
			_gltf_mode = true
			_visual.position = Vector3(0, -0.8, 0)
			return
	_visual.position = Vector3(0, -0.7, 0)
	var skin := Color(0.90, 0.72, 0.50)
	var shirt := Color(0.25, 0.50, 0.85)
	var pants := Color(0.20, 0.22, 0.40)
	var hair := Color(0.35, 0.24, 0.14)
	var shoe := Color(0.15, 0.15, 0.18)
	# Legs (pivot at hip y=0.5)
	_leg_l = Node3D.new(); _leg_l.position = Vector3(-0.14, 0.5, 0); _visual.add_child(_leg_l)
	_leg_l.add_child(_box(Vector3(0.22, 0.5, 0.24), pants, Vector3(0, -0.25, 0)))
	_leg_l.add_child(_box(Vector3(0.24, 0.12, 0.30), shoe, Vector3(0, -0.46, -0.03)))
	_leg_r = Node3D.new(); _leg_r.position = Vector3(0.14, 0.5, 0); _visual.add_child(_leg_r)
	_leg_r.add_child(_box(Vector3(0.22, 0.5, 0.24), pants, Vector3(0, -0.25, 0)))
	_leg_r.add_child(_box(Vector3(0.24, 0.12, 0.30), shoe, Vector3(0, -0.46, -0.03)))
	# Torso
	_visual.add_child(_box(Vector3(0.56, 0.60, 0.32), shirt, Vector3(0, 0.80, 0)))
	# Arms (pivot at shoulder y=1.05)
	_arm_l = Node3D.new(); _arm_l.position = Vector3(-0.37, 1.05, 0); _visual.add_child(_arm_l)
	_arm_l.add_child(_box(Vector3(0.18, 0.50, 0.20), shirt, Vector3(0, -0.25, 0)))
	_arm_l.add_child(_box(Vector3(0.18, 0.12, 0.20), skin, Vector3(0, -0.52, 0)))
	_arm_r = Node3D.new(); _arm_r.position = Vector3(0.37, 1.05, 0); _visual.add_child(_arm_r)
	_arm_r.add_child(_box(Vector3(0.18, 0.50, 0.20), shirt, Vector3(0, -0.25, 0)))
	_arm_r.add_child(_box(Vector3(0.18, 0.12, 0.20), skin, Vector3(0, -0.52, 0)))
	# Head + hair + face (faces -Z)
	_visual.add_child(_box(Vector3(0.46, 0.46, 0.46), skin, Vector3(0, 1.33, 0)))
	_visual.add_child(_box(Vector3(0.48, 0.14, 0.48), hair, Vector3(0, 1.52, 0)))
	_visual.add_child(_box(Vector3(0.48, 0.10, 0.10), hair, Vector3(0, 1.44, 0.20)))
	_visual.add_child(_box(Vector3(0.09, 0.09, 0.02), Color(0.12, 0.12, 0.2), Vector3(-0.10, 1.36, -0.235)))
	_visual.add_child(_box(Vector3(0.09, 0.09, 0.02), Color(0.12, 0.12, 0.2), Vector3(0.10, 1.36, -0.235)))


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r != null:
			return r
	return null


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.position = Vector3(0, -0.65, 0)
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 14
	_dust.lifetime = 0.45
	_dust.explosiveness = 1.0
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 180.0
	_dust.initial_velocity_min = 1.2
	_dust.initial_velocity_max = 2.6
	_dust.gravity = Vector3(0, -3, 0)
	_dust.scale_amount_min = 0.08
	_dust.scale_amount_max = 0.16
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 0.12)
	_dust.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.30)
	_dust.material_override = mat
	add_child(_dust)


func _physics_process(delta: float) -> void:
	if _dead or not started:
		return
	if _mantle_target != null:
		_mantle_t += delta
		var k := clampf(_mantle_t / 0.28, 0.0, 1.0)
		position = (_mantle_from as Vector3).lerp(_mantle_target, k)
		velocity = Vector3.ZERO
		if k >= 1.0:
			_mantle_target = null
			_jumps_left = 2
			_coyote = COYOTE_TIME
			_buffer = 0.0
		return
	var was_on_floor := is_on_floor()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_coyote -= delta
	else:
		_coyote = COYOTE_TIME
		_jumps_left = 2
	_buffer -= delta
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	if autopilot:
		_autopilot_think(delta)
	# Jump: ground (coyote) first, then one air jump (double jump).
	if _buffer > 0.0:
		if _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_buffer = 0.0
			_coyote = 0.0
			_jumps_left = 1
			_squash = -0.25
			jumped.emit()
		elif _jumps_left > 0:
			velocity.y = DOUBLE_JUMP_VELOCITY
			_buffer = 0.0
			_jumps_left = 0
			_squash = -0.25
			double_jumped.emit()
	# Wish direction: camera-relative from the full joystick Vector2.
	var wish := Vector3.ZERO
	if autopilot:
		wish = _ap_dir
	else:
		var d2 := input_dir
		if Input.is_action_pressed("move_left"):
			d2.x -= 1.0
		if Input.is_action_pressed("move_right"):
			d2.x += 1.0
		if Input.is_action_pressed("move_forward"):
			d2.y -= 1.0
		if Input.is_action_pressed("move_back"):
			d2.y += 1.0
		d2 = Vector2(clampf(d2.x, -1.0, 1.0), clampf(d2.y, -1.0, 1.0))
		if d2.length() > 1.0:
			d2 = d2.normalized()
		var cam := get_viewport().get_camera_3d()
		if cam != null and d2.length() > 0.01:
			var fwd := global_position - cam.global_position
			fwd.y = 0.0
			if fwd.length() > 0.01:
				fwd = fwd.normalized()
				var right := fwd.cross(Vector3.UP)
				wish = right * d2.x + fwd * (-d2.y)
	# Acceleration / friction (ice = low grip both ways).
	var accel := ACCEL
	var fric := FRICTION
	if not is_on_floor():
		accel = AIR_ACCEL
		fric = 2.0
	elif _on_ice:
		accel = ICE_ACCEL
		fric = ICE_FRICTION
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length() > 0.01:
		hv = hv.move_toward(wish * SPEED, accel * delta)
	else:
		hv = hv.move_toward(Vector3.ZERO, fric * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	# Floor material + bounce pads.
	_on_ice = false
	if is_on_floor():
		var fc := get_last_slide_collision()
		if fc != null and fc.get_collider() != null:
			var body := fc.get_collider()
			if body.is_in_group("ice"):
				_on_ice = true
			if not was_on_floor and body.is_in_group("bounce"):
				velocity.y = BOUNCE_VELOCITY
				_jumps_left = 1
				_squash = -0.35
				bounced.emit()
	if is_on_floor() and not was_on_floor:
		_squash = 0.35
		if _dust:
			_dust.restart()
		if velocity.y <= 0.0:
			landed.emit()
	# Checkpoint: only while grounded, only ones actually reached.
	if is_on_floor():
		var cp = level.checkpoint_at(position)
		if cp != null and cp != _last_checkpoint:
			_last_checkpoint = cp
			checkpoint_reached.emit(cp)
	if position.y < level.kill_y:
		respawn()


func _autopilot_think(delta: float) -> void:
	var target: Vector3 = level.goal_pos
	var have_nav: bool = _nav_idx < level.nav.size()
	if have_nav:
		var n: Dictionary = level.nav[_nav_idx]
		target = n["pos"]
		if n["kind"] == "mover" and n["ref"] != null:
			target = (n["ref"] as Node3D).global_position + Vector3(0, 0.6, 0)
		if n["kind"] == "vanish" and is_on_floor():
			# Wait at the edge until the block is solid with time to spare.
			if not level.vanish_solid(n["ref"]) or level.vanish_remaining(n["ref"]) < 1.0:
				_ap_dir = Vector3.ZERO
				return
		if n["kind"] == "blade" and is_on_floor():
			# Wait at the near edge until the blade sweeps away from center.
			if not level.blade_safe(n["ref"]):
				_ap_dir = Vector3.ZERO
				return
	var to := target - position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() < 1.3 and absf(to.y) < 2.5:
		if have_nav:
			_nav_idx += 1
			_stuck_t = 0.0
			return
	_ap_dir = flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	var sp := get_world_3d().direct_space_state
	if is_on_floor():
		var from := position + _ap_dir * 1.0 + Vector3(0, -0.4, 0)
		var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -2.5, 0)))
		var need_up := target.y > position.y + 0.8 and flat.length() < 4.0
		if hit.is_empty() or need_up:
			_buffer = JUMP_BUFFER
	elif velocity.y < -2.0 and _jumps_left > 0:
		# Double jump only when neither below nor the predicted landing spot
		# (0.35s ahead) has floor -- small gaps stay single-jump so the bot
		# lands early on the pad instead of flying over it.
		var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(position, position + Vector3(0, -3.5, 0)))
		var ahead := position + Vector3(velocity.x, 0.0, velocity.z) * 0.35
		var hit_ahead := sp.intersect_ray(PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3(0, -3.5, 0)))
		if hit.is_empty() and hit_ahead.is_empty():
			_buffer = JUMP_BUFFER
	# Stuck recovery (spinner pushes, mover drift): hop after 2s of no motion.
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if _ap_dir.length() > 0.1 and hspeed < 0.5:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	if _stuck_t > 2.0:
		_buffer = JUMP_BUFFER
		_stuck_t = 0.0


func _process(delta: float) -> void:
	if _visual == null:
		return
	_anim_t += delta
	var active := started and not _dead
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if hspeed > 0.5:
		# Block character faces -Z; the Kenney glTF character faces +Z.
		_facing = atan2(velocity.x, velocity.z) + (0.0 if _gltf_mode else PI)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _facing, 0.2)
	if _gltf_mode:
		if _gltf_anim != null:
			var want := "idle"
			if not is_on_floor():
				want = "jump"
			elif hspeed > 0.5 and active:
				want = "walk"
			if _gltf_anim.has_animation(want) and _gltf_anim.current_animation != want:
				_gltf_anim.play(want)
		if not is_on_floor():
			_visual.rotation.x = -0.12
		else:
			_visual.rotation.x = 0.0
	else:
		if is_on_floor() and active and hspeed > 0.5:
			var swing := sin(_anim_t * 13.0) * 0.75
			_leg_l.rotation.x = swing
			_leg_r.rotation.x = -swing
			_arm_l.rotation.x = -swing * 0.8
			_arm_r.rotation.x = swing * 0.8
		elif not is_on_floor():
			_leg_l.rotation.x = 0.5
			_leg_r.rotation.x = -0.3
			_arm_l.rotation.x = -0.9
			_arm_r.rotation.x = -0.9
		else:
			_leg_l.rotation.x = 0.0
			_leg_r.rotation.x = 0.0
			_arm_l.rotation.x = 0.0
			_arm_r.rotation.x = 0.0
	# Squash & stretch spring back to rest.
	if absf(_squash) > 0.001:
		_squash = move_toward(_squash, 0.0, delta * 5.0)
		_visual.scale = Vector3(1.0 + _squash * 0.5, 1.0 - _squash, 1.0 + _squash * 0.5)
	else:
		_visual.scale = Vector3.ONE


func respawn() -> void:
	position = _last_checkpoint
	velocity = Vector3.ZERO
	_jumps_left = 2
	_mantle_target = null
	if autopilot:
		# Resume from the nav waypoint nearest the checkpoint we fell back to.
		var best := 0
		var best_d := 1e20
		for i in range(level.nav.size()):
			var d: float = level.nav[i]["pos"].distance_to(_last_checkpoint)
			if d < best_d:
				best_d = d
				best = i
		_nav_idx = best
	fell.emit()
	hud.add_fall()


func die() -> void:
	_dead = true
	velocity = Vector3.ZERO


## Auto-mantle: smoothly pull up onto a ledge top (called by LevelGen zones).
func start_mantle(top: Vector3) -> void:
	if _mantle_target != null or _dead:
		return
	_mantle_from = position
	_mantle_target = top
	_mantle_t = 0.0
	_buffer = 0.0
	velocity = Vector3.ZERO


func win() -> void:
	_dead = true
	velocity = Vector3.ZERO
