extends CharacterBody3D

const WALK_SPEED := 3.2
const SPRINT_SPEED := 6.0
const CROUCH_SPEED := 1.6
const JUMP_VELOCITY := 4.2
const MOUSE_SENS := 0.0035
const TAKEDOWN_RANGE := 2.2
const COIN_COOLDOWN := 1.2
const MAX_AMMO := 8
const GUN_RANGE := 40.0
const GUN_NOISE_RADIUS := 22.0
const SPRINT_NOISE_RADIUS := 6.0
const PITCH_MIN := deg_to_rad(-60.0)
const PITCH_MAX := deg_to_rad(40.0)

@onready var pivot: Node3D = $CameraPivot
@onready var pitch_pivot: Node3D = $CameraPivot/PitchPivot
@onready var spring: SpringArm3D = $CameraPivot/PitchPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/PitchPivot/SpringArm3D/Camera3D
@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var interact_ray: RayCast3D = $CameraPivot/PitchPivot/SpringArm3D/Camera3D/InteractRay

var yaw := 0.0
var pitch := 0.0
var crouched := false
var ammo := MAX_AMMO
var coin_timer := 0.0
var _sprint_noise_cd := 0.0
var _downed := false

var standing_height := 1.8
var crouch_height := 1.0


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring.add_excluded_object(get_rid())
	_apply_camera_rotation()


func _input(event: InputEvent) -> void:
	# Use _input (not unhandled) so mouse look always receives pointer motion.
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			yaw -= event.relative.x * MOUSE_SENS
			pitch -= event.relative.y * MOUSE_SENS
			pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
			_apply_camera_rotation()
		return

	if event is InputEventMouseButton and event.pressed:
		# Click to recapture pointer for camera look.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return


func _apply_camera_rotation() -> void:
	if pivot:
		pivot.rotation.y = yaw
	if pitch_pivot:
		pitch_pivot.rotation.x = pitch


func _unhandled_input(event: InputEvent) -> void:
	if not Mission.is_playing() or _downed:
		if event.is_action_pressed("restart"):
			Mission.restart_level()
		elif event.is_action_pressed("ui_cancel"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		return

	if event.is_action_pressed("crouch"):
		_set_crouch(not crouched)

	if event.is_action_pressed("interact"):
		_try_takedown_or_interact()

	if event.is_action_pressed("throw_coin"):
		_throw_coin()

	if event.is_action_pressed("shoot"):
		_shoot()

	if event.is_action_pressed("restart"):
		Mission.restart_level()


func _physics_process(delta: float) -> void:
	coin_timer = maxf(0.0, coin_timer - delta)
	_sprint_noise_cd = maxf(0.0, _sprint_noise_cd - delta)

	if not Mission.is_playing() or _downed:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= 9.8 * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis_y := Basis(Vector3.UP, yaw)
	var direction := (basis_y * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var sprinting := Input.is_action_pressed("sprint") and not crouched and direction != Vector3.ZERO
	var speed := CROUCH_SPEED if crouched else (SPRINT_SPEED if sprinting else WALK_SPEED)

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 12.0 * delta)
		if sprinting and _sprint_noise_cd <= 0.0:
			AlertBus.emit_noise(global_position, SPRINT_NOISE_RADIUS, "sprint")
			_sprint_noise_cd = 0.45
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	if visual.has_method("set_moving"):
		visual.set_moving(direction != Vector3.ZERO and not _downed)
	move_and_slide()


func _set_crouch(value: bool) -> void:
	crouched = value
	var shape := collision.shape as CapsuleShape3D
	if shape == null:
		return
	if crouched:
		shape.height = crouch_height
		collision.position.y = crouch_height * 0.5
		visual.scale = Vector3(1.0, 0.7, 1.0)
		visual.position.y = -0.15
	else:
		shape.height = standing_height
		collision.position.y = standing_height * 0.5
		visual.scale = Vector3.ONE
		visual.position.y = 0.0


func _try_takedown_or_interact() -> void:
	# Prefer silent takedown on unaware guard behind them.
	var best: Node3D = null
	var best_dist := TAKEDOWN_RANGE
	for node in get_tree().get_nodes_in_group("guards"):
		if not node.has_method("can_be_taken_down") or not node.has_method("take_down"):
			continue
		if not node.can_be_taken_down():
			continue
		var g: Node3D = node as Node3D
		var to_guard: Vector3 = g.global_position - global_position
		to_guard.y = 0.0
		var dist := to_guard.length()
		if dist > best_dist:
			continue
		var forward: Vector3 = -g.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var from_guard: Vector3 = -to_guard.normalized()
		# Must be roughly behind the guard.
		if forward.dot(from_guard) < 0.35:
			continue
		best = g
		best_dist = dist
	if best:
		best.take_down()
		Mission.register_takedown()
		return

	# Elevator panels / call buttons / props
	var interact_target: Node = null
	if interact_ray.is_colliding():
		interact_target = interact_ray.get_collider() as Node
	if interact_target == null:
		var best_i: Node = null
		var best_d := 2.4
		for node in get_tree().get_nodes_in_group("interactable"):
			if node is Node3D:
				var d: float = global_position.distance_to((node as Node3D).global_position)
				if d < best_d:
					best_d = d
					best_i = node
		interact_target = best_i

	if interact_target:
		if interact_target.has_meta("elevator"):
			var elev: Node = interact_target.get_meta("elevator")
			if elev and elev.has_method("interact_from"):
				elev.interact_from(interact_target, self)
				return
		if interact_target.has_method("interact"):
			interact_target.interact(self)
			return
		# Walk into dossier/extract areas still works via Area body_entered.


func _throw_coin() -> void:
	if coin_timer > 0.0:
		return
	coin_timer = COIN_COOLDOWN
	var coin_scene := preload("res://scenes/coin.tscn")
	var coin: RigidBody3D = coin_scene.instantiate()
	get_tree().current_scene.add_child(coin)
	var origin := camera.global_position + (-camera.global_transform.basis.z * 0.8)
	coin.global_position = origin
	var throw_dir := -camera.global_transform.basis.z + Vector3.UP * 0.15
	coin.apply_central_impulse(throw_dir.normalized() * 9.0)


func _shoot() -> void:
	if ammo <= 0:
		return
	ammo -= 1
	Mission.register_shot()
	AlertBus.emit_noise(global_position, GUN_NOISE_RADIUS, "gunshot")

	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * GUN_RANGE)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit:
		var collider = hit.collider
		if collider and collider.has_method("on_shot"):
			collider.on_shot()
		_spawn_tracer(from, hit.position)
	else:
		_spawn_tracer(from, to)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)


func take_damage(_amount: float = 1.0) -> void:
	if _downed:
		return
	_downed = true
	AlertBus.player_downed.emit()
	Mission.fail_mission("Operative down.")


func is_crouching() -> bool:
	return crouched
