@tool
extends EditorPlugin

var character_spawned := false
var preview_mode : CheckBox
var character : CharacterBody3D
var rotation_gizmo: Control
var menu: MenuButton
var right_navigation_gizmo: Control
var left_navigation_gizmo: Control

func _enter_tree() -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	
	if not editor_settings.get_shortcut("Open Industry Project/Spawn Character"):
		var spawn_shortcut := Shortcut.new()
		var key_stroke := InputEventKey.new()
		key_stroke.keycode = KEY_R
		key_stroke.shift_pressed = true
		spawn_shortcut.events.append(key_stroke)
		editor_settings.add_shortcut("Open Industry Project/Spawn Character", spawn_shortcut)
		
	ProjectSettings.set_setting("addons/walk_mode/character/path", "res://addons/fpc/character.tscn")
	set_input_event_forwarding_always_enabled() 
	
func _forward_3d_gui_input(_camera: Camera3D, event: InputEvent):	
	var root := EditorInterface.get_edited_scene_root() as Node3D
	
	if(!root):
		return
		
	var canvas_viewport := root.get_viewport()
	var node3d_viewport := _camera.get_viewport()
	
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.is_shortcut("Open Industry Project/Spawn Character", event) and event.is_pressed():	
		var editor_ui = node3d_viewport.get_parent().get_parent().get_child(1)
		rotation_gizmo = editor_ui.get_child(8).get_child(0)
		menu = editor_ui.get_child(0).get_child(0)
		right_navigation_gizmo = editor_ui.get_child(6)
		left_navigation_gizmo = editor_ui.get_child(7)
	
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if(character_spawned == false):
				return
			
			canvas_viewport.gui_disable_input = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().edited_scene_root.remove_child(character)
			character_spawned = false
			RenderingServer.viewport_attach_camera(node3d_viewport.get_viewport_rid(),_camera.get_camera_rid())
			InputMap.load_default()
			
			rotation_gizmo.visible = true
			if(EditorInterface.get_editor_settings().get_setting("editors/3d/navigation/show_viewport_navigation_gizmo")):
				right_navigation_gizmo.visible = true
				left_navigation_gizmo.visible = true
			menu.visible = true
		else:
			canvas_viewport.gui_disable_input = false
			InputMap.load_from_project_settings()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			character = load(ProjectSettings.get_setting("addons/walk_mode/character/path")).instantiate()
			get_tree().edited_scene_root.add_child(character)
			character_spawned = true
			RenderingServer.viewport_attach_camera(node3d_viewport.get_viewport_rid(),character.find_children("*","Camera3D",true)[0].get_camera_rid())
			rotation_gizmo.visible = false
			right_navigation_gizmo.visible = false
			left_navigation_gizmo.visible = false
			menu.visible = false
					
	if(canvas_viewport.gui_disable_input == true):
		return

	canvas_viewport.push_input(event)
	
	return AfterGUIInput.AFTER_GUI_INPUT_STOP
	
