extends Control

@export var value: int = 0
@export var potion_texture: Texture

signal selected(potion: Node)
class_name PotionBottle

func _ready():
	$ValueLabel.text = str(value)
	if potion_texture:
		$Icon.texture = potion_texture
	connect("gui_input", self, "_on_input")

func _on_input(event):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("selected", self)

func swap_with(other: PotionBottle):
	# Swap values
	var temp = self.value
	self.value = other.value
	other.value = temp

	# Swap textures
	var temp_texture = self.potion_texture
	self.potion_texture = other.potion_texture
	other.potion_texture = temp_texture

	# Update display on self
	$ValueLabel.text = str(self.value)
	$Icon.texture = potion_texture

	# Update display on other potion
	other.get_node("ValueLabel").text = str(other.value)
	other.get_node("Icon").texture = other.potion_texture
