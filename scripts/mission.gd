class_name Mission
extends Node
## "Primeira Entrega": talk to the manager, drive the RV to the desert,
## cook in a 3-step timing minigame, then deliver back before the timer runs out.

enum S { IDLE, TALK, GET_RV, DRIVE_LAB, COOK, DELIVER, RESULT }

const TIME_LIMIT := 100.0
const TALK_RADIUS := 2.8
const LAB_RADIUS := 8.0
const DELIVERY_RADIUS := 7.0
const BASE_PAY := 5000
const STEPS := ["Aquecer", "Misturar", "Resfriar"]
const ZONE_W := [0.22, 0.15, 0.1]
const NEEDLE_SPEED := [0.6, 0.85, 1.1]
const LINES := [
    "Você chegou na hora. Gosto de gente pontual.",
    "Tenho um trabalho discreto para você. Há um trailer estacionado no terreno baldio do bairro.",
    "Leve-o até o ponto marcado no deserto, a oeste, e prepare a encomenda lá dentro.",
    "Capriche na qualidade. E depois de pronta, traga para o estacionamento daqui sem demora.",
]

var main: Node
var city: City
var player: Player
var rv: Vehicle
var giver: Npc
var state := S.IDLE
var time_left := 0.0
var quality := 0.0
var money := 0
var overrides_prompt := false
var prompt_text := ""
var _line := 0
var _scores: Array[float] = []
var _step := 0
var _needle := 0.0
var _needle_dir := 1.0
var _zone_c := 0.5
var _step_pause := 0.0
var _flip_time := 0.0
var _toast_time := 0.0
var _success := false

var ui: CanvasLayer
var objective: Label
var timer_lbl: Label
var money_lbl: Label
var toast: Label
var arrow_root: Control
var arrow: Polygon2D
var dist_lbl: Label
var dialog: ColorRect
var dialog_text: Label
var cook_panel: ColorRect
var cook_title: Label
var cook_feedback: Label
var bar: ColorRect
var zone: ColorRect
var needle: ColorRect
var result_panel: ColorRect
var result_title: Label
var result_body: Label
var marker: Node3D
var marker_gem: MeshInstance3D
var marker_ring: MeshInstance3D


func setup(main_node: Node, giver_npc: Npc) -> void:
    main = main_node
    city = main.city
    player = main.player
    rv = main.vehicles[1]
    giver = giver_npc
    _build_ui()
    _build_marker()


# ---------------------------------------------------------------- UI

func _label(parent: Node, size: int, color := Color(1, 0.97, 0.9)) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    l.add_theme_constant_override("outline_size", 6)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
    return l


func _rect(parent: Node, color: Color) -> ColorRect:
    var r := ColorRect.new()
    r.color = color
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(r)
    return r


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
    c.anchor_left = al
    c.anchor_top = at
    c.anchor_right = ar
    c.anchor_bottom = ab
    c.offset_left = ol
    c.offset_top = ot
    c.offset_right = o_r
    c.offset_bottom = ob


func _build_ui() -> void:
    ui = CanvasLayer.new()
    ui.layer = 9
    add_child(ui)

    arrow_root = Control.new()
    arrow_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _place(arrow_root, 0.5, 0, 0.5, 0, 0, 52, 0, 52)
    ui.add_child(arrow_root)
    var shadow := Polygon2D.new()
    arrow = Polygon2D.new()
    var pts := PackedVector2Array([Vector2(0, -26), Vector2(19, 18), Vector2(0, 7), Vector2(-19, 18)])
    arrow.polygon = pts
    arrow.color = Color(1.0, 0.82, 0.15)
    shadow.polygon = PackedVector2Array([Vector2(0, -31), Vector2(24, 22), Vector2(0, 11), Vector2(-24, 22)])
    shadow.color = Color(0, 0, 0, 0.6)
    arrow.add_child(shadow)
    shadow.show_behind_parent = true
    arrow_root.add_child(arrow)
    dist_lbl = _label(ui, 18)
    dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(dist_lbl, 0.5, 0, 0.5, 0, -100, 78, 100, 102)
    objective = _label(ui, 24, Color(1.0, 0.88, 0.45))
    objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(objective, 0.5, 0, 0.5, 0, -500, 104, 500, 140)

    timer_lbl = _label(ui, 40)
    timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _place(timer_lbl, 1, 0, 1, 0, -260, 40, -16, 90)
    money_lbl = _label(ui, 28, Color(0.55, 0.95, 0.5))
    money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _place(money_lbl, 1, 0, 1, 0, -260, 92, -16, 130)
    toast = _label(ui, 34, Color(1.0, 0.88, 0.45))
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(toast, 0.5, 0.3, 0.5, 0.3, -500, -30, 500, 30)

    dialog = _rect(ui, Color(0.05, 0.04, 0.03, 0.82))
    _place(dialog, 0.5, 1, 0.5, 1, -460, -280, 460, -120)
    var who := _label(dialog, 24, Color(1.0, 0.82, 0.2))
    who.text = "Gerente"
    _place(who, 0, 0, 1, 0, 24, 14, -24, 46)
    dialog_text = _label(dialog, 22)
    dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _place(dialog_text, 0, 0, 1, 1, 24, 50, -24, -36)
    var hint := _label(dialog, 16, Color(0.8, 0.78, 0.72))
    hint.text = "E - continuar"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _place(hint, 0, 1, 1, 1, 24, -32, -20, -8)

    cook_panel = _rect(ui, Color(0.04, 0.05, 0.06, 0.85))
    _place(cook_panel, 0.5, 0.5, 0.5, 0.5, -380, -150, 380, 150)
    cook_title = _label(cook_panel, 30, Color(1.0, 0.88, 0.45))
    cook_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(cook_title, 0, 0, 1, 0, 0, 18, 0, 60)
    bar = _rect(cook_panel, Color(0.25, 0.25, 0.27))
    _place(bar, 0.5, 0, 0.5, 0, -320, 110, 320, 150)
    zone = _rect(bar, Color(0.25, 0.8, 0.3))
    needle = _rect(bar, Color(1, 1, 1))
    cook_feedback = _label(cook_panel, 28)
    cook_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(cook_feedback, 0, 0, 1, 0, 0, 170, 0, 210)
    var chint := _label(cook_panel, 18, Color(0.8, 0.78, 0.72))
    chint.text = "ESPAÇO - parar o ponteiro na faixa verde"
    chint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(chint, 0, 1, 1, 1, 0, -50, 0, -18)

    result_panel = _rect(ui, Color(0.04, 0.04, 0.04, 0.85))
    _place(result_panel, 0.5, 0.5, 0.5, 0.5, -320, -170, 320, 170)
    result_title = _label(result_panel, 40)
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(result_title, 0, 0, 1, 0, 0, 22, 0, 76)
    result_body = _label(result_panel, 24)
    result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _place(result_body, 0, 0, 1, 1, 30, 96, -30, -50)
    var rhint := _label(result_panel, 18, Color(0.8, 0.78, 0.72))
    rhint.name = "Hint"
    rhint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _place(rhint, 0, 1, 1, 1, 0, -44, 0, -14)

    dialog.visible = false
    cook_panel.visible = false
    result_panel.visible = false
    timer_lbl.visible = false
    money_lbl.visible = false


func _build_marker() -> void:
    marker = Node3D.new()
    marker.name = "MissionMarker"
    marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    add_child(marker)
    var beam_mat := StandardMaterial3D.new()
    beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beam_mat.albedo_color = Color(1.0, 0.8, 0.15, 0.22)
    beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var beam := MeshInstance3D.new()
    beam.mesh = GeoBuilder.cyl_mesh(0.35, 0.35, 60.0, 12)
    beam.material_override = beam_mat
    beam.position.y = 31.0
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    marker.add_child(beam)
    marker_gem = MeshInstance3D.new()
    var gem := SphereMesh.new()
    gem.radius = 0.45
    gem.height = 1.2
    gem.radial_segments = 4
    gem.rings = 2
    marker_gem.mesh = gem
    marker_gem.material_override = Mats.emissive("marker_gem", Color(1.0, 0.8, 0.15), 2.5)
    marker_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    marker.add_child(marker_gem)
    var ring_mat: StandardMaterial3D = beam_mat.duplicate()
    ring_mat.albedo_color = Color(1.0, 0.8, 0.15, 0.3)
    marker_ring = MeshInstance3D.new()
    marker_ring.mesh = GeoBuilder.cyl_mesh(1.0, 1.0, 0.08, 32)
    marker_ring.material_override = ring_mat
    marker_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    marker.add_child(marker_ring)


# ---------------------------------------------------------------- flow

func handle_interact() -> bool:
    match state:
        S.IDLE:
            if _can_talk():
                _start_talk()
                return true
        S.TALK:
            _line += 1
            if _line >= LINES.size():
                dialog.visible = false
                player.frozen = false
                state = S.GET_RV
                _show_toast("Missão: Primeira Entrega")
            else:
                dialog_text.text = LINES[_line]
            return true
        S.COOK:
            return true
        S.RESULT:
            _close_result()
            return true
    return false


func _unhandled_input(event: InputEvent) -> void:
    if state == S.COOK and event.is_action_pressed("jump"):
        cook_press()
        get_viewport().set_input_as_handled()


func _can_talk() -> bool:
    return main.current_vehicle == null and _flat_dist(player.global_position, giver.global_position) < TALK_RADIUS


func _start_talk() -> void:
    state = S.TALK
    _line = 0
    dialog_text.text = LINES[0]
    dialog.visible = true
    player.frozen = true
    var d := giver.global_position - player.global_position
    player.model.rotation.y = atan2(d.x, d.z)


func _start_cook() -> void:
    state = S.COOK
    rv.driving = false
    _scores.clear()
    _setup_step(0)
    cook_panel.visible = true


func _setup_step(i: int) -> void:
    _step = i
    var w: float = ZONE_W[i]
    _zone_c = randf_range(w * 0.5 + 0.08, 1.0 - w * 0.5 - 0.08)
    _needle = 0.0
    _needle_dir = 1.0
    _step_pause = 0.0
    cook_title.text = "LABORATÓRIO - Etapa %d/3: %s" % [i + 1, STEPS[i]]
    cook_feedback.text = ""
    var bw := bar.size.x if bar.size.x > 0.0 else 640.0
    zone.position = Vector2((_zone_c - w * 0.5) * bw, 0)
    zone.size = Vector2(w * bw, 40)
    _update_needle()


func _update_needle() -> void:
    var bw := bar.size.x if bar.size.x > 0.0 else 640.0
    needle.position = Vector2(_needle * bw - 3.0, -8)
    needle.size = Vector2(6, 56)


func cook_press() -> void:
    if state != S.COOK or _step_pause > 0.0:
        return
    var half: float = ZONE_W[_step] * 0.5
    var d := absf(_needle - _zone_c)
    var score := 1.0 - 0.3 * (d / half) if d <= half else maxf(0.0, 0.6 - (d - half) * 2.5)
    _scores.append(score)
    if score >= 0.9:
        cook_feedback.text = "Perfeito!"
    elif score >= 0.7:
        cook_feedback.text = "Bom"
    elif score >= 0.4:
        cook_feedback.text = "Razoável"
    else:
        cook_feedback.text = "Ruim"
    _step_pause = 1.0


func _finish_cook() -> void:
    var total := 0.0
    for s in _scores:
        total += s
    quality = total / _scores.size()
    cook_panel.visible = false
    rv.driving = true
    state = S.DELIVER
    time_left = TIME_LIMIT
    _show_toast("Qualidade: %d%%. Entregue no Pollos Dorados!" % roundi(quality * 100.0))


func _finish(success: bool, reason := "") -> void:
    state = S.RESULT
    _success = success
    _toast_time = 0.0
    toast.text = ""
    cook_panel.visible = false
    timer_lbl.visible = false
    result_panel.visible = true
    var hint: Label = result_panel.get_node("Hint")
    if success:
        var pay := int(roundf((BASE_PAY * (0.5 + quality * 0.5) + time_left * 20.0) / 10.0)) * 10
        money += pay
        result_title.text = "MISSÃO CONCLUÍDA"
        result_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
        result_body.text = "Tempo: %s\nQualidade: %d%%\nPagamento: %s" % [_fmt_time(TIME_LIMIT - time_left), roundi(quality * 100.0), _fmt_money(pay)]
        hint.text = "E - continuar"
        money_lbl.visible = true
        money_lbl.text = _fmt_money(money)
    else:
        result_title.text = "MISSÃO FALHOU"
        result_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
        result_body.text = reason
        hint.text = "E - tentar de novo"


func _close_result() -> void:
    result_panel.visible = false
    if _success:
        state = S.IDLE
    else:
        if rv.global_transform.basis.y.y < 0.5:
            rv.reset_upright()
        if main.current_vehicle == rv:
            rv.driving = true
        state = S.GET_RV
    _flip_time = 0.0


func _show_toast(text: String) -> void:
    toast.text = text
    _toast_time = 3.5


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
    var target := Vector3.INF
    var ring := 0.0
    var obj := ""
    overrides_prompt = false
    prompt_text = ""
    var in_rv: bool = main.current_vehicle == rv

    match state:
        S.IDLE:
            target = giver.global_position + Vector3.UP * 2.5
            obj = "Fale com o gerente na frente do Pollos Dorados"
            if _can_talk():
                overrides_prompt = true
                prompt_text = "E - falar com o gerente"
        S.TALK:
            overrides_prompt = true
        S.GET_RV:
            target = rv.global_position + Vector3.UP * 4.5
            obj = "Pegue o trailer (RV)"
            if in_rv:
                state = S.DRIVE_LAB
        S.DRIVE_LAB:
            if in_rv:
                target = city.lab_spot
                ring = LAB_RADIUS
                obj = "Leve o trailer até o ponto marcado no deserto"
                if _flat_dist(rv.global_position, city.lab_spot) < LAB_RADIUS:
                    overrides_prompt = true
                    prompt_text = "Pare o trailer para começar"
                    if rv.linear_velocity.length() < 1.5:
                        _start_cook()
            else:
                target = rv.global_position + Vector3.UP * 4.5
                obj = "Volte para o trailer"
        S.COOK:
            overrides_prompt = true
            _process_cook(delta)
        S.DELIVER:
            time_left -= delta
            if time_left <= 0.0:
                time_left = 0.0
                _finish(false, "O tempo acabou.")
            elif in_rv:
                target = city.delivery_spot
                ring = DELIVERY_RADIUS
                obj = "Entregue no estacionamento do Pollos Dorados"
                if _flat_dist(rv.global_position, city.delivery_spot) < DELIVERY_RADIUS:
                    overrides_prompt = true
                    prompt_text = "Pare o trailer para entregar"
                    if rv.linear_velocity.length() < 2.0:
                        _finish(true)
            else:
                target = rv.global_position + Vector3.UP * 4.5
                obj = "Volte para o trailer!"
        S.RESULT:
            overrides_prompt = true

    if state in [S.DRIVE_LAB, S.DELIVER]:
        if rv.global_transform.basis.y.y < 0.3:
            _flip_time += delta
            if _flip_time > 1.5:
                _finish(false, "O trailer capotou.")
        else:
            _flip_time = 0.0

    timer_lbl.visible = state == S.DELIVER
    if timer_lbl.visible:
        timer_lbl.text = _fmt_time(time_left)
        timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if time_left < 20.0 else Color(1, 0.97, 0.9))
    objective.text = obj
    _toast_time -= delta
    toast.visible = _toast_time > 0.0
    _update_marker(target, ring, delta)
    if overrides_prompt:
        main.hud.set_prompt(prompt_text)


func _process_cook(delta: float) -> void:
    if _step_pause > 0.0:
        _step_pause -= delta
        if _step_pause <= 0.0:
            if _step + 1 < STEPS.size():
                _setup_step(_step + 1)
            else:
                _finish_cook()
        return
    _needle += _needle_dir * NEEDLE_SPEED[_step] * delta
    if _needle > 1.0:
        _needle = 2.0 - _needle
        _needle_dir = -1.0
    elif _needle < 0.0:
        _needle = -_needle
        _needle_dir = 1.0
    _needle = clampf(_needle, 0.0, 1.0)
    _update_needle()


func _update_marker(target: Vector3, ring: float, delta: float) -> void:
    var show := target != Vector3.INF
    marker.visible = show
    arrow_root.visible = show
    dist_lbl.visible = show
    if not show:
        return
    marker.global_position = target
    marker_gem.rotation.y += delta * 2.0
    marker_gem.position.y = (1.2 if ring > 0.0 else 0.0) + sin(Time.get_ticks_msec() * 0.003) * 0.25
    marker_ring.visible = ring > 0.0
    marker_ring.scale = Vector3(ring, 1.0, ring)
    var cam := get_viewport().get_camera_3d()
    if cam == null:
        return
    var from := cam.global_position
    var fwd := -cam.global_transform.basis.z
    var to := target - from
    arrow.rotation = Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z))
    var ref: Vector3 = player.global_position if main.current_vehicle == null else main.current_vehicle.global_position
    dist_lbl.text = "%d m" % roundi(_flat_dist(ref, target))


static func _flat_dist(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()


static func _fmt_time(t: float) -> String:
    var s := maxi(0, ceili(t))
    return "%d:%02d" % [s / 60, s % 60]


static func _fmt_money(v: int) -> String:
    var s := str(v)
    var out := ""
    while s.length() > 3:
        out = "." + s.substr(s.length() - 3) + out
        s = s.substr(0, s.length() - 3)
    return "$ " + s + out
