extends Node3D
class_name LevelGen
## Data-driven obby course builder: 16 levels (4 worlds x 4), parkour-style
## LEVELS table. A cursor walks a 4-direction path; steps place pads/hazards.
## Static terrain: one StaticBody3D + chunked ArrayMesh (vertex colors).
## Mechanics: moving platforms (AnimatableBody3D), lava (Area3D kill),
## bounce pads, vanish blocks, rotating bars (spinners), ice (low friction).
## Checkpoints: proximity + grounded only (W7 lesson: never skip forward).

const VOXEL := 1.0
const CHUNK := 16.0
const THICK := 1.0
const MOVER_SIZE := 3.0
const DIRS: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]

const THEMES := [
	{
		"name": "TOMB",
		"grass": Color(0.78, 0.66, 0.42), "dirt": Color(0.48, 0.38, 0.24),
		"stone": Color(0.62, 0.52, 0.36), "mover_col": Color(0.55, 0.42, 0.26),
		"sky_top": Color(0.05, 0.04, 0.08), "sky_horizon": Color(0.28, 0.20, 0.12),
		"sun": Color(1.0, 0.78, 0.45), "sun_rot": Vector3(-55, -25, 0),
	},
	{
		"name": "CANYON",
		"grass": Color(0.85, 0.62, 0.32), "dirt": Color(0.60, 0.38, 0.18),
		"stone": Color(0.70, 0.45, 0.28), "mover_col": Color(0.45, 0.30, 0.55),
		"sky_top": Color(0.85, 0.45, 0.25), "sky_horizon": Color(0.95, 0.72, 0.45),
		"sun": Color(1.0, 0.80, 0.55), "sun_rot": Vector3(-35, -45, 0),
	},
	{
		"name": "FROST",
		"grass": Color(0.78, 0.88, 0.98), "dirt": Color(0.45, 0.55, 0.70),
		"stone": Color(0.60, 0.70, 0.82), "mover_col": Color(0.30, 0.65, 0.80),
		"sky_top": Color(0.10, 0.14, 0.30), "sky_horizon": Color(0.35, 0.45, 0.65),
		"sun": Color(0.75, 0.85, 1.0), "sun_rot": Vector3(-60, 20, 0),
	},
	{
		"name": "VOLCANO",
		"grass": Color(0.30, 0.22, 0.24), "dirt": Color(0.16, 0.12, 0.14),
		"stone": Color(0.40, 0.28, 0.28), "mover_col": Color(0.95, 0.45, 0.10),
		"sky_top": Color(0.12, 0.04, 0.07), "sky_horizon": Color(0.65, 0.22, 0.10),
		"sun": Color(1.0, 0.60, 0.30), "sun_rot": Vector3(-40, -20, 0),
	},
]

## Steps: P=pad(w,l,dy) G=gap(d) L=lava(d) M=mover(d) B=bounce V=vanish(n)
##        S=spinner(w) I=ice(w,l) T=turn(+1 right / -1 left)
## Tomb:  C=climb ledge(h) K=spikes(d) X=sliding blade(w) F=crumble(n)
##        W=lever(door_id) A=pressure plate(door_id) D=door(id,w) R=relic(id)
## Start pad (6x6) and goal pad (6x6) are added automatically.
const LEVELS := [
	{"name": "ENTRANCE", "world": 0, "par": 45.0, "steps": [
		["G", 2.5], ["P", 4, 8], ["C", 3.5], ["P", 4, 12], ["K", 3.0], ["P", 4, 8]]},
	{"name": "BLADE HALL", "world": 0, "par": 55.0, "steps": [
		["G", 2.5], ["P", 4, 6], ["X", 6], ["G", 3.0], ["P", 4, 6],
		["F", 3], ["P", 4, 8], ["X", 6], ["G", 2.5], ["P", 4, 8]]},
	{"name": "LEVER GATE", "world": 0, "par": 55.0, "steps": [
		["G", 2.5], ["P", 4, 6], ["W", 0], ["G", 2.5], ["P", 4, 4],
		["D", 0, 6], ["G", 2.5], ["P", 4, 8], ["R", "relic1"], ["G", 3.0], ["P", 4, 8]]},
	{"name": "PRESSURE PATH", "world": 0, "par": 60.0, "steps": [
		["G", 2.5], ["P", 4, 6], ["A", 1], ["K", 3.0], ["P", 4, 6],
		["D", 1, 6], ["G", 2.5], ["P", 4, 8], ["R", "relic2"], ["G", 3.0], ["P", 4, 8]]},
	{"name": "CRUMBLE DEPTHS", "world": 0, "par": 65.0, "steps": [
		["G", 2.5], ["P", 4, 6], ["F", 3], ["X", 6], ["P", 4, 6],
		["R", "relic3"], ["G", 3.0], ["P", 4, 6], ["C", 3.5], ["P", 4, 8]]},
	{"name": "TREASURE SANCTUM", "world": 0, "par": 70.0, "treasure": true, "steps": [
		["G", 2.5], ["P", 4, 6], ["C", 3.5], ["W", 2], ["G", 2.5], ["P", 4, 4],
		["D", 2, 6], ["G", 2.5], ["P", 4, 10]]},
]

var cfg: Dictionary
var theme: Dictionary
var spawn_point := Vector3(0, 1.5, -3)
var goal_pos := Vector3.ZERO
var kill_y := -12.0
var checkpoints: Array[Vector3] = []
var nav: Array = []          # {pos, kind, ref} waypoints for the headless bot
var movers: Array = []
var spinners: Array = []
var vanish_blocks: Array = []
var blades: Array = []       # sliding kill blades {body, center, axis, amp, period, phase}
var crumbles: Array = []     # {body, col, mat, state, t}
var doors: Dictionary = {}   # id -> {body, col, mat, open}
var flags: Array = []        # {pos, mat} checkpoint flag visuals
var coin_total := 0
var time := 0.0

var _cursor := Vector3.ZERO
var _dir := 0
var _min_top := 0.0
var _boxes: Array = []
var _terrain_body: StaticBody3D

signal finished(final_time: float)
signal coin_taken(pos: Vector3)
signal relic_taken(pos: Vector3)


func _ready() -> void:
	cfg = LEVELS[clampi(Game.level_index, 0, LEVELS.size() - 1)]
	theme = THEMES[int(cfg["world"])]
	_pad(6, 6, 0, "start")
	for step in cfg["steps"]:
		_do_step(step)
	_pad(6, 6, 0, "goal")
	_build_collision()
	_build_chunk_meshes()
	_build_decorations()
	_build_light()
	kill_y = _min_top - 12.0


func _do_step(s: Array) -> void:
	match String(s[0]):
		"P": _pad(float(s[1]), float(s[2]), float(s[3]) if s.size() > 3 else 0.0, "normal")
		"I": _pad(float(s[1]), float(s[2]), 0.0, "ice")
		"G": _cursor += DIRS[_dir] * float(s[1])
		"L": _lava(float(s[1]))
		"M": _mover(float(s[1]))
		"B": _pad(3, 3, 0, "bounce")
		"V": _vanish(int(s[1]))
		"S": _spinner(float(s[1]))
		"T": _dir = (_dir + int(s[1]) + 4) % 4
		"C": _climb(float(s[1]))
		"K": _spikes(float(s[1]))
		"X": _blade(float(s[1]))
		"F": _crumble(int(s[1]))
		"W": _lever(int(s[1]))
		"A": _plate(int(s[1]))
		"D": _door(int(s[1]), float(s[2]))
		"R": _relic(String(s[1]))


func _pad(w: float, l: float, dy: float, kind: String) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var top := _cursor.y + dy
	var center := Vector3(_cursor.x, top - THICK / 2.0, _cursor.z) + dir * (l / 2.0)
	var size := Vector3(
		absf(right.x) * w + absf(dir.x) * l, THICK,
		absf(right.z) * w + absf(dir.z) * l)
	_min_top = minf(_min_top, top)
	if kind == "ice" or kind == "bounce":
		_build_special_pad(center, size, kind)
	else:
		_boxes.append({"min": center - size / 2.0, "size": size, "gold": kind == "goal"})
	if kind == "start":
		spawn_point = center + Vector3(0, THICK / 2.0 + 1.5, 0)
		checkpoints.append(spawn_point)
		_build_flag(spawn_point)
	elif kind == "goal":
		goal_pos = center + Vector3(0, THICK / 2.0 + 1.5, 0)
		_build_finish_gate(center + Vector3(0, THICK / 2.0, 0))
	elif l >= 5.0:
		var cp := _cursor + dir * 1.5 + Vector3(0, dy + 1.5, 0)
		if checkpoints.is_empty() or cp.distance_to(checkpoints.back()) > 5.0:
			checkpoints.append(cp)
			_build_flag(cp)
			# Nav waypoint AT the checkpoint so respawn resumes forward (nearest
			# nav search would otherwise pick a waypoint before the checkpoint).
			nav.append({"pos": cp, "kind": "normal", "ref": null})
	nav.append({"pos": _cursor + dir * (l / 2.0) + Vector3(0, dy + 0.6, 0), "kind": kind, "ref": null})
	# Coins sit mid-pad (away from the jump takeoff zone at the far edge) so
	# they are collectible on foot; short/bounce pads get none.
	if kind != "start" and kind != "goal" and kind != "bounce":
		if l >= 8.0:
			_spawn_coin(self, _cursor + dir * (l * 0.3) + Vector3(0, dy + 0.9, 0))
			_spawn_coin(self, _cursor + dir * (l * 0.6) + Vector3(0, dy + 0.9, 0))
		elif l >= 6.0:
			_spawn_coin(self, _cursor + dir * (l * 0.6) + Vector3(0, dy + 0.9, 0))
	_cursor += dir * l
	_cursor.y = top


func _lava(d: float) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var center := _cursor + dir * (d / 2.0) + Vector3(0, -1.0, 0)
	var size := Vector3(
		absf(right.x) * 10.0 + absf(dir.x) * d, 0.5,
		absf(right.z) * 10.0 + absf(dir.z) * d)
	var area := Area3D.new()
	area.name = "Lava"
	area.add_to_group("lava")
	area.position = center
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	area.add_child(col)
	area.body_entered.connect(_on_lava_entered)
	add_child(area)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = center
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.30, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.25, 0.02)
	mat.emission_energy_multiplier = 1.4
	mat.roughness = 0.6
	mi.material_override = mat
	add_child(mi)
	_cursor += dir * d


func _on_lava_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("respawn"):
		body.respawn()


func _mover(d: float) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var center := _cursor + dir * (d / 2.0)
	var body := AnimatableBody3D.new()
	body.name = "Mover_%d" % movers.size()
	body.sync_to_physics = true
	body.position = center + Vector3(0, -THICK / 2.0, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(MOVER_SIZE, THICK, MOVER_SIZE)
	col.shape = sh
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(MOVER_SIZE, THICK, MOVER_SIZE)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = theme["mover_col"]
	mat.roughness = 0.7
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)
	movers.append({"body": body, "center": center, "axis": right,
		"amp": 2.5, "period": 3.5, "phase": float(movers.size()) * 1.3})
	nav.append({"pos": center + Vector3(0, 0.6, 0), "kind": "mover", "ref": body})
	_spawn_coin(body, Vector3(0, THICK / 2.0 + 1.0, 0))
	_cursor += dir * d


func _vanish(n: float) -> void:
	var dir := DIRS[_dir]
	for i in range(int(n)):
		var c := _cursor + dir * (1.2 + 2.2 * i)
		var body := StaticBody3D.new()
		body.name = "Vanish_%d" % vanish_blocks.size()
		body.position = c + Vector3(0, -0.25, 0)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(2, 0.5, 2)
		col.shape = sh
		body.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2, 0.5, 2)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.55, 0.95)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.5
		mi.material_override = mat
		body.add_child(mi)
		add_child(body)
		var v := {"body": body, "col": col, "mat": mat,
			"period": 3.2, "solid": 2.0, "phase": -float(i) * 0.35, "is_solid": true}
		vanish_blocks.append(v)
		nav.append({"pos": c + Vector3(0, 0.6, 0), "kind": "vanish", "ref": v})
	_cursor += dir * (1.2 + 2.2 * (n - 1) + 1.2)


func _spinner(w: float) -> void:
	var dir := DIRS[_dir]
	var center := _cursor + dir * (w / 2.0)
	_pad(w, w, 0, "normal")
	var body := AnimatableBody3D.new()
	body.name = "Spinner_%d" % spinners.size()
	body.sync_to_physics = true
	body.position = center + Vector3(0, 0.55, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w - 1.5, 0.5, 0.5)
	col.shape = sh
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w - 1.5, 0.5, 0.5)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.25, 0.25)
	mat.roughness = 0.6
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)
	spinners.append({"body": body, "speed": 1.3})
	# Visual-only center pole (no collision: it would block the path).
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 0.15
	cm.height = 1.4
	pole.mesh = cm
	pole.position = center + Vector3(0, 0.7, 0)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = theme["stone"]
	pole.material_override = pm
	add_child(pole)


## --- Tomb mechanics -------------------------------------------------------

## Climbable ledge: a tall wall with an auto-mantle grab zone at its face.
func _climb(h: float) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var depth := 2.0
	var w := 4.0
	var base_y := _cursor.y
	var center := _cursor + dir * (depth / 2.0)
	var size := Vector3(
		absf(right.x) * w + absf(dir.x) * depth, h,
		absf(right.z) * w + absf(dir.z) * depth)
	var box_center := Vector3(center.x, base_y + h / 2.0, center.z)
	_boxes.append({"min": box_center - size / 2.0, "size": size, "gold": false})
	var top_y := base_y + h
	var zone := Area3D.new()
	zone.name = "Ledge_%d" % _special_count()
	zone.position = _cursor + dir * (-0.6) + Vector3(0, base_y + h / 2.0, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(absf(right.x) * w + absf(dir.x) * 2.0, h + 1.5, absf(right.z) * w + absf(dir.z) * 2.0)
	col.shape = sh
	zone.add_child(col)
	var mantle_top := _cursor + dir * (depth * 0.6) + Vector3(0, top_y + 0.75, 0)
	zone.body_entered.connect(_on_ledge_entered.bind(mantle_top))
	add_child(zone)
	# Single nav target at the ledge TOP: the grab zone auto-mantles the player
	# as it approaches, so the bot must aim high (a base waypoint would sit far
	# below the landing and never advance, walking the bot back off the wall).
	nav.append({"pos": _cursor + dir * 1.0 + Vector3(0, top_y + 0.6, 0), "kind": "normal", "ref": null})
	_min_top = minf(_min_top, base_y)
	_cursor += dir * depth
	_cursor.y = top_y


func _on_ledge_entered(body: Node3D, mantle_top: Vector3) -> void:
	if body.is_in_group("player") and body.has_method("start_mantle"):
		body.start_mantle(mantle_top)


## Spike pit: kill zone (respawn) with metal spike cones. Jump over it.
func _spikes(d: float) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var center := _cursor + dir * (d / 2.0) + Vector3(0, -0.6, 0)
	var size := Vector3(
		absf(right.x) * 10.0 + absf(dir.x) * d, 0.6,
		absf(right.z) * 10.0 + absf(dir.z) * d)
	var area := Area3D.new()
	area.name = "Spikes"
	area.add_to_group("lava")
	area.position = center
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	area.add_child(col)
	area.body_entered.connect(_on_lava_entered)
	add_child(area)
	var n := maxi(1, int(d / 0.8))
	for i in range(n):
		for j in range(3):
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.22
			cm.height = 0.7
			mi.mesh = cm
			mi.position = _cursor + dir * (0.4 + 0.8 * i) + right * ((float(j) - 1.0) * 1.2) + Vector3(0, -0.25, 0)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.7, 0.72, 0.75)
			mat.metallic = 0.5
			mat.roughness = 0.4
			mi.material_override = mat
			add_child(mi)
	_cursor += dir * d


## Sliding blade: a kill wall sweeping side-to-side across a pad. The bot
## waits at the near edge until the blade is displaced (blade_safe).
func _blade(w: float) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var center := _cursor + dir * (w / 2.0)
	var psize := Vector3(
		absf(right.x) * w + absf(dir.x) * w, THICK,
		absf(right.z) * w + absf(dir.z) * w)
	_boxes.append({"min": center + Vector3(0, -THICK / 2.0, 0) - psize / 2.0, "size": psize, "gold": false})
	var body := AnimatableBody3D.new()
	body.name = "Blade_%d" % blades.size()
	body.sync_to_physics = true
	body.position = center + Vector3(0, 1.5, 0)
	var bsize := Vector3(
		absf(right.x) * 0.4 + absf(dir.x) * 1.6, 3.0,
		absf(right.z) * 0.4 + absf(dir.z) * 1.6)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = bsize
	col.shape = sh
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bsize
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.78, 0.82)
	mat.metallic = 0.7
	mat.roughness = 0.3
	mi.material_override = mat
	body.add_child(mi)
	var area := Area3D.new()
	area.add_to_group("lava")
	var acol := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = bsize + Vector3(0.3, 0, 0.3)
	acol.shape = ash
	area.add_child(acol)
	area.body_entered.connect(_on_lava_entered)
	body.add_child(area)
	add_child(body)
	var b := {"body": body, "center": center, "axis": right,
		"amp": w * 0.5, "period": 5.0, "phase": float(blades.size()) * 1.7}
	blades.append(b)
	nav.append({"pos": _cursor + dir * 0.6 + Vector3(0, 0.6, 0), "kind": "blade", "ref": b})
	_cursor += dir * w


func blade_safe(b: Dictionary) -> bool:
	var s := sin(TAU * time / float(b["period"]) + float(b["phase"]))
	return absf(s) > 0.45


## Crumbling floor: collapses 0.7s after being stepped on, respawns after 3s.
func _crumble(n: int) -> void:
	var dir := DIRS[_dir]
	for i in range(n):
		var c := _cursor + dir * (1.2 + 2.2 * i)
		var body := StaticBody3D.new()
		body.name = "Crumble_%d" % crumbles.size()
		body.position = c + Vector3(0, -0.25, 0)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(2, 0.5, 2)
		col.shape = sh
		body.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2, 0.5, 2)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.5, 0.35)
		mat.roughness = 0.9
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		body.add_child(mi)
		add_child(body)
		var area := Area3D.new()
		area.position = c + Vector3(0, 0.4, 0)
		var acol := CollisionShape3D.new()
		var ash := BoxShape3D.new()
		ash.size = Vector3(2, 1.0, 2)
		acol.shape = ash
		area.add_child(acol)
		var cr := {"body": body, "col": col, "mat": mat, "state": "solid", "t": 0.0}
		area.body_entered.connect(_on_crumble_entered.bind(cr))
		add_child(area)
		crumbles.append(cr)
		nav.append({"pos": c + Vector3(0, 0.6, 0), "kind": "crumble", "ref": cr})
	_cursor += dir * (1.2 + 2.2 * (n - 1) + 1.2)


func _on_crumble_entered(body: Node3D, cr: Dictionary) -> void:
	if body.is_in_group("player") and cr["state"] == "solid":
		cr["state"] = "warning"
		cr["t"] = 0.0


## Lever: proximity-activated switch that opens a linked gate (latched).
func _lever(id: int) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var center := _cursor + dir * 1.0
	var psize := Vector3(absf(right.x) * 4 + absf(dir.x) * 3, THICK, absf(right.z) * 4 + absf(dir.z) * 3)
	var pc := _cursor + dir * 1.5
	_boxes.append({"min": pc + Vector3(0, -THICK / 2.0, 0) - psize / 2.0, "size": psize, "gold": false})
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.4, 0.6)
	base.mesh = bm
	base.position = center + Vector3(0, 0.2, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = theme["stone"]
	base.material_override = bmat
	add_child(base)
	var stick := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.15, 1.0, 0.15)
	stick.mesh = sm
	stick.position = center + Vector3(0, 0.9, 0)
	stick.rotation_degrees = Vector3(0, 0, -30)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.8, 0.3, 0.2)
	stick.material_override = smat
	add_child(stick)
	var area := Area3D.new()
	area.position = center + Vector3(0, 0.8, 0)
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.4
	col.shape = sh
	area.add_child(col)
	area.body_entered.connect(_on_lever_entered.bind(id, stick))
	add_child(area)
	nav.append({"pos": center + Vector3(0, 0.6, 0), "kind": "lever", "ref": null})
	_cursor += dir * 2.0


func _on_lever_entered(body: Node3D, id: int, stick: MeshInstance3D) -> void:
	if body.is_in_group("player"):
		stick.rotation_degrees.z = 30
		open_door(id)


## Pressure plate: stepping on it opens a linked gate (latched).
func _plate(id: int) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var center := _cursor + dir * 1.0
	var psize := Vector3(absf(right.x) * 4 + absf(dir.x) * 3, THICK, absf(right.z) * 4 + absf(dir.z) * 3)
	var pc := _cursor + dir * 1.5
	_boxes.append({"min": pc + Vector3(0, -THICK / 2.0, 0) - psize / 2.0, "size": psize, "gold": false})
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 0.15, 2.0)
	mi.mesh = bm
	mi.position = center + Vector3(0, 0.08, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.6, 0.7)
	mat.metallic = 0.4
	mi.material_override = mat
	add_child(mi)
	var area := Area3D.new()
	area.position = center + Vector3(0, 0.5, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.0, 1.0, 2.0)
	col.shape = sh
	area.add_child(col)
	area.body_entered.connect(_on_plate_entered.bind(id, mat))
	add_child(area)
	nav.append({"pos": center + Vector3(0, 0.6, 0), "kind": "plate", "ref": null})
	_cursor += dir * 2.0


func _on_plate_entered(body: Node3D, id: int, mat: StandardMaterial3D) -> void:
	if body.is_in_group("player"):
		mat.albedo_color = Color(0.3, 0.8, 0.4)
		open_door(id)


## Gate: a blocking wall opened by a linked lever/plate.
func _door(id: int, w: float) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var center := _cursor + dir * (w / 2.0)
	var psize := Vector3(
		absf(right.x) * w + absf(dir.x) * w, THICK,
		absf(right.z) * w + absf(dir.z) * w)
	_boxes.append({"min": center + Vector3(0, -THICK / 2.0, 0) - psize / 2.0, "size": psize, "gold": false})
	var body := StaticBody3D.new()
	body.name = "Door_%d" % id
	body.position = center + Vector3(0, 1.5, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(absf(right.x) * w + absf(dir.x) * 0.5, 3.0, absf(right.z) * w + absf(dir.z) * 0.5)
	col.shape = sh
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sh.size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.3)
	mat.roughness = 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)
	doors[id] = {"body": body, "col": col, "mat": mat, "open": false}
	nav.append({"pos": center + Vector3(0, 0.6, 0), "kind": "door", "ref": null})
	_cursor += dir * w


func open_door(id: int) -> void:
	if not doors.has(id):
		return
	var d: Dictionary = doors[id]
	if d["open"]:
		return
	d["open"] = true
	d["col"].set_deferred("disabled", true)
	d["mat"].albedo_color.a = 0.25
	var hud := get_node_or_null("../HUD")
	if hud != null and hud.has_method("toast"):
		hud.toast("GATE OPENED!")


## Relic: a golden idol collectible; 3 across the tomb unlock the treasure.
func _relic(id: String) -> void:
	var dir := DIRS[_dir]
	var right := DIRS[(_dir + 1) % 4]
	var center := _cursor + dir * 1.0
	var psize := Vector3(absf(right.x) * 4 + absf(dir.x) * 3, THICK, absf(right.z) * 4 + absf(dir.z) * 3)
	var pc := _cursor + dir * 1.5
	_boxes.append({"min": pc + Vector3(0, -THICK / 2.0, 0) - psize / 2.0, "size": psize, "gold": false})
	var area := Area3D.new()
	area.name = "Relic_%s" % id
	area.position = center + Vector3(0, 1.0, 0)
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.9
	col.shape = sh
	area.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.7, 0.5)
	mi.mesh = bm
	mi.rotation_degrees = Vector3(0, 45, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.5, 0.1)
	mat.metallic = 0.7
	mat.roughness = 0.3
	mi.material_override = mat
	area.add_child(mi)
	area.body_entered.connect(_on_relic_entered.bind(id, area))
	add_child(area)
	nav.append({"pos": center + Vector3(0, 0.6, 0), "kind": "relic", "ref": null})
	_cursor += dir * 2.0


func _on_relic_entered(body: Node3D, id: String, area: Area3D) -> void:
	if body.is_in_group("player"):
		Game.add_relic(id)
		relic_taken.emit(area.global_position)
		area.queue_free()


func _build_special_pad(center: Vector3, size: Vector3, kind: String) -> void:
	var body := StaticBody3D.new()
	body.name = "%s_%d" % [kind.capitalize(), _special_count()]
	body.add_to_group(kind)
	body.position = center
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	if kind == "ice":
		mat.albedo_color = Color(0.65, 0.85, 0.98)
		mat.roughness = 0.12
		mat.metallic = 0.15
	else:
		mat.albedo_color = Color(1.0, 0.75, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.32, 0.02)
		mat.roughness = 0.5
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


var _special_n := 0
func _special_count() -> int:
	_special_n += 1
	return _special_n


func _build_flag(cp: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 1.7, 0.12)
	pole.mesh = bm
	pole.position = cp + Vector3(0, -0.65, 0)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.85, 0.9)
	pole.material_override = pm
	add_child(pole)
	var flag := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.75, 0.45, 0.08)
	flag.mesh = fm
	flag.position = cp + Vector3(0.42, 0.55, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.25, 0.25)
	flag.material_override = mat
	add_child(flag)
	flags.append({"pos": cp, "mat": mat})


func activate_flag(cp: Vector3) -> void:
	for f in flags:
		if f["pos"].distance_to(cp) < 0.1:
			f["mat"].albedo_color = Color(0.25, 0.9, 0.35)
			return


func _build_collision() -> void:
	_terrain_body = StaticBody3D.new()
	_terrain_body.name = "TerrainBody"
	add_child(_terrain_body)
	for b in _boxes:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b["size"]
		col.shape = shape
		col.position = b["min"] + b["size"] / 2.0
		_terrain_body.add_child(col)


func _build_chunk_meshes() -> void:
	var chunk_quads := {}
	for b in _boxes:
		var mn: Vector3 = b["min"]
		var sz: Vector3 = b["size"]
		var gold: bool = b["gold"]
		var nx := int(sz.x / VOXEL)
		var nz := int(sz.z / VOXEL)
		for ix in range(nx):
			for iz in range(nz):
				var x0 := mn.x + ix * VOXEL
				var z0 := mn.z + iz * VOXEL
				var key := _chunk_key(x0, z0)
				if not chunk_quads.has(key):
					chunk_quads[key] = []
				(chunk_quads[key] as Array).append({"x0": x0, "z0": z0, "gold": gold, "y": mn.y + sz.y})
		var key0 := _chunk_key(mn.x, mn.z)
		if not chunk_quads.has(key0):
			chunk_quads[key0] = []
		(chunk_quads[key0] as Array).append({"side": true, "box_min": mn, "box_size": sz, "gold": gold})
	for key in chunk_quads:
		_build_single_mesh(key, chunk_quads[key])


func _chunk_key(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / CHUNK)), int(floor(z / CHUNK)))


func _build_single_mesh(key: Vector2i, quads: Array) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for q in quads:
		if q.has("side"):
			_emit_sides(verts, normals, colors, q["box_min"], q["box_size"], q["gold"])
		else:
			_emit_top(verts, normals, colors, q["x0"], q["z0"], q["gold"], q["y"])
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Chunk_%d_%d" % [key.x, key.y]
	mi.mesh = mesh
	add_child(mi)


func _emit_top(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, x0: float, z0: float, gold: bool, y: float) -> void:
	var c: Color = Color(1.0, 0.8, 0.2) if gold else theme["grass"]
	var a := Vector3(x0, y, z0)
	var b := Vector3(x0 + VOXEL, y, z0)
	var cc := Vector3(x0 + VOXEL, y, z0 + VOXEL)
	var d := Vector3(x0, y, z0 + VOXEL)
	var n := Vector3.UP
	verts.append_array([a, b, cc, a, cc, d])
	for i in range(6):
		normals.append(n)
		colors.append(c)


func _emit_sides(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, mn: Vector3, sz: Vector3, gold: bool) -> void:
	var c: Color = Color(1.0, 0.8, 0.2) if gold else theme["dirt"]
	var y0 := mn.y
	var y1 := mn.y + sz.y
	var x0 := mn.x
	var x1 := mn.x + sz.x
	var z0 := mn.z
	var z1 := mn.z + sz.z
	_quads(verts, normals, colors, [Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1)], Vector3.LEFT, c)
	_quads(verts, normals, colors, [Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], Vector3.RIGHT, c)
	_quads(verts, normals, colors, [Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1)], Vector3.BACK, c)
	_quads(verts, normals, colors, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], Vector3.FORWARD, c)


func _quads(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, corners: Array, n: Vector3, c: Color) -> void:
	verts.append_array([corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]])
	for i in range(6):
		normals.append(n)
		colors.append(c)


func _spawn_coin(parent: Node3D, lpos: Vector3) -> void:
	var coin := Area3D.new()
	coin.set_script(load("res://Coin.gd"))
	coin.position = lpos
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.55
	col.shape = sh
	coin.add_child(col)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.35
	cm.height = 0.08
	cm.radial_segments = 16
	mi.mesh = cm
	mi.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.42, 0.05)
	mat.metallic = 0.6
	mat.roughness = 0.3
	mi.material_override = mat
	coin.add_child(mi)
	coin.collected.connect(_on_coin_collected)
	parent.add_child(coin)
	coin_total += 1


func _on_coin_collected(pos: Vector3) -> void:
	coin_taken.emit(pos)


func _build_finish_gate(pad_top_center: Vector3) -> void:
	var area := Area3D.new()
	area.name = "GoalArea"
	area.position = pad_top_center + Vector3(0, 1.5, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 3, 6)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(_on_goal_entered)
	add_child(area)
	for px in [-2.8, 2.8]:
		var pillar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 4.0, 0.6)
		pillar.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.3, 0.05)
		pillar.material_override = mat
		pillar.position = pad_top_center + Vector3(px, 2.0, 0)
		add_child(pillar)


## Kenney Starter Kit decorations (CC0): grass tufts on pads, clouds above.
## Visual only -- no collision, physics stays on the proven voxel terrain.
func _build_decorations() -> void:
	if theme["name"] == "TOMB":
		_build_torches()
		return
	var cloud_scene: PackedScene = null
	var grass_scene: PackedScene = null
	if ResourceLoader.exists("res://assets/cloud.glb"):
		cloud_scene = load("res://assets/cloud.glb")
	if ResourceLoader.exists("res://assets/grass.glb"):
		grass_scene = load("res://assets/grass.glb")
	for i in range(nav.size()):
		var p: Vector3 = nav[i]["pos"]
		if grass_scene != null and i % 2 == 0:
			var g := grass_scene.instantiate()
			g.position = p + Vector3(1.6, -0.6, 0.0)
			g.rotation.y = float(i) * 1.7
			var gs := 0.8 + 0.3 * absf(sin(float(i)))
			g.scale = Vector3(gs, gs, gs)
			add_child(g)
		if cloud_scene != null and i % 3 == 0:
			var c := cloud_scene.instantiate()
			c.position = p + Vector3(6.0 * sin(float(i) * 2.1), 11.0 + 2.0 * sin(float(i)), 6.0 * cos(float(i) * 1.3))
			var cs := 1.5 + 0.5 * absf(sin(float(i) * 0.7))
			c.scale = Vector3(cs, cs, cs)
			add_child(c)


## Tomb torches: emissive flame posts along the path (visual only).
func _build_torches() -> void:
	for i in range(nav.size()):
		if i % 2 != 0:
			continue
		var p: Vector3 = nav[i]["pos"]
		var pole := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.15, 1.4, 0.15)
		pole.mesh = bm
		pole.position = p + Vector3(1.8, 0.1, 0.0)
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.3, 0.22, 0.15)
		pole.material_override = pm
		add_child(pole)
		var flame := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.3, 0.4, 0.3)
		flame.mesh = fm
		flame.position = p + Vector3(1.8, 0.95, 0.0)
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(1.0, 0.6, 0.2)
		fmat.emission_enabled = true
		fmat.emission = Color(1.0, 0.5, 0.1)
		fmat.emission_energy_multiplier = 2.0
		flame.material_override = fmat
		add_child(flame)


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = theme["sun_rot"]
	sun.light_color = theme["sun"]
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.name = "Env"
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = theme["sky_top"]
	sky_mat.ground_horizon_color = theme["sky_horizon"]
	sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.28)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9 if theme["name"] == "TOMB" else 0.6
	e.fog_enabled = true
	e.fog_light_color = theme["sky_horizon"]
	e.fog_density = 0.005
	env.environment = e
	add_child(env)


func _physics_process(delta: float) -> void:
	time += delta
	for m in movers:
		var off: float = m["amp"] * sin(TAU * time / m["period"] + m["phase"])
		m["body"].position = m["center"] + m["axis"] * off + Vector3(0, -THICK / 2.0, 0)
	for s in spinners:
		s["body"].rotation.y += s["speed"] * delta
	for v in vanish_blocks:
		var t := fmod(time + float(v["phase"]), float(v["period"]))
		var solid: bool = t < float(v["solid"])
		if solid != v["is_solid"]:
			v["is_solid"] = solid
			v["col"].set_deferred("disabled", not solid)
		var a := 0.15
		if solid:
			a = 0.55 if t > float(v["solid"]) - 0.4 else 1.0
		v["mat"].albedo_color.a = a
	for b in blades:
		var boff: float = b["amp"] * sin(TAU * time / float(b["period"]) + float(b["phase"]))
		b["body"].position = b["center"] + b["axis"] * boff + Vector3(0, 1.5, 0)
	for cr in crumbles:
		if cr["state"] == "warning":
			cr["t"] += delta
			cr["mat"].albedo_color = Color(0.85, 0.45, 0.2)
			if cr["t"] > 0.7:
				cr["state"] = "gone"
				cr["t"] = 0.0
				cr["col"].set_deferred("disabled", true)
				cr["mat"].albedo_color.a = 0.15
		elif cr["state"] == "gone":
			cr["t"] += delta
			if cr["t"] > 3.0:
				cr["state"] = "solid"
				cr["col"].set_deferred("disabled", false)
				cr["mat"].albedo_color = Color(0.6, 0.5, 0.35)
				cr["mat"].albedo_color.a = 1.0


func _on_goal_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if cfg.get("treasure", false) and Game.relic_count() < Game.RELICS_NEEDED:
			var hud := get_node_or_null("../HUD")
			if hud != null and hud.has_method("toast"):
				hud.toast("NEED %d RELICS!" % Game.RELICS_NEEDED)
			return
		finished.emit(_race_time())


func _race_time() -> float:
	var hud := get_node_or_null("../HUD")
	if hud != null and hud.has_method("get_time"):
		return hud.get_time()
	return 0.0


## Checkpoint activation: only when the player is grounded near it (W7 fix:
## respawn must go to the last checkpoint actually reached, never forward).
func checkpoint_at(pos: Vector3) -> Variant:
	for c in checkpoints:
		if absf(c.y - pos.y) < 3.0 and Vector2(c.x - pos.x, c.z - pos.z).length() < 2.5:
			return c
	return null


## Vanish block solid state + remaining solid time (headless bot timing).
func vanish_solid(v: Dictionary) -> bool:
	return v["is_solid"]


func vanish_remaining(v: Dictionary) -> float:
	var t := fmod(time + float(v["phase"]), float(v["period"]))
	return maxf(0.0, float(v["solid"]) - t) if t < float(v["solid"]) else 0.0
