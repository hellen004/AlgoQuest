extends Node


func _on_quit_button_pressed() -> void:
		get_tree().quit()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Main/GameManager.tscn")


func _on_level_select_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Main/LevelSelect.tscn")
