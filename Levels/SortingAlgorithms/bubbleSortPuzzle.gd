extends Node2D

@export var bottle_values := [8, 4, 1, 6, 3, 5, 2, 7]
@onready var potion_bottles := [
	$PotionBottles/Bottle1,
	$PotionBottles/Bottle2,
	$PotionBottles/Bottle3,
	$PotionBottles/Bottle4,
	$PotionBottles/Bottle5,
	$PotionBottles/Bottle6,
	$PotionBottles/Bottle7,
	$PotionBottles/Bottle8
]  # Changed to PotionBottles (plural)
@onready var counter_label = $CanvasLayer/CounterLabel

var current_index := 0
var swap_count := 0
var pass_count := 1
var is_sorted := false

func _ready():
	print("Checking all bottles:")
	for i in min(bottle_values.size(), potion_bottles.size()):
		var bottle = potion_bottles[i]
		print("Bottle ", i+i, ":")
		print("- Type: ", bottle.get_class_name())
		print("- Has script: ", bottle.get_script() != null)
		
		if bottle.get_script() == preload("res://Main/Levels/BubbleSort/PotionBottle.gd"):
			bottle.value = bottle_values[i]
		else:
			var new_bottle = preload("res://Main/Levels/BubbleSort/PotionBottle.tscn").instantiate()
			new_bottle.position = bottle.position
			$PotionBottle.remove_child(bottle)
			$PotionBottle.add_child(new_bottle)
			new_bottle.value = bottle_values[i]
			potion_bottles[i] = new_bottle
			print("Replaced invalid bottle at index", i)
			
	print("--- Bottle Setup Complete ---")

func _on_next_button_pressed():
	if is_sorted:
		return
		
	if current_index < bottle_values.size() - pass_count:
		# Highlight current pair
		potion_bottles[current_index].highlight()
		potion_bottles[current_index + 1].highlight()
		
		# Compare values
		if bottle_values[current_index] > bottle_values[current_index + 1]:
			swap_bottles(current_index)
		
		current_index += 1
	else:
		# End of pass
		current_index = 0
		pass_count += 1
		check_sorted()  # Check if fully sorted
	
	update_counter()

func swap_bottles(index: int):
	# Manual swap since Godot 4 doesn't have Array.swap()
	var temp = bottle_values[index]
	bottle_values[index] = bottle_values[index + 1]
	bottle_values[index + 1] = temp
	
	# Update bottle values
	potion_bottles[index].value = bottle_values[index]
	potion_bottles[index + 1].value = bottle_values[index + 1]
	
	# Animate movement
	var bottle_left_pos = potion_bottles[index].position
	var bottle_right_pos = potion_bottles[index + 1].position
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(potion_bottles[index], "position", bottle_right_pos, 0.3)
	tween.tween_property(potion_bottles[index + 1], "position", bottle_left_pos, 0.3)
	
	swap_count += 1

func update_counter():
	counter_label.text = "Swaps: %d | Pass: %d" % [swap_count, pass_count]
	for bottle in potion_bottles:
		bottle.unhighlight()

func check_sorted():
	is_sorted = true
	for i in bottle_values.size() - 1:
		if bottle_values[i] > bottle_values[i + 1]:
			is_sorted = false
			break
	
	if is_sorted:
		$CanvasLayer/DialogBox.show_text("Sorted in %d passes and %d swaps!" % [pass_count-1, swap_count])
		$CanvasLayer/LevelComplete.show()
		GameManager.unlock_next_level()
