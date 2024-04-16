extends Area3D

var can_switch : bool
@onready var interact = $Interact

func _interact():
	interact._interact()
