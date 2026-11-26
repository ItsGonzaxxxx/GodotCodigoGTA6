class_name VehicleModel
extends RefCounted
## Fábrica de modelos 3D de vehículos (originales, sin marcas). La usan el tráfico IA y
## los vehículos conducibles. Tipos: auto, taxi, camioneta, colectivo, camion, moto, bici.

class Result:
	var root: Node3D
	var body: Node3D                       # se inclina (cabeceo / balanceo)
	var wheels: Array[Node3D] = []         # nodos que giran (eje X)
	var steer_mounts: Array[Node3D] = []   # nodos que doblan (eje Y)
	var cranks: Array[Node3D] = []
	var wheel_radius: float = 0.33
	var length: float = 4.3
	var width: float = 1.8
	var box_size: Vector3 = Vector3(1.9, 1.1, 4.3)
	var box_center: Vector3 = Vector3(0, 1.0, 0)
	var paint_mats: Array[StandardMaterial3D] = []
	var paint_base: Color = Color.WHITE
	var tail_mat: StandardMaterial3D
	var hood: Node3D
	var seat_pos: Vector3 = Vector3(-0.4, 0.9, 0.2)
	var pose: String = "seated_car"
	var open_seat: bool = false
	var door_pos: Vector3 = Vector3(-1.2, 0.8, 0.0)
	var smoke_pos: Vector3 = Vector3(0, 1.0, -1.8)
	var headlight_pos: Array[Vector3] = []

static func _paint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.55
	m.roughness = 0.3
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	return m

static func _flat(c: Color, rough: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

static func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.09, 0.12, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.8
	m.roughness = 0.05
	return m

static func _lamp(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

static func _b(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.visibility_range_end = 220.0
	parent.add_child(mi)
	return mi

static func _tube(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = mat
	mi.position = (a + b) / 2.0
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	parent.add_child(mi)

static func _wheel(res: Result, parent: Node3D, pos: Vector3, r: float, w: float, steer: bool) -> void:
	var mount := Node3D.new()
	mount.position = pos
	parent.add_child(mount)
	var spin := Node3D.new()
	mount.add_child(spin)
	var tire := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = r
	tm.bottom_radius = r
	tm.height = w
	tm.radial_segments = 18
	tire.mesh = tm
	tire.material_override = _flat(Color(0.04, 0.04, 0.04), 0.9)
	tire.rotation_degrees.z = 90.0
	spin.add_child(tire)
	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = r * 0.62
	rm.bottom_radius = r * 0.62
	rm.height = w + 0.02
	rm.radial_segments = 12
	rim.mesh = rm
	rim.material_override = _flat(Color(0.7, 0.72, 0.75), 0.3, 0.8)
	rim.rotation_degrees.z = 90.0
	spin.add_child(rim)
	_b(spin, Vector3(w + 0.03, r * 0.1, r * 1.0), Vector3.ZERO, _flat(Color(0.3, 0.3, 0.32), 0.5, 0.7))
	res.wheels.append(spin)
	if steer:
		res.steer_mounts.append(mount)

static func _label(parent: Node3D, text: String, pos: Vector3, rot_y: float, px: float, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = px
	l.position = pos
	l.rotation_degrees.y = rot_y
	l.modulate = color
	l.visibility_range_end = 60.0
	parent.add_child(l)

static func build(kind: String, rng: RandomNumberGenerator, color: Color = Color.TRANSPARENT) -> Result:
	var res := Result.new()
	res.root = Node3D.new()
	res.body = Node3D.new()
	res.root.add_child(res.body)
	var c: Color = color
	if c == Color.TRANSPARENT:
		c = Color.from_hsv(rng.randf(), 0.55, 0.72)
		if rng.randf() < 0.3:
			c = [Color(0.9, 0.9, 0.92), Color(0.12, 0.12, 0.14), Color(0.6, 0.62, 0.66)][rng.randi() % 3]
	res.paint_base = c
	match kind:
		"auto", "taxi": _sedan(res, c, kind == "taxi")
		"camioneta": _pickup(res, c)
		"colectivo": _bus(res, rng)
		"camion": _truck(res, rng)
		"moto": _moto(res, c)
		"bici": _bike(res, c)
	return res

static func _lights(res: Result, front_z: float, rear_z: float, x: float, y: float, w: float) -> void:
	var head: Material = _lamp(Color(1.0, 0.95, 0.8), 1.2)
	res.tail_mat = _lamp(Color(0.9, 0.05, 0.05), 0.5)
	for s in [-1, 1]:
		_b(res.body, Vector3(w, 0.14, 0.06), Vector3(s * x, y, front_z), head)
		_b(res.body, Vector3(w, 0.14, 0.06), Vector3(s * x, y, rear_z), res.tail_mat)
		res.headlight_pos.append(Vector3(s * x, y, front_z - 0.1))

static func _sedan(res: Result, c: Color, taxi: bool) -> void:
	var body_c: Color = Color(0.07, 0.07, 0.08) if taxi else c
	var roof_c: Color = Color(0.95, 0.8, 0.1) if taxi else c
	var p: StandardMaterial3D = _paint(body_c)
	var pr: StandardMaterial3D = _paint(roof_c)
	res.paint_mats = [p, pr]
	res.paint_base = body_c
	var g: StandardMaterial3D = _glass()
	var dark: StandardMaterial3D = _flat(Color(0.06, 0.06, 0.07), 0.6)
	var b: Node3D = res.body
	_b(b, Vector3(1.8, 0.5, 4.3), Vector3(0, 0.56, 0), p)
	res.hood = _b(b, Vector3(1.7, 0.1, 1.25), Vector3(0, 0.84, -1.45), p)
	_b(b, Vector3(1.7, 0.1, 0.85), Vector3(0, 0.84, 1.7), p)
	_b(b, Vector3(1.62, 0.1, 1.9), Vector3(0, 1.45, 0.25), pr)
	_b(b, Vector3(1.6, 0.4, 2.0), Vector3(0, 1.17, 0.25), p)
	for s in [-1, 1]:
		_b(b, Vector3(0.03, 0.3, 1.7), Vector3(s * 0.81, 1.17, 0.25), g)
		_b(b, Vector3(0.12, 0.1, 0.18), Vector3(s * 1.0, 1.0, -0.55), p)
	_b(b, Vector3(1.5, 0.4, 0.04), Vector3(0, 1.14, -0.88), g, Vector3(0.7, 0, 0))
	_b(b, Vector3(1.5, 0.38, 0.04), Vector3(0, 1.14, 1.35), g, Vector3(-0.7, 0, 0))
	_b(b, Vector3(1.82, 0.2, 0.14), Vector3(0, 0.38, -2.18), dark)
	_b(b, Vector3(1.82, 0.2, 0.14), Vector3(0, 0.38, 2.18), dark)
	_b(b, Vector3(0.9, 0.12, 0.05), Vector3(0, 0.62, -2.16), dark)
	if taxi:
		_b(b, Vector3(0.5, 0.14, 0.2), Vector3(0, 1.58, 0.25), _lamp(Color(1, 0.9, 0.5), 1.0))
	_lights(res, -2.17, 2.17, 0.62, 0.66, 0.38)
	for sx in [-1, 1]:
		_wheel(res, res.root, Vector3(sx * 0.86, 0.33, -1.38), 0.33, 0.22, true)
		_wheel(res, res.root, Vector3(sx * 0.86, 0.33, 1.32), 0.33, 0.22, false)
	res.wheel_radius = 0.33
	res.length = 4.3
	res.width = 1.8
	res.box_size = Vector3(1.9, 1.1, 4.3)
	res.box_center = Vector3(0, 1.0, 0)
	res.seat_pos = Vector3(-0.42, 0.78, 0.35)
	res.pose = "seated_car"
	res.door_pos = Vector3(-1.3, 0.8, -0.1)
	res.smoke_pos = Vector3(0, 1.0, -1.6)

static func _pickup(res: Result, c: Color) -> void:
	var p: StandardMaterial3D = _paint(c)
	res.paint_mats = [p]
	var g: StandardMaterial3D = _glass()
	var dark: StandardMaterial3D = _flat(Color(0.06, 0.06, 0.07), 0.6)
	var b: Node3D = res.body
	_b(b, Vector3(1.95, 0.6, 5.3), Vector3(0, 0.7, 0), p)
	res.hood = _b(b, Vector3(1.85, 0.12, 1.4), Vector3(0, 1.04, -1.95), p)
	_b(b, Vector3(1.85, 0.8, 1.7), Vector3(0, 1.4, -0.45), p)
	_b(b, Vector3(1.8, 0.1, 1.5), Vector3(0, 1.85, -0.45), p)
	for s in [-1, 1]:
		_b(b, Vector3(0.03, 0.5, 1.4), Vector3(s * 0.93, 1.45, -0.45), g)
		_b(b, Vector3(0.1, 0.38, 2.5), Vector3(s * 0.93, 1.2, 1.7), p)
		_b(b, Vector3(0.12, 0.1, 0.18), Vector3(s * 1.05, 1.25, -1.05), p)
	_b(b, Vector3(1.7, 0.5, 0.04), Vector3(0, 1.42, -1.33), g, Vector3(0.45, 0, 0))
	_b(b, Vector3(1.8, 0.38, 0.1), Vector3(0, 1.2, 2.9), p)
	_b(b, Vector3(1.8, 0.06, 2.5), Vector3(0, 1.0, 1.7), dark)
	_b(b, Vector3(1.97, 0.22, 0.16), Vector3(0, 0.45, -2.7), dark)
	_b(b, Vector3(1.97, 0.22, 0.16), Vector3(0, 0.45, 2.7), dark)
	_lights(res, -2.66, 2.92, 0.7, 0.8, 0.4)
	for sx in [-1, 1]:
		_wheel(res, res.root, Vector3(sx * 0.9, 0.38, -1.7), 0.38, 0.26, true)
		_wheel(res, res.root, Vector3(sx * 0.9, 0.38, 1.6), 0.38, 0.26, false)
	res.wheel_radius = 0.38
	res.length = 5.3
	res.width = 1.95
	res.box_size = Vector3(2.0, 1.3, 5.3)
	res.box_center = Vector3(0, 1.1, 0)
	res.seat_pos = Vector3(-0.45, 1.0, -0.3)
	res.pose = "seated_car"
	res.door_pos = Vector3(-1.35, 0.9, -0.4)
	res.smoke_pos = Vector3(0, 1.2, -2.0)

static func _bus(res: Result, rng: RandomNumberGenerator) -> void:
	var c: Color = [Color(0.15, 0.35, 0.7), Color(0.75, 0.15, 0.15), Color(0.2, 0.5, 0.3), Color(0.9, 0.55, 0.1)][rng.randi() % 4]
	var p: StandardMaterial3D = _paint(c)
	res.paint_mats = [p]
	res.paint_base = c
	var g: StandardMaterial3D = _glass()
	var white: StandardMaterial3D = _flat(Color(0.94, 0.94, 0.94), 0.5)
	var dark: StandardMaterial3D = _flat(Color(0.06, 0.06, 0.07), 0.6)
	var b: Node3D = res.body
	_b(b, Vector3(2.5, 2.5, 10.5), Vector3(0, 1.65, 0), p)
	_b(b, Vector3(2.52, 0.6, 10.52), Vector3(0, 0.75, 0), white)
	for s in [-1, 1]:
		_b(b, Vector3(0.03, 0.95, 8.6), Vector3(s * 1.26, 1.95, -0.2), g)
	_b(b, Vector3(2.3, 1.1, 0.04), Vector3(0, 1.9, -5.27), g)
	_b(b, Vector3(2.3, 0.8, 0.04), Vector3(0, 1.95, 5.27), g)
	_b(b, Vector3(1.8, 0.32, 0.04), Vector3(0, 2.6, -5.28), _lamp(Color(1, 0.7, 0.1), 1.0))
	_b(b, Vector3(1.3, 0.3, 2.2), Vector3(0, 3.05, 0.5), white)
	_b(b, Vector3(0.04, 1.9, 1.1), Vector3(1.27, 1.55, -3.0), dark)
	_b(b, Vector3(2.52, 0.25, 0.2), Vector3(0, 0.55, -5.3), dark)
	_b(b, Vector3(2.52, 0.25, 0.2), Vector3(0, 0.55, 5.3), dark)
	res.hood = _b(b, Vector3(2.3, 0.2, 0.3), Vector3(0, 1.0, -5.35), dark)
	_lights(res, -5.27, 5.27, 0.9, 0.95, 0.4)
	var line: String = "LÍNEA %d" % rng.randi_range(10, 99)
	for s in [-1, 1]:
		_label(b, line, Vector3(s * 1.27, 0.8, 0), 90.0 * s, 0.012, Color(0.1, 0.1, 0.1))
	_label(b, line.replace("LÍNEA ", "") + " · CENTRO", Vector3(0, 2.6, -5.31), 0.0, 0.006, Color(1, 0.8, 0.2))
	for sx in [-1, 1]:
		_wheel(res, res.root, Vector3(sx * 1.05, 0.5, -3.5), 0.5, 0.3, true)
		_wheel(res, res.root, Vector3(sx * 1.05, 0.5, 2.9), 0.5, 0.3, false)
	res.wheel_radius = 0.5
	res.length = 10.5
	res.width = 2.5
	res.box_size = Vector3(2.55, 2.5, 10.5)
	res.box_center = Vector3(0, 1.7, 0)
	res.seat_pos = Vector3(-0.8, 1.3, -4.2)
	res.pose = "seated_car"
	res.door_pos = Vector3(-1.5, 1.0, -3.8)
	res.smoke_pos = Vector3(0, 1.4, -5.0)

static func _truck(res: Result, rng: RandomNumberGenerator) -> void:
	var c: Color = [Color(0.8, 0.2, 0.15), Color(0.15, 0.3, 0.6), Color(0.9, 0.7, 0.1)][rng.randi() % 3]
	var p: StandardMaterial3D = _paint(c)
	res.paint_mats = [p]
	res.paint_base = c
	var g: StandardMaterial3D = _glass()
	var white: StandardMaterial3D = _flat(Color(0.92, 0.92, 0.9), 0.6)
	var dark: StandardMaterial3D = _flat(Color(0.07, 0.07, 0.08), 0.6)
	var b: Node3D = res.body
	_b(b, Vector3(2.2, 0.4, 9.8), Vector3(0, 0.75, 0), dark)
	_b(b, Vector3(2.4, 2.1, 2.2), Vector3(0, 1.85, -3.6), p)
	res.hood = _b(b, Vector3(2.3, 0.5, 0.5), Vector3(0, 1.05, -4.85), p)
	_b(b, Vector3(2.0, 0.9, 0.04), Vector3(0, 2.2, -4.72), g, Vector3(0.15, 0, 0))
	for s in [-1, 1]:
		_b(b, Vector3(0.03, 0.8, 1.3), Vector3(s * 1.21, 2.2, -3.5), g)
		_b(b, Vector3(0.16, 0.12, 0.3), Vector3(s * 1.35, 2.2, -4.5), dark)
	_b(b, Vector3(2.5, 2.8, 6.2), Vector3(0, 2.25, 1.6), white)
	_b(b, Vector3(2.52, 0.12, 6.22), Vector3(0, 3.7, 1.6), _flat(Color(0.7, 0.7, 0.72), 0.5))
	_b(b, Vector3(2.45, 0.35, 0.2), Vector3(0, 0.55, -5.05), dark)
	for s in [-1, 1]:
		_label(b, "TRANSPORTES DEL SUR", Vector3(s * 1.26, 2.4, 1.6), 90.0 * s, 0.012, c)
	_lights(res, -4.72, 4.8, 0.8, 0.95, 0.4)
	for sx in [-1, 1]:
		_wheel(res, res.root, Vector3(sx * 1.0, 0.5, -3.6), 0.5, 0.32, true)
		_wheel(res, res.root, Vector3(sx * 1.0, 0.5, 2.3), 0.5, 0.32, false)
		_wheel(res, res.root, Vector3(sx * 1.0, 0.5, 3.6), 0.5, 0.32, false)
	res.wheel_radius = 0.5
	res.length = 10.0
	res.width = 2.5
	res.box_size = Vector3(2.55, 3.0, 10.0)
	res.box_center = Vector3(0, 2.0, 0)
	res.seat_pos = Vector3(-0.6, 1.4, -3.6)
	res.pose = "seated_car"
	res.door_pos = Vector3(-1.5, 1.2, -3.6)
	res.smoke_pos = Vector3(0, 1.4, -5.0)

static func _moto(res: Result, c: Color) -> void:
	var p: StandardMaterial3D = _paint(c)
	res.paint_mats = [p]
	var dark: StandardMaterial3D = _flat(Color(0.07, 0.07, 0.08), 0.5, 0.3)
	var metal: StandardMaterial3D = _flat(Color(0.6, 0.6, 0.65), 0.3, 0.8)
	var b: Node3D = res.body
	_b(b, Vector3(0.3, 0.28, 0.55), Vector3(0, 0.82, -0.2), p)
	res.hood = _b(b, Vector3(0.34, 0.12, 0.4), Vector3(0, 0.75, -0.62), p)
	_b(b, Vector3(0.28, 0.1, 0.75), Vector3(0, 0.78, 0.45), dark)
	_b(b, Vector3(0.3, 0.32, 0.45), Vector3(0, 0.45, 0.0), metal)
	_b(b, Vector3(0.24, 0.08, 0.6), Vector3(0, 0.38, 0.8), p, Vector3(0.25, 0, 0))
	_tube(b, Vector3(0.12, 0.3, 0.5), Vector3(0.14, 0.4, 1.0), 0.03, metal)
	var steer_root := Node3D.new()
	steer_root.position = Vector3(0, 0.0, -0.75)
	b.add_child(steer_root)
	res.steer_mounts.append(steer_root)
	_tube(steer_root, Vector3(0, 0.32, 0), Vector3(0, 0.98, 0.1), 0.025, metal)
	_b(steer_root, Vector3(0.62, 0.04, 0.04), Vector3(0, 1.0, 0.1), dark)
	_b(steer_root, Vector3(0.2, 0.2, 0.12), Vector3(0, 0.95, -0.08), _lamp(Color(1, 0.95, 0.8), 1.2))
	res.headlight_pos.append(Vector3(0, 0.95, -0.9))
	res.tail_mat = _lamp(Color(0.9, 0.05, 0.05), 0.5)
	_b(b, Vector3(0.16, 0.08, 0.05), Vector3(0, 0.72, 1.15), res.tail_mat)
	_wheel(res, steer_root, Vector3(0, 0.32, 0), 0.32, 0.13, false)
	_wheel(res, b, Vector3(0, 0.32, 0.72), 0.32, 0.15, false)
	res.wheel_radius = 0.32
	res.length = 2.1
	res.width = 0.8
	res.box_size = Vector3(0.8, 1.0, 2.0)
	res.box_center = Vector3(0, 0.95, 0)
	res.seat_pos = Vector3(0, 0.9, 0.35)
	res.pose = "seated_moto"
	res.open_seat = true
	res.door_pos = Vector3(-0.8, 0.6, 0.0)
	res.smoke_pos = Vector3(0, 0.6, -0.3)

static func _bike(res: Result, c: Color) -> void:
	var p: StandardMaterial3D = _paint(c)
	res.paint_mats = [p]
	var dark: StandardMaterial3D = _flat(Color(0.07, 0.07, 0.08), 0.5)
	var b: Node3D = res.body
	var bb := Vector3(0, 0.3, 0.1)
	var seat_top := Vector3(0, 0.92, 0.28)
	var head := Vector3(0, 0.88, -0.42)
	var rear := Vector3(0, 0.34, 0.58)
	_tube(b, bb, rear, 0.015, p)
	_tube(b, bb, seat_top, 0.018, p)
	_tube(b, seat_top, rear, 0.015, p)
	_tube(b, seat_top, head, 0.02, p)
	_tube(b, bb, head, 0.022, p)
	_b(b, Vector3(0.1, 0.04, 0.22), Vector3(0, 0.96, 0.3), dark)
	var steer_root := Node3D.new()
	steer_root.position = Vector3(0, 0.0, -0.58)
	b.add_child(steer_root)
	res.steer_mounts.append(steer_root)
	_tube(steer_root, Vector3(0, 0.34, 0), Vector3(0, 0.9, 0.16), 0.016, dark)
	_b(steer_root, Vector3(0.52, 0.03, 0.03), Vector3(0, 0.95, 0.15), dark)
	_b(steer_root, Vector3(0.07, 0.07, 0.06), Vector3(0, 0.88, 0.05), _lamp(Color(1, 1, 0.9), 0.8))
	res.headlight_pos.append(Vector3(0, 0.88, -0.5))
	res.tail_mat = _lamp(Color(0.8, 0.05, 0.05), 0.3)
	_b(b, Vector3(0.05, 0.05, 0.03), Vector3(0, 0.88, 0.6), res.tail_mat)
	for w in [steer_root, b]:
		var spin := Node3D.new()
		spin.position = Vector3(0, 0.34, 0.0 if w == steer_root else 0.58)
		w.add_child(spin)
		var tor := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.315
		tm.outer_radius = 0.345
		tm.rings = 24
		tm.ring_segments = 8
		tor.mesh = tm
		tor.material_override = _flat(Color(0.05, 0.05, 0.05), 0.9)
		tor.rotation_degrees.z = 90.0
		spin.add_child(tor)
		_b(spin, Vector3(0.02, 0.62, 0.02), Vector3.ZERO, dark)
		_b(spin, Vector3(0.02, 0.02, 0.62), Vector3.ZERO, dark)
		res.wheels.append(spin)
	var crank := Node3D.new()
	crank.position = bb
	b.add_child(crank)
	_b(crank, Vector3(0.02, 0.34, 0.03), Vector3(0, 0, 0), dark)
	_b(crank, Vector3(0.1, 0.03, 0.08), Vector3(0.1, 0.17, 0), dark)
	_b(crank, Vector3(0.1, 0.03, 0.08), Vector3(-0.1, -0.17, 0), dark)
	res.cranks.append(crank)
	res.wheel_radius = 0.34
	res.length = 1.8
	res.width = 0.6
	res.box_size = Vector3(0.6, 1.0, 1.7)
	res.box_center = Vector3(0, 0.95, 0)
	res.seat_pos = Vector3(0, 0.98, 0.28)
	res.pose = "seated_bike"
	res.open_seat = true
	res.door_pos = Vector3(-0.7, 0.6, 0.0)
	res.smoke_pos = Vector3(0, 0.6, 0.0)
