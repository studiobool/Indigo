extends CharacterBody3D

@export_category("Status")
var is_alive : bool
@export var health : int = 100
@onready var health_counter : ProgressBar
@export var monopyriac : float = 100
@onready var monopyriac_counter : ProgressBar

@export_category("Movement")
var direction : Vector3
var curr_speed : float
var is_sprint : bool
var stepped : bool
var old_vel : float
@onready var feet_audio_player = $Footstep
@export var footstep_sounds : Array[AudioStreamWAV]
@export var walk_speed : float = 3
@export var sprint_speed : float = 5.5
@export var crouch_speed : float = 1.75
@export var jump_velocity : float = 6.25
@export var rot_amount : float = 0.01375
const walk_freq = 0.0115
const sprint_freq = 0.0175
const walk_amount = 0.025
const sprint_amount = 0.05

# Variables
@onready var model = $Model
#@onready var anim_tree = $Model/AnimationTree

# Weapon holder variables
@export_category("Hand")
@onready var weapon_holder = $Head/Hand/Holder
var def_weapon_holder_pos : Vector3
var mouse_input : Vector2
var bob_amount : float = 0.02
var bob_freq : float = 0.01

# Camera variables
@onready var head = $Head
@onready var hand = $Head/Hand
@onready var headbob = $Head/Bob
@onready var fp_camera = $Head/Bob/Camera
@onready var tp_springpivot = $Pivot
@onready var tp_springarm = $Pivot/Arm
@onready var tp_camera = $Pivot/Arm/Camera

# Stand/Crouch variables
var crouching : bool
var floor_crounch : bool
@onready var stand_collision = $Normal
@onready var crouch_collision = $Crouch
@onready var stand_marker = $Marker/Normal
@onready var crouch_marker = $Marker/Crouch
@onready var crouch_detect = $CrouchDetect

# Interaction vars
@onready var interact_ray = $Head/Bob/Camera/InteractRay
@onready var grabhold_ray = $Head/Bob/Camera/GrabHoldRay
@onready var interact_indicator = $Indicators/InteractIndicator
@onready var grab_indicator = $Indicators/GrabIndicator
@onready var hold_indicator = $Indicators/HoldIndicator

# Physobj variables
@export_category("Physobj")
var physobj
var physlock : bool
var calc
@export var physpull : float = 12
@export var physrot : float = .05
@onready var physarm = $Head/Bob/Camera/PhysArm
@onready var physmarker = $Head/Bob/Camera/PhysArm/Marker
@onready var physjoint = $Head/Bob/Camera/Joint
@onready var physbody = $Head/Bob/Camera/StaticBody
@onready var physempty = $Head/Bob/Camera/PhysArm/Marker/RigidBody3D

# Gravity
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# First and third person perspective switch variables
#var view = 1

func _ready():
	view_change()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hand.set_as_top_level(true)
	physempty.set_as_top_level(true)

func _input(event):
	# Crouching
	if Input.is_action_pressed("crouch"):
		crouch()
	elif !crouch_detect.is_colliding():
		stand()
	
	if Input.is_action_just_pressed("fire"):
		if physobj:
			throw_physobj()
	
	if Input.is_action_pressed("alt_fire"):
		physlock = true
		rotate_physobj(event)
	if Input.is_action_just_released("alt_fire"):
		physlock = false

func _unhandled_input(event):
	if event is InputEventMouseMotion && is_alive:
		if !physlock:
			rotate_y(-event.relative.x * 0.004)
			tp_springarm.rotate_x(-event.relative.y * 0.004)
			tp_springarm.rotation.x = clamp(tp_springarm.rotation.x, deg_to_rad(-75), deg_to_rad(60))
			mouse_input = event.relative

func _process(delta):
	fp_camera.rotation.x = tp_springarm.rotation.x

	# Third-person camera movement
	tp_springpivot.global_rotation.y = head.global_rotation.y
	
	# First-person hand movement
	hand.global_position = head.global_position
	hand_movement(delta)
	
	if health_counter && monopyriac_counter:
		health_counter.text = str(health)
		monopyriac_counter.value = monopyriac
	
	if health >= 0:
		is_alive = true
	else:
		is_alive = false
	
	# Switch perspectives
	if Input.is_action_just_pressed("switch"):
		view_change()
	
	# Sprinting
	if Input.is_action_pressed("sprint") && Input.is_action_pressed("move_up") && !crouching:
		curr_speed = sprint_speed
	elif !crouching:
		curr_speed = walk_speed
	
	if velocity.length() > 4:
		bob_freq = sprint_freq
		bob_amount = sprint_amount
	else:
		bob_freq = walk_freq
		bob_amount = walk_amount
	
	if Input.is_action_just_pressed("test_m"):
		fill_monopyriac()
		if health <= 100 && monopyriac >= 75:
			health = 100
		elif health <= 81:
			health += 9
	
	_interaction()
	
	if Input.is_action_just_pressed("interact"):
		if physobj && !grabhold_ray.is_colliding():
			drop_physobj()
	
	#monopyriac -= delta / 2

func _physics_process(delta):
	physjoint.global_position = physmarker.global_position
	physbody.global_position = physmarker.global_position
	
	_physempty(delta)
	
	# Add the gravity.
	if !is_on_floor():
		velocity.y -= gravity * delta
	
	if is_alive:
		$Label.text = str(velocity.y) + ", " + str(velocity.length() / 5 * 2) + ", " + str(old_vel)
		$Label2.text = str(health)
	else:
		$Label.text = "Player dead."
		$Label2.text = ""
	
	# Handle Jump.
	if is_alive:
		if Input.is_action_just_pressed("jump") && is_on_floor():
			velocity.y = jump_velocity + (velocity.length() / 4)
		if Input.is_action_just_released("jump") && velocity.y >= jump_velocity / 2:
			velocity.y = (jump_velocity + (velocity.length() / 4)) / 2
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	model.global_rotation.y = lerp_angle(model.global_rotation.y, head.global_rotation.y, 12.5 * delta)
	
	move_and_slide()
	
	if health >= 0:
		movement(delta)
		cam_tilt(velocity.length(), input_dir.x, delta)
		weapon_bob(velocity.length(),delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, 10 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10 * delta)
		fp_camera.rotation.z = lerp_angle(fp_camera.rotation.z, -45.0, 7.5 * delta)
		head.global_position = lerp(head.global_position, crouch_marker.global_position, 15 * delta)
	
	var diff = velocity.y - old_vel
	if diff > 1:
		play_footstep()
	if old_vel < 0:
		if diff > 15:
			if health >= 30:
				take_damage(round(diff))
			else:
				take_damage(round(diff / 2))
	old_vel = velocity.y
	
	
	
	if crouching:
		if is_on_floor():
			floor_crounch = true
			head.global_position = lerp(head.global_position, crouch_marker.global_position, 15 * delta)
			tp_springpivot.global_position = lerp(tp_springpivot.global_position, crouch_marker.global_position, 15 * delta)
	else:
		floor_crounch = false
		head.global_position = lerp(head.global_position, stand_marker.global_position, 15 * delta)
		tp_springpivot.global_position = lerp(tp_springpivot.global_position, stand_marker.global_position, 15 * delta)

func hand_movement(delta):
	hand.global_rotation.x = lerp_angle(hand.global_rotation.x, fp_camera.global_rotation.x, 25.0 * delta)
	hand.global_rotation.y = lerp_angle(hand.global_rotation.y, fp_camera.global_rotation.y, 25.0 * delta)

func movement(delta):
	if direction && is_on_floor():
		velocity.x = lerp(velocity.x, direction.x * curr_speed, 15 * delta)
		velocity.z = lerp(velocity.z, direction.z * curr_speed, 15 * delta)
	elif is_on_floor():
		velocity.x = lerp(velocity.x, 0.0, 10 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10 * delta)
	elif direction:
		velocity.x = lerp(velocity.x, direction.x * curr_speed, 5 * delta)
		velocity.z = lerp(velocity.z, direction.z * curr_speed, 5 * delta)

func view_change():
	if !Global.view:
		Global.view = 1
		third_person()
	else:
		Global.view = 0
		first_person()

func first_person():
	tp_camera.current = false
	fp_camera.current = true

func third_person():
	tp_camera.current = true
	fp_camera.current = false

func _interaction():
	if interact_ray.is_colliding():
		if interact_ray.get_collider().has_node("Interact"):
			if Input.is_action_just_pressed("interact"):
				interact_ray.get_collider()._interact()
			if interact_ray.get_collider().can_switch:
				interact_indicator.visible = true
			else:
				interact_indicator.visible = false
		else:
			interact_indicator.visible = false
	else:
		interact_indicator.visible = false
	if grabhold_ray.is_colliding():
		if grabhold_ray.get_collider().has_node("Item"):
			grab_indicator.visible = true
			if Input.is_action_just_pressed("interact"):
				pass
			else:
				grab_indicator.visible = false
		elif grabhold_ray.get_collider().has_node("PhysObj"):
			hold_indicator.visible = true
			if Input.is_action_just_pressed("interact"):
				if !physobj:
					grab_physobj(grabhold_ray.get_collider())
				else:
					drop_physobj()
		else:
			grab_indicator.visible = false
			hold_indicator.visible = false
	else:
		grab_indicator.visible = false
		hold_indicator.visible = false

func grab_physobj(object):
	if object && object is RigidBody3D:
		physobj = object
		physjoint.set_node_b(object.get_path())

func drop_physobj():
	if physobj:
		physjoint.set_node_b(physjoint.get_path())
		physobj.linear_velocity = physempty.linear_velocity
		physobj = null

func _physempty(delta):
	var a = physempty.global_position
	var b = physmarker.global_position
	var c = a.distance_to(b)
	var _calc = (a.direction_to(b)) * physpull * c
	physempty.set_linear_velocity(_calc)

func hold_physobj(object,delta):
	if object != null:
		var a = object.global_position
		var b = physmarker.global_position
		var c = a.distance_to(b)
		calc = (a.direction_to(b)) * physpull * c
		object.set_linear_velocity(calc)

func rotate_physobj(event):
	if physobj && event is InputEventMouseMotion:
		physbody.rotate_x(deg_to_rad(event.relative.y * physrot))
		physbody.rotate_y(deg_to_rad(event.relative.x * physrot))

func throw_physobj():
	var knockback = global_position - physobj.global_position
	physobj.apply_central_impulse(-knockback)
	physjoint.set_node_b(physjoint.get_path())
	physobj = null

func cam_tilt(vel, input_x, delta):
	if vel > 0.3:
		fp_camera.rotation.z = lerp(fp_camera.rotation.z, -input_x * rot_amount * (velocity.length() / 5), 5 * delta)
		weapon_holder.rotation.z = lerp(weapon_holder.rotation.z, -input_x * rot_amount * (velocity.length() / 5), 5 * delta)
	else:
		fp_camera.rotation.z = lerp(fp_camera.rotation.z, 0.0, 7.5 * delta)
		weapon_holder.rotation.z = lerp(weapon_holder.rotation.z, 0.0, 7.5 * delta)

func weapon_bob(vel : float, delta):
	if vel > 2 and is_on_floor():
		weapon_holder.position.y = lerp(weapon_holder.position.y, def_weapon_holder_pos.y + sin(Time.get_ticks_msec() * bob_freq) * bob_amount * 2.25, 10 * delta)
		weapon_holder.position.x = lerp(weapon_holder.position.x, def_weapon_holder_pos.x + sin(Time.get_ticks_msec() * bob_freq * 0.5) * bob_amount * 2.25, 10 * delta)
		headbob.position.y = lerp(headbob.position.y, def_weapon_holder_pos.y + sin(Time.get_ticks_msec() * bob_freq) * bob_amount * 2, 10 * delta)
		headbob.position.x = lerp(headbob.position.x, def_weapon_holder_pos.x + sin(Time.get_ticks_msec() * bob_freq * 0.5) * bob_amount * 2, 10 * delta)
		can_footstep(weapon_holder.position.y)
	else:
		weapon_holder.position.y = lerp(weapon_holder.position.y, def_weapon_holder_pos.y, 10 * delta)
		weapon_holder.position.x = lerp(weapon_holder.position.x, def_weapon_holder_pos.x, 10 * delta)
		headbob.position.y = lerp(headbob.position.y, def_weapon_holder_pos.y, 10 * delta)
		headbob.position.x = lerp(headbob.position.x, def_weapon_holder_pos.x, 10 * delta)

func stand():
	crouching = false
	stand_collision.disabled = false
	crouch_collision.disabled = true

func crouch():
	crouching = true
	stand_collision.disabled = true
	crouch_collision.disabled = false
	curr_speed = crouch_speed

func take_damage(dmg):
	health -= max(dmg, 0)
	if health <= 0:
		pass# or what have you 

func fill_monopyriac():
	if monopyriac <= 25.0:
		monopyriac *= monopyriac
	else:
		monopyriac = 100.0

func can_footstep(y_value : float):
	if y_value < 0 and !stepped:
		play_footstep()
		stepped = true
	elif y_value > 0 and stepped:
		stepped = false

func play_footstep():
	var random_index : int = randi_range(0,footstep_sounds.size() - 1)
	feet_audio_player.stream = footstep_sounds[random_index]
	feet_audio_player.pitch_scale = randf_range(0.9,1.1)
	feet_audio_player.play()
