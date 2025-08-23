# level_select.gd
extends Control

# Map button node names to scene paths
var levels = {
	"Button1": "res://Scenes/levels/BubbleSort/bubble_sort.tscn",
	"Button2": "res://Scenes/levels/linear_search.tscn",
}

func _ready():
	# Connect each existing button to its level
	for button_name in levels:
		var button = get_node("VBoxContainer/" + button_name)
		if button:
			button.pressed.connect(_on_level_selected.bind(levels[button_name]))
		else:
			push_error("Button not found: " + button_name)

func _on_level_selected(path):
	get_tree().change_scene_to_file(path)
