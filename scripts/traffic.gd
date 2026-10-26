class_name Traffic
extends Node3D
## Spawns AI cars on the street grid and pedestrians on the sidewalks.

const CAR_COUNT := 10
const PED_COUNT := 22
const LOOK := 6.0

var main: Node
var cars: Array[TrafficCar] = []
var peds: Array[Pedestrian] = []
var rng := RandomNumberGenerator.new()


func setup(main_node: Node) -> void:
    main = main_node
    rng.seed = 4242
    var city: City = main.city
    var edges: Array = []
    for i in City.N + 1:
        for j in City.N + 1:
            var n := Vector2i(i, j)
            for d in TrafficCar.DIRS:
                if TrafficCar.inside(n + d):
                    edges.append([n, d])
    for k in CAR_COUNT:
        var e: Array = edges.pop_at(rng.randi() % edges.size())
        var car := TrafficCar.new()
        car.name = "TrafficCar%d" % k
        add_child(car)
        car.setup(self, k, CarMesh.KINDS[k % CarMesh.KINDS.size()], city.M.cars[k % city.M.cars.size()], e[0], e[1], rng.randf_range(0.1, 0.7))
        cars.append(car)
    for k in PED_COUNT:
        var p := Pedestrian.new()
        p.name = "Pedestre%d" % k
        p.style_seed = 77 + k * 13
        p.setup("pedestre")
        p.traffic = self
        add_child(p)
        var bx := rng.randi() % City.N
        var bz := rng.randi() % City.N
        if k < 8:
            bx = 1 + k % 3
            bz = 1 + (k / 3) % 2 + (1 if k % 3 == 2 else 0)
        var c := Vector3(City.line(bx) + City.PITCH * 0.5, 0, City.line(bz) + City.PITCH * 0.5)
        p.place(c, rng.randf() * 8.0 * Pedestrian.H, 1.0 if rng.randf() < 0.5 else -1.0, rng.randf_range(1.1, 1.6))
        peds.append(p)


## Returns [gap_to_stop_point, blocking_node] for the nearest thing in front of `car`.
func obstacle_ahead(car: TrafficCar) -> Array:
    var inv := car.global_transform.affine_inverse()
    var look := LOOK + car.speed * 1.3
    var best := INF
    var who: Node3D = null
    var cands: Array = []
    var pl: Player = main.player
    if pl.visible:
        cands.append([pl, 0.4, 3.5])
    for v in main.vehicles:
        cands.append([v, 1.3 if v.kind == "rv" else 0.95, 7.4 if v.kind == "rv" else 6.0])
    for c in cars:
        if c != car:
            cands.append([c, 0.95, 6.0])
    for p in peds:
        cands.append([p, 0.4, 3.5])
    for e in cands:
        var n: Node3D = e[0]
        if n is TrafficCar and n.blocker == car and car.id < n.id:
            continue
        var l := inv * n.global_position
        if l.z <= 0.0 or l.z > look + e[2] or absf(l.x) > 0.95 + e[1] or absf(l.y) > 3.0:
            continue
        var gap: float = l.z - e[2]
        if gap < best:
            best = gap
            who = n
    return [best, who]


## Returns a unit flee direction if a fast player vehicle is coming at `p`
## (and knocks `p` down if it is already being hit), else Vector3.ZERO.
func threat_to(p: Pedestrian) -> Vector3:
    for v: Vehicle in main.vehicles:
        var vel := v.linear_velocity
        vel.y = 0.0
        var sp := vel.length()
        if sp < 4.0:
            continue
        var l := v.global_transform.affine_inverse() * p.global_position
        var half := Vector2(1.3, 3.7) if v.kind == "rv" else Vector2(0.95, 2.3)
        if absf(l.x) < half.x + 0.35 and absf(l.z) < half.y + 0.35 and absf(l.y) < 2.5:
            p.knock_down(vel)
            return Vector3.ZERO
        if sp < 5.0:
            continue
        var rel := p.global_position - v.global_position
        rel.y = 0.0
        var vd := vel / sp
        var along := rel.dot(vd)
        var lat := rel - vd * along
        if along > 0.0 and along < 14.0 and lat.length() < 3.2:
            if lat.length() < 0.1:
                lat = Vector3(-vd.z, 0, vd.x)
            return lat.normalized()
    return Vector3.ZERO


func _physics_process(_delta: float) -> void:
    var pl: Vector3 = main.player.global_position
    if main.current_vehicle:
        pl = main.current_vehicle.global_position
    for car in cars:
        if car.blocked_time < 6.0:
            continue
        if not (car.blocker is TrafficCar):
            car.u_turn()
        elif car.global_position.distance_to(pl) > 60.0:
            var n := Vector2i(rng.randi_range(0, City.N), rng.randi_range(0, City.N))
            var d: Vector2i = TrafficCar.DIRS[rng.randi() % 4]
            if not TrafficCar.inside(n + d):
                d = -d
            car.teleport_to(n, d)
