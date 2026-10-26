extends Node
## Scripted smoke test: `godot --path . -- --autotest [--shots=DIR]`

var main: Node
var out_dir := "user://shots"


func _ready() -> void:
    main = get_parent()
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--shots="):
            out_dir = a.substr(8)
    DirAccess.make_dir_recursive_absolute(out_dir)
    _run()


func _wait(sec: float) -> void:
    await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    img.save_png(out_dir.path_join(name + ".png"))
    print("[autotest] shot ", name, " fps=", Engine.get_frames_per_second())


func _hold(action: String, sec: float) -> void:
    Input.action_press(action)
    await _wait(sec)
    Input.action_release(action)


func _run() -> void:
    var player: Player = main.player
    var rig: CameraRig = main.rig
    await _wait(3.0)
    print("[autotest] player at ", player.global_position, " on_floor=", player.is_on_floor())
    await _shot("01_start")
    Input.action_press("sprint")
    await _hold("move_left", 1.5)
    Input.action_release("sprint")
    print("[autotest] player after walk ", player.global_position)
    await _shot("02_walk")
    rig.yaw = city_yaw_toward(player.global_position, main.vehicles[0].global_position)
    player.teleport(main.vehicles[0].global_transform * Vector3(2.2, 0.3, 0))
    await _wait(0.5)
    await _shot("03_near_car")
    main.toggle_vehicle()
    print("[autotest] in vehicle: ", main.current_vehicle != null)
    var car: Vehicle = main.current_vehicle
    var p0 := car.global_position
    var fwd0 := car.global_transform.basis.z
    Input.action_press("move_forward")
    await _wait(2.0)
    print("[autotest] 2s speed=", car.forward_speed(), " disp_along_fwd=", (car.global_position - p0).dot(fwd0))
    await _wait(2.0)
    print("[autotest] 4s speed=", car.forward_speed(), " pos=", car.global_position)
    await _shot("04_driving")
    Input.action_press("move_left")
    var yaw0 := car.global_rotation.y
    var min_up := 1.0
    for i in 20:
        await _wait(0.1)
        min_up = minf(min_up, car.global_transform.basis.y.y)
    print("[autotest] min_up during turn=", min_up)
    print("[autotest] turning left: yaw delta=", wrapf(car.global_rotation.y - yaw0, -PI, PI), " up.y=", car.global_transform.basis.y.y)
    await _shot("05_turn")
    Input.action_release("move_left")
    await _wait(1.0)
    Input.action_release("move_forward")
    Input.action_press("move_back")
    await _wait(3.0)
    Input.action_release("move_back")
    print("[autotest] after brake speed=", car.forward_speed(), " up.y=", car.global_transform.basis.y.y)
    await _wait(1.0)
    main.toggle_vehicle()
    print("[autotest] exited: ", main.current_vehicle == null, " player=", player.global_position)
    await _wait(1.0)
    await _shot("06_exit")
    # RV
    var rv: Vehicle = main.vehicles[1]
    player.teleport(rv.global_transform * Vector3(2.5, 0.3, 0))
    rig.yaw = city_yaw_toward(player.global_position, rv.global_position)
    await _wait(1.0)
    await _shot("07_rv")
    main.toggle_vehicle()
    Input.action_press("move_forward")
    await _wait(4.0)
    print("[autotest] rv speed=", rv.forward_speed(), " up.y=", rv.global_transform.basis.y.y)
    await _shot("08_rv_drive")
    Input.action_release("move_forward")
    Input.action_press("move_back")
    for i in 40:
        if absf(rv.forward_speed()) < 1.5:
            break
        await _wait(0.1)
    Input.action_release("move_back")
    await _wait(0.5)
    main.toggle_vehicle()
    print("[autotest] exited rv: ", main.current_vehicle == null)
    await _wait(0.5)
    var city: City = main.city
    player.teleport(city.restaurant_inside)
    rig.yaw = city_yaw_toward(player.global_position, city.restaurant_counter)
    await _wait(1.5)
    print("[autotest] inside restaurant player=", player.global_position)
    await _shot("12_restaurante_dentro")
    var hxf := city.family_house_xf
    player.teleport(hxf * Vector3(3.0, City.CURB + 0.1, -3.0))
    rig.yaw = city_yaw_toward(player.global_position, hxf * Vector3(0, 0, 9.0))
    await _wait(1.5)
    await _shot("13_casa")
    player.teleport(hxf * Vector3(-0.6, City.CURB + 0.1, -2.2))
    rig.yaw = city_yaw_toward(player.global_position, hxf * Vector3(-0.6, 1.5, 2.0))
    rig.zoom = 1.2
    await _wait(1.5)
    await _shot("16_familia")
    player.teleport(city.restaurant_door + Vector3(1.0, 0, 3.2))
    rig.yaw = city_yaw_toward(player.global_position, city.restaurant_door + Vector3(1.0, 1.5, 8.0))
    await _wait(1.5)
    await _shot("17_restaurante_npcs")
    rig.zoom = 1.0
    await _mission_test(city, rv)
    await _garage_test(city)
    await _traffic_test(city)
    # aerial
    rig.target = null
    rig.global_position = Vector3(-60, 90, -120)
    rig.rotation = Vector3(-0.55, deg_to_rad(200.0), 0)
    rig.spring.spring_length = 0.0
    await _wait(1.0)
    await _shot("09_aerial")
    rig.global_position = Vector3(260, 25, -31)
    rig.rotation = Vector3(-0.05, -PI / 2.0, 0)
    await _wait(1.0)
    await _shot("10_mountains")
    rig.global_position = hxf * Vector3(10.0, 12.0, 32.0)
    rig.look_at(hxf * Vector3(0, 0, 14.0))
    await _wait(1.0)
    await _shot("14_casa_quintal")
    var rp := city.restaurant_door
    rig.global_position = rp + Vector3(28.0, 16.0, -22.0)
    rig.look_at(rp + Vector3(4.0, 0, 8.0))
    await _wait(1.0)
    await _shot("15_restaurante_aereo")
    rig.global_position = rp + Vector3(9.0, 2.2, -5.0)
    rig.look_at(rp + Vector3(-1.0, 2.6, 6.0))
    await _wait(1.0)
    await _shot("11_restaurante")
    print("[autotest] done")
    get_tree().quit()


func _place_vehicle(v: Vehicle, pos: Vector3, yaw: float) -> void:
    v.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * 0.9)
    v.linear_velocity = Vector3.ZERO
    v.angular_velocity = Vector3.ZERO
    v.reset_physics_interpolation()


func _mission_test(city: City, rv: Vehicle) -> void:
    var player: Player = main.player
    var rig: CameraRig = main.rig
    var m: Mission = main.mission
    var giver := m.giver
    player.teleport(giver.global_transform * Vector3(0.6, 0.2, 2.0))
    rig.yaw = city_yaw_toward(player.global_position, giver.global_position)
    await _wait(1.5)
    print("[autotest] mission can_talk=", m._can_talk(), " prompt=", main.hud.prompt.text)
    await _shot("18_missao_inicio")
    main.on_interact()
    await _wait(1.0)
    print("[autotest] mission state after talk=", m.state, " frozen=", player.frozen)
    await _shot("19_missao_dialogo")
    for i in m.lines().size():
        main.on_interact()
        await _wait(0.2)
    print("[autotest] mission state get_rv=", m.state == Mission.S.GET_VEH)
    await _wait(1.0)
    await _shot("20_missao_pegar_rv")
    player.teleport(rv.global_transform * Vector3(2.5, 0.3, 0))
    await _wait(0.5)
    main.on_interact()
    await _wait(1.0)
    print("[autotest] mission in rv=", main.current_vehicle == rv, " drive_lab=", m.state == Mission.S.DRIVE_LAB)
    _place_vehicle(rv, city.lab_spot + Vector3(30.0, 0.0, -8.0), -PI / 2.0)
    rig.yaw = PI / 2.0
    await _wait(2.0)
    await _shot("21_missao_deserto")
    _place_vehicle(rv, city.lab_spot, -PI / 2.0)
    for i in 30:
        if m.state == Mission.S.COOK:
            break
        await _wait(0.2)
    print("[autotest] mission cook=", m.state == Mission.S.COOK)
    await _wait(0.5)
    await _shot("22_missao_laboratorio")
    for i in 3:
        m._needle = m._zone_c
        m.cook_press()
        await _wait(0.3)
        if i == 0:
            await _shot("23_missao_lab_etapa")
        for j in 20:
            if m._step_pause <= 0.0:
                break
            await _wait(0.2)
    print("[autotest] mission quality=", m.quality, " deliver=", m.state == Mission.S.DELIVER, " time_left=", m.time_left)
    _place_vehicle(rv, city.lab_spot + Vector3(40.0, 0.0, -8.0), -PI / 2.0)
    await _wait(1.5)
    await _shot("24_missao_entrega")
    _place_vehicle(rv, city.delivery_spot, PI)
    for i in 30:
        if m.state == Mission.S.RESULT:
            break
        await _wait(0.2)
    print("[autotest] mission result success=", m._success, " money=", m.money)
    await _wait(0.5)
    await _shot("25_missao_concluida")
    main.on_interact()
    await _wait(0.3)
    print("[autotest] mission back to idle=", m.state == Mission.S.IDLE)
    print("[autotest] mission chapter now=", m.chapter, " giver=", m.giver.kind, " state idle=", m.state == Mission.S.IDLE)
    await _chapter2(city, m)
    await _chapter3(city, m, rv)
    m._done_time = 0.01
    await _wait(0.3)
    var pr: Progress = main.progress
    print("[autotest] replay idle=", m.state == Mission.S.IDLE, " chapter=", m.chapter, " replay=", m.replay, " saved chapter=", pr.chapter, " saved replay=", pr.replay, " objective=", m.objective.text)
    var ex: Vector3 = rv.global_position
    while main.current_vehicle != null:
        main.toggle_vehicle()
        await _wait(0.3)
    player.teleport(ex + Vector3(0, 0, 6))


func _talk_through(m: Mission) -> void:
    var player: Player = main.player
    while main.current_vehicle != null:
        main.current_vehicle.linear_velocity = Vector3.ZERO
        main.toggle_vehicle()
        await _wait(0.3)
    player.teleport(m.giver.global_transform * Vector3(0.6, 0.2, 2.0))
    main.rig.yaw = city_yaw_toward(player.global_position, m.giver.global_position)
    await _wait(1.0)
    print("[autotest] ch", m.chapter + 1, " prompt=", main.hud.prompt.text)
    main.on_interact()
    await _wait(0.3)
    for i in m.lines().size():
        main.on_interact()
        await _wait(0.2)


func _cook_all(m: Mission) -> void:
    for i in 30:
        if m.state == Mission.S.COOK:
            break
        await _wait(0.2)
    var cooking := m.state == Mission.S.COOK
    var n := 0
    while m.state == Mission.S.COOK and n < 8:
        m._needle = m._zone_c
        m.cook_press()
        n += 1
        await _wait(0.3)
        for j in 20:
            if m._step_pause <= 0.0:
                break
            await _wait(0.2)
    print("[autotest] cook ok=", cooking, " presses=", n, " quality=", m.quality)


func _wait_state(m: Mission, st: int, tries := 30) -> bool:
    for i in tries:
        if m.state == st:
            return true
        await _wait(0.2)
    return m.state == st


func _chapter2(city: City, m: Mission) -> void:
    var sedan: Vehicle = main.vehicles[0]
    await _talk_through(m)
    print("[autotest] ch2 get_veh=", m.state == Mission.S.GET_VEH, " veh=", m.veh.kind, " who=", m.who_lbl.text)
    main.player.teleport(sedan.global_transform * Vector3(2.2, 0.3, 0))
    await _wait(0.5)
    main.on_interact()
    await _wait(0.5)
    print("[autotest] ch2 pickup=", m.state == Mission.S.PICKUP, " timer=", m.time_left)
    var shots := ["29_farmacia", "30_ferro_velho", "31_deposito"]
    for i in city.pickup_spots.size():
        var spot: Dictionary = city.pickup_spots[i]
        var to: Vector3 = spot.pos + spot.crate_off
        _place_vehicle(sedan, spot.pos, atan2(to.x - spot.pos.x, to.z - spot.pos.z) + PI * 0.5)
        main.rig.yaw = city_yaw_toward(sedan.global_position, to) + 0.5
        for k in 20:
            if m._picked > i:
                break
            await _wait(0.2)
        print("[autotest] ch2 picked=", m._picked, " at ", spot.name)
        await _wait(0.6)
        await _shot(shots[i])
        if i == 0:
            m.time_left = 0.05
            await _wait(0.5)
            print("[autotest] ch2 timeout fail=", m.state == Mission.S.RESULT and not m._success)
            main.on_interact()
            await _wait(0.5)
            print("[autotest] ch2 retry picked=", m._picked, " state pickup=", m.state == Mission.S.PICKUP)
            _place_vehicle(sedan, spot.pos + Vector3(0, 0, -1), 0.0)
            for k in 20:
                if m._picked > 0:
                    break
                await _wait(0.2)
    print("[autotest] ch2 drive_lab=", m.state == Mission.S.DRIVE_LAB)
    _place_vehicle(sedan, city.lab_spot, -PI / 2.0)
    await _cook_all(m)
    print("[autotest] ch2 result success=", m.state == Mission.S.RESULT and m._success, " money=", m.money, " body=", m.result_body.text.replace("\n", " | "))
    await _shot("32_ingredientes_fim")
    main.on_interact()
    await _wait(0.3)
    print("[autotest] ch3 ready chapter=", m.chapter, " giver=", m.giver.kind)


func _chapter3(city: City, m: Mission, rv: Vehicle) -> void:
    await _talk_through(m)
    main.player.teleport(rv.global_transform * Vector3(2.5, 0.3, 0))
    await _wait(0.5)
    main.on_interact()
    await _wait(0.5)
    print("[autotest] ch3 drive_lab=", m.state == Mission.S.DRIVE_LAB)
    _place_vehicle(rv, city.lab_spot, PI / 2.0)
    await _cook_all(m)
    print("[autotest] ch3 chase=", m.state == Mission.S.CHASE, " rival=", is_instance_valid(m.rival))
    var d0 := rv.global_position.distance_to(m.rival.global_position)
    for i in 360:
        await get_tree().physics_frame
    var d1 := rv.global_position.distance_to(m.rival.global_position)
    print("[autotest] ch3 rival closing d0=", d0, " d1=", d1, " rival speed=", m.rival.linear_velocity.length(), " health=", m.health)
    main.rig.yaw = city_yaw_toward(rv.global_position, m.rival.global_position) + PI
    await _shot("33_perseguicao")
    var h0 := m.health
    var back := rv.global_transform.basis.z
    m._hit_cd = 0.0
    m.rival.global_transform = Transform3D(Basis(Vector3.UP, atan2(back.x, back.z)), rv.global_position - back * 9.0 + Vector3.UP * 0.6)
    m.rival.reset_physics_interpolation()
    m.rival.linear_velocity = back * 14.0
    for i in 90:
        await get_tree().physics_frame
        if m.health < h0:
            break
    print("[autotest] ch3 ram health ", h0, " -> ", m.health)
    await _shot("34_batida")
    m.health = 0.0
    await _wait(0.5)
    print("[autotest] ch3 destroyed fail=", m.state == Mission.S.RESULT and not m._success, " body=", m.result_body.text)
    main.on_interact()
    await _wait(0.5)
    print("[autotest] ch3 retry chase=", m.state == Mission.S.CHASE, " health=", m.health, " in_rv=", main.current_vehicle == rv)
    _place_vehicle(rv, city.lab_spot + Vector3(260.0, 0.0, -8.0), PI / 2.0)
    rv.global_position.y = city.height_at(rv.global_position.x, rv.global_position.z) + 1.0
    if await _wait_state(m, Mission.S.DELIVER, 40):
        print("[autotest] ch3 escaped=true rival_gone=", not is_instance_valid(m.rival))
    else:
        print("[autotest] ch3 escaped=false dist=", m.chase_lbl.text)
    _place_vehicle(rv, city.delivery_spot, PI)
    await _wait_state(m, Mission.S.RESULT)
    print("[autotest] ch3 result success=", m._success, " money=", m.money, " body=", m.result_body.text.replace("\n", " | "))
    await _shot("35_fuga_fim")
    main.on_interact()
    await _wait(0.5)
    print("[autotest] all done state=", m.state == Mission.S.DONE, " objective=", m.objective.text)


func _garage_test(city: City) -> void:
    var pr: Progress = main.progress
    var g: Garage = main.garage
    var m: Mission = main.mission
    var sedan: Vehicle = main.vehicles[0]
    var rv: Vehicle = main.vehicles[1]
    var base_power := sedan._base_power
    var base_rv := rv.engine_power
    var rival_speed := m.rival.ai_max_speed if is_instance_valid(m.rival) else -1.0
    var base_zone := m.zone_w(0)
    var base_dmg := m.hit_damage(10.0)
    print("[autotest] garage start money=", pr.money, " levels=", pr.levels)
    var earned := pr.money
    pr.money = 100
    print("[autotest] garage broke buy=", g.try_buy(0), " msg=", g.feedback.text, " lv=", pr.level("armor"))
    pr.money = earned
    while main.current_vehicle != null:
        main.current_vehicle.linear_velocity = Vector3.ZERO
        main.toggle_vehicle()
        await _wait(0.3)
    main.player.teleport(sedan.global_transform * Vector3(2.2, 0.3, 0))
    await _wait(0.3)
    main.on_interact()
    await _wait(0.3)
    _place_vehicle(sedan, city.garage_spot, PI)
    main.rig.yaw = 0.0
    await _wait(1.0)
    print("[autotest] garage near=", g.near(), " prompt=", main.hud.prompt.text)
    await _shot("36_oficina_fora")
    main.on_interact()
    await _wait(0.3)
    print("[autotest] garage open=", g.is_open, " frozen=", main.player.frozen, " driving=", sedan.driving)
    await _shot("37_oficina_menu")
    for i in 4:
        g.try_buy(i)
    print("[autotest] garage bought money=", pr.money, " levels=", pr.levels, " msg=", g.feedback.text)
    pr.money = 80000
    pr.changed.emit()
    var n := 0
    for i in Progress.ORDER.size():
        while g.try_buy(i):
            n += 1
    print("[autotest] garage maxed buys=", n, " levels=", pr.levels, " money=", pr.money, " again=", g.try_buy(0), " msg=", g.feedback.text)
    await _shot("38_oficina_max")
    var ev := InputEventKey.new()
    ev.physical_keycode = KEY_ESCAPE
    ev.keycode = KEY_ESCAPE
    ev.pressed = true
    Input.parse_input_event(ev)
    await _wait(0.3)
    ev = ev.duplicate()
    ev.pressed = false
    Input.parse_input_event(ev)
    await _wait(0.2)
    print("[autotest] garage closed=", not g.is_open, " paused=", get_tree().paused, " driving=", sedan.driving)
    print("[autotest] engine sedan ", base_power, " -> ", sedan.engine_power, " max_speed=", sedan.max_speed, " rv ", base_rv, " -> ", rv.engine_power, " rival ai_max=", rival_speed)
    print("[autotest] lab zone ", base_zone, " -> ", m.zone_w(0), " speed=", m.needle_speed(0))
    print("[autotest] armor dmg ", base_dmg, " -> ", m.hit_damage(10.0))
    _place_vehicle(sedan, Vector3(city.garage_spot.x, city.garage_spot.y, city.garage_spot.z + 4.0), 0.0)
    await _wait(0.5)
    var nit0 := sedan.nitro
    Input.action_press("move_forward")
    Input.action_press("sprint")
    var boosted := false
    for i in 60:
        await get_tree().physics_frame
        boosted = boosted or sedan.boosting
    await _shot("39_nitro")
    Input.action_release("sprint")
    var nit1 := sedan.nitro
    for i in 30:
        await get_tree().physics_frame
    Input.action_release("move_forward")
    print("[autotest] nitro cap=", sedan.nitro_cap, " boosted=", boosted, " ", nit0, " -> ", nit1, " -> ", sedan.nitro, " hud=", main.hud.nitro_bg.visible)
    sedan.linear_velocity = Vector3.ZERO
    var m0 := pr.money
    pr.income_t = Progress.INCOME_PERIOD - 0.2
    await _wait(0.6)
    print("[autotest] income ", m0, " -> ", pr.money, " toast=", m.toast.text)
    var p2 := Progress.new()
    p2.save_path = pr.save_path
    var ok := p2.load_game()
    print("[autotest] save load=", ok, " money=", p2.money, "==", pr.money, " levels=", p2.levels == pr.levels, " chapter=", p2.chapter, " replay=", p2.replay)
    var bad := FileAccess.open("user://save_bad.json", FileAccess.WRITE)
    bad.store_string("{not json")
    bad.close()
    p2.save_path = "user://save_bad.json"
    print("[autotest] corrupt load=", p2.load_game(), " money still=", p2.money)
    p2.free()
    while main.current_vehicle != null:
        main.current_vehicle.linear_velocity = Vector3.ZERO
        main.toggle_vehicle()
        await _wait(0.3)
    var wash_view := Vector3(city.garage_spot.x + 14.0, city.garage_spot.y + 0.3, city.garage_spot.z + 10.0)
    main.player.teleport(wash_view)
    main.rig.yaw = city_yaw_toward(wash_view, Vector3(city.garage_spot.x + 23.0, 0.0, city.garage_spot.z - 6.0))
    await _wait(0.8)
    await _shot("40_lava_rapido")


func _traffic_test(city: City) -> void:
    var tr: Traffic = main.traffic
    var player: Player = main.player
    var rig: CameraRig = main.rig
    var c0: Array = []
    for c in tr.cars:
        c0.append(c.global_position)
    var p0: Array = []
    for p in tr.peds:
        p0.append(p.global_position)
    await _wait(4.0)
    var moved := 0
    for i in tr.cars.size():
        if tr.cars[i].global_position.distance_to(c0[i]) > 3.0:
            moved += 1
    var walked := 0
    for i in tr.peds.size():
        if tr.peds[i].global_position.distance_to(p0[i]) > 1.0:
            walked += 1
    print("[autotest] traffic cars moved=", moved, "/", tr.cars.size(), " peds walked=", walked, "/", tr.peds.size())
    var car: TrafficCar = tr.cars[0]
    var cf := TrafficCar.d3(car.dir)
    var spot := car.global_position + cf * 16.0 + TrafficCar.right(car.dir) * 4.2
    spot.y = City.CURB + 0.1
    player.teleport(spot)
    rig.yaw = city_yaw_toward(spot, car.global_position + cf * 6.0)
    rig.pitch = -0.18
    await _wait(1.0)
    await _shot("27_ruas")
    var ped: Pedestrian = tr.peds[0]
    var sedan: Vehicle = main.vehicles[0]
    var fwd := ped.global_transform.basis.z
    sedan.global_transform = Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)), ped.global_position - fwd * 5.0 + Vector3.UP * 0.8)
    sedan.reset_physics_interpolation()
    sedan.linear_velocity = fwd * 9.0
    for i in 20:
        if ped.down_time > 0.0:
            break
        await _wait(0.1)
    print("[autotest] ped knocked down=", ped.down_time > 0.0)
    var side := ped.global_transform.basis.x
    player.teleport(ped.global_position + side * 6.0 + Vector3.UP * 0.3)
    rig.yaw = city_yaw_toward(player.global_position, ped.global_position)
    rig.pitch = -0.35
    await _wait(0.6)
    await _shot("28_atropelado")
    await _wait(4.5)
    print("[autotest] ped got up=", ped.down_time <= 0.0, " collision=", not ped.body_shape.disabled)
    var stuck := 0
    for c in tr.cars:
        if c.blocked_time > 3.0:
            stuck += 1
    print("[autotest] traffic stuck>3s=", stuck)


func city_yaw_toward(from: Vector3, to: Vector3) -> float:
    var d := to - from
    return atan2(-d.x, -d.z)
