extends RigidBody3D

const NOISE_RADIUS := 8.0

var _landed := false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(6.0).timeout.connect(queue_free)


func _on_body_entered(_body: Node) -> void:
	if _landed:
		return
	_landed = true
	AlertBus.emit_noise(global_position, NOISE_RADIUS, "coin")
	# Soft clink visual: flash scale
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var tw := create_tween()
		tw.tween_property(mesh, "scale", Vector3.ONE * 1.4, 0.08)
		tw.tween_property(mesh, "scale", Vector3.ONE, 0.12)
