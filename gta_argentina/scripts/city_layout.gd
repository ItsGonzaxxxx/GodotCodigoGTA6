class_name CityLayout
extends RefCounted
## Geometría y grafos de la ciudad (compartidos por mapa, peatones y tráfico).

const BLOCK := 40.0
const STREET := 12.0
const GRID := 6
const STEP := 52.0            # BLOCK + STREET
const WALK := 19.5            # distancia del centro de la manzana a la vereda caminable
const LANE := 3.0
const PLAZA := Vector2i(3, 3)

enum Zone { PLAZA, CENTRO, RESIDENCIAL, POPULAR, INDUSTRIAL }

static func cell_center(i: int, j: int) -> Vector3:
	return Vector3((i - GRID / 2.0 + 0.5) * STEP, 0.0, (j - GRID / 2.0 + 0.5) * STEP)

static func street_coord(k: int) -> float:
	return (k - GRID / 2.0) * STEP

static func zone_of(i: int, j: int) -> int:
	if Vector2i(i, j) == PLAZA:
		return Zone.PLAZA
	if i >= 2 and i <= 4 and j >= 2 and j <= 4:
		return Zone.CENTRO
	if i >= 4 and j <= 1:
		return Zone.INDUSTRIAL
	if i <= 1 and j >= 4:
		return Zone.POPULAR
	return Zone.RESIDENCIAL

# --- Grafo peatonal: 4 esquinas por manzana; aristas por vereda y por cruce de calle ---
static func ped_id(i: int, j: int, cx: int, cz: int) -> int:
	return (i * GRID + j) * 4 + (2 if cx > 0 else 0) + (1 if cz > 0 else 0)

static func ped_cell(id: int) -> Vector2i:
	var cell: int = id / 4
	return Vector2i(cell / GRID, cell % GRID)

static func build_ped_graph() -> Dictionary:
	var pos := PackedVector3Array()
	var nbr: Array = []
	pos.resize(GRID * GRID * 4)
	nbr.resize(GRID * GRID * 4)
	for i in GRID:
		for j in GRID:
			for cx in [-1, 1]:
				for cz in [-1, 1]:
					var id: int = ped_id(i, j, cx, cz)
					pos[id] = cell_center(i, j) + Vector3(cx * WALK, 0.2, cz * WALK)
					var n := PackedInt32Array()
					n.append(ped_id(i, j, -cx, cz))
					n.append(ped_id(i, j, cx, -cz))
					if i + cx >= 0 and i + cx < GRID:
						n.append(ped_id(i + cx, j, -cx, cz))
					if j + cz >= 0 and j + cz < GRID:
						n.append(ped_id(i, j + cz, cx, -cz))
					nbr[id] = n
	return {"pos": pos, "nbr": nbr}

# --- Grafo de tráfico: intersecciones (GRID+1)^2 ---
static func traffic_id(a: int, b: int) -> int:
	return a * (GRID + 1) + b

static func build_traffic_graph() -> Dictionary:
	var pos := PackedVector3Array()
	var nbr: Array = []
	pos.resize((GRID + 1) * (GRID + 1))
	nbr.resize((GRID + 1) * (GRID + 1))
	for a in GRID + 1:
		for b in GRID + 1:
			var id: int = traffic_id(a, b)
			pos[id] = Vector3(street_coord(a), 0.0, street_coord(b))
			var n := PackedInt32Array()
			if a > 0: n.append(traffic_id(a - 1, b))
			if a < GRID: n.append(traffic_id(a + 1, b))
			if b > 0: n.append(traffic_id(a, b - 1))
			if b < GRID: n.append(traffic_id(a, b + 1))
			nbr[id] = n
	return {"pos": pos, "nbr": nbr}

## Altura del suelo en (x, z): 0.2 sobre veredas/manzanas, 0 sobre la calle.
static func ground_height(x: float, z: float) -> float:
	var gx: float = x / STEP + GRID / 2.0
	var gz: float = z / STEP + GRID / 2.0
	var i: int = floori(gx)
	var j: int = floori(gz)
	if i < 0 or i >= GRID or j < 0 or j >= GRID:
		return 0.0
	var lx: float = (gx - i - 0.5) * STEP
	var lz: float = (gz - j - 0.5) * STEP
	if absf(lx) <= BLOCK / 2.0 and absf(lz) <= BLOCK / 2.0:
		return 0.2
	return 0.0
