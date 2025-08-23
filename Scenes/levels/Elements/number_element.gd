extends Area2D

@onready var number_label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

var element_index: int = 0

func _ready() -> void:
	if not number_label:
		push_error("NumberElement missing Label child!")
		var new_label = Label.new()
		new_label.name = "Label"
		add_child(new_label)
		number_label = new_label
	if not collision:
		push_error("NumberElement missing CollisionPolygon2D!")
	
	# Ensure input properties (fix for input issues)
	input_pickable = true
	monitoring = true
	monitorable = true
	
	# Debug print
	print("Element ready at index: ", element_index)

func set_number(number: int) -> void:
	number_label.text = str(number)
	number_label.add_theme_font_size_override("font_size", 48)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func set_random_texture() -> void:
	# New: Varied sprites like basic (assume block1-5.png exist)
	var rand_variant = randi_range(1, 5)  # Adjust if more/less variants
	var texture_path = "res://assets/block" + str(rand_variant) + ".png"
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	else:
		print("Texture not found: ", texture_path, " - using default")

func highlight(active: bool) -> void:
	# Integrated from basic: Green glow on select, with scale
	if active:
		modulate = Color(0.5, 1.0, 0.5)  # Green
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
	else:
		modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
	   (event is InputEventScreenTouch and event.pressed):
		print("Input event detected on element: ", element_index)  # Debug to confirm signal
		get_parent()._on_element_clicked(self)
