extends Node2D

@onready var dialog_box: Control = $DialogBox
@onready var dialog_label: Label = $DialogBox/Label
@onready var wizard_sprite: Sprite2D = $AlgoWiz
@onready var reset_button: TextureButton = $UIElements/UIContainer/ResetButton
@onready var back_button: TextureButton = $UIElements/UIContainer/BackButton
@onready var skip_button: TextureButton = $UIElements/UIContainer/SkipButton

@export var number_element_scene: PackedScene

const ARRAY_SIZE: int = 5
const ELEMENT_WIDTH: int = 150  # Adjust based on your sprite size
const ELEMENT_SPACING: int = 20
const START_X: int = 300  # Adjust for centering if needed
const START_Y: int = 563

var current_array: Array[int] = []
var number_elements: Array[Area2D] = []
var selected_element: Area2D = null
var moves_count: int = 0
var is_interactive: bool = false
var debug_color_rects: Array[ColorRect] = []

# Bubble Sort state tracking
var current_pass: int = 0
var next_expected_index: int = 0  # The index we expect player to start from
var swaps_made_this_pass: int = 0
var is_pass_complete: bool = false
var tutorial_skipped: bool = false

# ---------------- Timer / Best-time state ----------------
var timer_label: Label = null  # Optional HUD label: UIElements/UIContainer/TimerLabel
var puzzle_start_ms: int = 0
var puzzle_elapsed_ms: int = 0
var timer_running: bool = false
var best_time_ms: int = -1
const SAVE_PATH := "user://algoquest.save"

func _ready() -> void:
	randomize()
	# Optional label lookup (safe if it doesn't exist)
	timer_label = get_node_or_null("UIElements/UIContainer/TimerLabel") as Label

	# Connect buttons safely
	if not reset_button.pressed.is_connected(_on_reset_button_pressed):
		reset_button.pressed.connect(_on_reset_button_pressed)
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

	load_best_time()
	update_timer_label(0)

	generate_new_puzzle()
	show_dialog_sequence()

func generate_new_puzzle() -> void:
	clear_elements()

	# Reset timer state for new puzzle
	timer_running = false
	puzzle_elapsed_ms = 0
	update_timer_label(0)

	# Reset bubble sort state
	current_pass = 0
	next_expected_index = 0
	swaps_made_this_pass = 0
	is_pass_complete = false

	# Generate unique random numbers
	current_array.clear()
	while current_array.size() < ARRAY_SIZE:
		var rand_num = randi_range(1, 99)
		if not current_array.has(rand_num):
			current_array.append(rand_num)
	current_array.shuffle()

	for i in range(ARRAY_SIZE):
		var element: Area2D = number_element_scene.instantiate()
		element.element_index = i
		element.position = Vector2(START_X + i * (ELEMENT_WIDTH + ELEMENT_SPACING), START_Y)
		add_child(element)
		number_elements.append(element)

		element.set_number(current_array[i])
		element.set_random_texture()

	moves_count = 0
	highlight_expected_pair()

func clear_elements() -> void:
	for element in number_elements:
		element.queue_free()
	number_elements.clear()
	for rect in debug_color_rects:
		rect.queue_free()
	debug_color_rects.clear()

func highlight_expected_pair() -> void:
	# Clear all highlights first
	for element in number_elements:
		element.highlight(false)
	
	# Highlight the next expected pair if we're not done
	if next_expected_index < ARRAY_SIZE - 1 - current_pass and next_expected_index < number_elements.size() - 1:
		if number_elements[next_expected_index] and is_instance_valid(number_elements[next_expected_index]):
			number_elements[next_expected_index].modulate = Color(1.2, 1.2, 0.8)  # Slight yellow tint
		if number_elements[next_expected_index + 1] and is_instance_valid(number_elements[next_expected_index + 1]):
			number_elements[next_expected_index + 1].modulate = Color(1.2, 1.2, 0.8)

func _on_element_clicked(element: Area2D) -> void:
	if not is_interactive:
		return

	if selected_element == null:
		selected_element = element
		element.highlight(true)
	else:
		if selected_element == element:
			selected_element.highlight(false)
			selected_element = null
			return

		var first_index = min(selected_element.element_index, element.element_index)
		var second_index = max(selected_element.element_index, element.element_index)

		# Check if they selected adjacent elements
		if second_index - first_index != 1:
			await show_dialog("You can only swap adjacent pairs!")
			selected_element.highlight(false)
			selected_element = null
			return

		# BUBBLE SORT LOGIC: Check if they're starting from the correct position
		if first_index != next_expected_index:
			var pass_text = ""
			if current_pass == 0:
				pass_text = "first pass"
			else:
				pass_text = "pass " + str(current_pass + 1)
			
			await show_dialog("In Bubble Sort, you must start from the beginning!\nFor the " + pass_text + ", start comparing from index 0.")
			selected_element.highlight(false)
			selected_element = null
			return

		# Check if swap is needed
		var val1 = current_array[first_index]
		var val2 = current_array[second_index]
		
		if val1 > val2:
			# Swap needed
			swap_elements(first_index, second_index)
			swaps_made_this_pass += 1
			moves_count += 1
		else:
			# No swap needed, but still valid move in bubble sort
			await show_dialog("Good! These elements are already in order.")

		# Move to next expected index
		next_expected_index += 1
		
		# Check if we've completed this pass
		var max_index_for_pass = ARRAY_SIZE - 1 - current_pass
		if next_expected_index >= max_index_for_pass:
			await complete_pass()
		else:
			highlight_expected_pair()

		selected_element.highlight(false)
		selected_element = null

func complete_pass() -> void:
	current_pass += 1
	
	# Clear highlights
	for element in number_elements:
		element.modulate = Color.WHITE
	
	if swaps_made_this_pass == 0:
		# No swaps made - array is sorted!
		await show_dialog("Pass " + str(current_pass) + " complete with no swaps!\nArray is sorted!")
		check_win_condition()
	elif is_array_sorted():
		# Array happens to be sorted
		await show_dialog("Pass " + str(current_pass) + " complete!\nArray is now sorted!")
		check_win_condition()
	else:
		# Continue to next pass
		await show_dialog("Pass " + str(current_pass) + " complete!\nStarting pass " + str(current_pass + 1) + "...")
		next_expected_index = 0
		swaps_made_this_pass = 0
		highlight_expected_pair()

func is_array_sorted() -> bool:
	for i in range(current_array.size() - 1):
		if current_array[i] > current_array[i + 1]:
			return false
	return true

func swap_elements(i: int, j: int) -> void:
	var temp = current_array[i]
	current_array[i] = current_array[j]
	current_array[j] = temp

	var element_i = number_elements[i]
	var element_j = number_elements[j]

	element_i.element_index = j
	element_j.element_index = i
	number_elements[i] = element_j
	number_elements[j] = element_i

	var start_i = element_i.position
	var start_j = element_j.position
	var end_i = start_j
	var end_j = start_i
	var control_point_y = START_Y - 100

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(animate_arc.bind(element_i, start_i, end_i, control_point_y), 0.0, 1.0, 0.5)
	tween.tween_method(animate_arc.bind(element_j, start_j, end_j, control_point_y), 0.0, 1.0, 0.5)
	await tween.finished

	element_i.position = end_i
	element_j.position = end_j
	element_i.scale = Vector2.ONE
	element_j.scale = Vector2.ONE

func animate_arc(progress: float, element: Area2D, start_pos: Vector2, end_pos: Vector2, control_y: float) -> void:
	var mid_x = (start_pos.x + end_pos.x) / 2.0
	var t = progress
	var inv = 1.0 - t
	var pos_x = inv * inv * start_pos.x + 2.0 * inv * t * mid_x + t * t * end_pos.x
	var pos_y = inv * inv * start_pos.y + 2.0 * inv * t * control_y + t * t * end_pos.y
	element.position = Vector2(pos_x, pos_y)

	var scale_factor = 1.0 + sin(t * PI) * 0.2
	element.scale = Vector2(scale_factor, scale_factor)

func check_win_condition() -> void:
	if is_array_sorted():
		is_interactive = false
		var elapsed_ms = stop_puzzle_timer()

		# Build win message with timing + best
		var message := "Excellent! You've sorted the array using proper Bubble Sort technique!\nPasses completed: %d\nTime: %s" % [current_pass, format_ms(elapsed_ms)]
		if best_time_ms < 0 or elapsed_ms < best_time_ms:
			best_time_ms = elapsed_ms
			save_best_time()
			message += "\nNew Best!"
		elif best_time_ms >= 0:
			message += "\nBest: %s" % format_ms(best_time_ms)

		await show_dialog(message)
		celebrate_win()

		for element in number_elements:
			element.modulate = Color.WHITE

func celebrate_win() -> void:
	for element in number_elements:
		var tween = create_tween()
		tween.tween_property(element, "position:y", element.position.y - 50, 0.3).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(element, "position:y", element.position.y, 0.3).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(element, "modulate", Color(1, 1, 0), 0.5)
		tween.tween_property(element, "modulate", Color.WHITE, 0.5)

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
	# Randomly pick 1-2 animations from the three above
	var choices: Array[Callable] = [
		Callable(self, "animate_wizard_talk"),
		Callable(self, "animate_wizard_glow"),
		Callable(self, "animate_wizard_wiggle")
	]
	choices.shuffle()
	var count := randi_range(1, 2)
	for i in range(count):
		choices[i].call()

# ---------------- Dialog Handling ----------------
func show_dialog_sequence() -> void:
	var dialogs = [
		"Welcome to Bubble Sort!",
		"In Bubble Sort, we make multiple passes through the array.",
		"Each pass starts from the beginning (index 0).",
		"We compare adjacent elements and swap if out of order.",
		"Continue until a full pass is made with no swaps.",
		"The highlighted elements show where to start!"
	]
	for dialog in dialogs:
		await show_dialog(dialog)
		await get_tree().create_timer(0.5).timeout
	is_interactive = true
	start_puzzle_timer()

func show_dialog(text: String) -> void:
	dialog_label.text = text
	dialog_box.visible = true

	# Randomize wizard animations for this line
	play_random_wizard_animations()

	var m = dialog_box.modulate
	m.a = 0.0
	dialog_box.modulate = m

	var fade_in = get_tree().create_tween()
	fade_in.tween_property(dialog_box, "modulate:a", 1.0, 0.5)
	await fade_in.finished

	await get_tree().create_timer(2.0).timeout

	var fade_out = get_tree().create_tween()
	fade_out.tween_property(dialog_box, "modulate:a", 0.0, 0.5)
	await fade_out.finished

	dialog_box.visible = false

# ---------------- Timer Helpers ----------------
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
	cfg.set_value("bubble_sort", "best_time_ms", best_time_ms)
	cfg.save(SAVE_PATH)

func load_best_time() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err == OK:
		best_time_ms = int(cfg.get_value("bubble_sort", "best_time_ms", -1))
	else:
		best_time_ms = -1

# ---------------- Buttons / Input ----------------
func _on_reset_button_pressed() -> void:
	selected_element = null
	is_interactive = false
	tutorial_skipped = false  # Reset tutorial state

	# Hide any dialog and reset its alpha
	if dialog_box:
		dialog_box.visible = false
		var m = dialog_box.modulate
		m.a = 0.0
		dialog_box.modulate = m

	generate_new_puzzle()
	await show_dialog("Start from the beginning! Compare adjacent elements from left to right.")
	is_interactive = true
	start_puzzle_timer()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_selection.tscn")

func _on_skip_button_pressed() -> void:
	tutorial_skipped = true
	is_interactive = true
	start_puzzle_timer()
	
	# Hide dialog immediately
	if dialog_box:
		dialog_box.visible = false
		var m = dialog_box.modulate
		m.a = 0.0
		dialog_box.modulate = m
	
	# Hide skip button
	if skip_button:
		skip_button.visible = false
	
	print("Tutorial skipped - starting gameplay")

# Fallback input from basic (for debug/fix)
func _input(event: InputEvent) -> void:
	if not is_interactive:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
	   (event is InputEventScreenTouch and event.pressed):
		var click_pos = event.position
		for element in number_elements:
			var local_pos = element.to_local(click_pos)
			var rect = element.get_node("Sprite2D").get_rect()  # Adjust if sprite name differs
			if rect.has_point(local_pos):
				_on_element_clicked(element)
				break

# Update HUD timer every frame (if label exists)
func _process(_delta):
	if timer_running:
		var now := Time.get_ticks_msec()
		puzzle_elapsed_ms = now - puzzle_start_ms
		update_timer_label(puzzle_elapsed_ms)
