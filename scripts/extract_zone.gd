extends Area3D

@onready var label: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	Mission.state_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if Mission.has_dossier:
		label.text = "EXTRACT [E]"
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.7, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.15, 0.5, 0.25)
		mesh.material_override = mat
	else:
		label.text = "EXTRACT (need dossier)"
		var mat2 := StandardMaterial3D.new()
		mat2.albedo_color = Color(0.25, 0.35, 0.45)
		mesh.material_override = mat2


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		interact(body)


func interact(_player: Node = null) -> void:
	if not Mission.is_playing():
		return
	if Mission.has_dossier:
		Mission.try_extract()
	else:
		label.text = "Need the dossier first"
