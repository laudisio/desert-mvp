class_name CarMesh
extends RefCounted
## Procedural rounded car bodies (lofted cross-sections) shared by the player
## sedan, AI traffic and parked props. Each mesh has one surface per ROLE.

const ROLES := ["paint", "glass", "trim", "chrome", "lamp", "tail", "plate", "well"]
const KINDS := ["sedan", "pickup", "suv"]

static var _cache := {}


static func role_materials(paint: Material, tail: Material = null) -> Array:
    return [
        paint,
        Mats.solid("glass", Color(0.1, 0.14, 0.18), 0.08, 0.6),
        Mats.solid("car_trim", Color(0.12, 0.12, 0.13), 0.6),
        Mats.solid("chrome", Color(0.82, 0.83, 0.85), 0.2, 1.0),
        Mats.emissive("lamp", Color(1.0, 0.95, 0.8), 0.4),
        tail if tail else Mats.solid("tail", Color(0.6, 0.05, 0.05), 0.4),
        Mats.solid("plate", Color(0.92, 0.88, 0.7), 0.6),
        Mats.solid("wheel_well", Color(0.03, 0.03, 0.03), 1.0),
    ]


static func apply(mi: MeshInstance3D, mats: Array) -> void:
    for i in mi.mesh.get_surface_count():
        mi.set_surface_override_material(i, mats[i])


## Returns {mesh, wheels: [[pos, radius, width]], size, center}.
static func get_car(kind: String) -> Dictionary:
    if not _cache.has(kind):
        _cache[kind] = _build(kind)
    return _cache[kind]


static func get_wheel(radius: float, width: float) -> ArrayMesh:
    var key := "wheel_%.2f_%.2f" % [radius, width]
    if _cache.has(key):
        return _cache[key]
    var am := ArrayMesh.new()
    var tire := TorusMesh.new()
    tire.inner_radius = radius * 0.5
    tire.outer_radius = radius
    tire.rings = 20
    tire.ring_segments = 8
    var tube := radius * 0.25
    var sx := width * 0.5 / tube
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.append_from(tire, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3(sx, 1, 1)), Vector3.ZERO))
    st.append_from(GeoBuilder.cyl_mesh(radius * 0.55, radius * 0.55, width * 0.7, 16), 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO))
    st.commit(am)
    am.surface_set_material(0, Mats.solid("tire", Color(0.06, 0.06, 0.06), 0.9))
    var st2 := SurfaceTool.new()
    st2.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rot := Basis(Vector3.BACK, PI * 0.5)
    for side in [-1.0, 1.0]:
        st2.append_from(GeoBuilder.cyl_mesh(radius * 0.5, radius * 0.5, 0.02, 14), 0, Transform3D(rot, Vector3(side * width * 0.36, 0, 0)))
        st2.append_from(GeoBuilder.cyl_mesh(radius * 0.16, radius * 0.16, 0.05, 8), 0, Transform3D(rot, Vector3(side * width * 0.38, 0, 0)))
        for k in 5:
            var a := TAU * k / 5.0
            var off := Vector3(side * (width * 0.36 + 0.012), cos(a) * radius * 0.3, sin(a) * radius * 0.3)
            st2.append_from(GeoBuilder.cyl_mesh(0.025, 0.025, 0.03, 6), 0, Transform3D(rot, off))
    st2.commit(am)
    am.surface_set_material(1, Mats.solid("hub", Color(0.75, 0.75, 0.78), 0.3, 0.9))
    _cache[key] = am
    return am


# section: [z, y_bottom, y_top, half_width_bottom, half_width_top, chamfer]
static func _ring(s: Array) -> Array:
    var z: float = s[0]
    var yb: float = s[1]
    var yt: float = s[2]
    var wb: float = s[3]
    var wt: float = s[4]
    var c: float = minf(s[5], minf((yt - yb) * 0.45, wt * 0.45))
    return [
        Vector3(wb - c, yb, z), Vector3(wb, yb + c, z), Vector3(wt, yt - c, z), Vector3(wt - c, yt, z),
        Vector3(-wt + c, yt, z), Vector3(-wt, yt - c, z), Vector3(-wb, yb + c, z), Vector3(-wb + c, yb, z),
    ]


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
    if (b - a).cross(c - a).dot(out) > 0.0:
        var t := b
        b = c
        c = t
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)


static func loft(sections: Array, xf := Transform3D.IDENTITY) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings: Array = []
    for s in sections:
        var r := _ring(s)
        for i in r.size():
            r[i] = xf * r[i]
        rings.append(r)
    var axis: Array = []
    for s in sections:
        axis.append(xf * Vector3(0, (s[1] + s[2]) * 0.5, s[0]))
    st.set_smooth_group(0)
    for i in rings.size() - 1:
        var a: Array = rings[i]
        var b: Array = rings[i + 1]
        var mid: Vector3 = (axis[i] + axis[i + 1]) * 0.5
        for k in 8:
            var k2 := (k + 1) % 8
            var out: Vector3 = (a[k] + a[k2] + b[k] + b[k2]) * 0.25 - mid
            _tri(st, a[k], a[k2], b[k2], out)
            _tri(st, a[k], b[k2], b[k], out)
    st.set_smooth_group(0xFFFFFFFF)
    for e in [[0, -1.0], [rings.size() - 1, 1.0]]:
        var r: Array = rings[e[0]]
        var cen: Vector3 = axis[e[0]]
        var out := xf.basis * Vector3(0, 0, e[1])
        for k in 8:
            _tri(st, cen, r[k], r[(k + 1) % 8], out)
    st.generate_normals()
    st.index()
    return st.commit()


static func _box(st: SurfaceTool, size: Vector3, pos: Vector3, basis := Basis.IDENTITY) -> void:
    st.append_from(GeoBuilder.box_mesh(size), 0, Transform3D(basis, pos))


static func _build(kind: String) -> Dictionary:
    var body: Array
    var cabin: Array
    var roof: Array
    var wz := Vector2(1.42, -1.42)
    var wr := 0.35
    var bed := false
    match kind:
        "pickup":
            body = [[-2.45, 0.48, 1.06, 0.88, 0.86, 0.08], [-2.35, 0.42, 1.1, 0.93, 0.91, 0.08], [-0.3, 0.4, 1.1, 0.94, 0.91, 0.1],
                [1.3, 0.4, 1.06, 0.94, 0.9, 0.1], [2.2, 0.44, 0.94, 0.9, 0.84, 0.12], [2.42, 0.52, 0.82, 0.84, 0.78, 0.12]]
            cabin = [[-0.32, 1.04, 1.64, 0.9, 0.78, 0.06], [0.35, 1.04, 1.67, 0.9, 0.78, 0.08], [1.28, 1.04, 1.1, 0.9, 0.88, 0.02]]
            roof = [[-0.3, 1.61, 1.67, 0.8, 0.76, 0.03], [0.3, 1.64, 1.7, 0.8, 0.76, 0.03]]
            wz = Vector2(1.55, -1.6)
            wr = 0.38
            bed = true
        "suv":
            body = [[-2.3, 0.5, 1.08, 0.86, 0.84, 0.1], [-2.2, 0.42, 1.12, 0.94, 0.9, 0.12], [1.2, 0.42, 1.1, 0.94, 0.9, 0.1],
                [2.05, 0.45, 0.98, 0.92, 0.86, 0.12], [2.3, 0.52, 0.86, 0.86, 0.8, 0.12]]
            cabin = [[-2.22, 1.08, 1.78, 0.9, 0.78, 0.08], [-1.95, 1.08, 1.86, 0.9, 0.78, 0.1], [0.45, 1.08, 1.88, 0.9, 0.78, 0.1], [1.3, 1.08, 1.12, 0.9, 0.88, 0.02]]
            roof = [[-2.0, 1.83, 1.9, 0.8, 0.76, 0.03], [0.4, 1.85, 1.92, 0.8, 0.76, 0.03]]
            wz = Vector2(1.45, -1.45)
            wr = 0.4
        _:
            body = [[-2.25, 0.42, 0.86, 0.84, 0.8, 0.12], [-2.12, 0.34, 0.98, 0.9, 0.86, 0.12], [-1.0, 0.3, 1.0, 0.92, 0.88, 0.1],
                [1.1, 0.3, 0.98, 0.92, 0.88, 0.1], [2.0, 0.32, 0.86, 0.9, 0.85, 0.12], [2.25, 0.4, 0.74, 0.84, 0.78, 0.12]]
            cabin = [[-1.2, 0.96, 1.0, 0.86, 0.84, 0.02], [-0.55, 0.96, 1.47, 0.86, 0.7, 0.08], [0.45, 0.96, 1.5, 0.86, 0.7, 0.08], [1.28, 0.96, 1.0, 0.86, 0.84, 0.02]]
            roof = [[-0.5, 1.44, 1.5, 0.72, 0.68, 0.03], [0.4, 1.47, 1.53, 0.72, 0.68, 0.03]]
    var front: Array = body[body.size() - 1]
    var rear: Array = body[0]
    var hw: float = 0.0
    for s in body:
        hw = maxf(hw, s[3])
    var sts := {}
    for r in ROLES:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        sts[r] = st
    sts.paint.append_from(loft(body), 0, Transform3D.IDENTITY)
    sts.glass.append_from(loft(cabin), 0, Transform3D.IDENTITY)
    sts.paint.append_from(loft(roof), 0, Transform3D.IDENTITY)
    if bed:
        _box(sts.trim, Vector3(hw * 2.0 - 0.22, 0.04, 1.95), Vector3(0, 1.1, -1.32))
    var belt: float = cabin[1][1]
    for sx in [-1.0, 1.0]:
        # mirror, handles, door seams
        _box(sts.paint, Vector3(0.16, 0.1, 0.12), Vector3(sx * (hw + 0.06), belt + 0.08, cabin[cabin.size() - 1][0] - 0.25))
        for hz in [0.2, -0.85]:
            _box(sts.chrome, Vector3(0.03, 0.04, 0.18), Vector3(sx * (hw + 0.005), belt - 0.12, hz + (0.25 if bed else 0.0)))
        for seam in ([0.05, 1.15, -1.0] if kind != "pickup" else [0.05, 1.2, -0.32]):
            _box(sts.trim, Vector3(0.015, belt - 0.45, 0.02), Vector3(sx * (hw + 0.002), (belt + 0.45) * 0.5 + 0.02, seam))
        _box(sts.trim, Vector3(0.02, 0.06, wz.x - wz.y + 0.4), Vector3(sx * (hw + 0.004), front[1] + 0.12, (wz.x + wz.y) * 0.5))
        # lights
        _box(sts.lamp, Vector3(0.36, 0.13, 0.05), Vector3(sx * (front[4] - 0.24), front[2] - 0.1, front[0] + 0.005))
        _box(sts.tail, Vector3(0.38, 0.15, 0.05), Vector3(sx * (rear[4] - 0.24), rear[2] - 0.12, rear[0] - 0.005))
    # grille, bumpers, plate
    _box(sts.trim, Vector3(front[4] * 2.0 - 1.0, 0.14, 0.05), Vector3(0, front[2] - 0.12, front[0] + 0.01))
    var bump := CapsuleMesh.new()
    bump.radius = 0.1
    bump.height = hw * 2.0
    bump.radial_segments = 10
    bump.rings = 2
    sts.chrome.append_from(bump, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, front[1] + 0.02, front[0] - 0.02)))
    sts.chrome.append_from(bump, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, rear[1] + 0.02, rear[0] + 0.02)))
    _box(sts.plate, Vector3(0.42, 0.13, 0.02), Vector3(0, (rear[1] + rear[2]) * 0.5, rear[0] - 0.01))
    # wheel wells
    for z in [wz.x, wz.y]:
        for sx in [-1.0, 1.0]:
            sts.well.append_from(GeoBuilder.cyl_mesh(wr + 0.08, wr + 0.08, 0.02, 16), 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * (hw + 0.004), wr, z)))
    var am := ArrayMesh.new()
    for r in ROLES:
        var st: SurfaceTool = sts[r]
        st.commit(am)
    var wheels: Array = []
    for sx in [-1.0, 1.0]:
        for z in [wz.x, wz.y]:
            wheels.append([Vector3(sx * (hw - 0.1), wr, z), wr, 0.26])
    var len: float = front[0] - rear[0]
    var height: float = roof[roof.size() - 1][2]
    return {"mesh": am, "wheels": wheels, "size": Vector3(hw * 2.0, height - 0.3, len), "center": Vector3(0, (height + 0.3) * 0.5, (front[0] + rear[0]) * 0.5)}
