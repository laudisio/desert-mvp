extends Node

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _add_keys("move_forward", [KEY_W, KEY_UP])
    _add_keys("move_back", [KEY_S, KEY_DOWN])
    _add_keys("move_left", [KEY_A, KEY_LEFT])
    _add_keys("move_right", [KEY_D, KEY_RIGHT])
    _add_keys("sprint", [KEY_SHIFT])
    _add_keys("jump", [KEY_SPACE])
    _add_keys("interact", [KEY_E])
    _add_keys("pause", [KEY_ESCAPE, KEY_P])
    _add_keys("fullscreen", [KEY_F11])
    _add_keys("reset_vehicle", [KEY_R])
    _add_keys("toggle_help", [KEY_H])


func _add_keys(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for k in keys:
        var ev := InputEventKey.new()
        ev.physical_keycode = k
        InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("fullscreen"):
        toggle_fullscreen()


func toggle_fullscreen() -> void:
    var mode := DisplayServer.window_get_mode()
    if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
