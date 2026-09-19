extends CharacterBody3D

enum State { PATROL, SUSPICIOUS, ALERT, SEARCH, UNCONSCIOUS }

const WALK_SPEED := 2.1
const ALERT_SPEED := 3.6
const VIEW_DISTANCE := 14.0
const VIEW_DISTANCE_CROUCH := 9.0
const VIEW_ANGLE_DEG := 55.0
const HEAR_RADIUS_DEFAULT := 10.0
const SEARCH_TIME := 8.0
const SUSPICIOUS_TIME := 3.0
const SHOOT_RANGE := 16.0
const SHOOT_COOLDOWN := 0.9

@export var patrol_points: PackedVector3Array = PackedVector3Array()

@onready var visual: Node3D = $Visual
@onready var vision_mesh: MeshInstance3D = $VisionCone
@onready var agent: NavigationAgent3D = $NavigationAgent3D

var state: State = State.PATROL
var patrol_index := 0
var suspicion := 0.0
var search_timer := 0.0
var last_known := Vector3.ZERO
var shoot_cd := 0.0
var player: Node3D = null
var _mat_cone: StandardMaterial3D


func _ready() -> void:
	add_to_group("guards")
	AlertBus.noise_emitted.connect(_on_noise)
	AlertBus.global_alert_raised.connect(_on_global_alert)
	_mat_cone = StandardMaterial3D.new()
	_mat_cone.albedo_color = Color(0.9, 0.75, 0.2, 0.18)
	_mat_cone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cone.cull_mode = BaseMaterial3D.CULL_DISABLED
	vision_mesh.material_override = _mat_cone
	_build_vision_mesh()
	if patrol_points.is_empty():
		patrol_points = PackedVector3Array([global_position])
	_set_state(State.PATROL)


func _physics_process(delta: float) -> void:
	if state == State.UNCONSCIOUS:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D

	shoot_cd = maxf(0.0, shoot_cd - delta)
	_update_vision(delta)

	match state:
		State.PATROL:
			_patrol(delta)
		State.SUSPICIOUS:
			_face_toward(last_known, delta)
			search_timer -= delta
			if search_timer <= 0.0:
				_set_state(State.PATROL)
		State.ALERT:
			_chase_or_shoot(delta)
		State.SEARCH:
			_search(delta)

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	if visual.has_method("set_moving"):
		var moving := Vector2(velocity.x, velocity.z).length() > 0.2
		visual.set_moving(moving)
	_update_cone_visual()


func can_be_taken_down() -> bool:
	return state != State.UNCONSCIOUS and state != State.ALERT


func take_down() -> void:
	_set_state(State.UNCONSCIOUS)
	collision_layer = 0
	collision_mask = 1
	visual.rotation.z = deg_to_rad(90)
	visual.position.y = 0.35
	if visual.has_method("set_moving"):
		visual.set_moving(false)
	vision_mesh.visible = false


func on_shot() -> void:
	# Non-lethal mission: shots stun / drop guards (emergency).
	take_down()
	AlertBus.raise_alert(AlertBus.AlertLevel.LOUD)


func _set_state(s: State) -> void:
	state = s
	match s:
		State.PATROL:
			_mat_cone.albedo_color = Color(0.9, 0.75, 0.2, 0.18)
		State.SUSPICIOUS:
			_mat_cone.albedo_color = Color(1.0, 0.7, 0.15, 0.25)
			search_timer = SUSPICIOUS_TIME
		State.ALERT:
			_mat_cone.albedo_color = Color(1.0, 0.2, 0.15, 0.3)
			AlertBus.emit_noise(global_position, 1.0, "spotted")
			AlertBus.raise_alert(AlertBus.AlertLevel.COMPROMISED)
		State.SEARCH:
			_mat_cone.albedo_color = Color(1.0, 0.45, 0.1, 0.22)
			search_timer = SEARCH_TIME
		State.UNCONSCIOUS:
			pass


func _update_vision(delta: float) -> void:
	if player == null or state == State.UNCONSCIOUS:
		return
	if not Mission.is_playing():
		return

	var seen := _can_see_player()
	if seen:
		last_known = player.global_position
		suspicion = minf(1.0, suspicion + delta * (2.2 if state == State.ALERT else 1.4))
		if suspicion >= 1.0 and state != State.ALERT:
			_set_state(State.ALERT)
	else:
		if state == State.ALERT:
			# Lose sight → search last known.
			_set_state(State.SEARCH)
		elif state != State.SEARCH and state != State.SUSPICIOUS:
			suspicion = maxf(0.0, suspicion - delta * 0.6)


func _can_see_player() -> bool:
	var to_player: Vector3 = player.global_position + Vector3.UP * 0.9 - (global_position + Vector3.UP * 1.4)
	var dist := to_player.length()
	var max_dist := VIEW_DISTANCE
	if player.has_method("is_crouching") and player.is_crouching():
		max_dist = VIEW_DISTANCE_CROUCH
	if dist > max_dist:
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var dir := to_player.normalized()
	var flat_dir := Vector3(dir.x, 0.0, dir.z).normalized()
	if forward.angle_to(flat_dir) > deg_to_rad(VIEW_ANGLE_DEG):
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, player.global_position + Vector3.UP * 0.9)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit and hit.collider != player:
		return false
	return true


func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var target: Vector3 = patrol_points[patrol_index]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.6:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		return
	_move_toward(target, WALK_SPEED, delta)


func _chase_or_shoot(delta: float) -> void:
	if player == null:
		return
	last_known = player.global_position
	var dist := global_position.distance_to(player.global_position)
	_face_toward(player.global_position, delta)
	if dist > 4.0:
		_move_toward(player.global_position, ALERT_SPEED, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if dist <= SHOOT_RANGE and shoot_cd <= 0.0 and _can_see_player():
		shoot_cd = SHOOT_COOLDOWN
		AlertBus.emit_noise(global_position, 18.0, "gunshot")
		if player.has_method("take_damage"):
			player.take_damage(1.0)


func _search(delta: float) -> void:
	search_timer -= delta
	_move_toward(last_known, WALK_SPEED, delta)
	if global_position.distance_to(last_known) < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
	if search_timer <= 0.0:
		_set_state(State.PATROL)


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_toward(target, delta)


func _face_toward(target: Vector3, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	var yaw := atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, yaw, 8.0 * delta)


func _on_noise(at: Vector3, radius: float, kind: String) -> void:
	if state == State.UNCONSCIOUS or state == State.ALERT:
		return
	var dist := global_position.distance_to(at)
	if dist > radius:
		return
	last_known = at
	if kind == "gunshot" or AlertBus.level == AlertBus.AlertLevel.LOUD:
		_set_state(State.ALERT)
	else:
		_set_state(State.SUSPICIOUS)


func _on_global_alert(level: int) -> void:
	if state == State.UNCONSCIOUS:
		return
	if level >= AlertBus.AlertLevel.LOUD and state != State.ALERT:
		if player:
			last_known = player.global_position
		_set_state(State.ALERT)


func _build_vision_mesh() -> void:
	var im := ImmediateMesh.new()
	vision_mesh.mesh = im
	# Simple wedge on XZ for debug visibility.
	var len := VIEW_DISTANCE
	var half := deg_to_rad(VIEW_ANGLE_DEG)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3.ZERO
	var b := Vector3(sin(-half) * len, 0.05, -cos(-half) * len)
	var c := Vector3(sin(half) * len, 0.05, -cos(half) * len)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_add_vertex(c)
	im.surface_end()
	vision_mesh.position = Vector3(0, 0.1, 0)


func _update_cone_visual() -> void:
	vision_mesh.visible = state != State.UNCONSCIOUS
