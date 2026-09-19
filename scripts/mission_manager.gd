extends Node
## Tracks objectives, grade, win/fail, restart.

signal state_changed
signal mission_ended(won: bool, grade: String, message: String)

enum State { BRIEFING, PLAYING, WON, FAILED }

var state: State = State.PLAYING
var has_dossier: bool = false
var ever_compromised: bool = false
var ever_loud: bool = false
var shots_fired: int = 0
var takedowns: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AlertBus.global_alert_raised.connect(_on_alert)


func is_playing() -> bool:
	return state == State.PLAYING


func reset_run() -> void:
	state = State.PLAYING
	has_dossier = false
	ever_compromised = false
	ever_loud = false
	shots_fired = 0
	takedowns = 0
	AlertBus.reset()
	state_changed.emit()


func collect_dossier() -> void:
	if not is_playing():
		return
	has_dossier = true
	state_changed.emit()


func register_shot() -> void:
	shots_fired += 1
	ever_loud = true
	state_changed.emit()


func register_takedown() -> void:
	takedowns += 1
	state_changed.emit()


func try_extract() -> void:
	if not is_playing():
		return
	if not has_dossier:
		state_changed.emit()
		return
	var grade := compute_grade()
	_end(true, grade, "Dossier secured. Extract clean.")


func fail_mission(reason: String) -> void:
	if not is_playing():
		return
	_end(false, "FAILED", reason)


func compute_grade() -> String:
	if AlertBus.level == AlertBus.AlertLevel.CALM and not ever_compromised and not ever_loud:
		return "GHOST"
	if ever_loud or AlertBus.level == AlertBus.AlertLevel.LOUD:
		return "LOUD"
	return "COMPROMISED"


func _on_alert(level: int) -> void:
	if level >= AlertBus.AlertLevel.COMPROMISED:
		ever_compromised = true
	if level >= AlertBus.AlertLevel.LOUD:
		ever_loud = true
	state_changed.emit()


func _end(won: bool, grade: String, message: String) -> void:
	state = State.WON if won else State.FAILED
	mission_ended.emit(won, grade, message)
	state_changed.emit()


func restart_level() -> void:
	reset_run()
	get_tree().reload_current_scene()
