# This class provides a runner for scense to simulate interactions like keyboard or mouse
class_name GdUnitSceneRunner
extends Node

var _scene_tree :SceneTree = null
var _scene :Node = null
var _scene_name :String
var _verbose :bool
var _simulate_start_time :LocalTime
var _current_mouse_pos :Vector2
var _is_simulate_runnig := false
var _expected_signal_args :Array

func _init(scene :Node, verbose :bool):
	assert(scene != null, "Scene must be not null!")
	_scene_tree = Engine.get_main_loop()
	_scene_tree.root.add_child(self)
	add_child(scene)
	_verbose = verbose
	_scene = scene
	_scene_name = __extract_scene_name(scene)
	_simulate_start_time = LocalTime.now()
	__print("Start simulate %s" % _scene_name)
	# we have to remove the scene before tree exists, 
	# otherwise the scene is deleted by tree_exiting and causes into errors
	connect("tree_exited", self, "_tree_exiting")

func _tree_exiting():
	if is_instance_valid(_scene):
		self.remove_child(_scene)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# we hide the scene/main window after runner is finished 
		OS.window_maximized = false
		OS.set_window_minimized(true)
		__print("End simulate %s, total time %s" % [_scene_name, _simulate_start_time.elapsed_since()])

# resets the scene to inital state
# needs to more investigate how to reset a loaded scene fully, calling _ready is not enough
#func reset() -> Node:
#	__print("reset scene")
#	__reset(_scene)
#	return _scene

#func __reset(node: Node):
#	for child in node.get_children():
#		__reset(child)
#	if node.has_method("_ready"):
#		node._ready()

# Simulates that a key has been pressed
# key_code : the key code e.g. 'KEY_ENTER'
# shift : false by default set to true if simmulate shift is press
# control : false by default set to true if simmulate control is press
func simulate_key_pressed(key_code :int, shift :bool = false, control := false) -> GdUnitSceneRunner:
	simulate_key_press(key_code, shift, control)
	simulate_key_release(key_code, shift, control)
	return self

# Simulates that a key is pressed
# key_code : the key code e.g. 'KEY_ENTER'
# shift : false by default set to true if simmulate shift is press
# control : false by default set to true if simmulate control is press
func simulate_key_press(key_code :int, shift :bool = false, control := false) -> GdUnitSceneRunner:
	__print_current_focus()
	var action = InputEventKey.new()
	action.pressed = true
	action.scancode = key_code
	action.shift = shift
	action.control = control
	__print("	process key event %s (%s) <- %s:%s" % [_scene, _scene_name, action.as_text(), "pressing" if action.is_pressed() else "released"])
	_scene_tree.input_event(action)
	return self

# Simulates that a key has been released
# key_code : the key code e.g. 'KEY_ENTER'
# shift : false by default set to true if simmulate shift is press
# control : false by default set to true if simmulate control is press
func simulate_key_release(key_code :int, shift :bool = false, control := false) -> GdUnitSceneRunner:
	__print_current_focus()
	var action = InputEventKey.new()
	action.pressed = false
	action.scancode = key_code
	action.shift = shift
	action.control = control
	__print("	process key event %s (%s) <- %s:%s" % [_scene, _scene_name, action.as_text(), "pressing" if action.is_pressed() else "released"])
	_scene_tree.input_event(action)
	return self

# Simulates a mouse moved to relative position by given speed
# relative: The mouse position relative to the previous position (position at the last frame).
# speed : The mouse speed in pixels per second.‚
func simulate_mouse_move(relative :Vector2, speed :Vector2 = Vector2.ONE) -> GdUnitSceneRunner:
	var action := InputEventMouseMotion.new()
	action.relative = relative
	action.speed = speed
	__print("	process mouse motion event %s (%s) <- %s" % [_scene, _scene_name, action.as_text()])
	_scene_tree.input_event(action)
	return self

# Simulates a mouse button pressed
# buttonIndex: The mouse button identifier, one of the ButtonList button or button wheel constants.
func simulate_mouse_button_pressed(buttonIndex :int) -> GdUnitSceneRunner:
	simulate_mouse_button_press(buttonIndex)
	simulate_mouse_button_release(buttonIndex)
	return self

# Simulates a mouse button press (holding)
# buttonIndex: The mouse button identifier, one of the ButtonList button or button wheel constants.
func simulate_mouse_button_press(buttonIndex :int) -> GdUnitSceneRunner:
	var action := InputEventMouseButton.new()
	action.button_index = buttonIndex
	action.button_mask = buttonIndex
	action.pressed = true
	action.position = _current_mouse_pos
	__print("	process mouse button event %s (%s) <- %s" % [_scene, _scene_name, action.as_text()])
	_scene_tree.input_event(action)
	return self

# Simulates a mouse button released
# buttonIndex: The mouse button identifier, one of the ButtonList button or button wheel constants.
func simulate_mouse_button_release(buttonIndex :int) -> GdUnitSceneRunner:
	var action := InputEventMouseButton.new()
	action.button_index = buttonIndex
	action.button_mask = 0
	action.pressed = false
	action.position = _current_mouse_pos
	__print("	process mouse button event %s (%s) <- %s" % [_scene, _scene_name, action.as_text()])
	_scene_tree.input_event(action)
	return self

# Simulates scene processing for a certain number of frames by given delta peer frame
# frames: amount of frames to process
# delta_peer_frame: the time delta between a frame in ms
func simulate(frames: int, delta_peer_frame :float) -> GdUnitSceneRunner:
	for frame in frames:
		_is_simulate_runnig = true
		yield(get_tree().create_timer(delta_peer_frame), "timeout")
		_scene._process(delta_peer_frame)
	_is_simulate_runnig = false
	return self

# Simulates scene processing until the given signal is emited by the scene
# signal_name: the signal to stop the simulation
# arg..: optional signal arguments to be match for stop
func simulate_until_signal(signal_name :String, arg0 = null, arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> GdUnitSceneRunner:
	_scene.connect(signal_name, self, "__interupt_simulate")
	_expected_signal_args = [arg0, arg1, arg2, arg3, arg4, arg5]
	_is_simulate_runnig = true
	while _is_simulate_runnig:
		yield(get_tree().create_timer(.010), "timeout")
		_scene._process(.010)
	return self

func __interupt_simulate(arg0 = null, arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null):
	var current_signal_args = [arg0, arg1, arg2, arg3, arg4, arg5]
	# if signal has expected args we have to compare with received ones and only if matches we stop
	for i in _expected_signal_args.size():
		var expected_arg = _expected_signal_args[i]
		var signal_arg = current_signal_args[i]
		if expected_arg != null and expected_arg != signal_arg:
			return
	_is_simulate_runnig = false

# Sets the mouse cursor to given position relative to the viewport.
func set_mouse_pos(pos :Vector2) -> GdUnitSceneRunner:
	_scene.get_viewport().warp_mouse(pos)
	_current_mouse_pos = pos
	return self

# maximizes the window to bring the scene visible
func maximize_view() -> GdUnitSceneRunner:
	OS.set_window_maximized(true)
	OS.center_window()
	OS.move_window_to_foreground()
	return self

func __extract_scene_name(node :Node) -> String:
	var scene_script :GDScript = node.get_script()
	if not scene_script:
		return node.get_name()
	if not node.get_name().begins_with("@"):
		return node.get_name()
	return scene_script.resource_name.get_basename()

func __print(message :String) -> void:
	if _verbose:
		prints(message)

func __print_current_focus() -> void:
	if not _verbose:
		return
	var focused_node = _scene.get_focus_owner()
	if focused_node:
		prints("	focus on %s" % focused_node)
	else:
		prints("	no focus set")
