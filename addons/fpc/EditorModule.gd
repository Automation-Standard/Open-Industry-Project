@tool
extends Node

# This does not effect runtime yet but will in the future.

@export_category("Controller Editor Module")
@export_range(-360.0, 360.0, 0.01, "or_greater", "or_less") var head_y_rotation : float = 0.0:
	set(new_rotation):
		if HEAD:
			head_y_rotation = new_rotation
			HEAD.rotation.y = deg_to_rad(head_y_rotation)
			update_configuration_warnings()
@export_range(-90.0, 90.0, 0.01, "or_greater", "or_less") var head_x_rotation : float = 0.0:
	set(new_rotation):
		if HEAD:
			head_x_rotation = new_rotation
			HEAD.rotation.x = deg_to_rad(head_x_rotation)
			update_configuration_warnings()

@export_group("Nodes")
@export var CHARACTER : CharacterBody3D
@export var head_path : String = "Head" # Relative to the parent node
#@export var CAMERA : Camera3D
#@export var HEADBOB_ANIMATION : AnimationPlayer
#@export var JUMP_ANIMATION : AnimationPlayer
#@export var CROUCH_ANIMATION : AnimationPlayer
#@export var COLLISION_MESH : CollisionShape3D

@onready var HEAD = get_node("../" + head_path)


func _ready():
	if !Engine.is_editor_hint():
		print("not editor")
		HEAD.rotation.y = deg_to_rad(head_y_rotation)
		HEAD.rotation.x = deg_to_rad(head_x_rotation)


func _get_configuration_warnings():
	var warnings = []

	if head_y_rotation > 360:
		warnings.append("The head rotation is greater than 360")
	
	if head_y_rotation < -360:
		warnings.append("The head rotation is less than -360")

	# Returning an empty array gives no warnings
	return warnings
