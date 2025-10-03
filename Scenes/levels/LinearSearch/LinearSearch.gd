extends Node2D

@onready var dialog_box: Control = $DialogBox
@onready var dialog_label: Label = $DialogBox/Label
@onready var wizard_sprite: Sprite2D = $AlgoWiz
@onready var reset_button: TextureButton = $UIElements/UIContainer/ResetButton
@onready var back_button: TextureButton = $UIElements/UIContainer/BackButton
@onready var skip_button: TextureButton = $UIElements/UIContainer/SkipButton
@onready var target_label: Label = $TargetDisplay/TargetLabel
@onready var current_pointer: Sprite2D = $CurrentPointer

@export var number_element_scene: PackedScene

const ARRAY_SIZE: int = 8
const ELEMENT_WIDTH: int = 120
const ELEMENT_SPACING: int = 20
const START_X: int = 350
const START_Y: int = 200

var current_array: Array[int] = []
var number_elements: Array[Area2D] = []
var target_number: int = 0
var current_index: int = 0
var found_index: int = -1
var search_complete: bool = false
var is_interactive: bool = false
var steps_taken: int = 0
var tutorial_skipped: bool = false

# Track which numbers have been revealed (linear search specific)
var revealed_elements: Array[bool] = []

# Timer state
var timer_label: Label = null
var puzzle_start_ms: int = 0
var puzzle_elapsed_ms: int = 0
var timer_running: bool = false
var best_time_ms: int = -1
const SAVE_PATH := "user://algoquest.save"

func _ready() -> void:
	randomize()
	timer_label = get_node_or_null("UIElements/UIContainer/TimerLabel") as Label

	# Connect buttons
	if not reset_button.pressed.is_connected(_on_reset_button_pressed):
		reset_button.pressed.connect(_on_reset_button_pressed)
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)
	if skip_button and not skip_button.pressed.is_connected(_on_skip_button_pressed):
		skip_button.pressed.connect(_on_skip_button_pressed)

	load_best_time()
	update_timer_label(0)

	generate_new_puzzle()
	show_dialog_sequence()

func generate_new_puzzle() -> void:
	clear_elements()
	
	# Reset search state
	current_index = 0
	found_index = -1
	search_complete = false
	steps_taken = 0
	tutorial_skipped = false
	timer_running = false
	puzzle_elapsed_ms = 0
	update_timer_label(0)
	
	# Initialize revealed state for all elements
	revealed_elements.clear()
	for i in range(ARRAY_SIZE):
		revealed_elements.append(false)

	# Generate array with random numbers
	current_array.clear()
	for i in range(ARRAY_SIZE):
		current_array.append(randi_range(1, 99))

	# Choose target - sometimes in array, sometimes not
	if randi_range(0, 1) == 0:  # 1/2 chance target not in array
		target_number = randi_range(50, 100)  # Number not in array
	else:
		target_number = current_array[randi_range(0, current_array.size())]  # Pick from array

	# Create visual elements
	for i in range(ARRAY_SIZE):
		var element: Area2D = number_element_scene.instantiate()
		element.element_index = i
		element.position = Vector2(START_X + i * (ELEMENT_WIDTH + ELEMENT_SPACING), START_Y)
		add_child(element)
		number_elements.append(element)
		
		# Set the actual number but then hide it
		element.set_number(current_array[i])
		element.set_random_texture()
		# Hide the number by changing the label text to "?"
		hide_element_number(element)

	# Setup target display
	target_label.text = "Find: " + str(target_number)
	
	# Position pointer at first element
	update_pointer_position()
	update_visual_state()

	# Show skip button
	if skip_button:
		skip_button.visible = not tutorial_skipped

# Hide a specific element's number (linear search specific)
func hide_element_number(element: Area2D) -> void:
	var label = element.get_node("Label") as Label
	if label:
		label.text = "?"

# Reveal a specific element's number (linear search specific)
func reveal_element_number(element: Area2D) -> void:
	var label = element.get_node("Label") as Label
	if label:
		var actual_number = current_array[element.element_index]
		label.text = str(actual_number)
		revealed_elements[element.element_index] = true

# Check if an element's number is revealed
func is_element_revealed(index: int) -> bool:
	if index >= 0 and index < revealed_elements.size():
		return revealed_elements[index]
	return false

# Reveal all numbers (for end of search)
func reveal_all_numbers() -> void:
	for i in range(number_elements.size()):
		if not is_element_revealed(i):
			reveal_element_number(number_elements[i])

func clear_elements() -> void:
	for element in number_elements:
		if element and is_instance_valid(element):
			element.queue_free()
	number_elements.clear()
	revealed_elements.clear()

func update_pointer_position() -> void:
	if current_index < number_elements.size():
		var element_pos = number_elements[current_index].position
		current_pointer.position = Vector2(element_pos.x, element_pos.y - 80)
		current_pointer.visible = true
	else:
		current_pointer.visible = false

func update_visual_state() -> void:
	for i in range(number_elements.size()):
		var element = number_elements[i]
		if i < current_index:
			# Already checked - dim it
			element.modulate = Color(0.5, 0.5, 0.5)
		elif i == current_index and not search_complete:
			# Currently checking - highlight
			element.modulate = Color(1.2, 1.2, 0.8)
		else:
			# Not yet checked
			element.modulate = Color.WHITE

func _on_element_clicked(element: Area2D) -> void:
	if not is_interactive or search_complete:
		return

	var clicked_index = element.element_index

	# Check if clicked correct element
	if clicked_index != current_index:
		await show_dialog("Linear search checks elements in order! Click the highlighted element (index " + str(current_index) + ").")
		return

	# Reveal the number when clicked (linear search specific behavior)
	reveal_element_number(element)
	
	# Add a small delay to show the revealed number before continuing
	await get_tree().create_timer(0.5).timeout
	
	# Check current element
	check_current_element()

func check_current_element() -> void:
	if current_index >= current_array.size():
		return

	steps_taken += 1
	var current_value = current_array[current_index]
	
	if current_value == target_number:
		# Found the target!
		found_index = current_index
		search_complete = true
		# Highlight the found element with a special color
		number_elements[current_index].modulate = Color(0.2, 1.0, 0.2)  # Green
		await show_dialog("Found! Target " + str(target_number) + " is at index " + str(current_index) + "!")
		handle_search_complete()
	else:
		# Not found, continue searching
		await show_dialog("Checking index " + str(current_index) + ": " + str(current_value) + " ≠ " + str(target_number) + ". Continue searching...")
		current_index += 1
		
		if current_index >= current_array.size():
			# Reached end without finding target
			search_complete = true
			await show_dialog("Search complete! Target " + str(target_number) + " is not in the array.")
			handle_search_complete()
		else:
			update_pointer_position()
			update_visual_state()

func handle_search_complete() -> void:
	is_interactive = false
	var elapsed_ms = stop_puzzle_timer()
	
	# Reveal all remaining numbers for final view
	reveal_all_numbers()
	
	# Build completion message
	var message = ""
	if found_index >= 0:
		message = "Success! Found " + str(target_number) + " at index " + str(found_index) + "!\n"
	else:
		message = "Target not found after checking all elements.\n"
	
	message += "Steps taken: " + str(steps_taken) + "\n"
	message += "Time: " + format_ms(elapsed_ms) + "\n"
	
	# Algorithm analysis
	message += "\nLinear Search Analysis:\n"
	message += "• Time Complexity: O(n)\n"
	if found_index >= 0:
		message += "• Found in " + str(steps_taken) + "/" + str(ARRAY_SIZE) + " steps\n"
	else:
		message += "• Worst case: checked all " + str(ARRAY_SIZE) + " elements\n"
	
	# Best time tracking
	if best_time_ms < 0 or elapsed_ms < best_time_ms:
		best_time_ms = elapsed_ms
		save_best_time()
		message += "New Best Time!"
	elif best_time_ms >= 0:
		message += "Best: " + format_ms(best_time_ms)

	await show_dialog(message)
	celebrate_completion()

func celebrate_completion() -> void:
	if found_index >= 0:
		# Celebrate found element
		var element = number_elements[found_index]
		var tween = create_tween()
		tween.tween_property(element, "position:y", element.position.y - 50, 0.5).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(element, "position:y", element.position.y, 0.5).set_trans(Tween.TRANS_BOUNCE)

# ---------------- Dialog and Tutorial ----------------
func show_dialog_sequence() -> void:
	if tutorial_skipped:
		is_interactive = true
		start_puzzle_timer()
		if skip_button:
			skip_button.visible = false
		return

	if skip_button:
		skip_button.visible = true

	var dialogs = [
		"Welcome to Linear Search with Hidden Numbers!",
		"Numbers are hidden behind '?' symbols.",
		"Click elements in order to reveal their values.",
		"We search for the target: " + str(target_number),
		"Start from index 0 and check elements sequentially.",
		"Click the highlighted element to reveal and check it!"
	]
	
	for dialog in dialogs:
		if tutorial_skipped:
			break
		await show_dialog(dialog)
		if tutorial_skipped:
			break
		await get_tree().create_timer(0.5).timeout
	
	if not tutorial_skipped:
		is_interactive = true
		start_puzzle_timer()
	
	if skip_button:
		skip_button.visible = false

func show_dialog(text: String) -> void:
	if tutorial_skipped:
		return
		
	dialog_label.text = text
	dialog_box.visible = true
	play_random_wizard_animations()

	var m = dialog_box.modulate
	m.a = 0.0
	dialog_box.modulate = m

	var fade_in = get_tree().create_tween()
	fade_in.tween_property(dialog_box, "modulate:a", 1.0, 0.5)
	await fade_in.finished

	await get_tree().create_timer(3.0).timeout  # Longer for more text

	var fade_out = get_tree().create_tween()
	fade_out.tween_property(dialog_box, "modulate:a", 0.0, 0.5)
	await fade_out.finished

	dialog_box.visible = false

# ---------------- Wizard Animations ----------------
func animate_wizard_talk() -> void:
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(wizard_sprite, "position:y", wizard_sprite.position.y - 10, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(wizard_sprite, "position:y", wizard_sprite.position.y, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func animate_wizard_glow() -> void:
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(wizard_sprite, "modulate", Color(1, 1, 0.8), 0.5)
	tween.tween_property(wizard_sprite, "modulate", Color(1, 1, 1), 0.5)

func animate_wizard_wiggle() -> void:
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(wizard_sprite, "rotation_degrees", 5, 0.2)
	tween.tween_property(wizard_sprite, "rotation_degrees", -5, 0.2)
	tween.tween_property(wizard_sprite, "rotation_degrees", 0, 0.2)

func play_random_wizard_animations() -> void:
	var choices: Array[Callable] = [
		Callable(self, "animate_wizard_talk"),
		Callable(self, "animate_wizard_glow"),
		Callable(self, "animate_wizard_wiggle")
	]
	choices.shuffle()
	var count := randi_range(1, 2)
	for i in range(count):
		choices[i].call()

# ---------------- Timer Functions ----------------
func start_puzzle_timer() -> void:
	puzzle_start_ms = Time.get_ticks_msec()
	timer_running = true

func stop_puzzle_timer() -> int:
	if not timer_running:
		return puzzle_elapsed_ms
	timer_running = false
	puzzle_elapsed_ms = Time.get_ticks_msec() - puzzle_start_ms
	update_timer_label(puzzle_elapsed_ms)
	return puzzle_elapsed_ms

func format_ms(ms: int) -> String:
	var seconds := float(ms) / 1000.0
	return "%.2f s" % seconds

func update_timer_label(ms: int) -> void:
	if timer_label:
		var text := "Time: %s" % format_ms(ms)
		if best_time_ms >= 0:
			text += "  (Best: %s)" % format_ms(best_time_ms)
		timer_label.text = text

func save_best_time() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("linear_search", "best_time_ms", best_time_ms)
	cfg.save(SAVE_PATH)

func load_best_time() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err == OK:
		best_time_ms = int(cfg.get_value("linear_search", "best_time_ms", -1))
	else:
		best_time_ms = -1

# ---------------- Button Handlers ----------------
func _on_reset_button_pressed() -> void:
	is_interactive = false
	tutorial_skipped = false

	if dialog_box:
		dialog_box.visible = false
		var m = dialog_box.modulate
		m.a = 0.0
		dialog_box.modulate = m

	generate_new_puzzle()
	await show_dialog("New search puzzle generated! Click the highlighted elements in order to reveal and search.")
	is_interactive = true
	start_puzzle_timer()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_selection.tscn")

func _on_skip_button_pressed() -> void:
	tutorial_skipped = true
	is_interactive = true
	start_puzzle_timer()
	
	if dialog_box:
		dialog_box.visible = false
		var m = dialog_box.modulate
		m.a = 0.0
		dialog_box.modulate = m
	
	if skip_button:
		skip_button.visible = false

# Update timer display
func _process(_delta):
	if timer_running:
		var now := Time.get_ticks_msec()
		puzzle_elapsed_ms = now - puzzle_start_ms
		update_timer_label(puzzle_elapsed_ms)
