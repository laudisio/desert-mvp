class_name GeoBuilder
extends RefCounted
## Merges many primitive meshes into one ArrayMesh (one surface per material)
## and collects box colliders into a single StaticBody3D.

var _tools: Dictionary = {}
var _order: Array = []
var _shapes: Array = []


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


static func prism_mesh(size: Vector3) -> PrismMesh:
    var m := PrismMesh.new()
    m.size = size
    return m


func mesh(m: Mesh, xf: Transform3D, mat: Material) -> void:
    var st: SurfaceTool = _tools.get(mat)
    if st == null:
        st = SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        _tools[mat] = st
        _order.append(mat)
    st.append_from(m, 0, xf)


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
