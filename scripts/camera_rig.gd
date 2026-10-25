class_name CameraRig
extends Node3D

var target: Node3D
var height := 1.5
var distance := 4.5
var zoom := 1.0
var yaw := 0.0
var pitch := -0.2
var follow_vehicle := false
var sensitivity := 0.0025
var spring: SpringArm3D
var camera: Camera3D
var _idle := 10.0


func _ready() -> void:
    top_level = true
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    spring = SpringArm3D.new()
    spring.collision_mask = 1
    spring.margin = 0.15
    var s := SphereShape3D.new()
    s.radius = 0.2
    spring.shape = s
    spring.spring_length = distance
    add_child(spring)
    camera = Camera3D.new()
    camera.fov = 70.0
    camera.near = 0.1
    camera.far = 6000.0
    spring.add_child(camera)
    camera.make_current()


func set_target(node: Node3D, h: float, dist: float, vehicle: bool) -> void:
    target = node
    height = h
    distance = dist
    follow_vehicle = vehicle
    _idle = 10.0
    if not vehicle and node:
        global_position = node.global_position + Vector3.UP * h


func _unhandled_input(event: InputEvent) -> void:
    if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        return
    if event is InputEventMouseMotion:
        yaw -= event.relative.x * sensitivity
        pitch = clampf(pitch - event.relative.y * sensitivity, -1.3, 0.6)
        _idle = 0.0
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom = maxf(0.5, zoom - 0.1)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom = minf(2.2, zoom + 0.1)


func _process(delta: float) -> void:
    if target == null:
        return
    _idle += delta
    var t := target.get_global_transform_interpolated()
    var desired := t.origin + Vector3.UP * height
    var spd := 0.0
    if follow_vehicle:
        global_position = global_position.lerp(desired, 1.0 - exp(-14.0 * delta))
        var body := target as RigidBody3D
        var fwd := t.basis.z
        spd = body.linear_velocity.dot(fwd)
        if _idle > 1.2 and absf(spd) > 2.0:
            var behind := atan2(fwd.x, fwd.z) + PI
            yaw = lerp_angle(yaw, behind, 1.0 - exp(-3.0 * delta))
            pitch = lerpf(pitch, -0.2, 1.0 - exp(-2.0 * delta))
    else:
        global_position = global_position.lerp(desired, 1.0 - exp(-25.0 * delta))
    rotation = Vector3(pitch, yaw, 0.0)
    spring.spring_length = lerpf(spring.spring_length, distance * zoom, 1.0 - exp(-6.0 * delta))
    camera.fov = lerpf(camera.fov, 70.0 + clampf(absf(spd) / 40.0, 0.0, 1.0) * 14.0, 1.0 - exp(-4.0 * delta))
