class_name GeoBuilder
extends RefCounted
## Merges many primitive meshes into one ArrayMesh (one surface per material)
## and collects box colliders into a single StaticBody3D.

var _tools: Dictionary = {}
var _order: Array = []
var _shapes: Array = []


static var _hip_cache := {}


static func box_mesh(size: Vector3) -> BoxMesh:
    var m := BoxMesh.new()
    m.size = size
    return m


static func cyl_mesh(r_top: float, r_bottom: float, h: float, segments := 8) -> CylinderMesh:
    var m := CylinderMesh.new()
    m.top_radius = r_top
    m.bottom_radius = r_bottom
    m.height = h
    m.radial_segments = segments
    m.rings = 1
    return m


static func sphere_mesh(r: float, h: float, segments := 8, rings := 5) -> SphereMesh:
    var m := SphereMesh.new()
    m.radius = r
    m.height = h
    m.radial_segments = segments
    m.rings = rings
    return m


## Hip roof: base w (x) by d (z) at y=0, ridge along the longer side.
static func hip_roof_mesh(w: float, d: float, h: float) -> ArrayMesh:
    var key := "hip_%.2f_%.2f_%.2f" % [w, d, h]
    if _hip_cache.has(key):
        return _hip_cache[key]
    var x := w * 0.5
    var z := d * 0.5
    var rx := maxf(x - z, 0.0)
    var rz := maxf(z - x, 0.0)
    var a := Vector3(-rx, h, -rz)
    var c := Vector3(rx, h, rz)
    var p := [Vector3(-x, 0, -z), Vector3(x, 0, -z), Vector3(x, 0, z), Vector3(-x, 0, z)]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var faces := []
    if rx > 0.0:
        faces = [[p[0], p[1], c, a], [p[2], p[3], a, c], [p[1], p[2], c], [p[3], p[0], a]]
    else:
        faces = [[p[1], p[2], c, a], [p[3], p[0], a, c], [p[0], p[1], a], [p[2], p[3], c]]
    faces.append([p[0], p[3], p[2], p[1]])
    for f in faces:
        var cen := Vector3.ZERO
        for v in f:
            cen += v
        cen /= f.size()
        var out: Vector3 = cen - Vector3(0, h * 0.3, 0)
        if f.size() == 4 and f[0].y == 0.0 and f[2].y == 0.0:
            out = Vector3.DOWN
        for k in range(1, f.size() - 1):
            var v0: Vector3 = f[0]
            var v1: Vector3 = f[k]
            var v2: Vector3 = f[k + 1]
            if (v1 - v0).cross(v2 - v0).dot(out) > 0.0:
                var t := v1
                v1 = v2
                v2 = t
            st.add_vertex(v0)
            st.add_vertex(v1)
            st.add_vertex(v2)
    st.generate_normals()
    st.index()
    var m := st.commit()
    _hip_cache[key] = m
    return m


static func prism_mesh(size: Vector3) -> PrismMesh:
    var m := PrismMesh.new()
    m.size = size
    return m


func mesh(m: Mesh, xf: Transform3D, mat: Material, surface := 0) -> void:
    var st: SurfaceTool = _tools.get(mat)
    if st == null:
        st = SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        _tools[mat] = st
        _order.append(mat)
    st.append_from(m, surface, xf)


func mesh_multi(m: Mesh, xf: Transform3D, mats: Array) -> void:
    for i in m.get_surface_count():
        mesh(m, xf, mats[i], i)


func box(xf: Transform3D, size: Vector3, mat: Material, collide := true) -> void:
    mesh(box_mesh(size), xf, mat)
    if collide:
        shape_box(xf, size)


func shape_box(xf: Transform3D, size: Vector3) -> void:
    var s := BoxShape3D.new()
    s.size = size
    _shapes.append([xf, s])


func build(parent: Node, node_name: String) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = node_name
    body.collision_layer = 1
    body.collision_mask = 0
    if not _order.is_empty():
        var am := ArrayMesh.new()
        for mat in _order:
            var st: SurfaceTool = _tools[mat]
            st.commit(am)
            am.surface_set_material(am.get_surface_count() - 1, mat)
        var mi := MeshInstance3D.new()
        mi.mesh = am
        body.add_child(mi)
    for s in _shapes:
        var cs := CollisionShape3D.new()
        cs.shape = s[1]
        cs.transform = s[0]
        body.add_child(cs)
    parent.add_child(body)
    return body
