class_name Player
extends CharacterBody3D

const WALK_SPEED := 4.0
const RUN_SPEED := 7.5
const JUMP_VELOCITY := 5.0
const ACCEL := 10.0

var cam_rig: CameraRig
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_point := Vector3.ZERO
var model: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var _phase := 0.0


func _ready() -> void:
    collision_layer = 2
    collision_mask = 1 | 4
    floor_snap_length = 0.3
    floor_max_angle = deg_to_rad(50.0)
    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.35
    cap.height = 1.8
    shape.shape = cap
    shape.position.y = 0.9
    add_child(shape)
    _build_model()


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)
    return mi


func _limb(pos: Vector3) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    model.add_child(n)
    return n


func _build_model() -> void:
    model = Node3D.new()
    add_child(model)
    var skin := Mats.solid("skin", Color(0.87, 0.68, 0.55), 0.7)
    var shirt := Mats.solid("shirt", Color(0.36, 0.5, 0.4), 0.85)
    var pants := Mats.solid("pants", Color(0.55, 0.47, 0.36), 0.9)
    var shoes := Mats.solid("shoes", Color(0.15, 0.12, 0.1), 0.7)
    var hair := Mats.solid("hair", Color(0.18, 0.13, 0.1), 0.9)
    var dark := Mats.solid("eyes", Color(0.05, 0.05, 0.05), 0.4)

    _part(model, GeoBuilder.box_mesh(Vector3(0.46, 0.6, 0.26)), shirt, Vector3(0, 1.27, 0))
    _part(model, GeoBuilder.box_mesh(Vector3(0.44, 0.18, 0.25)), pants, Vector3(0, 0.97, 0))
    _part(model, GeoBuilder.cyl_mesh(0.06, 0.06, 0.1, 8), skin, Vector3(0, 1.61, 0))
    _part(model, GeoBuilder.sphere_mesh(0.14, 0.3, 12, 8), skin, Vector3(0, 1.77, 0))
    _part(model, GeoBuilder.sphere_mesh(0.148, 0.2, 12, 6), hair, Vector3(0, 1.85, -0.01))
    for sx in [-0.05, 0.05]:
        _part(model, GeoBuilder.box_mesh(Vector3(0.04, 0.025, 0.02)), dark, Vector3(sx, 1.79, 0.135))
    _part(model, GeoBuilder.box_mesh(Vector3(0.03, 0.05, 0.04)), skin, Vector3(0, 1.75, 0.145))

    leg_l = _limb(Vector3(0.11, 0.92, 0))
    leg_r = _limb(Vector3(-0.11, 0.92, 0))
    for leg in [leg_l, leg_r]:
        _part(leg, GeoBuilder.box_mesh(Vector3(0.17, 0.82, 0.2)), pants, Vector3(0, -0.41, 0))
        _part(leg, GeoBuilder.box_mesh(Vector3(0.18, 0.1, 0.3)), shoes, Vector3(0, -0.87, 0.05))
    arm_l = _limb(Vector3(0.31, 1.52, 0))
    arm_r = _limb(Vector3(-0.31, 1.52, 0))
    for arm in [arm_l, arm_r]:
        _part(arm, GeoBuilder.box_mesh(Vector3(0.14, 0.3, 0.15)), shirt, Vector3(0, -0.13, 0))
        _part(arm, GeoBuilder.box_mesh(Vector3(0.11, 0.34, 0.12)), skin, Vector3(0, -0.44, 0))
        _part(arm, GeoBuilder.sphere_mesh(0.06, 0.12, 8, 4), skin, Vector3(0, -0.64, 0))


func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = JUMP_VELOCITY

    var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var yaw := cam_rig.yaw if cam_rig else 0.0
    var forward := Vector3(-sin(yaw), 0, -cos(yaw))
    var right := Vector3(cos(yaw), 0, -sin(yaw))
    var dir := right * input.x - forward * input.y
    if dir.length() > 1.0:
        dir = dir.normalized()
    var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
    var accel := ACCEL if is_on_floor() else ACCEL * 0.25
    var hv := Vector3(velocity.x, 0, velocity.z).lerp(dir * speed, 1.0 - exp(-accel * delta))
    velocity.x = hv.x
    velocity.z = hv.z
    move_and_slide()

    if dir.length_squared() > 0.01:
        model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * delta))
    _animate(delta, hv.length())
    if global_position.y < -40.0:
        teleport(spawn_point)


func _animate(delta: float, speed: float) -> void:
    var amt := clampf(speed / RUN_SPEED, 0.0, 1.0)
    _phase += delta * (3.0 + speed * 1.7)
    var swing := sin(_phase) * 0.85 * amt
    if not is_on_floor():
        swing = 0.0
        leg_l.rotation.x = lerpf(leg_l.rotation.x, -0.5, 0.2)
        leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.3, 0.2)
        arm_l.rotation.x = lerpf(arm_l.rotation.x, -1.2, 0.2)
        arm_r.rotation.x = lerpf(arm_r.rotation.x, -1.2, 0.2)
        return
    leg_l.rotation.x = lerpf(leg_l.rotation.x, swing, 0.3)
    leg_r.rotation.x = lerpf(leg_r.rotation.x, -swing, 0.3)
    arm_l.rotation.x = lerpf(arm_l.rotation.x, -swing * 0.8, 0.3)
    arm_r.rotation.x = lerpf(arm_r.rotation.x, swing * 0.8, 0.3)
    model.position.y = absf(sin(_phase)) * 0.05 * amt


func teleport(pos: Vector3) -> void:
    global_position = pos
    velocity = Vector3.ZERO
    reset_physics_interpolation()


func enter_vehicle() -> void:
    visible = false
    process_mode = Node.PROCESS_MODE_DISABLED


func leave_vehicle(pos: Vector3, facing_yaw: float) -> void:
    process_mode = Node.PROCESS_MODE_INHERIT
    visible = true
    model.rotation.y = facing_yaw
    teleport(pos)
