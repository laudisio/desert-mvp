class_name TrafficCar
extends AnimatableBody3D
## AI car that follows the right-hand lane of the street grid, picks a random
## direction at each intersection and slows / stops for anything ahead.

const LANE := 1.8
const CRUISE := 10.0
const TURN_SPEED := 5.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var traffic: Traffic
var id := 0
var node := Vector2i.ZERO
var dir := Vector2i.ZERO
var speed := 0.0
var segs: Array = []
var blocker: Node3D = null
var blocked_time := 0.0
var _t := 0.0
var _len := 1.0
var _wheels: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


static func center(n: Vector2i) -> Vector3:
    return Vector3(City.line(n.x), 0.02, City.line(n.y))


static func d3(d: Vector2i) -> Vector3:
    return Vector3(d.x, 0, d.y)


static func right(d: Vector2i) -> Vector3:
    return Vector3(-d.y, 0, d.x)


static func inside(n: Vector2i) -> bool:
    return n.x >= 0 and n.y >= 0 and n.x <= City.N and n.y <= City.N


func setup(tr: Traffic, idx: int, paint: Material, from_node: Vector2i, d: Vector2i, frac: float) -> void:
    traffic = tr
    id = idx
    _rng.seed = 900 + idx
    collision_layer = 4
    collision_mask = 0
    _build(paint)
    dir = d
    node = from_node + d
    var p0 := center(from_node) + d3(d) * 5.0 + right(d) * LANE
    var p1 := center(node) - d3(d) * 5.0 + right(d) * LANE
    p0 = p0.lerp(p1, frac)
    segs = [[p0, (p0 + p1) * 0.5, p1, CRUISE]]
    _start_seg()
    global_transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), p0)


func _build(paint: Material) -> void:
    var M: Dictionary = traffic.main.city.M
    var parts := [
        [Vector3(1.8, 0.62, 4.4), Vector3(0, 0.62, 0), paint],
        [Vector3(1.6, 0.55, 2.2), Vector3(0, 1.2, -0.2), M.glass],
        [Vector3(1.56, 0.06, 1.9), Vector3(0, 1.49, -0.25), paint],
    ]
    for sx in [-0.62, 0.62]:
        parts.append([Vector3(0.35, 0.14, 0.04), Vector3(sx, 0.75, -2.21), M.tail])
        parts.append([Vector3(0.35, 0.14, 0.04), Vector3(sx, 0.75, 2.21), M.lamp])
    for p in parts:
        var mi := MeshInstance3D.new()
        mi.mesh = GeoBuilder.box_mesh(p[0])
        mi.position = p[1]
        mi.material_override = p[2]
        add_child(mi)
    for sx in [-0.82, 0.82]:
        for sz in [-1.35, 1.35]:
            var w := Node3D.new()
            w.position = Vector3(sx, 0.34, sz)
            var mi := MeshInstance3D.new()
            mi.mesh = GeoBuilder.cyl_mesh(0.34, 0.34, 0.24, 10)
            mi.material_override = M.tire
            mi.rotation.z = PI * 0.5
            w.add_child(mi)
            add_child(w)
            _wheels.append(w)
    var cs := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1.8, 1.3, 4.4)
    cs.shape = box
    cs.position.y = 0.85
    add_child(cs)


func _bez(sg: Array, t: float) -> Vector3:
    var a: Vector3 = sg[0]
    var c: Vector3 = sg[1]
    var b: Vector3 = sg[2]
    return a.lerp(c, t).lerp(c.lerp(b, t), t)


func _start_seg() -> void:
    var sg: Array = segs[0]
    var l := 0.0
    var prev := _bez(sg, 0.0)
    for k in range(1, 9):
        var p := _bez(sg, k / 8.0)
        l += prev.distance_to(p)
        prev = p
    _len = maxf(l, 0.01)


func _plan_next() -> void:
    var last: Array = segs[segs.size() - 1]
    var p1: Vector3 = last[2]
    var options: Array[Vector2i] = []
    for d in DIRS:
        if d == -dir or not inside(node + d):
            continue
        options.append(d)
        if d == dir:
            options.append(d)
    var d2: Vector2i = options[_rng.randi() % options.size()] if not options.is_empty() else -dir
    var a := center(node)
    var q0 := a + d3(d2) * 5.0 + right(d2) * LANE
    var c := (p1 + q0) * 0.5 if d2 == dir else a + right(dir) * LANE + right(d2) * LANE
    var nxt := node + d2
    var q1 := center(nxt) - d3(d2) * 5.0 + right(d2) * LANE
    segs.append([p1, c, q0, CRUISE if d2 == dir else TURN_SPEED])
    segs.append([q0, (q0 + q1) * 0.5, q1, CRUISE])
    dir = d2
    node = nxt


func u_turn() -> void:
    var p := global_position
    var f := d3(dir)
    var r := right(dir)
    var p1 := p - r * LANE * 2.0
    var from_node := node - dir
    dir = -dir
    node = from_node
    var q1 := center(node) - d3(dir) * 5.0 + right(dir) * LANE
    segs = [[p, p + f * 5.0 - r * LANE, p1, 3.0], [p1, (p1 + q1) * 0.5, q1, CRUISE]]
    _t = 0.0
    _start_seg()
    blocked_time = 0.0


func teleport_to(from_node: Vector2i, d: Vector2i) -> void:
    dir = d
    node = from_node + d
    var p0 := center(from_node) + d3(d) * 5.0 + right(d) * LANE
    var p1 := center(node) - d3(d) * 5.0 + right(d) * LANE
    segs = [[p0, (p0 + p1) * 0.5, p1, CRUISE]]
    _t = 0.0
    speed = 0.0
    blocked_time = 0.0
    _start_seg()
    global_transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), p0)
    reset_physics_interpolation()


func _physics_process(delta: float) -> void:
    if segs.size() < 2:
        _plan_next()
    var sg: Array = segs[0]
    var remaining := (1.0 - _t) * _len
    var target := minf(sg[3], float(segs[1][3]) + remaining * 0.7)
    var ob: Array = traffic.obstacle_ahead(self)
    blocker = ob[1]
    if blocker:
        target = minf(target, maxf(0.0, ob[0] * 1.1))
    speed = move_toward(speed, target, (4.0 if target > speed else 14.0) * delta)
    _t += speed * delta / _len
    while _t >= 1.0:
        var extra := (_t - 1.0) * _len
        segs.pop_front()
        if segs.size() < 2:
            _plan_next()
        _start_seg()
        _t = extra / _len
    var cur: Array = segs[0]
    var pos := _bez(cur, _t)
    var tan := _bez(cur, minf(_t + 0.02, 1.0)) - _bez(cur, maxf(_t - 0.02, 0.0))
    var yaw := atan2(tan.x, tan.z) if tan.length_squared() > 0.000001 else rotation.y
    global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
    for w in _wheels:
        w.rotation.x += speed * delta / 0.34
    if blocker and speed < 0.3:
        blocked_time += delta
    else:
        blocked_time = 0.0
