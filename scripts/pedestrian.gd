class_name Pedestrian
extends Npc
## Walks a loop around a city block's sidewalk; jumps out of the way of fast
## cars and gets knocked down (then stands back up) when hit.

const H := 24.8
const DOWN_TIME := 4.0

var traffic: Traffic
var center := Vector3.ZERO
var s := 0.0
var dir := 1.0
var speed := 1.3
var off := Vector3.ZERO
var down_time := 0.0
var _flee := Vector3.ZERO
var _flee_time := 0.0


func place(block_center: Vector3, start: float, direction: float, walk_speed: float) -> void:
    center = block_center
    s = start
    dir = direction
    speed = walk_speed
    collision_layer = 8
    collision_mask = 0
    global_position = _ground(path_point(s))
    var a := path_point(s + dir)
    var b := path_point(s)
    rotation.y = atan2(a.x - b.x, a.z - b.z)


func path_point(p: float) -> Vector3:
    p = fposmod(p, 8.0 * H)
    var side := int(p / (2.0 * H))
    var t := p - side * 2.0 * H - H
    match side:
        0:
            return center + Vector3(t, 0, -H)
        1:
            return center + Vector3(H, 0, t)
        2:
            return center + Vector3(-t, 0, H)
        _:
            return center + Vector3(-H, 0, -t)


func _ground(p: Vector3) -> Vector3:
    var on_slab := maxf(absf(p.x - center.x), absf(p.z - center.z)) <= City.SLAB * 0.5
    p.y = City.CURB if on_slab else 0.02
    return p


func knock_down(push: Vector3) -> void:
    if down_time > 0.0:
        return
    down_time = DOWN_TIME
    _flee_time = 0.0
    var flat := Vector3(push.x, 0, push.z)
    if flat.length_squared() > 0.01:
        rotation.y = atan2(flat.x, flat.z)
        off += flat.normalized() * 1.5
    model.rotation.x = PI * 0.5
    model.position.y = 0.18
    body_shape.disabled = true
    walk_amount = 0.0


func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if down_time > 0.0:
        down_time -= delta
        if down_time <= 0.0:
            model.rotation.x = 0.0
            model.position.y = 0.0
            body_shape.disabled = false
        return
    var prev := global_position
    var threat := traffic.threat_to(self)
    if threat != Vector3.ZERO and _flee_time <= 0.0:
        _flee = threat * 4.5
        _flee_time = 1.0
    if _flee_time > 0.0:
        _flee_time -= delta
        off += _flee * delta
    elif not _player_blocking():
        s += dir * speed * delta
        off = off.move_toward(Vector3.ZERO, 1.2 * delta)
    off = off.limit_length(8.0)
    global_position = _ground(path_point(s) + off)
    var d := global_position - prev
    d.y = 0.0
    var v := d.length() / maxf(delta, 0.0001)
    walk_amount = clampf(v / 1.4, 0.0, 1.6)
    if d.length_squared() > 0.000001:
        rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 1.0 - exp(-10.0 * delta))


func _player_blocking() -> bool:
    var p: Player = traffic.main.player
    if not p.visible:
        return false
    var to_p := p.global_position - global_position
    to_p.y = 0.0
    if to_p.length() > 1.1:
        return false
    var fwd := path_point(s + dir) - path_point(s)
    return to_p.dot(fwd) > 0.0
