extends Node3D

signal player_entered(room)

func _ready():
	# Add to the rooms group for easy reference
	add_to_group("rooms")
	
	# Create ConnectionPoints if they don't exist
	if not has_node("ConnectionPoints"):
		var connection_points = Node3D.new()
		connection_points.name = "ConnectionPoints"
		add_child(connection_points)
		
		# Create default connection points in all 4 directions
		var directions = ["north", "south", "east", "west"]
		var positions = {
			"north": Vector3(0, 1, -10),
			"south": Vector3(0, 1, 10),
			"east": Vector3(10, 1, 0),
			"west": Vector3(-10, 1, 0)
		}
		
		for dir in directions:
			var point = Marker3D.new()
			point.name = dir
			point.position = positions[dir]
			connection_points.add_child(point)
		
		print("Created default connection points for " + name)
	
	# Set up room detection
	if has_node("RoomDetector"):
		# Connect the RoomDetector's body_entered signal directly to our _on_player_entered method
		$RoomDetector.body_entered.connect(_on_player_entered)

func _on_player_entered(body):
	if body.is_in_group("player"):
		emit_signal("player_entered", self)
		print("Player entered " + name)
