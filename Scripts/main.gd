extends Control

func _on_texture_button_pressed():
	# Change to level selection scene
	get_tree().change_scene_to_file("res://Scenes/level_selection.tscn")
