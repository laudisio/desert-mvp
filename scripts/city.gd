class_name City
extends Node3D
## Procedural Albuquerque-style suburb: road grid, stucco houses, desert, mountains.

const N := 5
const BLOCK := 48.0
const WALK := 2.0
const ROAD := 10.0
const SLAB := BLOCK + WALK * 2.0
const PITCH := SLAB + ROAD
const ORIGIN := -N * PITCH / 2.0
const CITY_EDGE := -ORIGIN + ROAD / 2.0
const CURB := 0.15
const WORLD_HALF := 985.0
const HWY_IDX := 2
const WEST_IDX := 3
const HWY_END := 940.0

const STUCCO := [
    Color(0.86, 0.74, 0.58), Color(0.80, 0.62, 0.45), Color(0.90, 0.84, 0.72),
    Color(0.78, 0.56, 0.46), Color(0.85, 0.78, 0.66), Color(0.72, 0.66, 0.55),
    Color(0.88, 0.72, 0.62),
]
const CAR_COLORS := [
    Color(0.7, 0.1, 0.1), Color(0.1, 0.2, 0.45), Color(0.85, 0.85, 0.82),
    Color(0.12, 0.12, 0.13), Color(0.55, 0.57, 0.6), Color(0.35, 0.42, 0.3),
    Color(0.6, 0.5, 0.35), Color(0.75, 0.6, 0.2),
]

var rng := RandomNumberGenerator.new()
var noise_dunes := FastNoiseLite.new()
var noise_mtn := FastNoiseLite.new()
var noise_tint := FastNoiseLite.new()
var M: Dictionary = {}

var player_spawn := Transform3D()
var spawn_yaw := 0.0
var sedan_spawn := Transform3D()
var rv_spawn := Transform3D()


static func line(i: int) -> float:
    return ORIGIN + i * PITCH


static func T(pos: Vector3, yaw := 0.0) -> Transform3D:
    return Transform3D(Basis(Vector3.UP, yaw), pos)


func build() -> void:
    rng.seed = 20081
    noise_dunes.seed = 7
    noise_dunes.frequency = 0.004
    noise_dunes.fractal_octaves = 3
    noise_mtn.seed = 11
    noise_mtn.frequency = 0.0022
    noise_mtn.fractal_octaves = 5
    noise_tint.seed = 3
    noise_tint.frequency = 0.02
    _make_materials()
    _build_terrain()
    _build_roads()
    for bx in N:
        for bz in N:
            _build_block(bx, bz)
    _build_highway_props()
    _build_bounds()

    var hz := line(HWY_IDX)
    player_spawn = T(Vector3(-2.0, CURB + 0.05, hz + ROAD / 2.0 + 1.0))
    spawn_yaw = -PI / 2.0
    sedan_spawn = T(Vector3(3.0, 0.4, hz + ROAD / 2.0 - 1.6), PI / 2.0)
    var rx := line(4) + PITCH / 2.0
    var rz := line(1) + PITCH / 2.0
    rv_spawn = T(Vector3(rx, CURB + 0.6, rz), PI / 2.0)


# ---------------------------------------------------------------- materials

func _make_materials() -> void:
    M.asphalt = Mats.make("asphalt", Color.WHITE, "asphalt", 0.2, 0.95)
    M.line_y = Mats.solid("line_y", Color(0.95, 0.75, 0.15), 0.7)
    M.line_w = Mats.solid("line_w", Color(0.92, 0.92, 0.9), 0.7)
    M.concrete = Mats.make("concrete", Color.WHITE, "concrete", 0.3, 0.9, "rough")
    M.gravel = Mats.make("gravel", Color.WHITE, "gravel", 0.6, 1.0, "rough")
    M.dirt = Mats.make("dirt", Color(0.95, 0.86, 0.76), "sand", 0.12, 1.0, "sand")
    M.lawn = Mats.make("lawn", Color.WHITE, "grass", 0.4, 1.0)
    var terrain := Mats.make("terrain", Color.WHITE, "sand", 0.05, 1.0, "sand")
    terrain.vertex_color_use_as_albedo = true
    M.terrain = terrain
    M.stucco = []
    for i in STUCCO.size():
        M.stucco.append(Mats.make("stucco_%d" % i, STUCCO[i], "grain", 0.5, 0.95, "stucco"))
    M.trim = Mats.solid("trim", Color(0.93, 0.91, 0.86), 0.6)
    M.wood = Mats.solid("wood", Color(0.36, 0.24, 0.15), 0.8)
    M.glass = Mats.solid("glass", Color(0.1, 0.14, 0.18), 0.08, 0.6)
    M.garage = Mats.solid("garage", Color(0.9, 0.87, 0.8), 0.6)
    M.doors = [
        Mats.solid("door_0", Color(0.4, 0.25, 0.15), 0.7),
        Mats.solid("door_1", Color(0.15, 0.35, 0.45), 0.6),
        Mats.solid("door_2", Color(0.55, 0.15, 0.12), 0.6),
    ]
    M.roof_tile = Mats.make("roof_tile", Color(0.68, 0.33, 0.22), "grain", 1.0, 0.85, "rough")
    M.roof_shingle = Mats.make("roof_shingle", Color(0.36, 0.33, 0.3), "grain", 1.0, 0.95, "rough")
    M.roof_flat = Mats.make("roof_flat", Color(0.7, 0.68, 0.64), "gravel", 0.8, 1.0)
    M.block_wall = Mats.make("block_wall", Color(0.85, 0.78, 0.68), "concrete", 0.6, 0.95, "rough")
    M.metal = Mats.solid("metal", Color(0.6, 0.62, 0.64), 0.4, 0.8)
    M.dark_metal = Mats.solid("dark_metal", Color(0.18, 0.18, 0.19), 0.5, 0.6)
    M.pole_wood = Mats.solid("pole_wood", Color(0.33, 0.26, 0.2), 0.9)
    M.wire = Mats.solid("wire", Color(0.05, 0.05, 0.05), 0.8)
    M.cactus = Mats.solid("cactus", Color(0.3, 0.44, 0.24), 0.8)
    M.plant = Mats.solid("plant", Color(0.45, 0.52, 0.32), 0.8)
    M.tree = Mats.solid("tree", Color(0.28, 0.4, 0.18), 0.9)
    M.trunk = Mats.solid("trunk", Color(0.35, 0.27, 0.2), 0.9)
    M.rock = Mats.make("rock", Color(0.72, 0.6, 0.52), "grain", 1.0, 1.0, "rough")
    M.tumbleweed = Mats.solid("tumbleweed", Color(0.55, 0.45, 0.3), 1.0)
    M.tire = Mats.solid("tire", Color(0.06, 0.06, 0.06), 0.9)
    M.red = Mats.solid("sign_red", Color(0.75, 0.08, 0.08), 0.5)
    M.white = Mats.solid("sign_white", Color(0.95, 0.95, 0.95), 0.5)
    M.orange = Mats.solid("orange", Color(0.95, 0.45, 0.05), 0.6)
    M.lamp = Mats.emissive("lamp", Color(1.0, 0.95, 0.8), 0.4)
    M.tail = Mats.solid("tail", Color(0.6, 0.05, 0.05), 0.4)
    M.pool = Mats.solid("pool", Color(0.2, 0.55, 0.75), 0.05, 0.1)
    M.cars = []
    for i in CAR_COLORS.size():
        M.cars.append(Mats.solid("car_%d" % i, CAR_COLORS[i], 0.35, 0.5))


# ---------------------------------------------------------------- terrain

func height_at(x: float, z: float) -> float:
    var d := maxf(absf(x), absf(z))
    var f := smoothstep(CITY_EDGE + 15.0, CITY_EDGE + 140.0, d)
    if x > CITY_EDGE - 30.0:
        f *= smoothstep(9.0, 40.0, absf(z - line(HWY_IDX)))
    if x < -CITY_EDGE + 30.0:
        f *= smoothstep(7.0, 35.0, absf(z - line(WEST_IDX)))
    var h := (noise_dunes.get_noise_2d(x, z) * 0.5 + 0.5) * 16.0 * f
    var ring := smoothstep(1050.0, 1700.0, d)
    var east := smoothstep(1050.0, 1500.0, x)
    if ring > 0.0 or east > 0.0:
        var m := noise_mtn.get_noise_2d(x, z) * 0.5 + 0.5
        var mesa := ring * (40.0 + m * 160.0)
        mesa = lerpf(mesa, floorf(mesa / 35.0) * 35.0, 0.6)
        h += mesa + east * (200.0 + m * 220.0)
    return h


func _terrain_color(x: float, z: float, h: float) -> Color:
    var t := noise_tint.get_noise_2d(x, z) * 0.5 + 0.5
    var c := Color(1.0, 0.97, 0.94).lerp(Color(0.86, 0.8, 0.72), t * 0.6)
    var rock := clampf((h - 25.0) / 200.0, 0.0, 1.0)
    return c.lerp(Color(0.93, 0.62, 0.55), rock)


func _terrain_mesh(half: float, step: float, skip_inner: float, y_off: float) -> ArrayMesh:
    var n := int(half * 2.0 / step)
    var heights := PackedFloat32Array()
    heights.resize((n + 1) * (n + 1))
    for iz in n + 1:
        for ix in n + 1:
            heights[iz * (n + 1) + ix] = height_at(-half + ix * step, -half + iz * step) + y_off
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for iz in n:
        for ix in n:
            var x0 := -half + ix * step
            var z0 := -half + iz * step
            if skip_inner > 0.0 and maxf(absf(x0 + step * 0.5), absf(z0 + step * 0.5)) < skip_inner:
                continue
            var x1 := x0 + step
            var z1 := z0 + step
            var v00 := Vector3(x0, heights[iz * (n + 1) + ix], z0)
            var v10 := Vector3(x1, heights[iz * (n + 1) + ix + 1], z0)
            var v01 := Vector3(x0, heights[(iz + 1) * (n + 1) + ix], z1)
            var v11 := Vector3(x1, heights[(iz + 1) * (n + 1) + ix + 1], z1)
            for v in [v00, v10, v01, v10, v11, v01]:
                st.set_color(_terrain_color(v.x, v.z, v.y))
                st.add_vertex(v)
    st.generate_normals()
    return st.commit()


func _build_terrain() -> void:
    var inner := _terrain_mesh(1000.0, 10.0, 0.0, 0.0)
    var body := StaticBody3D.new()
    body.name = "Terrain"
    body.collision_layer = 1
    body.collision_mask = 0
    var mi := MeshInstance3D.new()
    mi.mesh = inner
    mi.material_override = M.terrain
    body.add_child(mi)
    var cs := CollisionShape3D.new()
    cs.shape = inner.create_trimesh_shape()
    body.add_child(cs)
    add_child(body)

    var far := MeshInstance3D.new()
    far.name = "FarTerrain"
    far.mesh = _terrain_mesh(2800.0, 40.0, 985.0, -0.6)
    far.material_override = M.terrain
    far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(far)


# ---------------------------------------------------------------- roads

func _build_roads() -> void:
    var b := GeoBuilder.new()
    for i in N + 1:
        var p := line(i)
        var x1 := HWY_END if i == HWY_IDX else CITY_EDGE
        b.box(T(Vector3((-CITY_EDGE + x1) * 0.5, -0.04, p)), Vector3(x1 + CITY_EDGE, 0.12, ROAD), M.asphalt)
        b.box(T(Vector3(p, -0.04, 0.0)), Vector3(ROAD, 0.12, CITY_EDGE * 2.0), M.asphalt)
        for j in N:
            var a := line(j) + ROAD * 0.5 + 4.0
            var c := line(j + 1) - ROAD * 0.5 - 4.0
            _dashes(b, true, p, a, c)
            _dashes(b, false, p, a, c)
        for j in N + 1:
            _crosswalks(b, line(j), p)
    _dashes(b, true, line(HWY_IDX), CITY_EDGE + 4.0, HWY_END - 4.0)
    # west dirt road
    var wz := line(WEST_IDX)
    b.box(T(Vector3((-HWY_END - CITY_EDGE) * 0.5, -0.05, wz)), Vector3(HWY_END - CITY_EDGE, 0.12, 7.0), M.dirt)
    b.build(self, "Roads")


func _dashes(b: GeoBuilder, along_x: bool, p: float, a: float, c: float) -> void:
    var s := a
    while s + 3.0 <= c:
        var mid := s + 1.5
        if along_x:
            b.box(T(Vector3(mid, 0.025, p)), Vector3(3.0, 0.01, 0.15), M.line_y, false)
        else:
            b.box(T(Vector3(p, 0.025, mid)), Vector3(0.15, 0.01, 3.0), M.line_y, false)
        s += 7.0


func _crosswalks(b: GeoBuilder, x: float, z: float) -> void:
    var off := ROAD * 0.5 + 1.8
    for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
        var cx: float = x + dir.x * off
        var cz: float = z + dir.y * off
        if absf(cx) > CITY_EDGE - 1.0 or absf(cz) > CITY_EDGE - 1.0:
            continue
        var k := -3.6
        while k <= 3.7:
            if dir.x != 0.0:
                b.box(T(Vector3(cx, 0.025, z + k)), Vector3(3.0, 0.01, 0.45), M.line_w, false)
            else:
                b.box(T(Vector3(x + k, 0.025, cz)), Vector3(0.45, 0.01, 3.0), M.line_w, false)
            k += 1.2


# ---------------------------------------------------------------- blocks

func _build_block(bx: int, bz: int) -> void:
    var cx := line(bx) + PITCH * 0.5
    var cz := line(bz) + PITCH * 0.5
    var b := GeoBuilder.new()
    b.box(T(Vector3(cx, CURB * 0.5, cz)), Vector3(SLAB, CURB, SLAB), M.concrete)
    if bx == 2 and bz == 2:
        _commercial_block(b, cx, cz)
    elif bx == 4 and bz == 1:
        _vacant_block(b, cx, cz)
    elif bx == 1 and bz == 3:
        _park_block(b, cx, cz)
    else:
        for row in 2:
            for k in 3:
                var lx := cx - 16.0 + k * 16.0
                var xf: Transform3D
                if row == 0:
                    xf = T(Vector3(lx, 0.0, cz - BLOCK * 0.5))
                else:
                    xf = T(Vector3(lx, 0.0, cz + BLOCK * 0.5), PI)
                _house_lot(b, xf)
    _street_furniture(b, cx, cz)
    b.build(self, "Block_%d_%d" % [bx, bz])


func _bx(b: GeoBuilder, xf: Transform3D, pos: Vector3, size: Vector3, mat: Material, collide := true, yaw := 0.0) -> void:
    b.box(xf * T(pos, yaw), size, mat, collide)


func _house_lot(b: GeoBuilder, xf: Transform3D) -> void:
    var y0 := CURB
    var stucco: Material = M.stucco[rng.randi() % M.stucco.size()]
    var pueblo := rng.randf() < 0.6
    var w := rng.randf_range(8.0, 9.5)
    var d := rng.randf_range(8.0, 10.0)
    var sb := rng.randf_range(6.0, 7.5)
    var gside := 1.0 if rng.randf() < 0.5 else -1.0
    var gw := 4.2
    var gd := 6.5
    var hx := -gside * gw * 0.5
    var gx := hx + gside * (w * 0.5 + gw * 0.5)
    var h := 3.2 if pueblo else 2.9

    # yard + driveway
    var lawn := rng.randf() < 0.22
    _bx(b, xf, Vector3(0, y0 + 0.01, sb * 0.5), Vector3(15.6, 0.02, sb), M.lawn if lawn else M.gravel, false)
    _bx(b, xf, Vector3(gx, y0 + 0.02, sb * 0.5), Vector3(3.6, 0.02, sb), M.concrete, false)
    _bx(b, xf, Vector3(0, y0 + 0.01, sb + 12.0), Vector3(15.6, 0.02, 24.0 - sb - 0.4), M.gravel, false)

    # house + garage bodies
    _bx(b, xf, Vector3(hx, y0 + h * 0.5, sb + d * 0.5), Vector3(w, h, d), stucco)
    _bx(b, xf, Vector3(gx, y0 + 1.4, sb + gd * 0.5), Vector3(gw, 2.8, gd), stucco)
    _bx(b, xf, Vector3(gx, y0 + 1.1, sb - 0.04), Vector3(3.0, 2.2, 0.1), M.garage, false)
    for k in 4:
        _bx(b, xf, Vector3(gx, y0 + 0.3 + k * 0.55, sb - 0.1), Vector3(3.0, 0.03, 0.02), M.trim, false)

    if pueblo:
        _bx(b, xf, Vector3(hx, y0 + h + 0.01, sb + d * 0.5), Vector3(w - 0.4, 0.02, d - 0.4), M.roof_flat, false)
        var ph := 0.45
        _bx(b, xf, Vector3(hx, y0 + h + ph * 0.5, sb + 0.12), Vector3(w, ph, 0.24), stucco, false)
        _bx(b, xf, Vector3(hx, y0 + h + ph * 0.5, sb + d - 0.12), Vector3(w, ph, 0.24), stucco, false)
        _bx(b, xf, Vector3(hx - w * 0.5 + 0.12, y0 + h + ph * 0.5, sb + d * 0.5), Vector3(0.24, ph, d), stucco, false)
        _bx(b, xf, Vector3(hx + w * 0.5 - 0.12, y0 + h + ph * 0.5, sb + d * 0.5), Vector3(0.24, ph, d), stucco, false)
        _bx(b, xf, Vector3(gx, y0 + 2.81, sb + gd * 0.5), Vector3(gw - 0.3, 0.02, gd - 0.3), M.roof_flat, false)
        var count := int(w / 0.9)
        for k in count:
            var vx := hx - w * 0.5 + 0.5 + k * 0.9
            b.mesh(GeoBuilder.cyl_mesh(0.08, 0.08, 0.6, 6), xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(vx, y0 + h - 0.3, sb - 0.15)), M.wood)
        _bx(b, xf, Vector3(hx + rng.randf_range(-2.0, 2.0), y0 + h + 0.45, sb + d * 0.65), Vector3(1.0, 0.8, 1.0), M.metal)
    else:
        var roof_mat: Material = M.roof_tile if rng.randf() < 0.5 else M.roof_shingle
        b.mesh(GeoBuilder.prism_mesh(Vector3(d + 0.8, 1.4, w + 0.8)), xf * T(Vector3(hx, y0 + h + 0.7, sb + d * 0.5), PI * 0.5), roof_mat)
        b.mesh(GeoBuilder.prism_mesh(Vector3(gd + 0.6, 1.0, gw + 0.4)), xf * T(Vector3(gx, y0 + 2.8 + 0.5, sb + gd * 0.5), PI * 0.5), roof_mat)

    # windows + door
    for sx in [-1.0, 1.0]:
        var wx: float = hx + sx * (w * 0.5 - 1.7)
        _bx(b, xf, Vector3(wx, y0 + 1.6, sb - 0.03), Vector3(1.5, 1.2, 0.06), M.glass, false)
        _bx(b, xf, Vector3(wx, y0 + 0.97, sb - 0.08), Vector3(1.7, 0.08, 0.16), M.trim, false)
        _bx(b, xf, Vector3(wx, y0 + 2.26, sb - 0.07), Vector3(1.7, 0.12, 0.14), M.wood if pueblo else M.trim, false)
        _bx(b, xf, Vector3(wx, y0 + 1.6, sb - 0.07), Vector3(0.06, 1.2, 0.04), M.trim, false)
        var side_x: float = hx + sx * (w * 0.5 + 0.03)
        _bx(b, xf, Vector3(side_x, y0 + 1.6, sb + d * 0.5), Vector3(0.06, 1.1, 1.3), M.glass, false)
    _bx(b, xf, Vector3(hx, y0 + 1.05, sb - 0.04), Vector3(1.0, 2.1, 0.08), M.doors[rng.randi() % M.doors.size()], false)
    _bx(b, xf, Vector3(hx, y0 + 0.06, sb - 0.7), Vector3(1.6, 0.12, 1.2), M.concrete, false)

    if pueblo and rng.randf() < 0.45:
        for sx in [-1.0, 1.0]:
            _bx(b, xf, Vector3(hx + sx * 1.5, y0 + 1.3, sb - 1.7), Vector3(0.2, 2.6, 0.2), M.wood)
        _bx(b, xf, Vector3(hx, y0 + 2.7, sb - 1.7), Vector3(3.4, 0.25, 0.28), M.wood, false)
        _bx(b, xf, Vector3(hx, y0 + 2.86, sb - 0.85), Vector3(3.6, 0.1, 1.9), M.wood, false)

    # walls
    var wall_h := 1.7
    var wz0 := sb + d * 0.5
    for sx in [-1.0, 1.0]:
        _bx(b, xf, Vector3(sx * 7.85, y0 + wall_h * 0.5, (wz0 + 23.8) * 0.5), Vector3(0.2, wall_h, 23.8 - wz0), M.block_wall)
    _bx(b, xf, Vector3(0, y0 + wall_h * 0.5, 23.7), Vector3(15.9, wall_h, 0.2), M.block_wall)

    if rng.randf() < 0.15:
        _bx(b, xf, Vector3(rng.randf_range(-3.0, 3.0), y0 + 0.03, sb + d + 4.5), Vector3(4.0, 0.04, 2.5), M.pool, false)
    elif rng.randf() < 0.3:
        _bx(b, xf, Vector3(-gside * 5.5, y0 + 1.1, 21.5), Vector3(2.4, 2.2, 2.0), M.wood)

    # front yard plants
    for k in rng.randi_range(1, 4):
        var px := rng.randf_range(-7.0, 7.0)
        if absf(px - gx) < 2.4 or absf(px - hx) < 1.0:
            continue
        var pz := rng.randf_range(1.0, sb - 1.4)
        _plant(b, xf * T(Vector3(px, y0, pz), rng.randf() * TAU))
    if rng.randf() < 0.35:
        _tree(b, xf * T(Vector3(-gside * rng.randf_range(4.0, 6.5), y0, rng.randf_range(2.0, sb - 2.0))))

    # mailbox
    var mx := gx + gside * 2.3
    _bx(b, xf, Vector3(mx, y0 + 0.55, 0.5), Vector3(0.08, 1.1, 0.08), M.wood)
    _bx(b, xf, Vector3(mx, y0 + 1.15, 0.5), Vector3(0.22, 0.24, 0.45), M.dark_metal, false)

    if rng.randf() < 0.5:
        _car_prop(b, xf * T(Vector3(gx, y0, sb - 2.7)), M.cars[rng.randi() % M.cars.size()])
    if rng.randf() < 0.25:
        _car_prop(b, xf * T(Vector3(rng.randf_range(-5.0, 5.0), 0.02, -WALK - 1.3), PI * 0.5), M.cars[rng.randi() % M.cars.size()])


func _commercial_block(b: GeoBuilder, cx: float, cz: float) -> void:
    var y0 := CURB
    var front := cz + 6.0
    b.box(T(Vector3(cx, y0 + 0.01, cz - 9.0)), Vector3(BLOCK, 0.02, 30.0), M.asphalt, false)
    for row_z in [front - 3.5, cz - 8.0, cz - 13.0]:
        for k in range(-8, 9):
            b.box(T(Vector3(cx + k * 2.7, y0 + 0.025, row_z)), Vector3(0.12, 0.01, 4.8), M.line_w, false)
    var mall_mat: Material = M.stucco[2]
    b.box(T(Vector3(cx, y0 + 2.6, front + 8.0)), Vector3(44.0, 5.2, 16.0), mall_mat)
    b.box(T(Vector3(cx, y0 + 5.9, front + 0.3)), Vector3(14.0, 1.4, 0.6), mall_mat, false)
    b.box(T(Vector3(cx, y0 + 5.4, front + 0.2)), Vector3(44.0, 0.5, 0.4), M.stucco[1], false)
    b.box(T(Vector3(cx, y0 + 3.4, front - 1.5)), Vector3(44.0, 0.2, 3.0), M.wood, false)
    for k in 9:
        b.box(T(Vector3(cx - 22.0 + 0.2 + k * 5.45, y0 + 1.65, front - 2.8)), Vector3(0.22, 3.3, 0.22), M.wood)
    var names := ["LAUNDROMAT", "TACOS", "PHARMACY", "DONUTS", "LIQUOR"]
    var colors := [Color(0.2, 0.6, 0.9), Color(0.95, 0.5, 0.1), Color(0.2, 0.75, 0.3), Color(0.95, 0.4, 0.6), Color(0.9, 0.15, 0.15)]
    for k in 5:
        var sx := cx - 17.6 + k * 8.8
        b.box(T(Vector3(sx, y0 + 1.5, front - 0.03)), Vector3(6.4, 2.6, 0.06), M.glass, false)
        b.box(T(Vector3(sx - 2.2, y0 + 1.2, front - 0.06)), Vector3(1.1, 2.3, 0.04), M.dark_metal, false)
        var lbl := Label3D.new()
        lbl.text = names[k]
        lbl.font_size = 110
        lbl.pixel_size = 0.008
        lbl.outline_size = 18
        lbl.modulate = colors[k]
        lbl.position = Vector3(sx, y0 + 4.3, front - 0.05)
        lbl.rotation.y = PI
        add_child(lbl)
    for k in 4:
        var car_x := cx - 19.0 + rng.randi_range(0, 13) * 2.7 + 1.35
        _car_prop(b, T(Vector3(car_x, y0 + 0.02, front - 3.5), PI), M.cars[rng.randi() % M.cars.size()])
    for k in 3:
        var car_x2 := cx - 19.0 + rng.randi_range(0, 13) * 2.7 + 1.35
        _car_prop(b, T(Vector3(car_x2, y0 + 0.02, cz - 13.0)), M.cars[rng.randi() % M.cars.size()])
    for lx in [cx - 12.0, cx + 12.0]:
        _street_light(b, T(Vector3(lx, y0, cz - 10.5)))
    b.box(T(Vector3(cx + 20.0, y0 + 0.75, front + 17.0)), Vector3(2.0, 1.5, 1.4), M.cars[1])


func _vacant_block(b: GeoBuilder, cx: float, cz: float) -> void:
    var y0 := CURB
    b.box(T(Vector3(cx, y0 + 0.01, cz)), Vector3(BLOCK, 0.02, BLOCK), M.dirt, false)
    for k in 25:
        var p := Vector3(cx + rng.randf_range(-22, 22), y0, cz + rng.randf_range(-22, 22))
        if Vector2(p.x - cx, p.z - cz).length() < 7.0:
            continue
        var r := rng.randf()
        if r < 0.4:
            _rock(b, T(p, rng.randf() * TAU), rng.randf_range(0.3, 0.9))
        elif r < 0.7:
            b.mesh(GeoBuilder.sphere_mesh(0.45, 0.8, 7, 4), T(p + Vector3(0, 0.4, 0), rng.randf() * TAU), M.tumbleweed)
        elif r < 0.85:
            _plant(b, T(p, rng.randf() * TAU))
        else:
            b.mesh(GeoBuilder.cyl_mesh(0.3, 0.3, 0.9, 10), T(p + Vector3(0, 0.45, 0)), M.orange)
            b.shape_box(T(p + Vector3(0, 0.45, 0)), Vector3(0.6, 0.9, 0.6))
    for k in 6:
        var fx := cx - 24.0 + k * 9.6
        b.box(T(Vector3(fx, y0 + 0.6, cz + 24.0)), Vector3(0.1, 1.2, 0.1), M.pole_wood)
    b.box(T(Vector3(cx, y0 + 1.0, cz + 24.0)), Vector3(48.0, 0.05, 0.04), M.wire, false)
    b.box(T(Vector3(cx, y0 + 0.5, cz + 24.0)), Vector3(48.0, 0.05, 0.04), M.wire, false)


func _park_block(b: GeoBuilder, cx: float, cz: float) -> void:
    var y0 := CURB
    b.box(T(Vector3(cx, y0 + 0.01, cz)), Vector3(BLOCK, 0.02, BLOCK), M.lawn, false)
    b.box(T(Vector3(cx, y0 + 0.02, cz)), Vector3(BLOCK, 0.02, 2.5), M.concrete, false)
    b.box(T(Vector3(cx, y0 + 0.02, cz)), Vector3(2.5, 0.02, BLOCK), M.concrete, false)
    var court := Vector3(cx + 12.0, y0 + 0.03, cz - 12.0)
    b.box(T(court), Vector3(14.0, 0.02, 20.0), M.asphalt, false)
    for zz in [-9.9, 9.9]:
        b.box(T(court + Vector3(0, 0.005, zz)), Vector3(14.0, 0.01, 0.1), M.line_w, false)
        b.box(T(Vector3(court.x, y0 + 1.6, court.z + zz * 1.02)), Vector3(0.15, 3.2, 0.15), M.metal)
        b.box(T(Vector3(court.x, y0 + 3.3, court.z + zz * 0.97)), Vector3(1.8, 1.1, 0.08), M.white, false)
    b.box(T(court + Vector3(0, 0.005, 0)), Vector3(14.0, 0.01, 0.1), M.line_w, false)
    for k in 10:
        var p := Vector3(cx + rng.randf_range(-21, 21), y0, cz + rng.randf_range(-21, 21))
        if absf(p.x - cx) < 3.0 or absf(p.z - cz) < 3.0:
            continue
        if p.x > cx + 3.0 and p.z < cz - 1.0:
            continue
        _tree(b, T(p))
    for k in 4:
        var bp := Vector3(cx - 6.0 + (k % 2) * 12.0 - 6.0, y0, cz + (2.4 if k < 2 else -2.4))
        b.box(T(bp + Vector3(0, 0.45, 0)), Vector3(2.0, 0.08, 0.5), M.wood)
        b.box(T(bp + Vector3(0, 0.22, 0)), Vector3(1.8, 0.44, 0.1), M.dark_metal, false)


func _street_furniture(b: GeoBuilder, cx: float, cz: float) -> void:
    var y0 := CURB
    var e := SLAB * 0.5 - 0.6
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var p := Vector3(cx + sx * e, y0, cz + sz * e)
            b.box(T(p + Vector3(0, 1.1, 0)), Vector3(0.07, 2.2, 0.07), M.metal)
            var yaw := atan2(sx, sz)
            b.mesh(GeoBuilder.cyl_mesh(0.4, 0.4, 0.03, 8), T(p + Vector3(0, 2.3, 0), yaw) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.0) * Basis(Vector3.UP, PI / 8.0), Vector3.ZERO), M.red)
    _street_light(b, T(Vector3(cx - e, y0, cz - e + 1.5)))
    _street_light(b, T(Vector3(cx + e, y0, cz + e - 1.5), PI))
    # power poles along north edge
    var pz := cz - SLAB * 0.5 + 0.5
    var prev := Vector3.INF
    var k := 0
    while k < 4:
        var px := cx - 19.5 + k * 13.0
        var base := Vector3(px, y0, pz)
        b.mesh(GeoBuilder.cyl_mesh(0.12, 0.16, 9.0, 6), T(base + Vector3(0, 4.5, 0)), M.pole_wood)
        b.shape_box(T(base + Vector3(0, 4.5, 0)), Vector3(0.3, 9.0, 0.3))
        b.box(T(base + Vector3(0, 8.4, 0)), Vector3(0.12, 0.12, 2.0), M.pole_wood, false)
        if prev != Vector3.INF:
            for off in [-0.9, 0.0, 0.9]:
                var a := prev + Vector3(0, 8.5, off)
                var c := base + Vector3(0, 8.5, off)
                b.box(T((a + c) * 0.5), Vector3(c.x - a.x, 0.03, 0.03), M.wire, false)
        prev = base
        k += 1


func _street_light(b: GeoBuilder, xf: Transform3D) -> void:
    b.mesh(GeoBuilder.cyl_mesh(0.08, 0.12, 7.0, 6), xf * T(Vector3(0, 3.5, 0)), M.metal)
    b.shape_box(xf * T(Vector3(0, 3.5, 0)), Vector3(0.25, 7.0, 0.25))
    b.box(xf * T(Vector3(0, 7.0, -0.9)), Vector3(0.1, 0.1, 1.9), M.metal, false)
    b.box(xf * T(Vector3(0, 6.9, -1.8)), Vector3(0.35, 0.15, 0.7), M.metal, false)
    b.box(xf * T(Vector3(0, 6.81, -1.8)), Vector3(0.28, 0.02, 0.6), M.lamp, false)


# ---------------------------------------------------------------- props

func _car_prop(b: GeoBuilder, xf: Transform3D, body: Material) -> void:
    b.box(xf * T(Vector3(0, 0.62, 0)), Vector3(1.8, 0.62, 4.4), body, false)
    b.box(xf * T(Vector3(0, 1.2, -0.2)), Vector3(1.6, 0.55, 2.2), M.glass, false)
    b.box(xf * T(Vector3(0, 1.49, -0.25)), Vector3(1.56, 0.06, 1.9), body, false)
    for sx in [-0.62, 0.62]:
        b.box(xf * T(Vector3(sx, 0.75, -2.21)), Vector3(0.35, 0.14, 0.04), M.tail, false)
        b.box(xf * T(Vector3(sx, 0.75, 2.21)), Vector3(0.35, 0.14, 0.04), M.lamp, false)
    var wheel_basis := Basis(Vector3.BACK, PI * 0.5)
    for sx in [-0.82, 0.82]:
        for sz in [-1.35, 1.35]:
            b.mesh(GeoBuilder.cyl_mesh(0.34, 0.34, 0.24, 10), xf * Transform3D(wheel_basis, Vector3(sx, 0.34, sz)), M.tire)
    b.shape_box(xf * T(Vector3(0, 0.85, 0)), Vector3(1.8, 1.3, 4.4))


func _plant(b: GeoBuilder, xf: Transform3D) -> void:
    var r := rng.randf()
    if r < 0.3:
        var th := rng.randf_range(0.2, 1.2)
        b.mesh(GeoBuilder.cyl_mesh(0.08, 0.1, th, 6), xf * T(Vector3(0, th * 0.5, 0)), M.trunk)
        for k in 12:
            var basis := Basis(Vector3.UP, k * TAU / 12.0) * Basis(Vector3.RIGHT, rng.randf_range(0.3, 1.2))
            b.mesh(GeoBuilder.box_mesh(Vector3(0.06, 0.8, 0.02)), xf * Transform3D(basis, Vector3(0, th, 0) + basis * Vector3(0, 0.4, 0)), M.plant)
    elif r < 0.5:
        for k in 9:
            var basis2 := Basis(Vector3.UP, k * TAU / 9.0) * Basis(Vector3.RIGHT, rng.randf_range(0.7, 1.2))
            b.mesh(GeoBuilder.box_mesh(Vector3(0.18, 0.7, 0.04)), xf * Transform3D(basis2, basis2 * Vector3(0, 0.35, 0)), M.plant)
    elif r < 0.7:
        b.mesh(GeoBuilder.sphere_mesh(0.32, 0.55, 10, 6), xf * T(Vector3(0, 0.25, 0)), M.cactus)
    elif r < 0.85:
        var ch := rng.randf_range(1.2, 2.2)
        b.mesh(GeoBuilder.cyl_mesh(0.14, 0.16, ch, 8), xf * T(Vector3(0, ch * 0.5, 0)), M.cactus)
        b.mesh(GeoBuilder.cyl_mesh(0.1, 0.1, 0.5, 8), xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.3, ch * 0.55, 0)), M.cactus)
        b.mesh(GeoBuilder.cyl_mesh(0.1, 0.1, 0.6, 8), xf * T(Vector3(0.5, ch * 0.55 + 0.3, 0)), M.cactus)
        b.shape_box(xf * T(Vector3(0, ch * 0.5, 0)), Vector3(0.3, ch, 0.3))
    else:
        _rock(b, xf, rng.randf_range(0.25, 0.6))


func _rock(b: GeoBuilder, xf: Transform3D, size: float) -> void:
    b.mesh(GeoBuilder.sphere_mesh(size, size * 1.2, 6, 3), xf * T(Vector3(0, size * 0.35, 0)), M.rock)
    if size > 0.5:
        b.shape_box(xf * T(Vector3(0, size * 0.35, 0)), Vector3(size * 1.4, size, size * 1.4))


func _tree(b: GeoBuilder, xf: Transform3D) -> void:
    var th := rng.randf_range(2.0, 3.0)
    b.mesh(GeoBuilder.cyl_mesh(0.12, 0.2, th, 7), xf * T(Vector3(0, th * 0.5, 0)), M.trunk)
    b.shape_box(xf * T(Vector3(0, th * 0.5, 0)), Vector3(0.4, th, 0.4))
    for k in 4:
        var r := rng.randf_range(1.1, 1.8)
        var off := Vector3(rng.randf_range(-0.9, 0.9), th + rng.randf_range(0.3, 1.4), rng.randf_range(-0.9, 0.9))
        b.mesh(GeoBuilder.sphere_mesh(r, r * 1.7, 9, 6), xf * T(off), M.tree)


# ---------------------------------------------------------------- highway + bounds

func _build_highway_props() -> void:
    var b := GeoBuilder.new()
    var hz := line(HWY_IDX)
    var x := CITY_EDGE + 30.0
    var prev := Vector3.INF
    while x < HWY_END:
        var base := Vector3(x, 0.0, hz + 9.0)
        b.mesh(GeoBuilder.cyl_mesh(0.12, 0.16, 9.0, 6), T(base + Vector3(0, 4.5, 0)), M.pole_wood)
        b.shape_box(T(base + Vector3(0, 4.5, 0)), Vector3(0.3, 9.0, 0.3))
        b.box(T(base + Vector3(0, 8.4, 0)), Vector3(0.12, 0.12, 2.0), M.pole_wood, false)
        if prev != Vector3.INF:
            for off in [-0.9, 0.9]:
                var a := prev + Vector3(0, 8.5, off)
                var c := base + Vector3(0, 8.5, off)
                b.box(T((a + c) * 0.5), Vector3(c.x - a.x, 0.03, 0.03), M.wire, false)
        prev = base
        x += 45.0
    # billboard
    var bb := Vector3(CITY_EDGE + 120.0, 0.0, hz - 14.0)
    for off in [-3.0, 3.0]:
        b.box(T(bb + Vector3(off, 3.0, 0)), Vector3(0.3, 6.0, 0.3), M.pole_wood)
    b.box(T(bb + Vector3(0, 6.5, 0)), Vector3(10.0, 3.6, 0.2), M.white, false)
    var lbl := Label3D.new()
    lbl.text = "LAND OF\nENCHANTMENT"
    lbl.font_size = 160
    lbl.pixel_size = 0.012
    lbl.modulate = Color(0.75, 0.2, 0.1)
    lbl.outline_size = 0
    lbl.position = bb + Vector3(0, 6.5, -0.12)
    lbl.rotation.y = PI
    lbl.shaded = true
    add_child(lbl)
    var lbl_b: Label3D = lbl.duplicate()
    lbl_b.position = bb + Vector3(0, 6.5, 0.12)
    lbl_b.rotation.y = 0.0
    add_child(lbl_b)
    # road closed barrier
    for k in 5:
        var bz := hz - 4.0 + k * 2.0
        b.box(T(Vector3(HWY_END - 2.0, 0.6, bz)), Vector3(0.4, 1.2, 1.6), M.orange)
        b.box(T(Vector3(HWY_END - 2.0, 0.8, bz)), Vector3(0.42, 0.2, 1.62), M.white, false)
    # desert scatter
    for k in 260:
        var p := Vector3(rng.randf_range(-950, 950), 0, rng.randf_range(-950, 950))
        if maxf(absf(p.x), absf(p.z)) < CITY_EDGE + 10.0:
            continue
        if absf(p.z - hz) < 12.0 and p.x > 0.0:
            continue
        if absf(p.z - line(WEST_IDX)) < 9.0 and p.x < 0.0:
            continue
        p.y = height_at(p.x, p.z)
        var r := rng.randf()
        if r < 0.45:
            _plant(b, T(p, rng.randf() * TAU))
        elif r < 0.8:
            _rock(b, T(p, rng.randf() * TAU), rng.randf_range(0.4, 2.2))
        else:
            b.mesh(GeoBuilder.sphere_mesh(0.5, 0.9, 7, 4), T(p + Vector3(0, 0.4, 0)), M.tumbleweed)
    b.build(self, "Desert")


func _build_bounds() -> void:
    var body := StaticBody3D.new()
    body.name = "Bounds"
    for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
        var cs := CollisionShape3D.new()
        var s := BoxShape3D.new()
        s.size = Vector3(10, 400, 2000) if d.x != 0.0 else Vector3(2000, 400, 10)
        cs.shape = s
        cs.position = d * (WORLD_HALF + 5.0) + Vector3(0, 100, 0)
        body.add_child(cs)
    add_child(body)
