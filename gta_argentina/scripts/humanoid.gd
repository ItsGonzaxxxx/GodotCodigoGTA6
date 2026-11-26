class_name Humanoid
extends Node3D
## Cuerpo humano articulado (cabeza, cuello, torso, pelvis, brazos y piernas de dos segmentos,
## manos y pies) con animación procedural: idle, caminar, correr, agacharse, saltar,
## sentarse (auto/moto) y pedalear. Lo usan el jugador y los peatones.

const HIP_STAND := 0.92
const HIP_SEAT := 0.5

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm: Array[Node3D] = []
var fore: Array[Node3D] = []
var leg: Array[Node3D] = []
var shin: Array[Node3D] = []
var phase: float = 0.0
var detail: bool = true
var _t: float = 0.0
var _vis_end: float = 0.0
var _cache: Dictionary = {}

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var key: String = c.to_html() + str(rough)
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_cache[key] = m
	return m

func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color, rough: float = 0.85, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c, rough)
	mi.position = pos
	mi.scale = scl
	if _vis_end > 0.0:
		mi.visibility_range_end = _vis_end
	parent.add_child(mi)
	return mi

func _cap(parent: Node3D, r: float, h: float, pos: Vector3, c: Color, rough: float = 0.85, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10 if detail else 8
	m.rings = 3
	return _mi(parent, m, pos, c, rough, scl)

func _sph(parent: Node3D, r: float, pos: Vector3, c: Color, rough: float = 0.85, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12 if detail else 8
	m.rings = 6 if detail else 4
	return _mi(parent, m, pos, c, rough, scl)

func _bx(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rough: float = 0.85) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mi(parent, m, pos, c, rough)

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func build(o: Dictionary) -> void:
	detail = o.get("detail", true)
	_vis_end = o.get("vis_end", 0.0)
	var skin: Color = o.get("skin", Color(0.9, 0.72, 0.58))
	var shirt: Color = o.get("shirt", Color(0.3, 0.45, 0.7))
	var pants: Color = o.get("pants", Color(0.2, 0.22, 0.3))
	var shoes: Color = o.get("shoes", Color(0.12, 0.12, 0.13))
	var hair: Color = o.get("hair", Color(0.15, 0.1, 0.07))
	var style: String = o.get("hair_style", "short")
	var long_sleeves: bool = o.get("long_sleeves", false)
	var extras: Array = o.get("extras", [])

	hips = _pivot(self, Vector3(0, HIP_STAND, 0))
	_bx(hips, Vector3(0.34, 0.2, 0.21), Vector3(0, 0.0, 0), pants)
	torso = _pivot(hips, Vector3(0, 0.08, 0))
	_cap(torso, 0.17, 0.62, Vector3(0, 0.28, 0), shirt, 0.9, Vector3(1.08, 1.0, 0.7))
	_cap(torso, 0.15, 0.3, Vector3(0, 0.02, 0), shirt, 0.9, Vector3(1.05, 1.0, 0.72))
	_cap(torso, 0.05, 0.12, Vector3(0, 0.58, 0), skin, 0.6)       # cuello
	head = _pivot(torso, Vector3(0, 0.63, 0))
	_sph(head, 0.105, Vector3(0, 0.1, 0), skin, 0.6, Vector3(0.92, 1.12, 1.0))
	match style:
		"short":
			_sph(head, 0.112, Vector3(0, 0.145, 0.012), hair, 0.9, Vector3(1.0, 0.85, 1.05))
		"long":
			_sph(head, 0.112, Vector3(0, 0.145, 0.012), hair, 0.9, Vector3(1.0, 0.85, 1.05))
			_bx(head, Vector3(0.21, 0.3, 0.07), Vector3(0, 0.0, 0.09), hair, 0.9)
	if detail:
		for s in [-1, 1]:
			_sph(head, 0.013, Vector3(s * 0.04, 0.12, -0.093), Color(0.05, 0.04, 0.04), 0.4)
			_sph(head, 0.022, Vector3(s * 0.098, 0.1, 0.0), skin, 0.6, Vector3(0.5, 1.0, 0.8))
		_bx(head, Vector3(0.025, 0.04, 0.03), Vector3(0, 0.08, -0.1), skin, 0.6)

	for i in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		var a: Node3D = _pivot(torso, Vector3(sx * 0.225, 0.5, 0))
		_sph(a, 0.065, Vector3.ZERO, shirt, 0.9)
		_cap(a, 0.05, 0.34, Vector3(0, -0.14, 0), shirt, 0.9)
		var f: Node3D = _pivot(a, Vector3(0, -0.29, 0))
		var fc: Color = shirt if long_sleeves else skin
		_cap(f, 0.042, 0.3, Vector3(0, -0.12, 0), fc, 0.9 if long_sleeves else 0.6)
		_sph(f, 0.045, Vector3(0, -0.27, 0), skin, 0.6)
		arm.append(a)
		fore.append(f)
		var l: Node3D = _pivot(hips, Vector3(sx * 0.095, -0.02, 0))
		_cap(l, 0.085, 0.52, Vector3(0, -0.2, 0), pants, 0.9)
		var sh: Node3D = _pivot(l, Vector3(0, -0.43, 0))
		_cap(sh, 0.065, 0.5, Vector3(0, -0.2, 0), pants, 0.9)
		_bx(sh, Vector3(0.1, 0.07, 0.27), Vector3(0, -0.425, -0.06), shoes, 0.6)
		leg.append(l)
		shin.append(sh)

	for e in extras:
		match e:
			"helmet":
				_sph(head, 0.125, Vector3(0, 0.17, 0), Color(1, 0.85, 0.1), 0.4, Vector3(1.0, 0.75, 1.05))
				_bx(head, Vector3(0.26, 0.02, 0.1), Vector3(0, 0.15, -0.12), Color(1, 0.85, 0.1), 0.4)
			"cap":
				_sph(head, 0.118, Vector3(0, 0.16, 0), Color(0.05, 0.08, 0.2), 0.7, Vector3(1.0, 0.7, 1.05))
				_bx(head, Vector3(0.2, 0.02, 0.1), Vector3(0, 0.145, -0.13), Color(0.05, 0.08, 0.2), 0.7)
			"moto_helmet":
				_sph(head, 0.135, Vector3(0, 0.12, 0), Color(0.8, 0.1, 0.1), 0.25, Vector3(1.0, 1.05, 1.1))
				_bx(head, Vector3(0.2, 0.07, 0.04), Vector3(0, 0.12, -0.13), Color(0.05, 0.05, 0.08), 0.2)
			"backpack":
				_bx(torso, Vector3(0.3, 0.4, 0.14), Vector3(0, 0.3, 0.16), Color(0.15, 0.15, 0.2), 0.8)
			"apron":
				_bx(torso, Vector3(0.28, 0.5, 0.03), Vector3(0, 0.22, -0.125), Color(0.95, 0.95, 0.95), 0.9)
			"vest":
				_bx(torso, Vector3(0.37, 0.42, 0.25), Vector3(0, 0.3, 0), Color(0.75, 0.95, 0.1), 0.8)
			"scarf":
				_cap(torso, 0.085, 0.14, Vector3(0, 0.56, 0), Color(0.95, 0.5, 0.1), 0.9)
			"stripes":
				for k in 3:
					_bx(torso, Vector3(0.37, 0.05, 0.25), Vector3(0, 0.18 + k * 0.12, 0), Color(1.0, 0.6, 0.1), 0.9)
			"hood":
				_sph(head, 0.128, Vector3(0, 0.12, 0.02), Color(0.16, 0.16, 0.18), 0.9, Vector3(1.0, 1.05, 1.08))
				_bx(head, Vector3(0.17, 0.07, 0.04), Vector3(0, 0.05, -0.1), Color(0.05, 0.05, 0.06), 0.9)
			"belt":
				_bx(torso, Vector3(0.36, 0.05, 0.23), Vector3(0, -0.02, 0), Color(0.08, 0.08, 0.08), 0.5)

func _rot(node: Node3D, x: float, k: float) -> void:
	node.rotation.x = lerpf(node.rotation.x, x, k)

## state: ground | air | crouch | seated_car | seated_moto | seated_bike
## speed: velocidad horizontal (m/s). steer: -1..1 (sólo sentado).
func animate(delta: float, speed: float, state: String, steer: float = 0.0) -> void:
	_t += delta
	var k: float = clampf(14.0 * delta, 0.0, 1.0)
	var hip_y: float = HIP_STAND
	var tl: float = 0.0
	var th: Array[float] = [0.0, 0.0]
	var sh: Array[float] = [0.0, 0.0]
	var ar: Array[float] = [0.0, 0.0]
	var fo: Array[float] = [0.15, 0.15]
	var twist: float = 0.0
	var head_y: float = 0.0
	match state:
		"ground":
			if speed > 0.15:
				phase += delta * (6.0 + speed * 1.6)
				var amp: float = clampf(0.25 + speed * 0.08, 0.0, 0.95)
				var s: float = sin(phase)
				th = [s * amp, -s * amp]
				sh = [-maxf(0.0, cos(phase)) * (0.4 + amp * 1.1), -maxf(0.0, -cos(phase)) * (0.4 + amp * 1.1)]
				ar = [-s * amp * 0.9, s * amp * 0.9]
				fo = [0.3 + amp * 0.7, 0.3 + amp * 0.7]
				tl = -clampf(speed * 0.016, 0.0, 0.2)
				twist = s * amp * 0.14
				hip_y -= amp * 0.045 * (0.5 + 0.5 * cos(2.0 * phase))
			else:
				ar = [sin(_t * 1.3) * 0.03 + 0.03, -sin(_t * 1.3) * 0.03 + 0.03]
				hip_y -= sin(_t * 1.7) * 0.004
				tl = sin(_t * 1.7) * 0.012
				head_y = sin(_t * 0.5) * 0.2
		"air":
			th = [0.65, -0.2]
			sh = [-1.0, -0.7]
			ar = [1.1, 0.8]
			fo = [0.5, 0.5]
			tl = -0.08
		"crouch":
			hip_y = 0.6
			th = [1.1, 1.1]
			sh = [-1.9, -1.9]
			tl = -0.45
			ar = [0.6, 0.6]
			fo = [0.9, 0.9]
			if speed > 0.2:
				phase += delta * speed * 5.0
				th[0] += sin(phase) * 0.25
				th[1] -= sin(phase) * 0.25
		"seated_car":
			hip_y = HIP_SEAT
			th = [1.45, 1.45]
			sh = [-1.45, -1.45]
			tl = -0.04
			ar = [1.15, 1.15]
			fo = [0.55, 0.55]
			head_y = -steer * 0.5
			twist = steer * 0.15
		"seated_moto":
			hip_y = HIP_SEAT
			th = [1.05, 1.05]
			sh = [-1.7, -1.7]
			tl = -0.38
			ar = [1.35, 1.35]
			fo = [0.25, 0.25]
			head_y = -steer * 0.4
		"seated_bike":
			phase += delta * (1.5 + speed * 1.6)
			hip_y = HIP_SEAT + 0.04
			th = [0.95 + sin(phase) * 0.55, 0.95 - sin(phase) * 0.55]
			sh = [-1.25 - cos(phase) * 0.5, -1.25 + cos(phase) * 0.5]
			tl = -0.5
			ar = [1.3, 1.3]
			fo = [0.3, 0.3]
			head_y = -steer * 0.4
	hips.position.y = lerpf(hips.position.y, hip_y, k)
	_rot(torso, tl, k)
	torso.rotation.y = lerpf(torso.rotation.y, twist, k)
	head.rotation.y = lerpf(head.rotation.y, head_y, k)
	for i in 2:
		_rot(leg[i], th[i], k)
		_rot(shin[i], sh[i], k)
		_rot(arm[i], ar[i], k)
		_rot(fore[i], fo[i], k)
