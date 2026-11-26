class_name Traffic
extends Node3D
## Gestor de tráfico: grafo de calles, mutex por intersección y autos activos.

var cars: Array[TrafficCar] = []
var locks: Dictionary = {}
var player: Node3D
var _pos: PackedVector3Array
var _nbr: Array
var _rng := RandomNumberGenerator.new()

func pos(id: int) -> Vector3:
	return _pos[id]

func spawn(count: int, player_ref: Node3D, seed_value: int) -> void:
	player = player_ref
	_rng.seed = seed_value
	var g: Dictionary = CityLayout.build_traffic_graph()
	_pos = g["pos"]
	_nbr = g["nbr"]
	var tries: int = 0
	while cars.size() < count and tries < count * 20:
		tries += 1
		var a: int = _rng.randi() % _pos.size()
		var nb: PackedInt32Array = _nbr[a]
		var b: int = nb[_rng.randi() % nb.size()]
		var t: float = _rng.randf_range(0.2, 0.6)
		var dir: Vector3 = (_pos[b] - _pos[a]).normalized()
		var p: Vector3 = _pos[a].lerp(_pos[b], t) + dir.cross(Vector3.UP) * CityLayout.LANE
		var clear: bool = true
		for c in cars:
			if c.position.distance_to(p) < 20.0:
				clear = false
				break
		if not clear:
			continue
		var r: float = _rng.randf()
		var kind: String = "auto"
		if r > 0.55: kind = "taxi"
		if r > 0.70: kind = "camioneta"
		if r > 0.82: kind = "colectivo"
		if r > 0.93: kind = "camion"
		var car := TrafficCar.new()
		add_child(car)
		car.setup(kind, self, a, b, t, _rng)
		cars.append(car)

func pick_next(node: int, from: int) -> int:
	var cands: Array[int] = []
	for n in _nbr[node]:
		if n != from:
			cands.append(n)
	if cands.is_empty():
		return from
	var straight: Vector3 = _pos[node] + (_pos[node] - _pos[from])
	for n in cands:
		if _pos[n].distance_to(straight) < 1.0 and _rng.randf() < 0.55:
			return n
	return cands[_rng.randi() % cands.size()]

func try_lock(id: int, car: TrafficCar) -> bool:
	if not locks.has(id) or locks[id] == car or not is_instance_valid(locks[id]):
		locks[id] = car
		return true
	return false

func force_lock(id: int, car: TrafficCar) -> void:
	locks[id] = car

func release(id: int, car: TrafficCar) -> void:
	if locks.get(id) == car:
		locks.erase(id)
