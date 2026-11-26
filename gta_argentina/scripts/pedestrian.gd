class_name Pedestrian
extends Node3D
## Peatón con rutina y comportamientos: walk (caminar/charlar), stalk (el chorro acecha al jugador),
## flee (el chorro huye con la plata), scared (civil asustado), pursue (policía persigue), caught.

const LINES := {
	"vecino": ["¿Qué hacés? Qué lindo día para unos mates.", "Mirá cómo está el tránsito hoy, una locura.", "Cuidá la plata, che, que anda gente rara."],
	"trabajador": ["Hay que laburar, no queda otra.", "Salí del turno hace nada y ya estoy cansado.", "Si buscás changas, preguntá en el taller."],
	"comerciante": ["Pasá nomás, tenemos de todo.", "Hoy el negocio anda tranquilo.", "Llevate algo, que está fresco."],
	"policia": ["Circulá tranquilo, amigo.", "Todo en orden por acá. Que tengas buen día.", "Si ves algo raro, avisá."],
	"hincha": ["Este domingo vamos a la cancha, no me lo pierdo.", "¡Vamos que este año sale campeón!", "El que no salta es del otro equipo."],
	"estudiante": ["Tengo parcial mañana y no estudié nada.", "Voy llegando tarde a cursar.", "¿Sabés a qué hora pasa el colectivo?"],
	"chorro": ["¿Qué mirás? Seguí tu camino.", "No tengo nada que hablar con vos.", "Dejame tranquilo, ¿querés?"],
}
const SPEAKERS := {"vecino": "Vecino", "trabajador": "Obrero", "comerciante": "Comerciante",
	"policia": "Policía", "hincha": "Hincha", "estudiante": "Estudiante", "chorro": "Desconocido"}
const SCARED_LINES := ["¡Auxilio, me robaron!", "¡Llamen a la policía!", "¡Ladrón, ladrón!", "¡Ay, qué susto!"]

var prompt: String = "Hablar"
var npc_type: String = "vecino"
var gpos: PackedVector3Array
var gnbr: Array
var cur: int = 0
var prev: int = -1
var tgt: int = 0
var speed: float = 1.3
var idle_left: float = 0.0
var player: Node3D
var crime: Crime
var mode: String = "walk"
var mode_t: float = 0.0
var loot: int = 0
var temp: bool = false
var cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()
var _visual: Humanoid

func setup(type: String, positions: PackedVector3Array, nbrs: Array, start_id: int, seed_val: int, player_ref: Node3D, crime_ref: Crime) -> void:
	npc_type = type
	gpos = positions
	gnbr = nbrs
	player = player_ref
	crime = crime_ref
	_rng.seed = seed_val
	speed = _rng.randf_range(1.1, 1.6)
	cur = start_id
	position = gpos[cur]
	tgt = _pick_next()
	_set_prompt()
	add_to_group("interactable")
	add_to_group("pedestrian")
	_build_visual()

func is_civil() -> bool:
	return npc_type != "policia" and npc_type != "chorro"

func _set_prompt() -> void:
	if mode == "flee" and npc_type == "chorro":
		prompt = "Agarrar al chorro"
	else:
		prompt = "Hablar con " + SPEAKERS[npc_type].to_lower()

func _build_visual() -> void:
	var h := Humanoid.new()
	add_child(h)
	_visual = h
	var skins: Array[Color] = [Color(0.95, 0.78, 0.62), Color(0.8, 0.6, 0.45), Color(0.6, 0.42, 0.3)]
	var hairs: Array[Color] = [Color(0.08, 0.06, 0.05), Color(0.25, 0.15, 0.08), Color(0.45, 0.3, 0.15), Color(0.55, 0.55, 0.55)]
	var o := {"detail": false, "vis_end": 90.0, "skin": skins[_rng.randi() % 3], "hair": hairs[_rng.randi() % 4],
		"hair_style": ["short", "short", "long"][_rng.randi() % 3], "shirt": Color.from_hsv(_rng.randf(), 0.45, 0.8),
		"pants": [Color(0.18, 0.2, 0.3), Color(0.25, 0.22, 0.2), Color(0.1, 0.1, 0.12)][_rng.randi() % 3], "extras": []}
	match npc_type:
		"trabajador":
			o["shirt"] = Color(0.9, 0.5, 0.1)
			o["pants"] = Color(0.2, 0.25, 0.4)
			o["extras"] = ["helmet", "vest"]
		"policia":
			o["shirt"] = Color(0.1, 0.15, 0.35)
			o["pants"] = Color(0.08, 0.1, 0.2)
			o["long_sleeves"] = true
			o["hair_style"] = "short"
			o["extras"] = ["cap", "belt"]
		"hincha":
			o["shirt"] = Color(0.1, 0.6, 0.25)
			o["extras"] = ["stripes", "scarf"]
		"comerciante":
			o["shirt"] = Color(0.85, 0.85, 0.85)
			o["extras"] = ["apron"]
		"estudiante":
			o["extras"] = ["backpack"]
		"chorro":
			o["shirt"] = Color(0.2, 0.2, 0.22)
			o["pants"] = Color(0.06, 0.06, 0.07)
			o["long_sleeves"] = true
			o["extras"] = ["hood"]
	h.build(o)
	var sc: float = _rng.randf_range(0.93, 1.05)
	h.scale = Vector3(sc, sc, sc)

# ---------- grafo ----------
func _pick_next() -> int:
	var cands: Array[int] = []
	for n in gnbr[cur]:
		if n != prev:
			cands.append(n)
	if cands.is_empty():
		return prev
	return cands[_rng.randi() % cands.size()]

func _choose_next() -> int:
	if mode == "walk" or mode == "caught":
		return _pick_next()
	var cands: Array[int] = []
	for n in gnbr[cur]:
		if n != prev:
			cands.append(n)
	if cands.is_empty():
		return prev
	var toward: bool = mode == "pursue" or mode == "stalk"
	var best: int = cands[0]
	var best_d: float = gpos[best].distance_to(player.global_position)
	for n in cands:
		var d: float = gpos[n].distance_to(player.global_position)
		if (toward and d < best_d) or (not toward and d > best_d):
			best = n
			best_d = d
	return best

func _nearest_node() -> int:
	var best: int = 0
	var best_d: float = 1e9
	for i in gpos.size():
		var d: float = gpos[i].distance_squared_to(position)
		if d < best_d:
			best_d = d
			best = i
	return best

func _set_mode(m: String) -> void:
	mode = m
	mode_t = 0.0
	idle_left = 0.0
	_set_prompt()

func _end_mode() -> void:
	_set_mode("walk")
	cur = _nearest_node()
	prev = -1
	tgt = _pick_next()

func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var want: float = atan2(-dir.x, -dir.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, want, clampf(8.0 * delta, 0.0, 1.0))

func _advance(delta: float, spd: float, near: bool) -> void:
	var dir: Vector3 = gpos[tgt] - position
	dir.y = 0.0
	if dir.length() < 0.2:
		prev = cur
		cur = tgt
		tgt = _choose_next()
		return
	dir = dir.normalized()
	position += dir * spd * delta
	position.y = 0.2
	_face(dir, delta)
	if near:
		_visual.animate(delta, spd, "ground")

func _direct(delta: float, point: Vector3, spd: float, near: bool, away: bool = false) -> void:
	var dir: Vector3 = point - global_position
	dir.y = 0.0
	if away:
		dir = -dir
	if dir.length() > 0.01:
		dir = dir.normalized()
		position += dir * spd * delta
		position.y = 0.2
		_face(dir, delta)
	if near:
		_visual.animate(delta, spd, "ground")

# ---------- ciclo ----------
func _process(delta: float) -> void:
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var d: float = to_player.length()
	var near: bool = d < 90.0
	_visual.visible = near
	cooldown = maxf(0.0, cooldown - delta)
	mode_t += delta
	match mode:
		"walk": _walk(delta, d, to_player, near)
		"stalk": _stalk(delta, d, near)
		"flee": _flee(delta, d, near)
		"scared": _scared(delta, near)
		"pursue": _pursue(delta, d, near)
		"caught":
			if near:
				_visual.animate(delta, 0.0, "crouch")
			if mode_t > 4.0:
				queue_free()

func _walk(delta: float, d: float, to_player: Vector3, near: bool) -> void:
	if temp and crime.wanted == 0 and d > 50.0:
		queue_free()
		return
	if npc_type == "chorro" and cooldown <= 0.0 and d < 16.0 and crime.can_be_robbed():
		_set_mode("stalk")
		return
	if npc_type == "policia" and crime.wanted > 0 and d < 80.0:
		_set_mode("pursue")
		return
	if d < 2.2 and idle_left < 1.0 and npc_type != "chorro":
		idle_left = 1.5
	if idle_left > 0.0:
		idle_left -= delta
		if d < 6.0:
			_face(to_player, delta)
		position.y = 0.2
		if near:
			_visual.animate(delta, 0.0, "ground")
		return
	var dir: Vector3 = gpos[tgt] - position
	dir.y = 0.0
	if dir.length() < 0.2:
		prev = cur
		cur = tgt
		tgt = _choose_next()
		if _rng.randf() < 0.2:
			idle_left = _rng.randf_range(2.0, 6.0)
		return
	_advance(delta, speed, near)

func _stalk(delta: float, d: float, near: bool) -> void:
	if not crime.can_be_robbed() or d > 28.0 or mode_t > 25.0:
		cooldown = 12.0
		_end_mode()
		return
	if d < 1.5:
		loot = crime.rob_player(self)
		_set_mode("flee")
		return
	if d < 12.0:
		_direct(delta, player.global_position, 3.4, near)
	else:
		_advance(delta, 3.2, near)

func _flee(delta: float, d: float, near: bool) -> void:
	if d > 75.0 or mode_t > 45.0:
		crime.thief_escaped(self)
		queue_free()
		return
	if d < 7.0 and mode_t > 0.5 and false:
		pass
	_advance(delta, 5.2, near)

func _scared(delta: float, near: bool) -> void:
	if mode_t > 7.0:
		_end_mode()
		return
	_advance(delta, 4.5, near)

func _pursue(delta: float, d: float, near: bool) -> void:
	if crime.wanted == 0 or d > 100.0:
		_end_mode()
		return
	var on_foot: bool = player.get("vehicle") == null
	if d < 1.7 and on_foot:
		crime.arrest()
		return
	if d < 14.0:
		_direct(delta, player.global_position, 5.8, near)
	else:
		_advance(delta, 5.8, near)

# ---------- acciones ----------
func scare() -> void:
	if mode == "walk":
		_set_mode("scared")
		if player.global_position.distance_to(global_position) < 30.0:
			player.message.emit("%s: %s" % [SPEAKERS[npc_type], SCARED_LINES[_rng.randi() % SCARED_LINES.size()]])

func interact(pl: Node) -> void:
	if mode == "flee" and npc_type == "chorro":
		crime.recover(self)
		loot = 0
		_set_mode("caught")
		return
	var lines: Array = LINES[npc_type]
	pl.message.emit("%s: %s" % [SPEAKERS[npc_type], lines[_rng.randi() % lines.size()]])
	idle_left = 4.0
