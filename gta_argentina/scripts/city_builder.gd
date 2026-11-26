class_name CityBuilder
extends RefCounted
## Construye la ciudad: calles, señalización, manzanas por zona, plaza, luminarias.

const SHOPS: Array[String] = [
	"KIOSCO 25 HORAS", "PANADERÍA LA ESPIGA", "CARNICERÍA DON PEPE", "FARMACIA DEL PUEBLO",
	"VERDULERÍA EL HUERTO", "LOCUTORIO ONLINE", "FERRETERÍA SAN MARTÍN", "PIZZERÍA LOS AMIGOS",
	"BAR NOTABLE EL FARO", "LIBRERÍA LA ESQUINA", "PELUQUERÍA BELLA", "MINIMERCADO LA ESTRELLA",
	"CAFÉ DEL BARRIO", "HELADERÍA POLO SUR", "TALLER MECÁNICO ROLDÁN", "EMPANADAS LA TUCUMANA"]
const PASTEL: Array[Color] = [
	Color(0.93, 0.85, 0.72), Color(0.85, 0.75, 0.70), Color(0.78, 0.84, 0.88),
	Color(0.90, 0.78, 0.60), Color(0.75, 0.82, 0.72), Color(0.88, 0.70, 0.66)]
const POPULAR_COLORS: Array[Color] = [
	Color(0.75, 0.35, 0.25), Color(0.2, 0.6, 0.65), Color(0.9, 0.75, 0.25),
	Color(0.85, 0.45, 0.6), Color(0.45, 0.65, 0.35), Color(0.6, 0.6, 0.62)]
const CENTRO_COLORS: Array[Color] = [
	Color(0.55, 0.6, 0.68), Color(0.7, 0.72, 0.75), Color(0.45, 0.52, 0.6), Color(0.8, 0.78, 0.72)]
const SIGN_COLORS: Array[Color] = [
	Color(0.7, 0.12, 0.12), Color(0.1, 0.3, 0.6), Color(0.1, 0.45, 0.25), Color(0.85, 0.6, 0.1), Color(0.25, 0.25, 0.28)]

var _root: Node3D
var _rng := RandomNumberGenerator.new()
var _facade: Shader
var _mats: Dictionary = {}
var _paving_shader: Shader
var lamp_mat: StandardMaterial3D

func build(parent: Node3D, seed_value: int) -> void:
	_root = parent
	_rng.seed = seed_value
	_facade = load("res://shaders/facade.gdshader")
	var total: float = CityLayout.GRID * CityLayout.STEP + CityLayout.STREET
	_paving_shader = load("res://shaders/paving.gdshader")
	_ground(total)
	_build_markings()
	_build_lamps()
	for i in CityLayout.GRID:
		for j in CityLayout.GRID:
			_build_cell(i, j)

# ---------- suelo ----------
func _ground(total: float) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(total, 1.0, total)
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(total, 1.0, total)
	mi.mesh = bm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/asphalt.gdshader")
	mi.material_override = sm
	sb.add_child(mi)
	sb.position = Vector3(0, -0.5, 0)
	_root.add_child(sb)

func _paving(pos: Vector3, size: Vector3, color: Color, grass: bool) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var sm := ShaderMaterial.new()
	sm.shader = _paving_shader
	sm.set_shader_parameter("base", color)
	sm.set_shader_parameter("grass", 1.0 if grass else 0.0)
	mi.material_override = sm
	sb.add_child(mi)
	sb.position = pos
	_root.add_child(sb)

# ---------- utilidades ----------
func _mat(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + ("e" if emissive else "")
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.8
	_mats[key] = m
	return m

func _box(pos: Vector3, size: Vector3, color: Color, collide: bool = true, parent: Node = null) -> Node3D:
	var root: Node3D
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		root = sb
	else:
		root = Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	root.add_child(mi)
	root.position = pos
	(parent if parent != null else _root).add_child(root)
	return root

func _multimesh(mesh: Mesh, color: Color, xforms: Array[Transform3D], emissive: bool = false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(color, emissive)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mmi)

func _pick(arr: Array) -> Variant:
	return arr[_rng.randi() % arr.size()]

# ---------- calles ----------
func _build_markings() -> void:
	var dashes: Array[Transform3D] = []
	var bars: Array[Transform3D] = []
	var rot90 := Basis(Vector3.UP, PI / 2.0)
	var G: int = CityLayout.GRID
	for k in G + 1:
		var s: float = CityLayout.street_coord(k)
		for m in G:
			var z0: float = CityLayout.street_coord(m) + 8.0
			var z1: float = CityLayout.street_coord(m + 1) - 8.0
			var z: float = z0
			while z < z1:
				dashes.append(Transform3D(Basis(), Vector3(s, 0.03, z)))
				dashes.append(Transform3D(rot90, Vector3(z, 0.03, s)))
				z += 6.0
	for i in G:
		for j in G:
			var c: Vector3 = CityLayout.cell_center(i, j)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					if sx == 1 and i + 1 < G:
						for b in 5:
							bars.append(Transform3D(Basis(), Vector3(c.x + sx * 26.0, 0.03, c.z + sz * CityLayout.WALK + (b - 2) * 0.9)))
					if sz == 1 and j + 1 < G:
						for b in 5:
							bars.append(Transform3D(rot90, Vector3(c.x + sx * CityLayout.WALK + (b - 2) * 0.9, 0.03, c.z + sz * 26.0)))
	var dm := BoxMesh.new()
	dm.size = Vector3(0.25, 0.02, 3.0)
	_multimesh(dm, Color(0.9, 0.8, 0.25), dashes)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.02, 10.0)   # barras largas; se orientan según el cruce
	# las barras de cruce en X se rotan 90° para quedar paralelas al sentido de marcha
	var fixed: Array[Transform3D] = []
	for t in bars:
		fixed.append(Transform3D(t.basis * Basis(Vector3.UP, PI / 2.0), t.origin))
	_multimesh(bm, Color(0.92, 0.92, 0.92), fixed)

func _build_lamps() -> void:
	var poles: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	for i in CityLayout.GRID:
		for j in CityLayout.GRID:
			var c: Vector3 = CityLayout.cell_center(i, j)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var p: Vector3 = c + Vector3(sx * 19.9, 0.2, sz * 19.9)
					poles.append(Transform3D(Basis(), p + Vector3(0, 3.0, 0)))
					heads.append(Transform3D(Basis(), p + Vector3(0, 6.1, 0)))
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.1
	pm.height = 6.0
	_multimesh(pm, Color(0.25, 0.27, 0.3), poles)
	var hm := BoxMesh.new()
	hm.size = Vector3(0.9, 0.2, 0.45)
	_multimesh(hm, Color(1.0, 0.92, 0.65), heads, true)
	lamp_mat = _mat(Color(1.0, 0.92, 0.65), true)

# ---------- manzanas ----------
func _build_cell(i: int, j: int) -> void:
	var c: Vector3 = CityLayout.cell_center(i, j)
	var zone: int = CityLayout.zone_of(i, j)
	var slab := Color(0.62, 0.62, 0.64)
	match zone:
		CityLayout.Zone.PLAZA: slab = Color(0.3, 0.55, 0.28)
		CityLayout.Zone.POPULAR: slab = Color(0.5, 0.44, 0.38)
		CityLayout.Zone.INDUSTRIAL: slab = Color(0.5, 0.5, 0.5)
	_paving(c + Vector3(0, 0.1, 0), Vector3(CityLayout.BLOCK, 0.2, CityLayout.BLOCK), slab, zone == CityLayout.Zone.PLAZA)
	match zone:
		CityLayout.Zone.PLAZA: _build_plaza(c)
		CityLayout.Zone.CENTRO: _build_lots(c, 28.0, 68.0, CENTRO_COLORS, Color(0.2, 0.3, 0.45), 1.0)
		CityLayout.Zone.RESIDENCIAL: _build_residential(c)
		CityLayout.Zone.POPULAR: _build_popular(c)
		CityLayout.Zone.INDUSTRIAL: _build_industrial(c)

func _building(base: Vector3, size: Vector3, wall: Color, glass: Color, sign_text: String = "", out: Vector2i = Vector2i.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var sm := ShaderMaterial.new()
	sm.shader = _facade
	sm.set_shader_parameter("wall_color", wall)
	sm.set_shader_parameter("window_color", glass)
	sm.set_shader_parameter("size_y", size.y)
	sm.set_shader_parameter("seed", _rng.randf() * 10.0)
	mi.material_override = sm
	sb.add_child(mi)
	var cornice := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(size.x + 0.4, 0.35, size.z + 0.4)
	cornice.mesh = cb
	cornice.material_override = _mat(wall.lightened(0.15))
	cornice.position = Vector3(0, size.y / 2.0 - 0.15, 0)
	sb.add_child(cornice)
	sb.position = base + Vector3(0, size.y / 2.0, 0)
	_root.add_child(sb)
	if sign_text != "":
		_add_sign(sb, size, sign_text, out)
	return sb

func _add_sign(parent: Node3D, size: Vector3, text: String, out: Vector2i) -> void:
	var board := Node3D.new()
	var y: float = -size.y / 2.0 + 2.8
	if _rng.randf() < 0.5:
		board.position = Vector3(out.x * (size.x / 2.0 + 0.07), y, 0)
		board.rotation_degrees.y = 90.0 * out.x
	else:
		board.position = Vector3(0, y, out.y * (size.z / 2.0 + 0.07))
		board.rotation_degrees.y = 0.0 if out.y > 0 else 180.0
	parent.add_child(board)
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.0, 1.2, 0.12)
	bg.mesh = bm
	bg.material_override = _mat(_pick(SIGN_COLORS))
	board.add_child(bg)
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 64
	lab.pixel_size = 0.0055
	lab.position = Vector3(0, 0, 0.07)
	lab.modulate = Color(1, 1, 1)
	lab.outline_size = 4
	lab.visibility_range_end = 90.0
	board.add_child(lab)

func _build_lots(c: Vector3, h_min: float, h_max: float, colors: Array[Color], glass: Color, shop_chance: float) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var h: float = snappedf(_rng.randf_range(h_min, h_max), 3.2)
			var txt: String = _pick(SHOPS) if _rng.randf() < shop_chance else ""
			_building(c + Vector3(sx * 10.0, 0.2, sz * 10.0), Vector3(17, h, 17), _pick(colors), glass, txt, Vector2i(sx, sz))

func _build_residential(c: Vector3) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var h: float = 3.2 * _rng.randi_range(2, 4)
			var txt: String = _pick(SHOPS) if _rng.randf() < 0.4 else ""
			_building(c + Vector3(sx * 10.0, 0.2, sz * 10.0), Vector3(15, h, 15), _pick(PASTEL), Color(0.3, 0.4, 0.5), txt, Vector2i(sx, sz))
	for k in 3:
		var side: int = [-1, 1][_rng.randi() % 2]
		var along: float = _rng.randf_range(-14.0, 14.0)
		var p: Vector3 = c + (Vector3(side * 18.6, 0.2, along) if _rng.randf() < 0.5 else Vector3(along, 0.2, side * 18.6))
		_tree(p)

func _build_popular(c: Vector3) -> void:
	for a in 4:
		for b in 4:
			var p: Vector3 = c + Vector3(-12.75 + a * 8.5, 0.2, -12.75 + b * 8.5)
			var w: float = _rng.randf_range(7.0, 8.0)
			var h: float = _pick([3.5, 6.5, 6.5, 9.0])
			_building(p, Vector3(w, h, w), _pick(POPULAR_COLORS), Color(0.15, 0.2, 0.25))
			_box(p + Vector3(0, h + 0.3, 0), Vector3(w + 0.4, 0.2, w + 0.4), Color(0.45, 0.47, 0.5), false)
			if _rng.randf() < 0.4:
				var tank := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.7
				cm.bottom_radius = 0.7
				cm.height = 1.4
				tank.mesh = cm
				tank.material_override = _mat(Color(0.12, 0.2, 0.45))
				tank.position = p + Vector3(1.5, h + 1.1, 1.5)
				_root.add_child(tank)

func _build_industrial(c: Vector3) -> void:
	_box(c + Vector3(0, 4.7, -2), Vector3(32, 9, 30), Color(0.55, 0.62, 0.7))
	_box(c + Vector3(0, 9.4, -2), Vector3(33, 0.4, 31), Color(0.35, 0.38, 0.42), false)
	_box(c + Vector3(8, 7.0, -2), Vector3(1.4, 6, 1.4), Color(0.4, 0.4, 0.42))   # chimenea
	var board := _box(c + Vector3(0, 6.5, 13.1), Vector3(9, 1.4, 0.15), Color(0.1, 0.3, 0.6), false)
	var lab := Label3D.new()
	lab.text = "METALÚRGICA DEL SUR"
	lab.font_size = 64
	lab.pixel_size = 0.0075
	lab.position = Vector3(0, 0, 0.1)
	lab.visibility_range_end = 90.0
	board.add_child(lab)
	var cols: Array[Color] = [Color(0.7, 0.25, 0.2), Color(0.2, 0.4, 0.65), Color(0.25, 0.55, 0.35)]
	for k in 3:
		_box(c + Vector3(-12 + k * 12.0, 1.5, 17.0), Vector3(10, 2.6, 2.4), cols[k])

func _tree(p: Vector3) -> void:
	_box(p + Vector3(0, 1.75, 0), Vector3(0.5, 3.5, 0.5), Color(0.4, 0.28, 0.18))
	_box(p + Vector3(0, 5.0, 0), Vector3(3.6, 3.0, 3.6), Color(0.2, 0.5, 0.2), false)

func _build_plaza(c: Vector3) -> void:
	for k in 8:
		var a: float = k * TAU / 8.0
		_tree(c + Vector3(cos(a) * 14.0, 0.2, sin(a) * 14.0))
	_box(c + Vector3(0, 8.2, 0), Vector3(2.2, 16.0, 2.2), Color(0.82, 0.82, 0.8))      # monumento
	_box(c + Vector3(0, 0.7, 0), Vector3(5, 1.0, 5), Color(0.7, 0.7, 0.68))
	var bench: Node3D = _box(c + Vector3(6, 0.6, 0), Vector3(2.4, 0.8, 0.8), Color(0.45, 0.3, 0.15))
	var mate := Node3D.new()
	mate.set_script(load("res://scripts/interactable.gd"))
	mate.set("prompt", "Tomar mate")
	mate.set("action", "mate")
	bench.add_child(mate)
	var kiosk: Node3D = _box(c + Vector3(-12, 1.6, 12), Vector3(3, 3.2, 3), Color(0.85, 0.2, 0.2))
	var k := Node3D.new()
	k.set_script(load("res://scripts/interactable.gd"))
	k.set("prompt", "Comprar alfajor y Coca ($500)")
	k.set("action", "kiosco")
	k.set("price", 500)
	k.position = Vector3(0, -1.0, 2.2)
	kiosk.add_child(k)
	var lab := Label3D.new()
	lab.text = "KIOSCO"
	lab.font_size = 64
	lab.pixel_size = 0.01
	lab.position = Vector3(0, 0.9, 1.56)
	kiosk.add_child(lab)
