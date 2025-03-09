extends Area3D

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Transition to the next room
		print("Player entered door")
		# Implement room transition logic here