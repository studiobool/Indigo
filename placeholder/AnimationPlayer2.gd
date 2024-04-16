extends AnimationPlayer

@onready var button = $AnimatableBody3D/MeshInstance3D/Button

func _process(delta):
	if button.is_activated:
		if button.switch:
			await play("new_animation_2")
			button.is_activated = false
			button.can_switch = true
		else:
			await play("new_animation")
			button.is_activated = false
			button.can_switch = true
