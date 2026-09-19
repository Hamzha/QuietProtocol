extends Node3D
## Elevator cabin that rides between floors. Press E on the panel (or while inside) to go.

signal arrived(floor_index: int)

@export var floor_heights: PackedFloat32Array = PackedFloat32Array([0.0, 4.5, 9.0])
@export var cabin_size: Vector3 = Vector3(2.4, 2.6, 2.4)
@export var travel_speed: float = 3.5

var current_floor: int = 0
var busy: bool = false
var _cabin: AnimatableBody3D
var _ride_area: Area3D
var _panel: Area3D
var _status: Label3D
var _players_inside: Array[Node3D] = []
var _call_buttons: Array[Area3D] = []


func setup(heights: PackedFloat32Array, start_floor: int = 0) -> void:
	floor_heights = heights
	current_floor = start_floor
	_build_cabin()
	_build_panel()
	global_position = Vector3(global_position.x, floor_heights[current_floor], global_position.z)
	_update_status()


func _build_cabin() -> void:
	_cabin = AnimatableBody3D.new()
	_cabin.name = "Cabin"
	_cabin.sync_to_physics = true
	add_child(_cabin)

	var sx := cabin_size.x
	var sy := cabin_size.y
	var sz := cabin_size.z
	var metal := Color(0.35, 0.38, 0.42)
	var accent := Color(0.75, 0.7, 0.35)
	var floor_col := Color(0.2, 0.22, 0.25)

	# Floor platform (ride surface)
	_add_cabin_box(Vector3(0, 0.08, 0), Vector3(sx, 0.16, sz), floor_col)
	# Ceiling
	_add_cabin_box(Vector3(0, sy, 0), Vector3(sx, 0.12, sz), metal)
	# Back wall
	_add_cabin_box(Vector3(0, sy * 0.5, -sz * 0.5 + 0.06), Vector3(sx - 0.1, sy, 0.12), metal)
	# Left / right walls
	_add_cabin_box(Vector3(-sx * 0.5 + 0.06, sy * 0.5, 0), Vector3(0.12, sy, sz - 0.1), metal)
	_add_cabin_box(Vector3(sx * 0.5 - 0.06, sy * 0.5, 0), Vector3(0.12, sy, sz - 0.1), metal)
	# Front rails (open doorway feel)
	_add_cabin_box(Vector3(-sx * 0.35, sy * 0.5, sz * 0.5 - 0.06), Vector3(0.18, sy, 0.12), accent)
	_add_cabin_box(Vector3(sx * 0.35, sy * 0.5, sz * 0.5 - 0.06), Vector3(0.18, sy, 0.12), accent)

	# Cabin light
	var light := OmniLight3D.new()
	light.position = Vector3(0, sy - 0.3, 0)
	light.light_color = Color(1.0, 0.95, 0.8)
	light.light_energy = 1.1
	light.omni_range = 5.0
	_cabin.add_child(light)

	# Detect riders
	_ride_area = Area3D.new()
	_ride_area.collision_layer = 0
	_ride_area.collision_mask = 2 # player
	_ride_area.monitoring = true
	var ride_shape := CollisionShape3D.new()
	var ride_box := BoxShape3D.new()
	ride_box.size = Vector3(sx - 0.3, sy - 0.4, sz - 0.3)
	ride_shape.shape = ride_box
	ride_shape.position = Vector3(0, sy * 0.5, 0)
	_ride_area.add_child(ride_shape)
	_cabin.add_child(_ride_area)
	_ride_area.body_entered.connect(_on_rider_enter)
	_ride_area.body_exited.connect(_on_rider_exit)

	_status = Label3D.new()
	_status.position = Vector3(0, sy - 0.55, -sz * 0.5 + 0.2)
	_status.font_size = 48
	_status.modulate = accent
	_status.text = "L1"
	_cabin.add_child(_status)


func _add_cabin_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_i.mesh = box
	mesh_i.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.55
	mat.roughness = 0.35
	mesh_i.material_override = mat
	_cabin.add_child(mesh_i)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	_cabin.add_child(col)


func _build_panel() -> void:
	_panel = Area3D.new()
	_panel.name = "ElevatorPanel"
	_panel.add_to_group("interactable")
	_panel.collision_layer = 8
	_panel.collision_mask = 2
	_panel.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.8, 0.3)
	shape.shape = box
	_panel.add_child(shape)
	_panel.position = Vector3(cabin_size.x * 0.35, 1.3, -cabin_size.z * 0.35)
	_cabin.add_child(_panel)

	var panel_mesh := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.25, 0.7, 0.08)
	panel_mesh.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.12, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 0.5)
	mat.emission_energy_multiplier = 0.6
	panel_mesh.material_override = mat
	_panel.add_child(panel_mesh)

	var hint := Label3D.new()
	hint.text = "E · FLOOR"
	hint.position = Vector3(0, 0.55, 0.08)
	hint.font_size = 28
	hint.modulate = Color(0.7, 1.0, 0.8)
	_panel.add_child(hint)

	_panel.set_meta("elevator", self)


func add_call_button(floor_index: int, world_pos: Vector3) -> void:
	var btn := Area3D.new()
	btn.name = "CallButton_F%d" % (floor_index + 1)
	btn.add_to_group("interactable")
	btn.collision_layer = 8
	btn.collision_mask = 2
	btn.position = world_pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.8, 0.4)
	shape.shape = box
	btn.add_child(shape)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 0.55, 0.12)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.75, 0.2)
	mat.emission_energy_multiplier = 0.7
	mesh.material_override = mat
	btn.add_child(mesh)

	var label := Label3D.new()
	label.text = "CALL %d" % (floor_index + 1)
	label.position = Vector3(0, 0.5, 0.1)
	label.font_size = 26
	label.modulate = Color(1.0, 0.9, 0.5)
	btn.add_child(label)

	btn.set_meta("elevator", self)
	btn.set_meta("call_floor", floor_index)
	add_child(btn)
	# Keep button in world space relative to elevator root parent — actually call buttons
	# should NOT move with cabin. Reparent to elevator's parent after add.
	_call_buttons.append(btn)


func finalize_call_buttons(host: Node3D) -> void:
	for btn in _call_buttons:
		var gp := btn.global_position
		remove_child(btn)
		host.add_child(btn)
		btn.global_position = gp


func interact(_player: Node = null) -> void:
	# Direct interact on panel Area if routed here.
	if has_meta("call_floor"):
		go_to_floor(int(get_meta("call_floor")))
	else:
		var next := (current_floor + 1) % floor_heights.size()
		go_to_floor(next)


func interact_from(area: Node, _player: Node = null) -> void:
	if busy:
		return
	if area.has_meta("call_floor"):
		go_to_floor(int(area.get_meta("call_floor")))
	else:
		var next := (current_floor + 1) % floor_heights.size()
		go_to_floor(next)


func go_to_floor(floor_index: int) -> void:
	if busy:
		return
	floor_index = clampi(floor_index, 0, floor_heights.size() - 1)
	if floor_index == current_floor:
		_update_status()
		return
	busy = true
	_status.text = "→ %d" % (floor_index + 1)
	var target_y := floor_heights[floor_index]
	var start_y := _cabin.global_position.y
	# Cabin is child of this node; move this root on Y so shaft alignment stays.
	var start := global_position
	var end := Vector3(start.x, target_y, start.z)
	var dist := absf(end.y - start.y)
	var duration := maxf(0.8, dist / travel_speed)

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_position", end, duration)
	tw.finished.connect(func ():
		current_floor = floor_index
		busy = false
		_update_status()
		arrived.emit(floor_index)
	)


func _update_status() -> void:
	if _status:
		_status.text = "L%d" % (current_floor + 1)


func _on_rider_enter(body: Node3D) -> void:
	if body.is_in_group("player") and not _players_inside.has(body):
		_players_inside.append(body)


func _on_rider_exit(body: Node3D) -> void:
	_players_inside.erase(body)


func _physics_process(_delta: float) -> void:
	# Keep riders glued while moving (AnimatableBody helps; this is backup).
	if not busy:
		return
	for p in _players_inside:
		if is_instance_valid(p):
			# Match cabin horizontal and ride Y with cabin floor.
			p.global_position.x = global_position.x
			p.global_position.z = global_position.z + cabin_size.z * 0.1
			p.global_position.y = global_position.y + 0.15
