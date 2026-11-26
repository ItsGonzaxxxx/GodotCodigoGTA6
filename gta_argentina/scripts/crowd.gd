class_name Crowd
extends Node3D
## Genera y mantiene a los peatones (incluye chorros y policías). Repone chorros.

const MIN_THIEVES := 5

var peds: Array[Pedestrian] = []
var crime: Crime
var player: Node3D
var _pos: PackedVector3Array
var _nbr: Array
var _rng := RandomNumberGenerator.new()
var _seed_next: int = 1000
var _check_t: float = 0.0

func spawn(count: int, player_ref: Node3D, seed_value: int) -> void:
	player = player_ref
	var g: Dictionary = CityLayout.build_ped_graph()
	_pos = g["pos"]
	_nbr = g["nbr"]
	_rng.seed = seed_value
	for k in count:
		var id: int = _rng.randi() % _pos.size()
		var cell: Vector2i = CityLayout.ped_cell(id)
		var zone: int = CityLayout.zone_of(cell.x, cell.y)
		var pool: Array[String]
		match zone:
			CityLayout.Zone.CENTRO: pool = ["trabajador", "comerciante", "policia", "vecino", "estudiante", "chorro"]
			CityLayout.Zone.POPULAR: pool = ["vecino", "vecino", "estudiante", "trabajador", "hincha", "chorro"]
			CityLayout.Zone.INDUSTRIAL: pool = ["trabajador", "trabajador", "trabajador", "policia", "chorro"]
			CityLayout.Zone.PLAZA: pool = ["vecino", "estudiante", "hincha", "comerciante"]
			_: pool = ["vecino", "vecino", "estudiante", "comerciante", "hincha", "trabajador"]
		spawn_one(pool[_rng.randi() % pool.size()], id, false)
	for i in MIN_THIEVES:
		spawn_one("chorro", _rng.randi() % _pos.size(), false)

func spawn_one(type: String, node_id: int, temp: bool) -> Pedestrian:
	var p := Pedestrian.new()
	add_child(p)
	_seed_next += 1
	p.setup(type, _pos, _nbr, node_id, _seed_next, player, crime)
	p.temp = temp
	peds.append(p)
	return p

func _node_far_from(pos: Vector3, min_d: float, max_d: float) -> int:
	for i in 30:
		var id: int = _rng.randi() % _pos.size()
		var d: float = _pos[id].distance_to(pos)
		if d >= min_d and d <= max_d:
			return id
	return _rng.randi() % _pos.size()

func spawn_police(around: Vector3) -> void:
	var p: Pedestrian = spawn_one("policia", _node_far_from(around, 40.0, 75.0), true)
	p._set_mode("pursue")

func _process(delta: float) -> void:
	_check_t += delta
	if _check_t < 4.0:
		return
	_check_t = 0.0
	peds = peds.filter(func(p: Pedestrian) -> bool: return is_instance_valid(p) and not p.is_queued_for_deletion())
	var thieves: int = 0
	for p in peds:
		if p.npc_type == "chorro":
			thieves += 1
	if thieves < MIN_THIEVES:
		spawn_one("chorro", _node_far_from(player.global_position, 50.0, 120.0), false)
