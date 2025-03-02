extends CanvasLayer

func _on_playbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")


func _on_quit_btn_pressed() -> void:
	get_tree().quit()
