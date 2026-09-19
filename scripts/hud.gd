extends CanvasLayer

@onready var status: Label = $Root/Status
@onready var objective: Label = $Root/Objective
@onready var ammo: Label = $Root/Ammo
@onready var help: Label = $Root/Help
@onready var end_panel: PanelContainer = $Root/EndPanel
@onready var end_title: Label = $Root/EndPanel/VBox/Title
@onready var end_body: Label = $Root/EndPanel/VBox/Body
@onready var end_hint: Label = $Root/EndPanel/VBox/Hint


func _ready() -> void:
	Mission.state_changed.connect(_refresh)
	Mission.mission_ended.connect(_on_ended)
	AlertBus.global_alert_raised.connect(func(_l): _refresh())
	end_panel.visible = false
	help.text = "Mouse look · click to lock cursor · Esc free cursor · WASD · Ctrl crouch · Shift sprint · E interact · F coin · LMB shoot · R restart"
	_refresh()


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and "ammo" in player:
		ammo.text = "Ammo: %d" % player.ammo


func _refresh() -> void:
	var alert_names: Array[String] = ["CALM", "COMPROMISED", "LOUD"]
	var alert_name: String = alert_names[AlertBus.level]
	status.text = "Alert: %s" % alert_name
	match AlertBus.level:
		AlertBus.AlertLevel.CALM:
			status.modulate = Color(0.7, 0.9, 0.75)
		AlertBus.AlertLevel.COMPROMISED:
			status.modulate = Color(1.0, 0.8, 0.35)
		AlertBus.AlertLevel.LOUD:
			status.modulate = Color(1.0, 0.4, 0.35)

	if Mission.has_dossier:
		objective.text = "Objective: Reach EXTRACT on L3"
	else:
		objective.text = "Objective: L2 offices are huge — lifts/stairs to L3 for the DOSSIER"


func _on_ended(won: bool, grade: String, message: String) -> void:
	end_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if won:
		end_title.text = "MISSION COMPLETE — %s" % grade
		end_title.modulate = Color(0.75, 0.95, 0.8)
	else:
		end_title.text = "MISSION FAILED"
		end_title.modulate = Color(1.0, 0.45, 0.4)
	end_body.text = message
	end_hint.text = "Press R to restart"
