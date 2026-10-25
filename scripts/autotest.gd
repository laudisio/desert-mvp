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


func city_yaw_toward(from: Vector3, to: Vector3) -> float:
    var d := to - from
    return atan2(-d.x, -d.z)
