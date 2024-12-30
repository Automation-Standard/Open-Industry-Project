@tool
# COPYRIGHT Colormatic Studios
# MIT licence
# Quality Godot First Person Controller v2


extends CharacterBody3D


## The settings for the character's movement and feel.
@export_category("Character")
## The speed that the character moves at without crouching or sprinting.
@export var base_speed : float = 3.0
## The speed that the character moves at when sprinting.
@export var sprint_speed : float = 6.0
## The speed that the character moves at when crouching.
@export var crouch_speed : float = 1.0

## How fast the character speeds up and slows down when Motion Smoothing is on.
@export var acceleration : float = 10.0
## How high the player jumps.
@export var jump_velocity : float = 4.5
## How far the player turns when the mouse is moved.
@export var mouse_sensitivity : float = 0.1
## Invert the Y input for mouse and joystick
@export var invert_mouse_y : bool = false # Possibly add an invert mouse X in the future
## Wether the player can use movement inputs. Does not stop outside forces or jumping. See Jumping Enabled.
@export var immobile : bool = false
## The reticle file to import at runtime. By default are in res://addons/fpc/reticles/. Set to an empty string to remove.
@export_file var default_reticle

@export_group("Nodes")
## The node that holds the camera. This is rotated instead of the camera for mouse input.
@export var HEAD : Node3D
@export var CAMERA : Camera3D
@export var HEADBOB_ANIMATION : AnimationPlayer
@export var JUMP_ANIMATION : AnimationPlayer
@export var CROUCH_ANIMATION : AnimationPlayer
@export var COLLISION_MESH : CollisionShape3D

@export_group("Controls")
# We are using UI controls because they are built into Godot Engine so they can be used right away
@export var JUMP : String = "ui_accept"
@export var LEFT : String = "ui_left"
@export var RIGHT : String = "ui_right"
@export var FORWARD : String = "ui_up"
@export var BACKWARD : String = "ui_down"
## By default this does not pause the game, but that can be changed in _process.
@export var PAUSE : String = "ui_cancel"
@export var CROUCH : String = "crouch"
@export var SPRINT : String = "sprint"

# Uncomment if you want controller support
#@export var controller_sensitivity : float = 0.035
#@export var LOOK_LEFT : String = "look_left"
#@export var LOOK_RIGHT : String = "look_right"
#@export var LOOK_UP : String = "look_up"
#@export var LOOK_DOWN : String = "look_down"

@export_group("Feature Settings")
## Enable or disable jumping. Useful for restrictive storytelling environments.
@export var jumping_enabled : bool = true
## Wether the player can move in the air or not.
@export var in_air_momentum : bool = true
## Smooths the feel of walking.
@export var motion_smoothing : bool = true
@export var sprint_enabled : bool = true
@export var crouch_enabled : bool = true
@export_enum("Hold to Crouch", "Toggle Crouch") var crouch_mode : int = 0
@export_enum("Hold to Sprint", "Toggle Sprint") var sprint_mode : int = 0
## Wether sprinting should effect FOV.
@export var dynamic_fov : bool = true
## If the player holds down the jump button, should the player keep hopping.
@export var continuous_jumping : bool = true
## Enables the view bobbing animation.
@export var view_bobbing : bool = true
## Enables an immersive animation when the player jumps and hits the ground.
@export var jump_animation : bool = true
## This determines wether the player can use the pause button, not wether the game will actually pause.
@export var pausing_enabled : bool = true
## Use with caution.
@export var gravity_enabled : bool = true


# Member variables
var speed : float = base_speed
var current_speed : float = 0.0
# States: normal, crouching, sprinting
var state : String = "normal"
var low_ceiling : bool = false # This is for when the cieling is too low and the player needs to crouch.
var was_on_floor : bool = true # Was the player on the floor last frame (for landing animation)

# The reticle should always have a Control node as the root
var RETICLE : Control

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity") # Don't set this as a const, see the gravity section in _physics_process

# Stores mouse input for rotating the camera in the phyhsics process
var mouseInput : Vector2 = Vector2(0,0)

func _ready():
	if Engine.is_editor_hint():
		return
		
	#It is safe to comment this line if your game doesn't start with the mouse captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# If the controller is rotated in a certain direction for game design purposes, redirect this rotation into the head.
	HEAD.rotation.y = rotation.y
	rotation.y = 0
	
	if default_reticle:
		change_reticle(default_reticle)
	
	# Reset the camera position
	# If you want to change the default head height, change these animations.
	HEADBOB_ANIMATION.play("RESET")
	JUMP_ANIMATION.play("RESET")
	CROUCH_ANIMATION.play("RESET")
	
	check_controls()

func check_controls(): # If you add a control, you might want to add a check for it here.
	# The actions are being disabled so the engine doesn't halt the entire project in debug mode
	if !InputMap.has_action(JUMP):
		push_error("No control mapped for jumping. Please add an input map control. Disabling jump.")
		jumping_enabled = false
	if !InputMap.has_action(LEFT):
		push_error("No control mapped for move left. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(RIGHT):
		push_error("No control mapped for move right. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(FORWARD):
		push_error("No control mapped for move forward. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(BACKWARD):
		push_error("No control mapped for move backward. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(PAUSE):
		push_error("No control mapped for pause. Please add an input map control. Disabling pausing.")
		pausing_enabled = false
	if !InputMap.has_action(CROUCH):
		push_error("No control mapped for crouch. Please add an input map control. Disabling crouching.")
		crouch_enabled = false
	if !InputMap.has_action(SPRINT):
		push_error("No control mapped for sprint. Please add an input map control. Disabling sprinting.")
		sprint_enabled = false


func change_reticle(reticle): # Yup, this function is kinda strange
	if RETICLE:
		RETICLE.queue_free()
	
	RETICLE = load(reticle).instantiate()
	RETICLE.character = self
	$UserInterface.add_child(RETICLE)


func _physics_process(delta):
	if get_tree().edited_scene_root == self:
		return
	# Big thanks to github.com/LorenzoAncora for the concept of the improved debug values
	current_speed = Vector3.ZERO.distance_to(get_real_velocity())
	var cv : Vector3 = get_real_velocity()
	var vd : Array[float] = [
		snappedf(cv.x, 0.001),
		snappedf(cv.y, 0.001),
		snappedf(cv.z, 0.001)
	]
	var readable_velocity : String = "X: " + str(vd[0]) + " Y: " + str(vd[1]) + " Z: " + str(vd[2])

	# Gravity
	#gravity = ProjectSettings.get_setting("physics/3d/default_gravity") # If the gravity changes during your game, uncomment this code
	if not is_on_floor() and gravity and gravity_enabled:
		velocity.y -= gravity * delta
	
	handle_jumping()
	
	var input_dir = Vector2.ZERO
	if !immobile: # Immobility works by interrupting user input, so other forces can still be applied to the player
		input_dir = Input.get_vector(LEFT, RIGHT, FORWARD, BACKWARD)
	handle_movement(delta, input_dir)

	handle_head_rotation()
	
	# The player is not able to stand up if the ceiling is too low
	low_ceiling = $CrouchCeilingDetection.is_colliding()
	
	handle_state(input_dir)
	if dynamic_fov: # This may be changed to an AnimationPlayer
		update_camera_fov()
	
	if view_bobbing:
		headbob_animation(input_dir)
	
	if jump_animation:
		if !was_on_floor and is_on_floor(): # The player just landed
			match randi() % 2: #TODO: Change this to detecting velocity direction
				0:
					JUMP_ANIMATION.play("land_left", 0.25)
				1:
					JUMP_ANIMATION.play("land_right", 0.25)
	
	was_on_floor = is_on_floor() # This must always be at the end of physics_process


func handle_jumping():
	if jumping_enabled:
		if continuous_jumping: # Hold down the jump button
			if Input.is_action_pressed(JUMP) and is_on_floor() and !low_ceiling:
				if jump_animation:
					JUMP_ANIMATION.play("jump", 0.25)
				velocity.y += jump_velocity # Adding instead of setting so jumping on slopes works properly
		else:
			if Input.is_action_just_pressed(JUMP) and is_on_floor() and !low_ceiling:
				if jump_animation:
					JUMP_ANIMATION.play("jump", 0.25)
				velocity.y += jump_velocity


func handle_movement(delta, input_dir):
	var direction = input_dir.rotated(-HEAD.rotation.y)
	direction = Vector3(direction.x, 0, direction.y)
	move_and_slide()
	
	if in_air_momentum:
		if is_on_floor():
			if motion_smoothing:
				velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
				velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)
			else:
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
	else:
		if motion_smoothing:
			velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
			velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed

func handle_head_rotation():
	HEAD.rotation_degrees.y -= mouseInput.x * mouse_sensitivity
	if invert_mouse_y:
		HEAD.rotation_degrees.x -= mouseInput.y * mouse_sensitivity * -1.0
	else:
		HEAD.rotation_degrees.x -= mouseInput.y * mouse_sensitivity
	
	# Uncomment for controller support
	#var controller_view_rotation = Input.get_vector(LOOK_DOWN, LOOK_UP, LOOK_RIGHT, LOOK_LEFT) * controller_sensitivity # These are inverted because of the nature of 3D rotation.
	#HEAD.rotation.x += controller_view_rotation.x
	#if invert_mouse_y:
		#HEAD.rotation.y += controller_view_rotation.y * -1.0
	#else:
		#HEAD.rotation.y += controller_view_rotation.y
	
	
	mouseInput = Vector2(0,0)
	HEAD.rotation.x = clamp(HEAD.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func handle_state(moving):
	if sprint_enabled:
		if sprint_mode == 0:
			if Input.is_action_pressed(SPRINT) and state != "crouching":
				if moving:
					if state != "sprinting":
						enter_sprint_state()
				else:
					if state == "sprinting":
						enter_normal_state()
			elif state == "sprinting":
				enter_normal_state()
		elif sprint_mode == 1:
			if moving:
				# If the player is holding sprint before moving, handle that cenerio
				if Input.is_action_pressed(SPRINT) and state == "normal":
					enter_sprint_state()
				if Input.is_action_just_pressed(SPRINT):
					match state:
						"normal":
							enter_sprint_state()
						"sprinting":
							enter_normal_state()
			elif state == "sprinting":
				enter_normal_state()
	
	if crouch_enabled:
		if crouch_mode == 0:
			if Input.is_action_pressed(CROUCH) and state != "sprinting":
				if state != "crouching":
					enter_crouch_state()
			elif state == "crouching" and !$CrouchCeilingDetection.is_colliding():
				enter_normal_state()
		elif crouch_mode == 1:
			if Input.is_action_just_pressed(CROUCH):
				match state:
					"normal":
						enter_crouch_state()
					"crouching":
						if !$CrouchCeilingDetection.is_colliding():
							enter_normal_state()


# Any enter state function should only be called once when you want to enter that state, not every frame.

func enter_normal_state():
	#print("entering normal state")
	var prev_state = state
	if prev_state == "crouching":
		CROUCH_ANIMATION.play_backwards("crouch")
	state = "normal"
	speed = base_speed

func enter_crouch_state():
	#print("entering crouch state")
	var prev_state = state
	state = "crouching"
	speed = crouch_speed
	CROUCH_ANIMATION.play("crouch")

func enter_sprint_state():
	#print("entering sprint state")
	var prev_state = state
	if prev_state == "crouching":
		CROUCH_ANIMATION.play_backwards("crouch")
	state = "sprinting"
	speed = sprint_speed


func update_camera_fov():
	if state == "sprinting":
		CAMERA.fov = lerp(CAMERA.fov, 85.0, 0.3)
	else:
		CAMERA.fov = lerp(CAMERA.fov, 75.0, 0.3)


func headbob_animation(moving):
	if moving and is_on_floor():
		var use_headbob_animation : String
		match state:
			"normal","crouching":
				use_headbob_animation = "walk"
			"sprinting":
				use_headbob_animation = "sprint"
		
		var was_playing : bool = false
		if HEADBOB_ANIMATION.current_animation == use_headbob_animation:
			was_playing = true
		
		HEADBOB_ANIMATION.play(use_headbob_animation, 0.25)
		HEADBOB_ANIMATION.speed_scale = (current_speed / base_speed) * 1.75
		if !was_playing:
			HEADBOB_ANIMATION.seek(float(randi() % 2)) # Randomize the initial headbob direction
			# Let me explain that piece of code because it looks like it does the opposite of what it actually does.
			# The headbob animation has two starting positions. One is at 0 and the other is at 1.
			# randi() % 2 returns either 0 or 1, and so the animation randomly starts at one of the starting positions.
			# This code is extremely performant but it makes no sense.
		
	else:
		if HEADBOB_ANIMATION.current_animation == "sprint" or HEADBOB_ANIMATION.current_animation == "walk":
			HEADBOB_ANIMATION.speed_scale = 1
			HEADBOB_ANIMATION.play("RESET", 1)


func _process(delta):
	var status : String = state
	if !is_on_floor():
		status += " in the air"
	
	if pausing_enabled:
		if Input.is_action_just_pressed(PAUSE):
			# You may want another node to handle pausing, because this player may get paused too.
			match Input.mouse_mode:
				Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					#get_tree().paused = false
				Input.MOUSE_MODE_VISIBLE:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					#get_tree().paused = false


func _unhandled_input(event : InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouseInput.x += event.relative.x
		mouseInput.y += event.relative.y
	# Toggle debug menu
	elif event is InputEventKey:
		if event.is_released():
			# Where we're going, we don't need InputMap
			if event.keycode == 4194338: # F7
				$UserInterface/DebugPanel.visible = !$UserInterface/DebugPanel.visible
