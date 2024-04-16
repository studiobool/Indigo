extends Node

var switch : bool
var can_switch : bool
@export var cam_view : int
@onready var animation = $AnimationPlayer2
@onready var cam_1 = $Camera3D
@onready var cam_2 = $Camera3D2

func _ready():
	switch = false
	can_switch = true

func _process(delta):
	$"..".can_switch = can_switch
	if Global.view:
		if cam_view == 1:
			cam_1.current = true
			cam_2.current = false
		elif cam_view == 2:
			cam_2.current = true
			cam_1.current = false
		else:
			cam_1.current = false
			cam_2.current = false
	else:
		cam_1.current = false
		cam_2.current = false

func _interact():
	if can_switch:
		if switch:
			switch = false
			can_switch = false
			animation.play("new_animation_2")
		else:
			switch = true
			can_switch = false
			animation.play("new_animation")

func _on_animation_player_2_animation_finished(anim_name):
	can_switch = true
