extends Node3D

var city: City
var player: Player
var rig: CameraRig
var hud: Hud
var vehicles: Array[Vehicle] = []
var current_vehicle: Vehicle = null
var npcs: Array[Npc] = []
var mission: Mission
var traffic: Traffic


func _ready() -> void:
    _setup_environment()
    city = City.new()
    city.name = "City"
    add_child(city)
    city.build()

    player = Player.new()
    player.name = "Player"
    player.transform = city.player_spawn
    player.spawn_point = city.player_spawn.origin + Vector3.UP
    add_child(player)

    for spot in city.npc_spots:
        var npc := Npc.new()
        npc.name = "Npc_" + spot[0]
        npc.setup(spot[0])
        npc.transform = spot[1]
        npc.watch = player
        add_child(npc)
        npcs.append(npc)

    for spec in [["sedan", city.sedan_spawn], ["rv", city.rv_spawn]]:
        var v := Vehicle.new()
        v.name = spec[0]
        v.setup(spec[0])
        v.transform = spec[1]
        add_child(v)
        vehicles.append(v)

    rig = CameraRig.new()
    rig.name = "CameraRig"
    add_child(rig)
    rig.set_target(player, 1.5, 4.5, false)
    rig.yaw = city.spawn_yaw
    player.cam_rig = rig
    player.model.rotation.y = city.spawn_yaw + PI

    traffic = Traffic.new()
    traffic.name = "Traffic"
    add_child(traffic)
    traffic.setup(self)

    hud = Hud.new()
    add_child(hud)

    mission = Mission.new()
    mission.name = "Mission"
    add_child(mission)
    mission.setup(self)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

    if "--autotest" in OS.get_cmdline_user_args():
        var t: Node = load("res://scripts/autotest.gd").new()
        add_child(t)


func _setup_environment() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.22, 0.44, 0.78)
    sky_mat.sky_horizon_color = Color(0.92, 0.78, 0.62)
    sky_mat.sky_curve = 0.12
    sky_mat.ground_horizon_color = Color(0.86, 0.72, 0.58)
    sky_mat.ground_bottom_color = Color(0.45, 0.35, 0.26)
    sky_mat.sun_angle_max = 25.0
    var sky := Sky.new()
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.9
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.0
    env.ssao_enabled = true
    env.ssao_radius = 1.2
    env.ssao_intensity = 1.6
    env.glow_enabled = true
    env.glow_bloom = 0.04
    env.fog_enabled = true
    env.fog_light_color = Color(0.9, 0.78, 0.66)
    env.fog_density = 0.0009
    env.fog_sun_scatter = 0.25
    env.fog_aerial_perspective = 0.4
    env.fog_sky_affect = 0.3
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.12
    env.adjustment_contrast = 1.05
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.rotation_degrees = Vector3(-30.0, -70.0, 0.0)
    sun.light_color = Color(1.0, 0.9, 0.74)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    sun.directional_shadow_max_distance = 220.0
    sun.shadow_blur = 1.0
    add_child(sun)


func nearest_vehicle() -> Vehicle:
    var best: Vehicle = null
    var best_d := INF
    for v in vehicles:
        var d := Vector2(v.global_position.x - player.global_position.x, v.global_position.z - player.global_position.z).length()
        if d < v.enter_radius and d < best_d:
            best = v
            best_d = d
    return best


func toggle_vehicle() -> void:
    if current_vehicle:
        var v := current_vehicle
        if v.linear_velocity.length() > 6.0:
            return
        v.driving = false
        var exit_pos := v.global_transform * v.exit_offset
        exit_pos.y = maxf(exit_pos.y, v.global_position.y + 0.2)
        var fwd := v.global_transform.basis.z
        player.leave_vehicle(exit_pos, atan2(fwd.x, fwd.z))
        rig.set_target(player, 1.5, 4.5, false)
        current_vehicle = null
    else:
        var near := nearest_vehicle()
        if near:
            current_vehicle = near
            near.driving = true
            player.enter_vehicle()
            rig.set_target(near, near.cam_height, near.cam_distance, true)


func force_enter(v: Vehicle) -> void:
    if current_vehicle == v:
        return
    if current_vehicle:
        current_vehicle.driving = false
    current_vehicle = v
    v.driving = true
    player.enter_vehicle()
    rig.set_target(v, v.cam_height, v.cam_distance, true)


func on_interact() -> void:
    if mission.handle_interact():
        return
    toggle_vehicle()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        on_interact()
    elif event.is_action_pressed("reset_vehicle"):
        if current_vehicle:
            current_vehicle.reset_upright()
        else:
            var near := nearest_vehicle()
            if near:
                near.reset_upright()
    elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
    if current_vehicle:
        var kmh := absf(current_vehicle.forward_speed()) * 3.6
        hud.set_speed(kmh, true)
        hud.set_prompt("E - sair do veículo" if current_vehicle.linear_velocity.length() <= 6.0 else "")
    else:
        hud.set_speed(0.0, false)
        var near := nearest_vehicle()
        hud.set_prompt("E - entrar no veículo" if near else "")
