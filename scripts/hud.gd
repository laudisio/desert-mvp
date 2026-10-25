class_name Hud
extends CanvasLayer

const HELP_TEXT := "WASD - andar / dirigir\nMouse - câmera   Roda - zoom\nShift - correr   Espaço - pular / freio de mão\nE - entrar / sair do veículo\nR - desvirar veículo\nF11 - tela cheia   Esc - pausa\nH - esconder ajuda"

var help: Label
var prompt: Label
var speed: Label
var fps: Label
var pause_panel: Control


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 10
    help = _label(17)
    help.text = HELP_TEXT
    _place(help, 0, 0, 0, 0, 20, 16, 520, 220)
    fps = _label(14)
    fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _place(fps, 1, 0, 1, 0, -220, 12, -16, 40)
    prompt = _label(26)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(prompt, 0.5, 1, 0.5, 1, -400, -110, 400, -60)
    speed = _label(40)
    speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _place(speed, 1, 1, 1, 1, -360, -90, -30, -24)
    _build_pause()


func _label(size: int) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    l.add_theme_constant_override("outline_size", 6)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(l)
    return l


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
    c.anchor_left = al
    c.anchor_top = at
    c.anchor_right = ar
    c.anchor_bottom = ab
    c.offset_left = ol
    c.offset_top = ot
    c.offset_right = o_r
    c.offset_bottom = ob


func _build_pause() -> void:
    pause_panel = ColorRect.new()
    (pause_panel as ColorRect).color = Color(0, 0, 0, 0.55)
    _place(pause_panel, 0, 0, 1, 1, 0, 0, 0, 0)
    add_child(pause_panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    _place(box, 0.5, 0.5, 0.5, 0.5, -160, -140, 160, 140)
    pause_panel.add_child(box)
    var title := Label.new()
    title.text = "PAUSADO"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    box.add_child(title)
    for spec in [["Continuar", _on_resume], ["Tela cheia (F11)", Game.toggle_fullscreen], ["Sair do jogo", _on_quit]]:
        var btn := Button.new()
        btn.text = spec[0]
        btn.custom_minimum_size = Vector2(320, 52)
        btn.add_theme_font_size_override("font_size", 22)
        btn.pressed.connect(spec[1])
        box.add_child(btn)
    pause_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        set_paused(not get_tree().paused)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("toggle_help"):
        help.visible = not help.visible


func set_paused(p: bool) -> void:
    get_tree().paused = p
    pause_panel.visible = p
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func _on_resume() -> void:
    set_paused(false)


func _on_quit() -> void:
    get_tree().quit()


func set_prompt(text: String) -> void:
    prompt.text = text


func set_speed(kmh: float, show: bool) -> void:
    speed.visible = show
    speed.text = "%d km/h" % roundi(kmh)


func _process(_delta: float) -> void:
    fps.text = "%d FPS" % Engine.get_frames_per_second()
