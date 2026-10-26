class_name Vehicle
extends VehicleBody3D

var kind := "sedan"
var driving := false
var engine_power := 2400.0
var brake_force := 30.0
var max_speed := 42.0
var reverse_ratio := 0.45
var steer_low := 0.55
var steer_high := 0.16
var front_slip := 1.7
var rear_slip := 1.6
var handbrake_slip := 0.9
var enter_radius := 3.4
var exit_offset := Vector3(2.0, 0.2, 0.3)
var cam_distance := 7.0
var cam_height := 1.6
var throttle := 0.0
var rear_wheels: Array[VehicleWheel3D] = []
var _tail_mat: StandardMaterial3D
var _audio: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _audio_phase := 0.0
var _mix_rate := 22050.0
var _flipped_time := 0.0
var paint_color := Color(0.38, 0.52, 0.44)
var ai_target: Node3D = null
var ai_max_speed := 25.0
var _ai_stuck := 0.0
var _ai_reverse := 0.0


func setup(kind_name: String) -> void:
    kind = kind_name
    collision_layer = 4
    collision_mask = 1 | 4
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    angular_damp = 0.8
    linear_damp = 0.02
    _tail_mat = StandardMaterial3D.new()
    _tail_mat.albedo_color = Color(0.6, 0.04, 0.04)
    _tail_mat.emission_enabled = true
    _tail_mat.emission = Color(1, 0.05, 0.05)
    _tail_mat.emission_energy_multiplier = 0.0
    if kind == "rv":
        _build_rv()
    else:
        _build_sedan()
    _setup_audio()


func _mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    add_child(mi)
    return mi


func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
    return _mesh(GeoBuilder.box_mesh(size), mat, pos)


func _shape(size: Vector3, pos: Vector3) -> void:
    var cs := CollisionShape3D.new()
    var s := BoxShape3D.new()
    s.size = size
    cs.shape = s
    cs.position = pos
    add_child(cs)


func _add_wheel(pos: Vector3, radius: float, width: float, steer: bool, drive: bool) -> void:
    var w := VehicleWheel3D.new()
    w.position = pos
    w.wheel_radius = radius
    w.wheel_rest_length = 0.22
    w.suspension_travel = 0.25
    w.suspension_stiffness = 40.0
    w.suspension_max_force = mass * 10.0
    w.damping_compression = 2.2
    w.damping_relaxation = 2.8
    w.wheel_friction_slip = front_slip if steer else rear_slip
    w.wheel_roll_influence = 0.02
    w.use_as_steering = steer
    w.use_as_traction = drive
    var tire := MeshInstance3D.new()
    tire.mesh = CarMesh.get_wheel(radius, width)
    w.add_child(tire)
    add_child(w)
    if drive and not steer:
        rear_wheels.append(w)


func _build_sedan() -> void:
    mass = 1200.0
    engine_power = 2400.0
    brake_force = 30.0
    max_speed = 42.0
    center_of_mass = Vector3(0, 0.15, 0)
    var paint := Mats.solid("sedan_paint_" + paint_color.to_html(), paint_color, 0.3, 0.6)
    var car := CarMesh.get_car("sedan")
    var body := _mesh(car.mesh, null, Vector3.ZERO)
    CarMesh.apply(body, CarMesh.role_materials(paint, _tail_mat))
    _shape(Vector3(1.84, 0.6, 4.5), Vector3(0, 0.72, 0))
    _shape(Vector3(1.66, 0.6, 2.3), Vector3(0, 1.3, -0.2))
    for sx in [-0.83, 0.83]:
        _add_wheel(Vector3(sx, 0.55, 1.45), 0.36, 0.26, true, false)
        _add_wheel(Vector3(sx, 0.55, -1.45), 0.36, 0.26, false, true)
    enter_radius = 3.4
    exit_offset = Vector3(2.0, 0.2, 0.3)
    cam_distance = 7.0
    cam_height = 1.6


func _build_rv() -> void:
    mass = 3800.0
    engine_power = 5600.0
    brake_force = 90.0
    max_speed = 30.0
    steer_low = 0.5
    steer_high = 0.14
    center_of_mass = Vector3(0, 0.35, 0)
    var body := Mats.solid("rv_body", Color(0.93, 0.89, 0.78), 0.6)
    var stripe := Mats.solid("rv_stripe", Color(0.48, 0.3, 0.18), 0.6)
    var glass := Mats.solid("glass", Color(0.1, 0.14, 0.18), 0.08, 0.6)
    var dark := Mats.solid("dark_metal", Color(0.18, 0.18, 0.19), 0.5, 0.6)
    var lamp := Mats.emissive("lamp", Color(1.0, 0.95, 0.8), 0.4)
    _mesh(CarMesh.loft([[-3.8, 0.75, 3.1, 1.17, 1.1, 0.22], [-3.72, 0.7, 3.2, 1.2, 1.14, 0.26], [2.52, 0.7, 3.2, 1.2, 1.14, 0.26], [2.6, 0.75, 3.12, 1.17, 1.1, 0.22]]), body, Vector3.ZERO)
    _mesh(CarMesh.loft([[2.5, 0.65, 2.05, 1.15, 1.08, 0.14], [3.5, 0.65, 2.05, 1.15, 1.06, 0.14], [4.1, 0.68, 1.4, 1.15, 1.05, 0.16], [4.25, 0.75, 1.2, 1.1, 1.0, 0.14]]), body, Vector3.ZERO)
    _box(Vector3(2.42, 0.35, 6.3), stripe, Vector3(0, 1.45, -0.6))
    _box(Vector3(2.32, 0.2, 1.5), stripe, Vector3(0, 1.45, 3.3))
    var ws := _box(Vector3(2.0, 0.85, 0.05), glass, Vector3(0, 1.72, 3.82))
    ws.rotation.x = -atan2(0.6, 0.65)
    for sx in [-1.0, 1.0]:
        _box(Vector3(0.05, 0.55, 0.8), glass, Vector3(sx * 1.16, 1.65, 3.05))
        _box(Vector3(0.05, 0.6, 1.5), glass, Vector3(sx * 1.21, 2.35, -2.2))
        _box(Vector3(0.05, 0.6, 1.0), glass, Vector3(sx * 1.21, 2.35, 0.6))
        _box(Vector3(0.4, 0.2, 0.05), lamp, Vector3(sx * 0.8, 0.98, 4.26))
        _box(Vector3(0.3, 0.3, 0.05), _tail_mat, Vector3(sx * 1.0, 1.2, -3.81))
    _box(Vector3(0.05, 1.9, 0.75), Mats.solid("rv_door", Color(0.85, 0.82, 0.72), 0.6), Vector3(-1.22, 1.75, -0.3))
    _box(Vector3(1.0, 0.4, 1.1), body, Vector3(0, 3.4, -1.2))
    _box(Vector3(2.3, 0.25, 0.25), dark, Vector3(0, 0.75, 4.3))
    _box(Vector3(2.44, 0.25, 0.25), dark, Vector3(0, 0.8, -3.85))
    _shape(Vector3(2.4, 2.5, 6.4), Vector3(0, 1.95, -0.6))
    _shape(Vector3(2.3, 1.4, 1.6), Vector3(0, 1.35, 3.4))
    for sx in [-1.02, 1.02]:
        _add_wheel(Vector3(sx, 0.75, 2.9), 0.45, 0.32, true, false)
        _add_wheel(Vector3(sx, 0.75, -2.3), 0.45, 0.32, false, true)
    enter_radius = 4.8
    exit_offset = Vector3(2.4, 0.3, 2.9)
    cam_distance = 10.0
    cam_height = 2.4


func _setup_audio() -> void:
    _audio = AudioStreamPlayer3D.new()
    var gen := AudioStreamGenerator.new()
    gen.mix_rate = _mix_rate
    gen.buffer_length = 0.12
    _audio.stream = gen
    _audio.volume_db = -10.0
    _audio.unit_size = 8.0
    _audio.position = Vector3(0, 0.8, 1.5)
    add_child(_audio)


func forward_speed() -> float:
    return linear_velocity.dot(global_transform.basis.z)


func _physics_process(delta: float) -> void:
    var fwd_speed := forward_speed()
    var steer_in := 0.0
    var handbrake := false
    throttle = 0.0
    if driving:
        throttle = Input.get_axis("move_back", "move_forward")
        steer_in = Input.get_axis("move_right", "move_left")
        handbrake = Input.is_action_pressed("jump")
    elif ai_target:
        var ai := _ai_inputs(delta, fwd_speed)
        throttle = ai.x
        steer_in = ai.y

    var max_steer := lerpf(steer_low, steer_high, clampf(absf(fwd_speed) / 30.0, 0.0, 1.0))
    steering = move_toward(steering, steer_in * max_steer, 2.5 * delta)

    var ef := 0.0
    var br := 1.5 * mass / 1200.0
    var braking := false
    if throttle > 0.0:
        if fwd_speed < -1.0:
            br = brake_force
            braking = true
        else:
            ef = engine_power * throttle
            br = 0.0
    elif throttle < 0.0:
        if fwd_speed > 1.0:
            br = brake_force
            braking = true
        else:
            ef = engine_power * reverse_ratio * throttle
            br = 0.0
    if not driving and ai_target == null:
        br = brake_force * 0.5
    var top := ai_max_speed if ai_target else max_speed
    if (ef > 0.0 and fwd_speed > top) or (ef < 0.0 and fwd_speed < -max_speed * 0.3):
        ef = 0.0
    engine_force = ef
    brake = br
    for w in rear_wheels:
        w.wheel_friction_slip = handbrake_slip if handbrake else rear_slip
        if handbrake:
            w.brake = brake_force * 0.6
    _tail_mat.emission_energy_multiplier = 3.0 if (braking or handbrake) else 0.0

    var v := linear_velocity
    apply_central_force(-v * v.length() * 0.45)
    apply_central_force(-global_transform.basis.y * v.length_squared() * 0.8)
    _stabilize(delta)


## Simple pursuit: aim at where the target will be, back up and re-aim when stuck.
func _ai_inputs(delta: float, fwd_speed: float) -> Vector2:
    var tgt := ai_target.global_position
    var dist := global_position.distance_to(tgt)
    if ai_target is RigidBody3D and dist > 12.0:
        tgt += (ai_target as RigidBody3D).linear_velocity * clampf(dist / 30.0, 0.0, 1.2)
    var l := global_transform.affine_inverse() * tgt
    var ang := atan2(l.x, l.z)
    if _ai_reverse > 0.0:
        _ai_reverse -= delta
        return Vector2(-1.0, -signf(ang))
    if absf(fwd_speed) < 1.0:
        _ai_stuck += delta
        if _ai_stuck > 1.5:
            _ai_stuck = 0.0
            _ai_reverse = 1.3
    else:
        _ai_stuck = 0.0
    return Vector2(1.0 if absf(ang) < 1.4 else 0.7, clampf(ang * 1.8, -1.0, 1.0))


func _stabilize(delta: float) -> void:
    var up := global_transform.basis.y
    var grounded := false
    for c in get_children():
        if c is VehicleWheel3D and c.is_in_contact():
            grounded = true
            break
    if grounded and up.y > 0.4:
        var axis := up.cross(Vector3.UP)
        apply_torque(axis * mass * 9.0 - angular_velocity.project(global_transform.basis.z) * mass * 0.6)
    if up.y < 0.35 and linear_velocity.length() < 3.0:
        _flipped_time += delta
        if _flipped_time > 2.0:
            reset_upright()
    else:
        _flipped_time = 0.0


func _process(_delta: float) -> void:
    var active := driving or ai_target != null
    if active and not _audio.playing:
        _audio.play()
        _playback = _audio.get_stream_playback()
    elif not active and _audio.playing:
        _audio.stop()
        _playback = null
    if _playback == null:
        return
    var rpm := clampf(absf(forward_speed()) / max_speed, 0.0, 1.0)
    var freq := 32.0 + rpm * 90.0 + absf(throttle) * 12.0
    var vol := 0.25 + absf(throttle) * 0.25
    var frames := _playback.get_frames_available()
    for i in frames:
        _audio_phase = fmod(_audio_phase + freq / _mix_rate, 1.0)
        var s := (_audio_phase * 2.0 - 1.0) * 0.45 + sin(_audio_phase * TAU * 2.0) * 0.3 + randf_range(-0.06, 0.06)
        _playback.push_frame(Vector2(s, s) * vol)


func reset_upright() -> void:
    var fwd := global_transform.basis.z
    fwd.y = 0.0
    if fwd.length_squared() < 0.01:
        fwd = Vector3.BACK
    var yaw := atan2(fwd.x, fwd.z)
    global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3.UP * 1.5)
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    _flipped_time = 0.0
    reset_physics_interpolation()
