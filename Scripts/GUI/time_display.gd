# Scripts/GUI/time_display.gd
extends Control

@onready var time_label: Label = $VBoxContainer/TimeLabel
@onready var phase_label: Label = $VBoxContainer/PhaseLabel
@onready var speed_label: Label = $VBoxContainer/SpeedLabel

var daylight_cycle: UnifiedEnvironment

func _ready():
	# Find the daylight cycle
	await get_tree().process_frame
	daylight_cycle = find_daylight_cycle()
	
	if daylight_cycle:
		daylight_cycle.connect("time_changed", _on_time_changed)
		print("Time display connected to daylight cycle")
	else:
		print("Warning: Could not find daylight cycle")

func find_daylight_cycle() -> Node:
	# Look for unified environment first
	var unified_env = get_tree().get_first_node_in_group("unified_environment")
	if unified_env:
		return unified_env
	
	# Fallback to old daylight cycle
	return get_tree().get_first_node_in_group("daylight_cycle")

func _on_time_changed(time: float, time_text: String):
	if time_label:
		time_label.text = time_text
	
	if phase_label:
		var phase = get_phase_from_time_text(time_text)
		phase_label.text = phase
	
	if speed_label and daylight_cycle:
		speed_label.text = "Speed: %.1fx" % daylight_cycle.time_speed_multiplier

func get_phase_from_time_text(time_text: String) -> String:
	if "Dawn" in time_text:
		return "🌅 Dawn"
	elif "Morning" in time_text:
		return "🌄 Morning"
	elif "Day" in time_text:
		return "☀️ Day"
	elif "Evening" in time_text:
		return "🌇 Evening"
	elif "Sunset" in time_text:
		return "🌆 Sunset"
	else:
		return "🌙 Night"
