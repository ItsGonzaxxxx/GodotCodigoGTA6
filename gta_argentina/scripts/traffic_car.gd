class_name TrafficCar
extends AnimatableBody3D
## Vehículo de tráfico IA: sigue carriles por la derecha, respeta intersecciones
## (una a la vez), frena detrás de otros autos y del jugador. Tipos: auto, taxi, colectivo.

var kind: String = "auto"
var model: VehicleModel.Result
var mgr: Traffic
var max_speed: float = 10.0
var speed: float = 0.0
var length: float = 4.2
var heading: float = 0.0
var node_from: int = 0
var node_to: int = 0
var node_next: int = -1
var phase: int = 0
var target: Vector3
var hold_lock: int = -1
var wait_time: float = 0.0

func setup(k: String, m: Traffic, from_id: int, to_id: int, t: float, rng: RandomNumberGenerator) -> void:
	kind = k
	mgr = m
	sync_to_physics = false
	_build_visuals(rng)
	node_from = from_id
	node_to = to_id
	var a: Vector3 = mgr.pos(from_id)
	var b: Vector3 = mgr.pos(to_id)
	var dir: Vector3 = (b - a).normalized()
	var right: Vector3 = dir.cross(Vector3.UP)
	position = a.lerp(b, t) + right * CityLayout.LANE
	heading = atan2(-dir.x, -dir.z)
	rotation.y = heading
	target = b + right * CityLayout.LANE
	speed = max_speed * 0.5

func _build_visuals(rng: RandomNumberGenerator) -> void:
	model = VehicleModel.build(kind, rng)
	add_child(model.root)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = model.box_size
	cs.shape = bs
	cs.position = model.box_center
	add_child(cs)
	length = model.length
	match kind:
		"colectivo": max_speed = 7.5
		"camion": max_speed = 7.0
		"camioneta": max_speed = rng.randf_range(8.0, 10.0)
		_: max_speed = rng.randf_range(8.5, 12.0)
	if model.tail_mat != null:
		model.tail_mat.emission_energy_multiplier = 0.5 + DayNight.night

func _physics_process(delta: float) -> void:
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var right: Vector3 = fwd.cross(Vector3.UP)
	var to_t: Vector3 = target - position
	to_t.y = 0.0
	var dist: float = to_t.length()
	var desired: float = max_speed

	if phase == 0:
		var stop_dist: float = 6.5 + length / 2.0 + 0.5
		if hold_lock != node_to:
			if dist < stop_dist + 8.0 and mgr.try_lock(node_to, self):
				hold_lock = node_to
			elif dist < stop_dist + 8.0:
				desired = minf(desired, maxf(0.0, (dist - stop_dist) * 1.2))
				if desired < 0.3 and speed < 0.3:
					wait_time += delta
					if wait_time > 8.0:
						mgr.force_lock(node_to, self)
						hold_lock = node_to
						wait_time = 0.0
		else:
			wait_time = 0.0

	for other in mgr.cars:
		if other == self:
			continue
		desired = minf(desired, _gap_limit(other.position, other.length, fwd, right))
	if mgr.player != null:
		desired = minf(desired, _gap_limit(mgr.player.global_position, 1.0, fwd, right))

	speed = move_toward(speed, desired, (3.5 if desired > speed else 9.0) * delta)
	var want: float = atan2(-to_t.x, -to_t.z)
	heading = lerp_angle(heading, want, clampf(3.0 * delta, 0.0, 1.0))
	rotation.y = heading
	position += Vector3(-sin(heading), 0.0, -cos(heading)) * speed * delta
	position.y = 0.0
	for w in model.wheels:
		w.rotation.x -= speed * delta / model.wheel_radius
	for m in model.steer_mounts:
		m.rotation.y = clampf(angle_difference(heading, want) * 0.5, -0.5, 0.5)
	if model.tail_mat != null:
		model.tail_mat.emission_energy_multiplier = (3.0 if desired < speed - 0.5 else 0.5) + DayNight.night * 0.8

	if dist < 2.5:
		_arrive()

func _gap_limit(op: Vector3, olen: float, fwd: Vector3, right: Vector3) -> float:
	var rel: Vector3 = op - position
	rel.y = 0.0
	var along: float = rel.dot(fwd)
	if along <= 0.0:
		return 99.0
	var lat: float = absf(rel.dot(right))
	var gap: float = along - (length + olen) / 2.0
	if lat < 2.6 and gap < 10.0:
		return maxf(0.0, (gap - 2.0) * 1.2)
	return 99.0

func _arrive() -> void:
	if phase == 0:
		node_next = mgr.pick_next(node_to, node_from)
		var dout: Vector3 = (mgr.pos(node_next) - mgr.pos(node_to)).normalized()
		target = mgr.pos(node_to) + dout.cross(Vector3.UP) * CityLayout.LANE + dout * 7.0
		phase = 1
	else:
		if hold_lock >= 0:
			mgr.release(hold_lock, self)
			hold_lock = -1
		node_from = node_to
		node_to = node_next
		phase = 0
		var d: Vector3 = (mgr.pos(node_to) - mgr.pos(node_from)).normalized()
		target = mgr.pos(node_to) + d.cross(Vector3.UP) * CityLayout.LANE
