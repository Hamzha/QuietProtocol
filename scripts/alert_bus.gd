extends Node
## Global noise / alert events for guards and mission grading.

signal noise_emitted(position: Vector3, radius: float, kind: String)
signal global_alert_raised(level: int)
signal player_downed

enum AlertLevel { CALM, COMPROMISED, LOUD }

var level: AlertLevel = AlertLevel.CALM
var full_alert_time: float = 0.0
const FULL_ALERT_FAIL_SECONDS := 45.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset() -> void:
	level = AlertLevel.CALM
	full_alert_time = 0.0


func emit_noise(at: Vector3, radius: float, kind: String = "generic") -> void:
	noise_emitted.emit(at, radius, kind)
	if kind == "gunshot":
		raise_alert(AlertLevel.LOUD)
	elif kind == "spotted":
		raise_alert(AlertLevel.COMPROMISED)


func raise_alert(new_level: AlertLevel) -> void:
	if new_level > level:
		level = new_level
		global_alert_raised.emit(level)


func _process(delta: float) -> void:
	if level == AlertLevel.LOUD and Mission.is_playing():
		full_alert_time += delta
		if full_alert_time >= FULL_ALERT_FAIL_SECONDS:
			Mission.fail_mission("Cover blown — embassy locked down.")
