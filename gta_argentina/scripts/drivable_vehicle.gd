class_name DrivableVehicle
extends CharacterBody3D
## Vehículo conducible con física arcade: aceleración con curva de motor, frenado,
## marcha atrás, derrape (freno de mano), dirección por modelo de bicicleta (distancia entre ejes),
## colisiones con daño visual (capó doblado, pintura sucia, humo), luces, bocina y sonido de motor.
## Tipos: auto, camioneta, colectivo, camion, moto, bici.

const RATE := 22050.0
const SPECS := {
	"auto": {"name": "Auto", "max": 34.0, "accel": 9.0, "brake": 22.0, "rev": 8.0, "grip": 9.0, "wb": 2.7, "s_lo": 0.55, "s_hi": 0.13, "s_rate": 2.6, "lean": -0.004, "cam_d": 6.5, "cam_h": 1.9, "f0": 35.0, "f1": 90.0, "vol": 0.3, "dk": 1.0},
	"camioneta": {"name": "Camioneta", "max": 30.0, "accel": 7.0, "brake": 18.0, "rev": 7.0, "grip": 8.0, "wb": 3.3, "s_lo": 0.5, "s_hi": 0.12, "s_rate": 2.4, "a_lat": 10.0, "lean": -0.004, "cam_d": 7.5, "cam_h": 2.3, "f0": 30.0, "f1": 80.0, "vol": 0.32, "dk": 0.8},
	"colectivo": {"name": "Colectivo", "max": 22.0, "accel": 3.4, "brake": 12.0, "rev": 5.0, "grip": 10.0, "wb": 5.8, "s_lo": 0.5, "s_hi": 0.12, "s_rate": 1.8, "a_lat": 7.0, "lean": -0.003, "cam_d": 11.0, "cam_h": 3.7, "f0": 22.0, "f1": 58.0, "vol": 0.35, "dk": 0.5},
	"camion": {"name": "Camión", "max": 24.0, "accel": 3.0, "brake": 13.0, "rev": 5.0, "grip": 10.0, "wb": 5.6, "s_lo": 0.5, "s_hi": 0.1, "s_rate": 1.8, "a_lat": 6.0, "lean": -0.003, "cam_d": 11.5, "cam_h": 3.9, "f0": 20.0, "f1": 55.0, "vol": 0.38, "dk": 0.4},
	"moto": {"name": "Moto", "max": 42.0, "accel": 13.0, "brake": 22.0, "rev": 4.0, "grip": 7.0, "wb": 1.4, "s_lo": 0.6, "s_hi": 0.12, "s_rate": 4.0, "lean": 0.05, "cam_d": 5.0, "cam_h": 1.8, "f0": 55.0, "f1": 170.0, "vol": 0.28, "dk": 1.3},
	"bici": {"name": "Bicicleta", "max": 8.5, "accel": 2.6, "brake": 9.0, "rev": 2.0, "grip": 8.0, "wb": 1.1, "s_lo": 0.7, "s_hi": 0.25, "s_rate": 5.0, "a_lat": 6.0, "lean": 0.06, "cam_d": 4.0, "cam_h": 1.7, "f0": 0.0, "f1": 0.0, "vol": 0.0, "dk": 1.5},
}

var kind: String = "auto"
var spec: Dictionary
var model: VehicleModel.Result
var driver: Node = null
var steer: float = 0.0
var damage: float = 0.0
var wrecked: bool = false
var speed_forward: float = 0.0
var test_input: Dictionary = {}
var seat_node: Node3D
var _throttle: float = 0.0
var _prev_vf: float = 0.0
var _shown_damage: float = -1.0
var _lights: Array[SpotLight3D] = []
var _smoke: CPUParticles3D
var _engine: AudioStreamPlayer3D
var _engine_pb: AudioStreamGeneratorPlayback
var _horn: AudioStreamPlayer3D
var _crash: AudioStreamPlayer3D
var _eph: float = 0.0
var _crash_cd: float = 0.0

func setup(k: String, rng: RandomNumberGenerator, color: Color = Color.TRANSPARENT) -> void:
	kind = k
	spec = SPECS[k]
	model = VehicleModel.build(k, rng, color)
	add_child(model.root)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = model.box_size
	cs.shape = bs
	cs.position = model.box_center
	add_child(cs)
	var door := VehicleDoor.new()
	door.vehicle = self
	door.prompt = "Subir: " + spec["name"]
	door.position = model.door_pos
	add_child(door)
	seat_node = Node3D.new()
	seat_node.position = model.seat_pos
	model.body.add_child(seat_node)
	for hp in model.headlight_pos:
		var sl := SpotLight3D.new()
		sl.position = hp
		sl.spot_range = 45.0
		sl.spot_angle = 32.0
		sl.light_energy = 3.0
		sl.visible = false
		model.body.add_child(sl)
		_lights.append(sl)
	_smoke = CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.25, 0.25, 0.25, 0.6)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = smat
	_smoke.mesh = sm
	_smoke.amount = 24
	_smoke.lifetime = 1.4
	_smoke.direction = Vector3.UP
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 1.0
	_smoke.initial_velocity_max = 2.2
	_smoke.gravity = Vector3(0, 0.6, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.6
	_smoke.emitting = false
	_smoke.position = model.smoke_pos
	model.body.add_child(_smoke)
	_horn = AudioStreamPlayer3D.new()
	_horn.stream = AudioGen.horn()
	_horn.max_distance = 120.0
	add_child(_horn)
	_crash = AudioStreamPlayer3D.new()
	_crash.stream = AudioGen.crash()
	_crash.max_distance = 150.0
	add_child(_crash)

func kph() -> float:
	return absf(speed_forward) * 3.6

func exit_position() -> Vector3:
	var h: float = rotation.y
	var right := Vector3(cos(h), 0.0, -sin(h))
	var p: Vector3 = global_position - right * (model.width / 2.0 + 1.1)
	p.y = CityLayout.ground_height(p.x, p.z) + 0.1
	return p

func on_enter(p: Node) -> void:
	driver = p
	if spec["f0"] > 0.0 and _engine == null:
		_engine = AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = 0.12
		_engine.stream = gen
		_engine.max_distance = 80.0
		add_child(_engine)
		_engine.play()
		_engine_pb = _engine.get_stream_playback() as AudioStreamGeneratorPlayback

func on_exit() -> void:
	driver = null
	if _engine != null:
		_engine.queue_free()
		_engine = null
		_engine_pb = null
	if _horn.playing:
		_horn.stop()

func _input_state() -> Dictionary:
	if not test_input.is_empty():
		return test_input
	if driver != null:
		return {
			"throttle": Input.get_axis("move_back", "move_forward"),
			"steer": Input.get_axis("move_right", "move_left"),
			"hand": Input.is_action_pressed("handbrake"),
			"sprint": Input.is_action_pressed("run"),
			"horn": Input.is_action_pressed("horn"),
		}
	return {}

func _physics_process(delta: float) -> void:
	var inp: Dictionary = _input_state()
	var active: bool = not inp.is_empty()
	var throttle: float = inp.get("throttle", 0.0)
	var steer_in: float = inp.get("steer", 0.0)
	var hand: bool = inp.get("hand", false)
	var sprint: bool = inp.get("sprint", false) and kind == "bici"
	_throttle = throttle
	_crash_cd = maxf(0.0, _crash_cd - delta)

	var maxs: float = spec["max"] * (0.35 if wrecked else 1.0) * (1.35 if sprint else 1.0)
	var accel: float = spec["accel"] * (1.6 if sprint else 1.0)
	var brake: float = spec["brake"]

	# 1) giro con la velocidad longitudinal anterior
	var h0: float = rotation.y
	var fwd0 := Vector3(-sin(h0), 0.0, -cos(h0))
	var vf0: float = Vector3(velocity.x, 0.0, velocity.z).dot(fwd0)
	var ratio: float = clampf(absf(vf0) / spec["max"], 0.0, 1.0)
	var max_steer: float = lerpf(spec["s_lo"], spec["s_hi"], ratio)
	# límite por aceleración lateral (agarre): v² · tan(δ) / wb <= a_lat
	max_steer = minf(max_steer, atan(spec["wb"] * float(spec.get("a_lat", 11.0)) / maxf(vf0 * vf0, 1.0)))
	steer = move_toward(steer, steer_in * max_steer, spec["s_rate"] * delta)
	var yaw_rate: float = 0.0
	if absf(vf0) > 0.2:
		yaw_rate = vf0 * tan(steer) / spec["wb"]
		if hand and absf(vf0) > 3.0:
			yaw_rate *= 1.5
	rotation.y += yaw_rate * delta

	# 2) nuevo sistema de ejes; la velocidad del mundo se conserva (permite derrapar)
	var h: float = rotation.y
	var fwd := Vector3(-sin(h), 0.0, -cos(h))
	var right := Vector3(cos(h), 0.0, -sin(h))
	var v2 := Vector3(velocity.x, 0.0, velocity.z)
	var vf: float = v2.dot(fwd)
	var vl: float = v2.dot(right)
	var braking: bool = false
	if active:
		if throttle > 0.05:
			if vf < -0.5:
				vf += brake * delta
				braking = true
			else:
				vf += accel * throttle * (1.0 - clampf(vf / maxs, 0.0, 1.0)) * delta
		elif throttle < -0.05:
			if vf > 0.5:
				vf -= brake * delta
				braking = true
			else:
				vf -= accel * 0.6 * (1.0 - clampf(-vf / spec["rev"], 0.0, 1.0)) * delta
		else:
			vf -= signf(vf) * minf(absf(vf), (0.8 + absf(vf) * 0.06) * delta)
		if hand:
			vf -= signf(vf) * minf(absf(vf), brake * 0.7 * delta)
			braking = true
	else:
		vf = move_toward(vf, 0.0, brake * delta)
	var grip: float = spec["grip"] * (0.15 if hand else 1.0)
	vl *= exp(-grip * delta)
	velocity = fwd * vf + right * vl

	# 3) altura del suelo (calle / vereda) y movimiento con colisiones
	position.y = move_toward(position.y, CityLayout.ground_height(position.x, position.z), 4.0 * delta)
	velocity.y = 0.0
	var intended: float = Vector3(velocity.x, 0.0, velocity.z).length()
	move_and_slide()
	var rv: Vector3 = get_real_velocity()
	velocity.x = rv.x
	velocity.z = rv.z
	var actual: float = Vector2(rv.x, rv.z).length()
	var impact: float = intended - actual
	if impact > 3.5 and get_slide_collision_count() > 0:
		_on_impact(impact)

	speed_forward = vf
	_update_visuals(delta, vf, yaw_rate, braking, inp)
	if _engine_pb != null:
		_fill_engine(vf)

func _on_impact(impact: float) -> void:
	damage = minf(140.0, damage + (impact - 3.0) * 4.0 * spec["dk"])
	if damage >= 100.0:
		wrecked = true
	if _crash_cd <= 0.0:
		_crash.volume_db = clampf(-12.0 + impact, -12.0, 4.0)
		_crash.play()
		_crash_cd = 0.4
	if driver != null:
		driver.call("on_vehicle_impact", impact)

func _update_visuals(delta: float, vf: float, yaw_rate: float, braking: bool, inp: Dictionary) -> void:
	var acc: float = (vf - _prev_vf) / maxf(delta, 0.0001)
	_prev_vf = vf
	var lat: float = vf * yaw_rate
	var lim: float = 0.7 if spec["lean"] > 0.0 else 0.08
	var roll: float = clampf(lat * spec["lean"], -lim, lim)
	var pitch: float = clampf(acc * 0.004, -0.05, 0.05)
	var k: float = clampf(6.0 * delta, 0.0, 1.0)
	model.body.rotation.x = lerpf(model.body.rotation.x, pitch, k)
	model.body.rotation.z = lerpf(model.body.rotation.z, roll, k)
	for w in model.wheels:
		w.rotation.x -= vf * delta / model.wheel_radius
	for m in model.steer_mounts:
		m.rotation.y = steer
	for c in model.cranks:
		c.rotation.x -= vf * delta * 2.0
	if model.tail_mat != null:
		model.tail_mat.emission_energy_multiplier = 3.0 if braking else 0.5 + DayNight.night
	var lights_on: bool = driver != null and DayNight.night > 0.35
	for sl in _lights:
		sl.visible = lights_on
	if inp.get("horn", false) and kind != "bici":
		if not _horn.playing:
			_horn.play()
	elif _horn.playing:
		_horn.stop()
	if absf(damage - _shown_damage) > 0.5:
		_shown_damage = damage
		_apply_damage()

func _apply_damage() -> void:
	var t: float = clampf(damage / 140.0, 0.0, 0.8)
	for m in model.paint_mats:
		m.albedo_color = model.paint_base.lerp(Color(0.1, 0.09, 0.08), t)
		m.roughness = 0.3 + damage * 0.005
	if model.hood != null:
		model.hood.rotation.x = deg_to_rad(minf(damage, 100.0) * 0.35)
		model.hood.scale.z = 1.0 - minf(damage, 100.0) * 0.003
	_smoke.emitting = damage > 55.0

func _fill_engine(vf: float) -> void:
	var n: int = _engine_pb.get_frames_available()
	if n <= 0:
		return
	var ratio: float = clampf(absf(vf) / spec["max"], 0.0, 1.0)
	var gear: int = mini(int(ratio * 5.0), 4)
	var within: float = ratio * 5.0 - gear
	var rpm: float = 0.2 + 0.6 * within + 0.2 * maxf(_throttle, 0.0)
	var f: float = spec["f0"] + spec["f1"] * rpm
	var vol: float = spec["vol"] * (0.55 + 0.45 * maxf(_throttle, 0.2))
	var step: float = f / RATE
	for i in n:
		_eph += step
		if _eph > 1.0:
			_eph -= 1.0
		var s: float = (_eph * 2.0 - 1.0) * 0.45 + sin(_eph * TAU * 2.0) * 0.25 + sin(_eph * TAU * 0.5) * 0.2 + randf_range(-0.04, 0.04)
		_engine_pb.push_frame(Vector2(s, s) * vol)
