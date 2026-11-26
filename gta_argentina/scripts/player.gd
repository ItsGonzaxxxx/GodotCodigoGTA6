extends CharacterBody3D
## Jugador: personaje articulado con animaciones (idle, caminar, correr, agacharse, saltar),
## cámara en tercera persona y manejo de vehículos (subir/bajar con E).

signal money_changed(value: int)
signal message(text: String)
signal prompt_changed(text: String)
signal notice(text: String)

const WALK_SPEED := 4.5
const RUN_SPEED := 8.5
const CROUCH_SPEED := 2.2
const JUMP_VELOCITY := 5.5
const GRAVITY := 15.0
const INTERACT_RANGE := 3.0
const MOUSE_SENS := 0.003  # se multiplica por la opción del jugador
const BODY_SCALE := 0.95

var money: int = 5000
var yaw: float = 0.0
var pitch: float = -0.25
var crouching: bool = false
var vehicle: Node = null
var crime: Crime
var controls_enabled: bool = true
var mouse_free: bool = false

var _pivot: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _col: CollisionShape3D
var _capsule: CapsuleShape3D
var _human: Humanoid
var _last_prompt: String = ""
var _mouse_idle: float = 0.0
var _shake: float = 0.0

func _ready() -> void:
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = 1.8
	_col = CollisionShape3D.new()
	_col.shape = _capsule
	add_child(_col)

	_human = Humanoid.new()
	add_child(_human)
	_human.build({"skin": Color(0.88, 0.7, 0.55), "shirt": Color(0.2, 0.3, 0.5), "pants": Color(0.16, 0.2, 0.34),
		"shoes": Color(0.9, 0.9, 0.9), "hair": Color(0.1, 0.07, 0.05), "long_sleeves": true, "extras": ["belt"]})
	_human.scale = Vector3.ONE * BODY_SCALE

	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 1.5, 0)
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = 5.0
	_arm.margin = 0.2
	var sph := SphereShape3D.new()
	sph.radius = 0.3
	_arm.shape = sph
	_arm.add_excluded_object(get_rid())
	_pivot.add_child(_arm)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 70.0
	_cam.far = 700.0
	_arm.add_child(_cam)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_shape()

func toggle_mouse() -> void:
	mouse_free = not mouse_free
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse_free else Input.MOUSE_MODE_CAPTURED

func capture_mouse() -> void:
	mouse_free = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func teleport_to(p: Vector3) -> void:
	if vehicle != null:
		exit_vehicle()
	global_position = p
	velocity = Vector3.ZERO

func make_camera_current() -> void:
	_cam.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = MOUSE_SENS * GameSettings.mouse_sens_mul
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens, -1.2, 0.5)
		_mouse_idle = 0.0
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		toggle_mouse()
	elif event is InputEventMouseButton and event.pressed and not mouse_free:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("snatch"):
		if crime != null:
			crime.try_snatch()

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return
	if vehicle != null:
		_drive(delta)
		_update_prompt()
		return
	_pivot.rotation = Vector3(pitch, yaw, 0)
	_cam.fov = lerpf(_cam.fov, 70.0, clampf(4.0 * delta, 0.0, 1.0))

	crouching = Input.is_action_pressed("crouch")
	_update_shape()

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = (Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed: float = WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("run"):
		speed = RUN_SPEED

	var accel: float = 12.0 if is_on_floor() else 3.0
	velocity.x = lerpf(velocity.x, dir.x * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * speed, clampf(accel * delta, 0.0, 1.0))

	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not crouching:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()

	if dir.length() > 0.1:
		var target: float = atan2(-dir.x, -dir.z)
		_human.rotation.y = lerp_angle(_human.rotation.y, target, clampf(10.0 * delta, 0.0, 1.0))

	var hspeed: float = Vector2(velocity.x, velocity.z).length()
	var state: String = "ground"
	if not is_on_floor():
		state = "air"
	elif crouching:
		state = "crouch"
	_human.animate(delta, hspeed, state)

	if global_position.y < -30.0:
		global_position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO

	_update_prompt()

func _update_shape() -> void:
	var h: float = 1.2 if crouching else 1.8
	_capsule.height = h
	_col.position.y = h / 2.0

# ---------- vehículos ----------
func enter_vehicle(v: Node) -> void:
	if vehicle != null:
		return
	vehicle = v
	v.call("on_enter", self)
	_col.disabled = true
	velocity = Vector3.ZERO
	_arm.spring_length = v.spec["cam_d"]
	_pivot.position = Vector3(0, v.spec["cam_h"], 0)
	pitch = -0.2
	yaw = v.rotation.y
	notice.emit("%s — W/S acelerar/frenar · A/D girar · Espacio freno de mano · H bocina · E bajar" % v.spec["name"])

func exit_vehicle() -> void:
	if vehicle == null:
		return
	var v: Node = vehicle
	vehicle = null
	v.call("on_exit")
	global_position = v.call("exit_position")
	velocity = Vector3.ZERO
	_col.disabled = false
	_human.transform = Transform3D.IDENTITY
	_human.scale = Vector3.ONE * BODY_SCALE
	_human.visible = true
	_arm.spring_length = 5.0
	_pivot.position = Vector3(0, 1.5, 0)
	pitch = -0.25

func on_vehicle_impact(impact: float) -> void:
	_shake = clampf(impact * 0.012, 0.0, 0.35)
	if impact > 9.0:
		message.emit("Vos: ¡Qué chocada!")

func _drive(delta: float) -> void:
	var v: Node = vehicle
	global_position = v.global_position
	velocity = Vector3.ZERO
	_mouse_idle += delta
	var vf: float = v.get("speed_forward")
	if _mouse_idle > 1.5 and vf > 1.5:
		yaw = lerp_angle(yaw, v.rotation.y, clampf(1.8 * delta, 0.0, 1.0))
	_shake = move_toward(_shake, 0.0, delta * 0.6)
	_pivot.rotation = Vector3(pitch, yaw, 0)
	_pivot.position = Vector3(randf_range(-_shake, _shake), v.spec["cam_h"] + randf_range(-_shake, _shake), 0)
	_cam.fov = lerpf(_cam.fov, 70.0 + clampf(absf(vf) * 0.5, 0.0, 18.0), clampf(4.0 * delta, 0.0, 1.0))
	var m: VehicleModel.Result = v.get("model")
	if m.open_seat:
		_human.visible = true
		var seat: Node3D = v.get("seat_node")
		var pos: Vector3 = seat.global_position - Vector3(0, Humanoid.HIP_SEAT * BODY_SCALE, 0)
		_human.global_transform = Transform3D(seat.global_basis.orthonormalized(), pos)
		_human.scale = Vector3.ONE * BODY_SCALE
	else:
		_human.visible = false
	_human.animate(delta, absf(vf), m.pose, clampf(v.get("steer") * 2.0, -1.0, 1.0))

# ---------- interacción ----------
func _nearest_interactable() -> Node:
	var best: Node = null
	var best_d: float = INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		var d: float = global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

func _update_prompt() -> void:
	var text: String = ""
	if vehicle != null:
		text = "[E] Bajar"
	else:
		var n: Node = _nearest_interactable()
		if n != null:
			text = "[E] " + str(n.get("prompt"))
	if text != _last_prompt:
		_last_prompt = text
		prompt_changed.emit(text)

func _try_interact() -> void:
	if vehicle != null:
		exit_vehicle()
		return
	var n: Node = _nearest_interactable()
	if n != null:
		n.call("interact", self)

func add_money(amount: int) -> bool:
	if money + amount < 0:
		return false
	money += amount
	money_changed.emit(money)
	return true
