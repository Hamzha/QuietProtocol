extends Area3D

@onready var label: Label3D = $Label3D

var taken := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	label.text = "DOSSIER [E]"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.3, 0.05)
	$MeshInstance3D.material_override = mat


func _on_body_entered(body: Node) -> void:
	if taken:
		return
	if body.is_in_group("player"):
		interact(body)


func interact(_player: Node = null) -> void:
	if taken or not Mission.is_playing():
		return
	taken = true
	Mission.collect_dossier()
	label.text = "SECURED"
	visible = false
	monitoring = false
	set_deferred("monitorable", false)
