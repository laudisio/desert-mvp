class_name Mission
extends Node
## Mission chain: "Primeira Entrega" -> "Ingredientes" -> "Fuga do Deserto".
## Each chapter: talk to a giver, take a vehicle, cook in the desert lab
## (timing minigame), plus a chapter-specific leg (delivery, pickups, chase).

enum S { IDLE, TALK, GET_VEH, PICKUP, DRIVE_LAB, COOK, CHASE, DELIVER, RESULT, DONE }

const TALK_RADIUS := 2.8
const LAB_RADIUS := 8.0
const DELIVERY_RADIUS := 7.0
const PICKUP_RADIUS := 6.0
const ESCAPE_DIST := 100.0
const ESCAPE_HOLD := 3.0
const RIVAL_DELAY := 2.5
const STEPS_3 := ["Aquecer", "Misturar", "Resfriar"]
const STEPS_4 := ["Aquecer", "Misturar", "Filtrar", "Resfriar"]
const ZONE_3 := [0.22, 0.15, 0.1]
const ZONE_4 := [0.18, 0.13, 0.1, 0.075]
const SPEED_3 := [0.6, 0.85, 1.1]
const SPEED_4 := [0.7, 0.95, 1.2, 1.45]
const CHAPTERS := [
    {
        "title": "Primeira Entrega", "giver": "gerente", "who": "Gerente", "veh": 1, "hard": false,
        "pay": 5000, "time": 100.0, "where": "na frente do Pollos Dorados", "label": "o gerente",
        "lines": [
            "Você chegou na hora. Gosto de gente pontual.",
            "Tenho um trabalho discreto para você. Há um trailer estacionado no terreno baldio do bairro.",
            "Leve-o até o ponto marcado no deserto, a oeste, e prepare a encomenda lá dentro.",
            "Capriche na qualidade. E depois de pronta, traga para o estacionamento daqui sem demora.",
        ],
    },
    {
        "title": "Ingredientes", "giver": "careca", "who": "Segurança", "veh": 0, "hard": true,
        "pay": 8000, "time": 150.0, "where": "na frente do Pollos Dorados", "label": "o segurança",
        "lines": [
            "O chefe gostou do seu trabalho. Agora a encomenda vai ser maior.",
            "Precisamos de três caixas: uma na farmácia do centro comercial, uma no ferro-velho da rodovia, a leste, e uma no depósito da estrada de terra, a oeste.",
            "Pegue o sedan. Você tem dois minutos e meio para buscar tudo e chegar ao laboratório no deserto.",
            "Dessa vez são quatro etapas no laboratório. Não erre.",
        ],
    },
    {
        "title": "Fuga do Deserto", "giver": "gerente", "who": "Gerente", "veh": 1, "hard": false,
        "pay": 12000, "time": 0.0, "where": "na frente do Pollos Dorados", "label": "o gerente",
        "lines": [
            "Temos um problema. Um grupo rival descobriu o nosso ponto no deserto.",
            "Mesmo assim, preciso de mais um lote. Leve o trailer até o acampamento e prepare a encomenda.",
            "Se alguém aparecer, não pare. Despiste quem estiver atrás de você antes de voltar.",
            "Não quero ninguém seguindo você até o meu restaurante.",
        ],
    },
]

var main: Node
var city: City
var player: Player
var rv: Vehicle
var sedan: Vehicle
var veh: Vehicle
var giver: Npc
var chapter := 0
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
var _timed := false
var _picked := 0
var _crates: Array[Node3D] = []
var rival: Vehicle
var health := 100.0
var _rival_wait := 0.0
var _escape_time := 0.0
var _hit_cd := 0.0
var _rel_prev := 0.0
var _done_time := 0.0

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
var who_lbl: Label
var chase_panel: ColorRect
var health_fill: ColorRect
var chase_lbl: Label
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


func setup(main_node: Node) -> void:
    main = main_node
    city = main.city
    player = main.player
    sedan = main.vehicles[0]
    rv = main.vehicles[1]
    _build_ui()
    _build_marker()
    _build_crates()
    _set_chapter(0)


func ch() -> Dictionary:
    return CHAPTERS[mini(chapter, CHAPTERS.size() - 1)]


func lines() -> Array:
    return ch().lines


func _set_chapter(i: int) -> void:
    chapter = i
    if chapter >= CHAPTERS.size():
        state = S.DONE
        _done_time = 6.0
        return
    state = S.IDLE
    veh = main.vehicles[ch().veh]
    for n: Npc in main.npcs:
        if n.kind == ch().giver:
            giver = n
    who_lbl.text = ch().who


func _steps() -> Array:
    return STEPS_4 if ch().hard else STEPS_3


func _veh_name() -> String:
    return "o trailer" if veh == rv else "o sedan"


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
    who_lbl = _label(dialog, 24, Color(1.0, 0.82, 0.2))
    _place(who_lbl, 0, 0, 1, 0, 24, 14, -24, 46)
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

    chase_panel = _rect(ui, Color(0.04, 0.04, 0.04, 0.7))
    _place(chase_panel, 0, 1, 0, 1, 16, -200, 336, -120)
    var hl := _label(chase_panel, 18)
    hl.text = "Trailer"
    _place(hl, 0, 0, 1, 0, 12, 6, -12, 30)
    var hb := _rect(chase_panel, Color(0.2, 0.2, 0.2))
    _place(hb, 0, 0, 1, 0, 90, 10, -12, 28)
    health_fill = _rect(hb, Color(0.3, 0.85, 0.35))
    _place(health_fill, 0, 0, 1, 1, 0, 0, 0, 0)
    chase_lbl = _label(chase_panel, 18, Color(1.0, 0.55, 0.45))
    _place(chase_lbl, 0, 0, 1, 1, 12, 36, -12, -6)

    chase_panel.visible = false
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


func _build_crates() -> void:
    var wood := Mats.solid("crate_wood", Color(0.62, 0.45, 0.26), 0.9)
    var band := Mats.solid("crate_band", Color(0.2, 0.2, 0.2), 0.6, 0.5)
    for spot in city.pickup_spots:
        var root := Node3D.new()
        root.name = "Crates"
        add_child(root)
        root.global_position = spot.pos + spot.crate_off
        for k in 3:
            var p := Vector3((k % 2) * 0.75 - 0.35, 0.3 + (k / 2) * 0.6, 0.0)
            var c := MeshInstance3D.new()
            c.mesh = GeoBuilder.box_mesh(Vector3(0.7, 0.6, 0.7))
            c.material_override = wood
            c.position = p
            c.rotation.y = k * 0.3
            root.add_child(c)
            var bd := MeshInstance3D.new()
            bd.mesh = GeoBuilder.box_mesh(Vector3(0.72, 0.08, 0.72))
            bd.material_override = band
            bd.position = p
            bd.rotation.y = k * 0.3
            root.add_child(bd)
        _crates.append(root)


func _reset_pickups() -> void:
    _picked = 0
    for c in _crates:
        c.visible = true


# ---------------------------------------------------------------- flow

func handle_interact() -> bool:
    match state:
        S.IDLE:
            if _can_talk():
                _start_talk()
                return true
        S.TALK:
            _line += 1
            if _line >= lines().size():
                dialog.visible = false
                player.frozen = false
                state = S.GET_VEH
                _reset_pickups()
                health = 100.0
                quality = 0.0
                _show_toast("Missão %d: %s" % [chapter + 1, ch().title])
            else:
                dialog_text.text = lines()[_line]
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
    dialog_text.text = lines()[0]
    dialog.visible = true
    player.frozen = true
    var d := giver.global_position - player.global_position
    player.model.rotation.y = atan2(d.x, d.z)


func _start_cook() -> void:
    state = S.COOK
    _timed = false
    veh.driving = false
    _scores.clear()
    _setup_step(0)
    cook_panel.visible = true


func _setup_step(i: int) -> void:
    _step = i
    var w: float = (ZONE_4 if ch().hard else ZONE_3)[i]
    _zone_c = randf_range(w * 0.5 + 0.08, 1.0 - w * 0.5 - 0.08)
    _needle = 0.0
    _needle_dir = 1.0
    _step_pause = 0.0
    cook_title.text = "LABORATÓRIO - Etapa %d/%d: %s" % [i + 1, _steps().size(), _steps()[i]]
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
    var half: float = (ZONE_4 if ch().hard else ZONE_3)[_step] * 0.5
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
    veh.driving = main.current_vehicle == veh
    match chapter:
        0:
            state = S.DELIVER
            _timed = true
            time_left = ch().time
            _show_toast("Qualidade: %d%%. Entregue no Pollos Dorados!" % roundi(quality * 100.0))
        1:
            _finish(true)
        _:
            _start_chase()


func _start_chase() -> void:
    state = S.CHASE
    health = 100.0
    _escape_time = 0.0
    _hit_cd = 0.0
    _rival_wait = RIVAL_DELAY
    _spawn_rival()
    _show_toast("Qualidade: %d%%. Um carro preto está vindo! Fuja!" % roundi(quality * 100.0))


func _spawn_rival() -> void:
    _despawn_rival()
    rival = Vehicle.new()
    rival.name = "Rival"
    rival.paint_color = Color(0.06, 0.06, 0.07)
    rival.setup("sedan")
    rival.contact_monitor = true
    rival.max_contacts_reported = 4
    var p := city.lab_spot + Vector3(-85.0, 0.0, -8.0)
    p.y = city.height_at(p.x, p.z) + 1.0
    rival.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), p)
    add_child(rival)
    rival.body_entered.connect(_on_rival_hit)


func _despawn_rival() -> void:
    if is_instance_valid(rival):
        rival.queue_free()
    rival = null


func _on_rival_hit(body: Node) -> void:
    if body != veh or state != S.CHASE or _hit_cd > 0.0 or _rel_prev < 2.0:
        return
    _hit_cd = 0.6
    health = maxf(0.0, health - clampf(_rel_prev * 2.2, 5.0, 22.0))


func _physics_process(delta: float) -> void:
    _hit_cd -= delta
    if state != S.CHASE or not is_instance_valid(rival):
        return
    _rel_prev = (rival.linear_velocity - veh.linear_velocity).length()
    if _rival_wait > 0.0:
        _rival_wait -= delta
        if _rival_wait <= 0.0:
            rival.ai_target = veh


func _finish(success: bool, reason := "") -> void:
    state = S.RESULT
    _success = success
    _toast_time = 0.0
    toast.text = ""
    cook_panel.visible = false
    timer_lbl.visible = false
    chase_panel.visible = false
    _timed = false
    if is_instance_valid(rival):
        rival.ai_target = null
    result_panel.visible = true
    var hint: Label = result_panel.get_node("Hint")
    if success:
        var bonus := time_left * 20.0 if ch().time > 0.0 else health * 40.0
        var pay := int(roundf((float(ch().pay) * (0.5 + quality * 0.5) + bonus) / 10.0)) * 10
        money += pay
        result_title.text = "MISSÃO CONCLUÍDA"
        result_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
        var first := "Tempo: %s" % _fmt_time(ch().time - time_left) if ch().time > 0.0 else "Trailer: %d%% inteiro" % roundi(health)
        result_body.text = "%s\nQualidade: %d%%\nPagamento: %s" % [first, roundi(quality * 100.0), _fmt_money(pay)]
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
    _flip_time = 0.0
    if _success:
        _despawn_rival()
        _set_chapter(chapter + 1)
        if state == S.DONE:
            _show_toast("Todas as missões concluídas!")
        else:
            _show_toast("Nova missão: fale com %s" % ch().label)
        return
    if veh.global_transform.basis.y.y < 0.5:
        veh.reset_upright()
    if chapter == 2 and quality > 0.0:
        _retry_chase()
        return
    if main.current_vehicle == veh:
        veh.driving = true
    _reset_pickups()
    state = S.GET_VEH


## Checkpoint for the chase: back at the camp with the cooked batch.
func _retry_chase() -> void:
    var p := city.lab_spot + Vector3(6.0, 0.0, -8.0)
    p.y = city.height_at(p.x, p.z) + 1.0
    veh.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), p)
    veh.linear_velocity = Vector3.ZERO
    veh.angular_velocity = Vector3.ZERO
    veh.reset_physics_interpolation()
    main.force_enter(veh)
    _start_chase()


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
    var in_veh: bool = main.current_vehicle == veh
    var vpos := veh.global_position + Vector3.UP * (4.5 if veh == rv else 3.0)

    match state:
        S.IDLE:
            target = giver.global_position + Vector3.UP * 2.5
            obj = "Fale com %s %s" % [ch().label, ch().where]
            if _can_talk():
                overrides_prompt = true
                prompt_text = "E - falar com %s" % ch().label
        S.TALK:
            overrides_prompt = true
        S.GET_VEH:
            target = vpos
            obj = "Pegue %s" % _veh_name()
            if veh == rv:
                obj = "Pegue o trailer (RV)"
            if in_veh:
                if chapter == 1:
                    state = S.PICKUP
                    _timed = true
                    time_left = ch().time
                else:
                    state = S.DRIVE_LAB
        S.PICKUP:
            if in_veh:
                var spot: Dictionary = city.pickup_spots[_picked]
                target = spot.pos
                ring = PICKUP_RADIUS
                obj = "Busque a caixa %d/3 no %s" % [_picked + 1, spot.name] if spot.name != "farmácia" else "Busque a caixa 1/3 na farmácia"
                if _flat_dist(veh.global_position, spot.pos) < PICKUP_RADIUS:
                    overrides_prompt = true
                    prompt_text = "Pare o carro para carregar"
                    if veh.linear_velocity.length() < 1.5:
                        _crates[_picked].visible = false
                        _picked += 1
                        _show_toast("Caixa %d/3 carregada" % _picked)
                        if _picked >= city.pickup_spots.size():
                            state = S.DRIVE_LAB
            else:
                target = vpos
                obj = "Volte para o carro!"
        S.DRIVE_LAB:
            if in_veh:
                target = city.lab_spot
                ring = LAB_RADIUS
                obj = "Leve %s até o laboratório no deserto" % _veh_name()
                if _flat_dist(veh.global_position, city.lab_spot) < LAB_RADIUS:
                    overrides_prompt = true
                    prompt_text = "Pare para começar"
                    if veh.linear_velocity.length() < 1.5:
                        _start_cook()
            else:
                target = vpos
                obj = "Volte para %s" % _veh_name()
        S.COOK:
            overrides_prompt = true
            _process_cook(delta)
        S.CHASE:
            _process_chase(delta)
            if state == S.CHASE:
                target = city.delivery_spot
                obj = "Despiste o carro preto! Abra %d m de distância" % roundi(ESCAPE_DIST) if in_veh else "Volte para o trailer!"
                if not in_veh:
                    target = vpos
        S.DELIVER:
            if in_veh:
                target = city.delivery_spot
                ring = DELIVERY_RADIUS
                obj = "Entregue no estacionamento do Pollos Dorados"
                if _flat_dist(veh.global_position, city.delivery_spot) < DELIVERY_RADIUS:
                    overrides_prompt = true
                    prompt_text = "Pare o trailer para entregar"
                    if veh.linear_velocity.length() < 2.0:
                        _finish(true)
            else:
                target = vpos
                obj = "Volte para o trailer!"
        S.RESULT:
            overrides_prompt = true
        S.DONE:
            _done_time -= delta
            if _done_time > 0.0:
                obj = "Todas as missões concluídas! Obrigado por jogar."

    if _timed and state in [S.PICKUP, S.DRIVE_LAB, S.DELIVER]:
        time_left -= delta
        if time_left <= 0.0:
            time_left = 0.0
            _finish(false, "O tempo acabou.")

    if state in [S.PICKUP, S.DRIVE_LAB, S.CHASE, S.DELIVER]:
        if veh.global_transform.basis.y.y < 0.3:
            _flip_time += delta
            if _flip_time > 1.5:
                _finish(false, "%s capotou." % _veh_name().capitalize())
        else:
            _flip_time = 0.0

    timer_lbl.visible = _timed and state in [S.PICKUP, S.DRIVE_LAB, S.DELIVER]
    if timer_lbl.visible:
        timer_lbl.text = _fmt_time(time_left)
        timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if time_left < 20.0 else Color(1, 0.97, 0.9))
    objective.text = obj
    _toast_time -= delta
    toast.visible = _toast_time > 0.0
    _update_marker(target, ring, delta)
    if overrides_prompt:
        main.hud.set_prompt(prompt_text)


func _process_chase(delta: float) -> void:
    chase_panel.visible = true
    health_fill.anchor_right = health / 100.0
    health_fill.color = Color(0.3, 0.85, 0.35) if health > 50.0 else (Color(0.95, 0.75, 0.2) if health > 25.0 else Color(0.95, 0.25, 0.2))
    if health <= 0.0:
        _finish(false, "O trailer foi destruído.")
        return
    if not is_instance_valid(rival):
        return
    var d := _flat_dist(veh.global_position, rival.global_position)
    if d > ESCAPE_DIST:
        _escape_time += delta
        chase_lbl.text = "Perseguidor a %d m - despistando..." % roundi(d)
    else:
        _escape_time = 0.0
        chase_lbl.text = "Perseguidor a %d m" % roundi(d)
    if _escape_time > ESCAPE_HOLD:
        _despawn_rival()
        chase_panel.visible = false
        state = S.DELIVER
        _show_toast("Você despistou! Entregue no Pollos Dorados")


func _process_cook(delta: float) -> void:
    if _step_pause > 0.0:
        _step_pause -= delta
        if _step_pause <= 0.0:
            if _step + 1 < _steps().size():
                _setup_step(_step + 1)
            else:
                _finish_cook()
        return
    _needle += _needle_dir * (SPEED_4 if ch().hard else SPEED_3)[_step] * delta
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
