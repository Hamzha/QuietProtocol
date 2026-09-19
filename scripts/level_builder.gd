extends Node3D
## Vast multi-floor embassy — L1 Lobby → L2 Offices (office-plan inspired) → L3 Archive

const FURN := "res://assets/env/furniture/"
const FLOOR_H := 4.5
const FLOORS := 3
## Vast floorplate (was ~22×22). Now ~56×40m.
const HALF_X := 28.0
const HALF_Z := 20.0
const FURNITURE_SCALE := 2.25
const DESK_TOP := 0.384 * FURNITURE_SCALE

var _wall := Color(0.9, 0.9, 0.88)
var _carpet := Color(0.42, 0.43, 0.45)
var _tile := Color(0.78, 0.78, 0.76)
var _trim := Color(0.55, 0.52, 0.48)


func _ready() -> void:
	_build_level()


func _build_level() -> void:
	_setup_atmosphere()
	_build_tower_shell()
	_build_core_stairs_and_lifts()
	_dress_lobby()
	_dress_offices_vast()
	_dress_archive()
	_place_gameplay()
	Mission.reset_run()


func _setup_atmosphere() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.03, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.42)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_bloom = 0.25
	environment.ssao_enabled = true
	env.environment = environment
	add_child(env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-40, 155, 0)
	moon.light_color = Color(0.45, 0.55, 0.85)
	moon.light_energy = 0.2
	moon.shadow_enabled = true
	add_child(moon)


func _build_tower_shell() -> void:
	var total_h := FLOOR_H * FLOORS
	var wx := HALF_X * 2
	var wz := HALF_Z * 2

	# Exterior
	_box(Vector3(0, total_h * 0.5, -HALF_Z - 0.25), Vector3(wx + 1.0, total_h, 0.5), _wall)
	_box(Vector3(0, total_h * 0.5, HALF_Z + 0.25), Vector3(wx + 1.0, total_h, 0.5), _wall)
	_box(Vector3(-HALF_X - 0.25, total_h * 0.5, 0), Vector3(0.5, total_h, wz + 1.0), _wall)
	_box(Vector3(HALF_X + 0.25, total_h * 0.5, 0), Vector3(0.5, total_h, wz + 1.0), _wall)
	_box(Vector3(0, total_h + 0.2, 0), Vector3(wx + 1.5, 0.4, wz + 1.5), Color(0.14, 0.15, 0.17))

	var floor_cols := [
		Color(0.5, 0.45, 0.38),
		_carpet,
		Color(0.18, 0.19, 0.22),
	]
	for i in FLOORS:
		var y := i * FLOOR_H
		_floor(Vector3(0, y - 0.1, 0), Vector3(wx, 0.2, wz), floor_cols[i])
		if i < FLOORS - 1:
			_box(Vector3(0, y + FLOOR_H - 0.15, 0), Vector3(wx - 0.6, 0.25, wz - 0.6), Color(0.88, 0.88, 0.86), false)

	# Window bands
	for i in FLOORS:
		var cy := i * FLOOR_H + 1.9
		var x := -HALF_X + 4.0
		while x < HALF_X - 3.0:
			_window(Vector3(x, cy, -HALF_Z - 0.08))
			_window(Vector3(x, cy, HALF_Z + 0.08))
			x += 7.0
		var z := -HALF_Z + 4.0
		while z < HALF_Z - 3.0:
			_window_side(Vector3(-HALF_X - 0.08, cy, z))
			_window_side(Vector3(HALF_X + 0.08, cy, z))
			z += 7.0

	# Structural columns grid
	for xi in [-18.0, -6.0, 6.0, 18.0]:
		for zi in [-12.0, 0.0, 12.0]:
			_box(Vector3(xi, total_h * 0.5, zi), Vector3(0.8, total_h, 0.8), _trim)

	_plaque(Vector3(0, 2.5, HALF_Z - 0.6), "L1  LOBBY", Color(0.95, 0.85, 0.45))
	_plaque(Vector3(0, FLOOR_H + 2.5, HALF_Z - 0.6), "L2  OFFICES", Color(0.7, 0.9, 1.0))
	_plaque(Vector3(0, FLOOR_H * 2 + 2.5, HALF_Z - 0.6), "L3  ARCHIVE / EXTRACT", Color(1.0, 0.55, 0.4))


func _build_core_stairs_and_lifts() -> void:
	# Central core like the reference plan (stairs center)
	var wall_c := Color(0.62, 0.6, 0.58)
	for i in FLOORS:
		var y0 := i * FLOOR_H
		# Stair shaft box with openings on +X and -X
		_box(Vector3(0, y0 + FLOOR_H * 0.5, -4.2), Vector3(7.5, FLOOR_H, 0.3), wall_c)
		_box(Vector3(0, y0 + FLOOR_H * 0.5, 4.2), Vector3(7.5, FLOOR_H, 0.3), wall_c)
		_box(Vector3(-3.8, y0 + 3.1, 0), Vector3(0.3, FLOOR_H - 2.0, 8.0), wall_c)
		_box(Vector3(3.8, y0 + 3.1, 0), Vector3(0.3, FLOOR_H - 2.0, 8.0), wall_c)
		_plaque(Vector3(-4.2, y0 + 2.2, 0), "STAIRS", Color(0.95, 0.9, 0.7))

	for i in FLOORS - 1:
		_build_switchback(0.0, i * FLOOR_H)

	# Lift bank east of stairs
	var ex := 7.5
	var total_h := FLOOR_H * FLOORS
	var shaft := Color(0.32, 0.34, 0.38)
	_box(Vector3(ex + 1.6, total_h * 0.5, 0), Vector3(0.3, total_h, 7.0), shaft)
	_box(Vector3(ex - 0.2, total_h * 0.5, -3.3), Vector3(3.2, total_h, 0.3), shaft)
	_box(Vector3(ex - 0.2, total_h * 0.5, 3.3), Vector3(3.2, total_h, 0.3), shaft)
	for i in FLOORS:
		var y0 := i * FLOOR_H
		_box(Vector3(ex - 1.5, y0 + 3.25, 0), Vector3(0.25, FLOOR_H - 2.5, 6.2), shaft)
		_plaque(Vector3(ex - 2.0, y0 + 2.3, 0), "LIFTS", Color(0.85, 0.95, 1.0))

	var heights := PackedFloat32Array()
	for i in FLOORS:
		heights.append(float(i) * FLOOR_H)

	var elev_script: Script = load("res://scripts/elevator.gd") as Script
	for idx in 2:
		var elev: Node3D = Node3D.new()
		elev.set_script(elev_script)
		elev.name = "Elevator_%d" % (idx + 1)
		var z_off := -1.4 if idx == 0 else 1.4
		elev.position = Vector3(ex - 0.1, 0, z_off)
		add_child(elev)
		elev.call("setup", heights, 0)
		for f in FLOORS:
			_make_call_button(elev, f, Vector3(ex - 2.4, f * FLOOR_H + 1.35, z_off))


func _build_switchback(shaft_x: float, y0: float) -> void:
	var step_h := 0.28
	var step_d := 0.4
	var step_w := 2.6
	var steps := int((FLOOR_H * 0.5) / step_h)
	var col := Color(0.5, 0.5, 0.52)
	var y := y0
	var z := -3.2
	for s in steps:
		_box(Vector3(shaft_x - 1.4, y + step_h * 0.5, z), Vector3(step_w, step_h, step_d), col)
		z += step_d * 0.9
		y += step_h
	_box(Vector3(shaft_x, y + 0.08, 0), Vector3(5.5, 0.16, 1.5), col)
	z = 0.6
	for s in steps:
		_box(Vector3(shaft_x + 1.4, y + step_h * 0.5, z), Vector3(step_w, step_h, step_d), col)
		z += step_d * 0.9
		y += step_h
	_box(Vector3(shaft_x, y0 + FLOOR_H + 0.08, 3.0), Vector3(5.5, 0.16, 1.2), col)


func _make_call_button(elev: Node3D, floor_index: int, pos: Vector3) -> void:
	var btn := Area3D.new()
	btn.add_to_group("interactable")
	btn.collision_layer = 8
	btn.collision_mask = 2
	btn.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.7, 0.35)
	shape.shape = box
	btn.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.5, 0.1)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.25)
	mat.emission_energy_multiplier = 0.85
	mesh.material_override = mat
	btn.add_child(mesh)
	var label := Label3D.new()
	label.text = "▲ %d" % (floor_index + 1)
	label.position = Vector3(-0.25, 0.45, 0)
	label.font_size = 28
	label.modulate = Color(1.0, 0.9, 0.45)
	btn.add_child(label)
	btn.set_meta("elevator", elev)
	btn.set_meta("call_floor", floor_index)
	add_child(btn)


# ---------- L1 Lobby ----------

func _dress_lobby() -> void:
	_ceiling_light_grid(0.0, 8.0, 8.0, Color(1.0, 0.95, 0.85), 0.7)
	_prop("desk.glb", Vector3(-12, 0, 8), Vector3(0, 0, 0), 1.0)
	_prop("loungeSofaLong.glb", Vector3(-18, 0, 10), Vector3(0, 90, 0), 1.0)
	_prop("loungeSofaLong.glb", Vector3(-10, 0, 12), Vector3(0, 180, 0), 1.0)
	_prop("tableCoffee.glb", Vector3(-14, 0, 10), Vector3(0, 0, 0), 1.0)
	_prop("pottedPlant.glb", Vector3(-22, 0, -14), Vector3(0, 0, 0), 1.2)
	_prop("pottedPlant.glb", Vector3(22, 0, -14), Vector3(0, 0, 0), 1.2)
	_prop("pottedPlant.glb", Vector3(-22, 0, 14), Vector3(0, 0, 0), 1.2)
	_prop("lampRoundFloor.glb", Vector3(-16, 0, 8), Vector3(0, 0, 0), 1.0, false)
	_omni(Vector3(-16, 1.7, 8), Color(1.0, 0.85, 0.55), 0.55, 7.0)
	_plaque(Vector3(-14, 2.4, HALF_Z - 0.7), "RECEPTION", Color(0.95, 0.85, 0.5))


# ---------- L2 Vast Offices (inspired by plan) ----------

func _dress_offices_vast() -> void:
	var y := FLOOR_H
	_ceiling_light_grid(y, 6.0, 6.0, Color(1.0, 0.98, 0.92), 0.95)

	_build_michael_office(y)
	_build_conference(y)
	_build_break_room(y)
	_build_kitchen(y)
	_build_restrooms(y)
	_build_ryan_office(y)
	_build_reception_desk(y)
	# Flood open floor — rooms already claim NW/N/NE; fill everything else.
	_flood_office_floor(y)
	_build_extra_lounge_tables(y)


func _room_walls(cx: float, cz: float, w: float, d: float, y: float, door_side: String = "s") -> void:
	# Interior room: walls with one doorway gap on door_side (n/s/e/w)
	var h := 2.8
	var t := 0.2
	var yy := y + h * 0.5
	var door_w := 1.6
	# North / South
	if door_side == "n":
		_wall_with_door(Vector3(cx, yy, cz - d * 0.5), Vector3(w, h, t), door_w, true)
		_box(Vector3(cx, yy, cz + d * 0.5), Vector3(w, h, t), _wall)
	elif door_side == "s":
		_box(Vector3(cx, yy, cz - d * 0.5), Vector3(w, h, t), _wall)
		_wall_with_door(Vector3(cx, yy, cz + d * 0.5), Vector3(w, h, t), door_w, true)
	else:
		_box(Vector3(cx, yy, cz - d * 0.5), Vector3(w, h, t), _wall)
		_box(Vector3(cx, yy, cz + d * 0.5), Vector3(w, h, t), _wall)
	# East / West
	if door_side == "w":
		_wall_with_door(Vector3(cx - w * 0.5, yy, cz), Vector3(t, h, d), door_w, false)
		_box(Vector3(cx + w * 0.5, yy, cz), Vector3(t, h, d), _wall)
	elif door_side == "e":
		_box(Vector3(cx - w * 0.5, yy, cz), Vector3(t, h, d), _wall)
		_wall_with_door(Vector3(cx + w * 0.5, yy, cz), Vector3(t, h, d), door_w, false)
	else:
		_box(Vector3(cx - w * 0.5, yy, cz), Vector3(t, h, d), _wall)
		_box(Vector3(cx + w * 0.5, yy, cz), Vector3(t, h, d), _wall)


func _wall_with_door(pos: Vector3, size: Vector3, door_w: float, along_x: bool) -> void:
	# Split wall into two segments leaving a center doorway
	if along_x:
		var remain := size.x - door_w
		var seg := remain * 0.5
		_box(pos + Vector3(-(door_w * 0.5 + seg * 0.5), 0, 0), Vector3(seg, size.y, size.z), _wall)
		_box(pos + Vector3(door_w * 0.5 + seg * 0.5, 0, 0), Vector3(seg, size.y, size.z), _wall)
		_box(pos + Vector3(0, size.y * 0.35, 0), Vector3(door_w + 0.1, size.y * 0.3, size.z), _wall) # lintel
	else:
		var remain := size.z - door_w
		var seg := remain * 0.5
		_box(pos + Vector3(0, 0, -(door_w * 0.5 + seg * 0.5)), Vector3(size.x, size.y, seg), _wall)
		_box(pos + Vector3(0, 0, door_w * 0.5 + seg * 0.5), Vector3(size.x, size.y, seg), _wall)
		_box(pos + Vector3(0, size.y * 0.35, 0), Vector3(size.x, size.y * 0.3, door_w + 0.1), _wall)


func _build_michael_office(y: float) -> void:
	# NW private office
	_room_walls(-20, -13, 12, 10, y, "s")
	_plaque(Vector3(-20, y + 2.5, -8.2), "MICHAEL", Color(0.3, 0.35, 0.4))
	_prop("deskCorner.glb", Vector3(-22, y, -14), Vector3(0, 90, 0), 1.05)
	_prop("chairDesk.glb", Vector3(-20.5, y, -12.5), Vector3(0, 200, 0), 1.0)
	_prop("computerScreen.glb", Vector3(-22, y + DESK_TOP, -14.3), Vector3(0, 90, 0), 1.0, false)
	_prop("chair.glb", Vector3(-18, y, -12), Vector3(0, 180, 0), 1.0)
	_prop("chair.glb", Vector3(-17, y, -13.5), Vector3(0, 90, 0), 1.0)
	_prop("chairRounded.glb", Vector3(-18.5, y, -14.5), Vector3(0, 45, 0), 1.0)
	_prop("loungeSofa.glb", Vector3(-16, y, -16), Vector3(0, 0, 0), 1.0)
	_prop("tableCoffee.glb", Vector3(-16, y, -14.5), Vector3(0, 0, 0), 1.0)
	_prop("bookcaseOpen.glb", Vector3(-24.5, y, -12), Vector3(0, 90, 0), 1.05)
	_prop("bookcaseClosed.glb", Vector3(-24.5, y, -15), Vector3(0, 90, 0), 1.05)
	_prop("sideTableDrawers.glb", Vector3(-15.5, y, -10.5), Vector3(0, 0, 0), 1.0)
	_prop("plantSmall2.glb", Vector3(-15.5, y, -10), Vector3(0, 0, 0), 1.1)
	_prop("lampRoundFloor.glb", Vector3(-15.2, y, -16.5), Vector3(0, 0, 0), 1.0, false)
	_omni(Vector3(-20, y + 3.0, -13), Color(1.0, 0.95, 0.85), 0.8, 8.0)


func _build_conference(y: float) -> void:
	_room_walls(-2, -13, 14, 10, y, "s")
	_plaque(Vector3(-2, y + 2.5, -8.2), "CONFERENCE", Color(0.3, 0.35, 0.4))
	_prop("table.glb", Vector3(-2, y, -16.5), Vector3(0, 0, 0), 1.25)
	_prop("tableCloth.glb", Vector3(2, y, -16.5), Vector3(0, 0, 0), 1.1)
	# Dense chair rows facing west (presentation)
	for row in 4:
		for col in 6:
			var cx := -7.0 + col * 1.55
			var cz := -15.0 + row * 1.35
			_prop("chair.glb", Vector3(cx, y, cz), Vector3(0, -90, 0), 0.95)
	_prop("bookcaseClosedWide.glb", Vector3(-7.5, y, -16.5), Vector3(0, 90, 0), 1.0)
	_prop("sideTable.glb", Vector3(3.5, y, -9.5), Vector3(0, 0, 0), 1.0)
	_omni(Vector3(-2, y + 3.1, -13), Color(1.0, 0.98, 0.95), 1.0, 10.0)


func _build_break_room(y: float) -> void:
	_room_walls(18, -13, 14, 10, y, "s")
	_plaque(Vector3(18, y + 2.5, -8.2), "BREAK ROOM", Color(0.3, 0.35, 0.4))
	var tables := [
		Vector2(14, -15), Vector2(18, -15), Vector2(22, -15),
		Vector2(14, -11.5), Vector2(18, -11.5), Vector2(22, -11.5)
	]
	for t in tables:
		_prop("tableRound.glb", Vector3(t.x, y, t.y), Vector3(0, 10, 0), 1.05)
		_prop("chair.glb", Vector3(t.x + 1.15, y, t.y), Vector3(0, 90, 0), 0.95)
		_prop("chair.glb", Vector3(t.x - 1.15, y, t.y), Vector3(0, -90, 0), 0.95)
		_prop("chair.glb", Vector3(t.x, y, t.y + 1.15), Vector3(0, 180, 0), 0.95)
		_prop("chair.glb", Vector3(t.x, y, t.y - 1.15), Vector3(0, 0, 0), 0.95)
	_prop("kitchenCabinet.glb", Vector3(23.5, y, -10), Vector3(0, 180, 0), 1.0)
	_prop("kitchenCabinet.glb", Vector3(21.5, y, -9.2), Vector3(0, 180, 0), 1.0)
	_prop("cabinetTelevision.glb", Vector3(12.5, y, -9.5), Vector3(0, 0, 0), 1.0)
	_omni(Vector3(18, y + 3.0, -13), Color(1.0, 0.95, 0.85), 0.85, 9.0)


func _build_kitchen(y: float) -> void:
	_room_walls(-2, 6, 8, 7, y, "n")
	_plaque(Vector3(-2, y + 2.5, 2.7), "KITCHEN", Color(0.3, 0.35, 0.4))
	_floor(Vector3(-2, y - 0.08, 6), Vector3(7.6, 0.12, 6.6), _tile)
	_prop("table.glb", Vector3(-2, y, 6), Vector3(0, 0, 0), 1.05)
	_prop("chair.glb", Vector3(-3.3, y, 5), Vector3(0, 0, 0), 0.95)
	_prop("chair.glb", Vector3(-0.7, y, 5), Vector3(0, 0, 0), 0.95)
	_prop("chair.glb", Vector3(-3.3, y, 7), Vector3(0, 180, 0), 0.95)
	_prop("chair.glb", Vector3(-0.7, y, 7), Vector3(0, 180, 0), 0.95)
	_prop("kitchenCabinet.glb", Vector3(-4.5, y, 8), Vector3(0, 0, 0), 1.0)
	_prop("kitchenCabinet.glb", Vector3(-3.0, y, 8.4), Vector3(0, 0, 0), 1.0)
	_prop("sideTableDrawers.glb", Vector3(0.5, y, 8), Vector3(0, 180, 0), 1.0)
	_prop("tableCoffeeSquare.glb", Vector3(0.8, y, 5), Vector3(0, 0, 0), 1.0)
	_omni(Vector3(-2, y + 3.0, 6), Color(1.0, 0.95, 0.9), 0.75, 7.0)


func _build_restrooms(y: float) -> void:
	_room_walls(-6, 14, 7, 8, y, "n")
	_plaque(Vector3(-6, y + 2.5, 10.2), "MEN'S", Color(0.35, 0.4, 0.5))
	_floor(Vector3(-6, y - 0.08, 14), Vector3(6.6, 0.12, 7.6), _tile)
	_room_walls(2, 14, 7, 8, y, "n")
	_plaque(Vector3(2, y + 2.5, 10.2), "WOMEN'S", Color(0.5, 0.35, 0.45))
	_floor(Vector3(2, y - 0.08, 14), Vector3(6.6, 0.12, 7.6), _tile)
	_prop("loungeSofa.glb", Vector3(3.5, y, 12), Vector3(0, 180, 0), 1.0)
	_prop("chairModernCushion.glb", Vector3(1.0, y, 12), Vector3(0, 180, 0), 1.0)
	_prop("chairModernCushion.glb", Vector3(0.2, y, 13.2), Vector3(0, 90, 0), 1.0)
	_prop("sideTable.glb", Vector3(2.2, y, 11.2), Vector3(0, 0, 0), 1.0)


func _build_ryan_office(y: float) -> void:
	_room_walls(10, 12, 6, 6, y, "w")
	_plaque(Vector3(10, y + 2.5, 9.2), "RYAN", Color(0.3, 0.35, 0.4))
	_prop("desk.glb", Vector3(10, y, 12), Vector3(0, 180, 0), 0.95)
	_prop("chairDesk.glb", Vector3(10, y, 10.8), Vector3(0, 0, 0), 0.95)
	_prop("computerScreen.glb", Vector3(10, y + DESK_TOP, 12.2), Vector3(0, 180, 0), 1.0, false)
	_prop("chair.glb", Vector3(11.5, y, 11), Vector3(0, -40, 0), 0.95)
	_prop("bookcaseOpenLow.glb", Vector3(12.2, y, 13.5), Vector3(0, 180, 0), 1.0)
	_prop("sideTableDrawers.glb", Vector3(8.2, y, 13.2), Vector3(0, 90, 0), 1.0)


func _build_reception_desk(y: float) -> void:
	_prop("desk.glb", Vector3(-12, y, 2), Vector3(0, 20, 0), 1.1)
	_prop("desk.glb", Vector3(-10, y, 3.5), Vector3(0, 50, 0), 1.1)
	_prop("desk.glb", Vector3(-13.5, y, 3.8), Vector3(0, -10, 0), 1.05)
	_prop("chairDesk.glb", Vector3(-11, y, 1.2), Vector3(0, 200, 0), 1.0)
	_prop("chairDesk.glb", Vector3(-12.8, y, 2.5), Vector3(0, 170, 0), 1.0)
	_prop("computerScreen.glb", Vector3(-12, y + DESK_TOP, 1.7), Vector3(0, 20, 0), 1.0, false)
	_prop("computerScreen.glb", Vector3(-10, y + DESK_TOP, 3.2), Vector3(0, 50, 0), 1.0, false)
	_prop("chair.glb", Vector3(-9, y, 5.2), Vector3(0, 200, 0), 1.0)
	_prop("chair.glb", Vector3(-8, y, 4.2), Vector3(0, 160, 0), 1.0)
	_prop("loungeSofaOttoman.glb", Vector3(-14.5, y, 5.5), Vector3(0, 0, 0), 1.0)
	_prop("plantSmall1.glb", Vector3(-8.5, y, 4), Vector3(0, 0, 0), 1.1)
	_plaque(Vector3(-11, y + 2.3, 5.5), "RECEPTION", Color(0.4, 0.45, 0.5))
	_omni(Vector3(-11, y + 3.0, 2.5), Color(1.0, 0.95, 0.85), 0.7, 7.0)


func _desk_station(pos: Vector3, rot_y: float, _floor_y: float) -> void:
	_prop("desk.glb", pos, Vector3(0, rot_y, 0), 1.0)
	var back := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 1.35)
	_prop("chairDesk.glb", pos + back, Vector3(0, rot_y + 180.0, 0), 0.95)
	var mon := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, DESK_TOP, -0.15)
	_prop("computerScreen.glb", pos + mon, Vector3(0, rot_y, 0), 1.0, false)
	var key := Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, DESK_TOP + 0.02, 0.25)
	_prop("computerKeyboard.glb", pos + key, Vector3(0, rot_y, 0), 1.0, false)


func _pod4(cx: float, cz: float, y: float) -> void:
	_desk_station(Vector3(cx - 1.35, y, cz - 1.15), 0, y)
	_desk_station(Vector3(cx + 1.35, y, cz - 1.15), 0, y)
	_desk_station(Vector3(cx - 1.35, y, cz + 1.15), 180, y)
	_desk_station(Vector3(cx + 1.35, y, cz + 1.15), 180, y)


func _in_blocked_zone(x: float, z: float) -> bool:
	# Stairs + lift core
	if absf(x) < 9.5 and absf(z) < 5.5:
		return true
	# Lift bank east of stairs
	if x > 5.5 and x < 11.0 and absf(z) < 4.0:
		return true
	# Private rooms (rough footprints)
	# Michael (-20,-13) 12x10
	if x > -26.5 and x < -13.5 and z > -18.5 and z < -7.5:
		return true
	# Conference (-2,-13) 14x10
	if x > -9.5 and x < 5.5 and z > -18.5 and z < -7.5:
		return true
	# Break (18,-13) 14x10
	if x > 10.5 and x < 25.5 and z > -18.5 and z < -7.5:
		return true
	# Kitchen (-2,6) 8x7
	if x > -6.5 and x < 2.5 and z > 2.0 and z < 10.0:
		return true
	# Restrooms
	if x > -10.0 and x < 6.0 and z > 9.5 and z < 18.5:
		return true
	# Ryan (10,12) 6x6
	if x > 6.5 and x < 13.5 and z > 8.5 and z < 15.5:
		return true
	# Reception cluster
	if x > -15.5 and x < -7.0 and z > 0.0 and z < 6.5:
		return true
	return false


func _flood_office_floor(y: float) -> void:
	# Tight pod grid across the whole plate
	var pod_spacing_x := 5.2
	var pod_spacing_z := 5.0
	var x := -24.0
	while x <= 24.0:
		var z := -6.0
		while z <= 16.0:
			if not _in_blocked_zone(x, z):
				_pod4(x, z, y)
				# Cubicle cabinet on the +X side of each pod (divider)
				if not _in_blocked_zone(x + 2.5, z):
					_prop("bookcaseClosedWide.glb", Vector3(x + 2.55, y, z), Vector3(0, 90, 0), 1.0)
				# Low cabinet on +Z edge
				if not _in_blocked_zone(x, z + 2.4):
					_prop("cabinetTelevisionDoors.glb", Vector3(x, y, z + 2.45), Vector3(0, 0, 0), 1.0)
			z += pod_spacing_z
		x += pod_spacing_x

	# Perimeter single desks facing outer walls
	var wx := -25.8
	var wz := -6.0
	while wz <= 16.0:
		if not _in_blocked_zone(wx, wz):
			_desk_station(Vector3(wx, y, wz), 90, y)
			_prop("sideTableDrawers.glb", Vector3(wx + 1.7, y, wz), Vector3(0, 90, 0), 0.95)
		wz += 2.6
	wx = 25.8
	wz = -6.0
	while wz <= 16.0:
		if not _in_blocked_zone(wx, wz):
			_desk_station(Vector3(wx, y, wz), -90, y)
			_prop("sideTableDrawers.glb", Vector3(wx - 1.7, y, wz), Vector3(0, -90, 0), 0.95)
		wz += 2.6

	# South wall row (near restrooms / glass)
	x = -24.0
	while x <= 24.0:
		if not _in_blocked_zone(x, 17.5):
			_desk_station(Vector3(x, y, 17.5), 180, y)
			_prop("bookcaseOpenLow.glb", Vector3(x, y, 18.8), Vector3(0, 0, 0), 1.0)
		x += 3.0

	# North corridor filler between private rooms and open floor (z ~ -7)
	x = -24.0
	while x <= 24.0:
		if not _in_blocked_zone(x, -7.2):
			_prop("bookcaseClosed.glb", Vector3(x, y, -7.2), Vector3(0, 0, 0), 1.0)
			_prop("chair.glb", Vector3(x + 1.2, y, -6.2), Vector3(0, 180, 0), 0.95)
		x += 3.2

	# Gap fillers: chairs + coffee tables in leftover pockets
	for p in [
		Vector2(-8, 7), Vector2(8, 7), Vector2(-8, 12), Vector2(8, 11),
		Vector2(-12, 15), Vector2(16, 15), Vector2(-4, -6.5), Vector2(4, -6.5),
		Vector2(-24, 14), Vector2(24, 14), Vector2(-18, 14), Vector2(18, -6)
	]:
		if _in_blocked_zone(p.x, p.y):
			continue
		_prop("tableCoffee.glb", Vector3(p.x, y, p.y), Vector3(0, 0, 0), 1.0)
		_prop("chairCushion.glb", Vector3(p.x + 1.1, y, p.y), Vector3(0, -90, 0), 0.95)
		_prop("chairCushion.glb", Vector3(p.x - 1.1, y, p.y), Vector3(0, 90, 0), 0.95)
		_prop("plantSmall3.glb", Vector3(p.x, y, p.y + 1.3), Vector3(0, 0, 0), 1.1)

	# Continuous filing cabinets along mid aisles
	for fz in [-4.0, 1.0, 6.0, 11.0]:
		for fx in [-11.0, 11.0]:
			if not _in_blocked_zone(fx, fz):
				_prop("bookcaseClosedWide.glb", Vector3(fx, y, fz), Vector3(0, 90, 0), 1.05)
				_prop("cabinetTelevision.glb", Vector3(fx, y, fz + 1.8), Vector3(0, 90, 0), 1.0)


func _build_extra_lounge_tables(y: float) -> void:
	_prop("tableCoffee.glb", Vector3(-8, y, -6.5), Vector3(0, 0, 0), 1.05)
	_prop("chairCushion.glb", Vector3(-9.2, y, -6.5), Vector3(0, 90, 0), 1.0)
	_prop("chairCushion.glb", Vector3(-6.8, y, -6.5), Vector3(0, -90, 0), 1.0)
	_prop("tableCoffeeSquare.glb", Vector3(8, y, -6.5), Vector3(0, 0, 0), 1.05)
	_prop("chairRounded.glb", Vector3(9.2, y, -6.5), Vector3(0, -90, 0), 1.0)
	_prop("chairRounded.glb", Vector3(6.8, y, -6.5), Vector3(0, 90, 0), 1.0)
	_prop("loungeSofaLong.glb", Vector3(-8, y, 16), Vector3(0, 180, 0), 1.05)
	_prop("tableCoffee.glb", Vector3(-8, y, 14.5), Vector3(0, 0, 0), 1.0)
	_prop("loungeSofa.glb", Vector3(12, y, 16), Vector3(0, 180, 0), 1.0)
	_prop("loungeSofaCorner.glb", Vector3(15, y, 15), Vector3(0, 90, 0), 1.0)
	_prop("chair.glb", Vector3(-6.5, y, 15.5), Vector3(0, 90, 0), 1.0)
	_prop("chair.glb", Vector3(-9.5, y, 15.5), Vector3(0, -90, 0), 1.0)
	# Plants everywhere along glass
	for i in 10:
		_prop("pottedPlant.glb", Vector3(-24.0 + i * 5.0, y, -18.5), Vector3(0, 0, 0), 1.15)
		_prop("plantSmall1.glb", Vector3(-22.0 + i * 5.0, y, 18.5), Vector3(0, 0, 0), 1.15)


# ---------- L3 Archive ----------

func _dress_archive() -> void:
	var y := FLOOR_H * 2
	_ceiling_light_grid(y, 8.0, 8.0, Color(1.0, 0.85, 0.65), 0.55)
	for z in [-12.0, -6.0, 0.0, 6.0]:
		_prop("bookcaseClosedWide.glb", Vector3(-16, y, z), Vector3(0, 90, 0), 1.1)
		_prop("bookcaseOpen.glb", Vector3(-10, y, z + 1.5), Vector3(0, -90, 0), 1.1)
		_prop("bookcaseClosedWide.glb", Vector3(10, y, z), Vector3(0, -90, 0), 1.1)
	_prop("table.glb", Vector3(0, y, -10), Vector3(0, 0, 0), 1.1)
	_omni(Vector3(0, y + 2.2, -10), Color(1.0, 0.75, 0.45), 1.0, 8.0)
	_box(Vector3(18, y + 0.05, 12), Vector3(5.0, 0.08, 5.0), Color(0.15, 0.5, 0.3), false)
	_omni(Vector3(18, y + 2.6, 12), Color(0.4, 1.0, 0.55), 1.2, 10.0)
	_plaque(Vector3(18, y + 2.6, HALF_Z - 0.7), "EXTRACT →", Color(0.4, 1.0, 0.55))


func _place_gameplay() -> void:
	var player := preload("res://scenes/player.tscn").instantiate()
	player.position = Vector3(-14, 0.15, 12)
	add_child(player)

	_spawn_guard(Vector3(-8, 0.1, 0), PackedVector3Array([
		Vector3(-18, 0.1, -8), Vector3(8, 0.1, -8), Vector3(8, 0.1, 10), Vector3(-18, 0.1, 10)
	]))
	# L2 office guards — long patrols across the vast floor
	var y2 := FLOOR_H + 0.1
	_spawn_guard(Vector3(-16, y2, 0), PackedVector3Array([
		Vector3(-24, y2, -6), Vector3(-10, y2, -6), Vector3(-10, y2, 10), Vector3(-24, y2, 10)
	]))
	_spawn_guard(Vector3(16, y2, 0), PackedVector3Array([
		Vector3(10, y2, -6), Vector3(24, y2, -6), Vector3(24, y2, 10), Vector3(10, y2, 10)
	]))
	var y3 := FLOOR_H * 2 + 0.1
	_spawn_guard(Vector3(0, y3, 0), PackedVector3Array([
		Vector3(-12, y3, -10), Vector3(12, y3, -10), Vector3(12, y3, 8), Vector3(-12, y3, 8)
	]))

	var dossier := preload("res://scenes/dossier.tscn").instantiate()
	dossier.position = Vector3(0.8, FLOOR_H * 2 + DESK_TOP + 0.05, -10)
	add_child(dossier)

	var extract := preload("res://scenes/extract.tscn").instantiate()
	extract.position = Vector3(18, FLOOR_H * 2 + 0.1, 12)
	add_child(extract)

	add_child(preload("res://scenes/hud.tscn").instantiate())


# ---------- Lights ----------

func _ceiling_light_grid(floor_y: float, step_x: float, step_z: float, color: Color, energy: float) -> void:
	var y := floor_y + FLOOR_H - 0.45
	var x := -HALF_X + 4.0
	while x < HALF_X - 3.0:
		var z := -HALF_Z + 4.0
		while z < HALF_Z - 3.0:
			# Skip dense core around stairs
			if absf(x) < 5.0 and absf(z) < 5.0:
				z += step_z
				continue
			_ceiling_fixture(Vector3(x, y, z), color, energy)
			z += step_z
		x += step_x


func _ceiling_fixture(pos: Vector3, color: Color, energy: float) -> void:
	# Visual panel
	_box(pos, Vector3(1.6, 0.08, 0.9), Color(0.95, 0.95, 0.9), false)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.15, 0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 9.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = false # many lights — keep perf sane
	add_child(light)


# ---------- Helpers ----------

func _prop(file_name: String, pos: Vector3, rot_deg: Vector3, scale_mul: float = 1.0, with_collision: bool = true) -> Node3D:
	var path := FURN + file_name
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var node: Node3D = packed.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees = rot_deg
	node.scale = Vector3.ONE * (FURNITURE_SCALE * scale_mul)
	add_child(node)
	if with_collision:
		for child in _find_meshes(node):
			(child as MeshInstance3D).create_convex_collision()
	return node


func _find_meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_meshes(c))
	return out


func _floor(pos: Vector3, size: Vector3, color: Color) -> void:
	_box(pos, size, color, true)


func _window(pos: Vector3) -> void:
	_box(pos, Vector3(2.8, 2.0, 0.14), Color(0.22, 0.24, 0.28), false)
	var glass := _box(pos + Vector3(0, 0, -0.04 if pos.z < 0 else 0.04), Vector3(2.4, 1.65, 0.05), Color(0.15, 0.25, 0.45), false)
	_style_glass(glass)
	_omni(pos + Vector3(0, 0, 1.0 if pos.z < 0 else -1.0), Color(0.4, 0.55, 0.95), 0.25, 4.0)


func _window_side(pos: Vector3) -> void:
	_box(pos, Vector3(0.14, 2.0, 2.8), Color(0.22, 0.24, 0.28), false)
	var glass := _box(pos + Vector3(-0.04 if pos.x < 0 else 0.04, 0, 0), Vector3(0.05, 1.65, 2.4), Color(0.15, 0.25, 0.45), false)
	_style_glass(glass)


func _style_glass(body: StaticBody3D) -> void:
	var mi := body.get_node("MeshInstance3D") as MeshInstance3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.28, 0.5, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.4, 0.8)
	mat.emission_energy_multiplier = 0.7
	mi.material_override = mat


func _plaque(pos: Vector3, text: String, color: Color) -> void:
	_box(pos, Vector3(clampf(0.45 * text.length(), 2.5, 8.0), 0.45, 0.08), Color(0.12, 0.12, 0.14), false)
	var l := Label3D.new()
	l.text = text
	l.position = pos + Vector3(0, 0, 0.06)
	l.font_size = 34
	l.modulate = color
	l.outline_size = 4
	add_child(l)


func _omni(pos: Vector3, color: Color, energy: float, dist: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = dist
	light.shadow_enabled = false
	add_child(light)


func _box(pos: Vector3, size: Vector3, color: Color, with_collision: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh_i := MeshInstance3D.new()
	mesh_i.name = "MeshInstance3D"
	var box := BoxMesh.new()
	box.size = size
	mesh_i.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_i.material_override = mat
	body.add_child(mesh_i)
	if with_collision:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
	add_child(body)
	return body


func _spawn_guard(pos: Vector3, points: PackedVector3Array) -> void:
	var g: Node = preload("res://scenes/guard.tscn").instantiate()
	g.position = pos
	g.set("patrol_points", points)
	add_child(g)
