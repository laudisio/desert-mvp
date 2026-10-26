class_name Garage
extends Node
## Upgrade shop at the "Oficina": stop next to it, press E and buy with keys 1-5.

const RADIUS := 6.0

var main: Node
var city: City
var progress: Progress
var is_open := false
var ui: CanvasLayer
var panel: ColorRect
var money_lbl: Label
var rows: Array[Label] = []
var feedback: Label
var _feedback_time := 0.0


func setup(main_node: Node) -> void:
    main = main_node
    city = main.city
    progress = main.progress
    _build_ui()
    progress.changed.connect(_on_changed)
    _on_changed()


func _build_ui() -> void:
    ui = CanvasLayer.new()
    ui.layer = 11
    add_child(ui)
    panel = ColorRect.new()
    panel.color = Color(0.05, 0.04, 0.03, 0.9)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _place(panel, 0.5, 0.5, 0.5, 0.5, -470, -270, 470, 270)
    ui.add_child(panel)
    var title := _label(40, Color(1.0, 0.82, 0.2))
    title.text = "OFICINA"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(title, 0, 0, 1, 0, 0, 14, 0, 64)
    money_lbl = _label(26, Color(0.55, 0.95, 0.5))
    money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(money_lbl, 0, 0, 1, 0, 0, 66, 0, 100)
    for i in Progress.ORDER.size():
        var l := _label(21)
        _place(l, 0, 0, 1, 0, 36, 116 + i * 66, -36, 176 + i * 66)
        rows.append(l)
    feedback = _label(22, Color(1.0, 0.88, 0.45))
    feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(feedback, 0, 1, 1, 1, 0, -82, 0, -50)
    var hint := _label(18, Color(0.8, 0.78, 0.72))
    hint.text = "1-5 - comprar     E / Esc - sair"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(hint, 0, 1, 1, 1, 0, -44, 0, -14)
    panel.visible = false


func _label(size: int, color := Color(1, 0.97, 0.9)) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    l.add_theme_constant_override("outline_size", 5)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(l)
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


func _ref_pos() -> Vector3:
    return main.current_vehicle.global_position if main.current_vehicle else main.player.global_position


func near() -> bool:
    return Mission._flat_dist(_ref_pos(), city.garage_spot) < RADIUS


func mission_free() -> bool:
    return main.mission.state in [Mission.S.IDLE, Mission.S.DONE]


func handle_interact() -> bool:
    if is_open:
        close()
        return true
    if not near():
        return false
    if not mission_free():
        _toast("Termine a missão antes de usar a oficina")
        return true
    var v: Vehicle = main.current_vehicle
    if v and v.linear_velocity.length() > 2.0:
        return true
    open()
    return true


func open() -> void:
    is_open = true
    panel.visible = true
    feedback.text = ""
    main.player.frozen = true
    if main.current_vehicle:
        main.current_vehicle.driving = false
    _on_changed()


func close() -> void:
    is_open = false
    panel.visible = false
    main.player.frozen = false
    if main.current_vehicle:
        main.current_vehicle.driving = true


func try_buy(i: int) -> bool:
    var id: String = Progress.ORDER[i]
    var item: Dictionary = Progress.ITEMS[id]
    var c := progress.cost(id)
    if c < 0:
        feedback.text = "%s já está no máximo" % item.name
        return false
    if progress.money < c:
        feedback.text = "Dinheiro insuficiente: faltam %s" % Mission._fmt_money(c - progress.money)
        return false
    progress.buy(id)
    feedback.text = "Comprado: %s" % item.desc[progress.level(id) - 1]
    return true


func _unhandled_input(event: InputEvent) -> void:
    if not is_open:
        return
    if event.is_action_pressed("pause"):
        close()
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and not event.echo:
        var k: int = (event as InputEventKey).physical_keycode
        if k >= KEY_1 and k < KEY_1 + Progress.ORDER.size():
            try_buy(k - KEY_1)
            get_viewport().set_input_as_handled()


func _on_changed() -> void:
    for v: Vehicle in main.vehicles:
        v.apply_upgrades(progress.level("engine"), progress.level("nitro"))
    city.set_wash_level(progress.level("wash"))
    money_lbl.text = "Seu dinheiro: %s" % Mission._fmt_money(progress.money)
    for i in Progress.ORDER.size():
        var id: String = Progress.ORDER[i]
        var item: Dictionary = Progress.ITEMS[id]
        var lv := progress.level(id)
        var mx := progress.max_level(id)
        var stars := "■".repeat(lv) + "□".repeat(mx - lv)
        var nxt := "MÁXIMO" if lv >= mx else "%s  -  %s" % [item.desc[lv], Mission._fmt_money(item.costs[lv])]
        rows[i].text = "%d. %s   %s\n      %s" % [i + 1, item.name, stars, nxt]
        var afford: bool = lv < mx and progress.money >= item.costs[lv]
        rows[i].add_theme_color_override("font_color", Color(1, 0.97, 0.9) if afford else Color(0.62, 0.6, 0.56))


func _toast(text: String) -> void:
    feedback.text = text
    main.mission._show_toast(text)


func _process(_delta: float) -> void:
    if is_open:
        money_lbl.text = "Seu dinheiro: %s" % Mission._fmt_money(progress.money)
        main.hud.set_prompt("")
        return
    if near():
        var v: Vehicle = main.current_vehicle
        if not mission_free():
            main.hud.set_prompt("Oficina: termine a missão primeiro")
        elif v and v.linear_velocity.length() > 2.0:
            main.hud.set_prompt("Pare para entrar na oficina")
        else:
            main.hud.set_prompt("E - abrir a oficina")
