class_name InputSetup
## Registra las acciones de entrada por código (teclado + mouse).

static func setup() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)
	_key("run", KEY_SHIFT)
	_key("crouch", KEY_C)
	_key("interact", KEY_E)
	_key("handbrake", KEY_SPACE)
	_key("horn", KEY_H)
	_key("snatch", KEY_R)

static func _key(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
