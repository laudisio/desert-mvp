class_name Npc
extends StaticBody3D
## Idle low-poly NPC: breathes and turns its head toward `watch` when close.

const LOOK_RADIUS := 9.0

var kind := ""
var watch: Node3D
var model: Node3D
var torso: Node3D
var head: Node3D
var _phase := 0.0


func setup(kind_name: String) -> void:
    kind = kind_name
    collision_layer = 1
    collision_mask = 0
    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.32
    cap.height = 1.8
    shape.shape = cap
    shape.position.y = 0.9
    add_child(shape)
    _phase = randf() * TAU
    _build()


func _m(key: String, c: Color, rough := 0.8) -> StandardMaterial3D:
    return Mats.solid("npc_" + key, c, rough)


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.rotation = rot
    parent.add_child(mi)
    return mi


func _node(parent: Node3D, pos: Vector3) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    parent.add_child(n)
    return n


func _build() -> void:
    var skin_light := Color(0.9, 0.72, 0.6)
    var s := {
        "skin": skin_light, "shirt": Color(0.8, 0.8, 0.8), "pants": Color(0.2, 0.2, 0.22),
        "shoes": Color(0.1, 0.08, 0.07), "hair": Color(0.2, 0.14, 0.1), "bald": false,
        "jacket": null, "tie": null, "glasses": false, "long_hair": false, "goatee": false,
        "fringe": null, "stubble": null, "crutches": false, "width": 1.0, "height": 1.0,
        "belly": 0.0, "hands": "side",
    }
    match kind:
        "gerente":
            s.skin = Color(0.5, 0.34, 0.24)
            s.shirt = Color(0.97, 0.86, 0.45)
            s.tie = Color(0.25, 0.12, 0.08)
            s.pants = Color(0.14, 0.15, 0.2)
            s.hair = Color(0.08, 0.07, 0.07)
            s.glasses = true
            s.hands = "front"
            s.height = 1.02
        "advogado":
            s.shirt = Color(0.55, 0.3, 0.6)
            s.jacket = Color(0.55, 0.5, 0.38)
            s.tie = Color(0.95, 0.75, 0.15)
            s.pants = Color(0.55, 0.5, 0.38)
            s.hair = Color(0.35, 0.24, 0.15)
            s.hands = "open"
            s.belly = 0.03
        "careca":
            s.skin = Color(0.88, 0.7, 0.6)
            s.shirt = Color(0.35, 0.33, 0.3)
            s.jacket = Color(0.56, 0.48, 0.36)
            s.pants = Color(0.2, 0.2, 0.22)
            s.bald = true
            s.fringe = Color(0.78, 0.76, 0.72)
            s.stubble = Color(0.72, 0.7, 0.66)
            s.width = 1.06
            s.hands = "side"
        "mulher":
            s.shirt = Color(0.35, 0.5, 0.72)
            s.pants = Color(0.22, 0.3, 0.45)
            s.hair = Color(0.92, 0.8, 0.5)
            s.long_hair = true
            s.width = 0.88
            s.height = 0.96
            s.hands = "front"
        "forte":
            s.shirt = Color(0.42, 0.18, 0.16)
            s.pants = Color(0.6, 0.52, 0.38)
            s.bald = true
            s.goatee = true
            s.hair = Color(0.3, 0.2, 0.12)
            s.width = 1.18
            s.belly = 0.06
            s.hands = "hips"
        "adolescente":
            s.shirt = Color(0.2, 0.22, 0.3)
            s.jacket = Color(0.15, 0.17, 0.22)
            s.pants = Color(0.3, 0.35, 0.45)
            s.hair = Color(0.12, 0.09, 0.07)
            s.glasses = true
            s.crutches = true
            s.height = 0.97
    _build_body(s)


func _build_body(s: Dictionary) -> void:
    model = _node(self, Vector3.ZERO)
    model.scale = Vector3(1.0, s.height, 1.0)
    var w: float = s.width
    var skin := _m(kind + "_skin", s.skin, 0.7)
    var shirt := _m(kind + "_shirt", s.shirt)
    var pants := _m(kind + "_pants", s.pants, 0.9)
    var shoes := _m("shoes", s.shoes, 0.6)
    var dark := _m("eyes", Color(0.05, 0.05, 0.05), 0.4)
    var top: Material = shirt if s.jacket == null else _m(kind + "_jacket", s.jacket)

    for sx in [-0.11 * w, 0.11 * w]:
        _part(model, GeoBuilder.box_mesh(Vector3(0.17 * w, 0.82, 0.2)), pants, Vector3(sx, 0.51, 0))
        _part(model, GeoBuilder.box_mesh(Vector3(0.18 * w, 0.1, 0.3)), shoes, Vector3(sx, 0.05, 0.05))

    torso = _node(model, Vector3(0, 0.92, 0))
    _part(torso, GeoBuilder.box_mesh(Vector3(0.44 * w, 0.18, 0.25 + s.belly)), pants, Vector3(0, 0.05, 0))
    _part(torso, GeoBuilder.box_mesh(Vector3(0.46 * w, 0.6, 0.26 + s.belly)), top, Vector3(0, 0.35, 0))
    if s.jacket != null:
        _part(torso, GeoBuilder.box_mesh(Vector3(0.16, 0.42, 0.02)), shirt, Vector3(0, 0.44, 0.135 + s.belly * 0.5))
    if s.tie != null:
        _part(torso, GeoBuilder.box_mesh(Vector3(0.07, 0.4, 0.02)), _m(kind + "_tie", s.tie, 0.5), Vector3(0, 0.45, 0.15 + s.belly * 0.5))
    if s.long_hair:
        _part(torso, GeoBuilder.box_mesh(Vector3(0.32, 0.26, 0.08)), _m(kind + "_hair", s.hair), Vector3(0, 0.58, -0.15))

    for side in [-1.0, 1.0]:
        var arm := _node(torso, Vector3(side * 0.31 * w, 0.6, 0))
        _part(arm, GeoBuilder.box_mesh(Vector3(0.14, 0.3, 0.15)), top, Vector3(0, -0.13, 0))
        _part(arm, GeoBuilder.box_mesh(Vector3(0.11, 0.34, 0.12)), top if s.jacket != null else skin, Vector3(0, -0.44, 0))
        _part(arm, GeoBuilder.sphere_mesh(0.06, 0.12, 8, 4), skin, Vector3(0, -0.64, 0))
        match s.hands:
            "front":
                arm.rotation = Vector3(-0.45, 0, -side * 0.42)
            "open":
                arm.rotation = Vector3(-0.7, 0, side * 0.25)
            "hips":
                arm.rotation = Vector3(0, 0, side * 0.55)
            _:
                arm.rotation = Vector3(0, 0, side * 0.06)
        if s.crutches:
            arm.rotation = Vector3(-0.15, 0, side * 0.12)
            var c := _node(model, Vector3(side * 0.42 * w, 0, 0.12))
            c.rotation = Vector3(-0.05, 0, side * 0.05)
            var metal := _m("crutch", Color(0.7, 0.72, 0.75), 0.3)
            _part(c, GeoBuilder.cyl_mesh(0.02, 0.02, 1.3, 6), metal, Vector3(0, 0.65, 0))
            _part(c, GeoBuilder.box_mesh(Vector3(0.12, 0.04, 0.05)), _m("crutch_pad", Color(0.1, 0.1, 0.1)), Vector3(0, 1.3, 0))

    _part(torso, GeoBuilder.cyl_mesh(0.06, 0.06, 0.1, 8), skin, Vector3(0, 0.69, 0))
    head = _node(torso, Vector3(0, 0.85, 0))
    _part(head, GeoBuilder.sphere_mesh(0.14, 0.3, 12, 8), skin, Vector3.ZERO)
    var hair := _m(kind + "_hair", s.hair, 0.9)
    if not s.bald:
        _part(head, GeoBuilder.sphere_mesh(0.148, 0.2, 12, 6), hair, Vector3(0, 0.08, -0.01))
    if s.long_hair:
        _part(head, GeoBuilder.box_mesh(Vector3(0.31, 0.3, 0.12)), hair, Vector3(0, -0.04, -0.1))
    if s.fringe != null:
        _part(head, GeoBuilder.cyl_mesh(0.145, 0.145, 0.07, 12), _m(kind + "_fringe", s.fringe), Vector3(0, -0.01, -0.02))
    if s.stubble != null:
        _part(head, GeoBuilder.box_mesh(Vector3(0.2, 0.08, 0.08)), _m(kind + "_stubble", s.stubble), Vector3(0, -0.1, 0.09))
    if s.goatee:
        _part(head, GeoBuilder.box_mesh(Vector3(0.09, 0.09, 0.05)), hair, Vector3(0, -0.12, 0.12))
        _part(head, GeoBuilder.box_mesh(Vector3(0.12, 0.025, 0.04)), hair, Vector3(0, -0.05, 0.135))
    for sx in [-0.05, 0.05]:
        _part(head, GeoBuilder.box_mesh(Vector3(0.04, 0.025, 0.02)), dark, Vector3(sx, 0.02, 0.135))
    if s.glasses:
        var frame := _m("glasses", Color(0.08, 0.08, 0.08), 0.3)
        for sx in [-0.055, 0.055]:
            _part(head, GeoBuilder.box_mesh(Vector3(0.085, 0.055, 0.012)), frame, Vector3(sx, 0.02, 0.148))
        _part(head, GeoBuilder.box_mesh(Vector3(0.3, 0.015, 0.012)), frame, Vector3(0, 0.035, 0.145))
    _part(head, GeoBuilder.box_mesh(Vector3(0.03, 0.05, 0.04)), skin, Vector3(0, -0.02, 0.145))


func _process(delta: float) -> void:
    _phase += delta * 1.6
    torso.position.y = 0.92 + sin(_phase) * 0.006
    torso.scale = Vector3(1.0 + sin(_phase) * 0.012, 1.0, 1.0 + sin(_phase) * 0.012)
    var target_yaw := 0.0
    if watch and watch.is_visible_in_tree():
        var to_p := global_transform.affine_inverse() * watch.global_position
        if to_p.length() < LOOK_RADIUS and to_p.z > -0.5:
            target_yaw = clampf(atan2(to_p.x, to_p.z), -1.1, 1.1)
    head.rotation.y = lerp_angle(head.rotation.y, target_yaw, 1.0 - exp(-4.0 * delta))
