extends Node3D
## Loads a Kenney FBX character, applies a skin texture, and plays idle/run.

## Measured native height of Kenney characterMedium.fbx (meters in Godot).
const NATIVE_HEIGHT := 3.765
const TARGET_HEIGHT := 1.75

@export var model_path: String = "res://assets/characters/player/characterMedium.fbx"
@export var skin_path: String = "res://assets/characters/player/skin.png"
@export var idle_path: String = "res://assets/characters/player/idle.fbx"
@export var run_path: String = "res://assets/characters/player/run.fbx"
@export var model_scale: float = 1.0
@export var y_offset: float = 0.0

var _anim: AnimationPlayer
var _moving := false
var _model: Node3D


func _ready() -> void:
	var packed: PackedScene = load(model_path) as PackedScene
	if packed == null:
		push_error("Failed to load character model: %s" % model_path)
		return

	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	# Shrink oversized Kenney humanoid to person scale.
	var fit := (TARGET_HEIGHT / NATIVE_HEIGHT) * model_scale
	_model.scale = Vector3.ONE * fit
	_model.position.y = y_offset
	add_child(_model)

	call_deferred("_plant_feet")
	_apply_skin(_model)
	_anim = _ensure_animation_player(_model)
	_import_animation(idle_path, "idle", ["Idle"])
	_import_animation(run_path, "run", ["Run"])
	var idle_name := _resolve_anim("idle")
	if idle_name != "":
		_anim.play(idle_name)


func _plant_feet() -> void:
	if _model == null:
		return
	var aabb := _world_aabb(_model)
	if aabb.size.y <= 0.01:
		return
	# Bring world-space bottom to this node's origin (feet on floor).
	var bottom_local_y := to_local(aabb.position).y
	_model.position.y -= bottom_local_y


func _world_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for mi in _all_meshes(node):
		var mesh_i := mi as MeshInstance3D
		var local := mesh_i.get_aabb()
		for x in [0, 1]:
			for y in [0, 1]:
				for z in [0, 1]:
					var corner := local.position + local.size * Vector3(x, y, z)
					var p: Vector3 = mesh_i.global_transform * corner
					if first:
						result = AABB(p, Vector3.ZERO)
						first = false
					else:
						result = result.expand(p)
	return result


func set_moving(moving: bool) -> void:
	if _moving == moving:
		return
	_moving = moving
	if _anim == null:
		return
	var idle_name := _resolve_anim("idle")
	var run_name := _resolve_anim("run")
	if moving and run_name != "":
		_anim.play(run_name)
	elif idle_name != "":
		_anim.play(idle_name)


func _resolve_anim(key: String) -> String:
	if _anim == null:
		return ""
	if _anim.has_animation(key):
		return key
	for n in ["default/%s" % key, "%s" % key]:
		if _anim.has_animation(n):
			return n
	for n in _anim.get_animation_list():
		if String(n).to_lower().ends_with(key) or key in String(n).to_lower():
			return String(n)
	return ""


func _all_meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_meshes(c))
	return out


func _apply_skin(root: Node) -> void:
	var tex: Texture2D = load(skin_path) as Texture2D
	if tex == null:
		push_warning("Missing skin texture: %s" % skin_path)
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_apply_material_recursive(root, mat)


func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = mat
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_recursive(child, mat)


func _ensure_animation_player(model: Node) -> AnimationPlayer:
	var existing := _find_animation_player(model)
	if existing:
		return existing
	# Must be sibling of "Root" so Kenney track paths resolve.
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	model.add_child(ap)
	return ap


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _import_animation(path: String, anim_key: String, name_hints: Array) -> void:
	if _anim == null:
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_warning("Failed to load animation FBX: %s" % path)
		return
	var temp: Node = packed.instantiate()
	var source_ap := _find_animation_player(temp)
	if source_ap == null:
		temp.queue_free()
		push_warning("No AnimationPlayer in: %s" % path)
		return

	var lib_name := &"default"
	if not _anim.has_animation_library(lib_name):
		_anim.add_animation_library(lib_name, AnimationLibrary.new())
	var lib: AnimationLibrary = _anim.get_animation_library(lib_name)

	var chosen: Animation = null
	var anim_names: PackedStringArray = source_ap.get_animation_list()
	for anim_name in anim_names:
		var s := String(anim_name)
		for hint in name_hints:
			if String(hint).to_lower() in s.to_lower() and "targeting" not in s.to_lower():
				chosen = source_ap.get_animation(anim_name)
				break
		if chosen:
			break
	if chosen == null and not anim_names.is_empty():
		# Last non-targeting clip.
		for anim_name in anim_names:
			if "targeting" not in String(anim_name).to_lower():
				chosen = source_ap.get_animation(anim_name)
				break
		if chosen == null:
			chosen = source_ap.get_animation(anim_names[0])

	if chosen:
		var animation: Animation = chosen.duplicate(true)
		animation.loop_mode = Animation.LOOP_LINEAR
		if lib.has_animation(anim_key):
			lib.remove_animation(anim_key)
		lib.add_animation(anim_key, animation)

	temp.queue_free()
