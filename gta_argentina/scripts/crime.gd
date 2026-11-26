class_name Crime
extends Node
## Delito ficticio como mecánica de juego: chorros que roban al jugador (y huyen), arrebato del jugador,
## testigos, nivel de búsqueda (0–3 estrellas), policías que persiguen y arresto con fianza.

signal wanted_changed(level: int)
signal notify(text: String, color: Color)
signal banner(text: String, color: Color)

var player: CharacterBody3D
var crowd: Node3D
var wanted: int = 0
var spawn_point: Vector3 = Vector3(8.0, 1.0, 20.0)
var _since_crime: float = 999.0
var _far_t: float = 0.0
var _snatch_cd: float = 0.0

func can_be_robbed() -> bool:
	return player.get("vehicle") == null and int(player.get("money")) >= 300

func rob_player(thief: Pedestrian) -> int:
	var money: int = player.money
	var amt: int = mini(money, clampi(int(money * 0.15), 300, 1200))
	player.add_money(-amt)
	player.message.emit("Desconocido: ¡Dame todo y no te pasa nada!")
	banner.emit("¡TE CHOREARON!", Color(1.0, 0.45, 0.35))
	notify.emit("Un chorro te sacó $%d. ¡Corrélo y agarralo con E!" % amt, Color(1.0, 0.6, 0.5))
	return amt

func recover(thief: Pedestrian) -> void:
	player.add_money(thief.loot)
	player.message.emit("Vos: ¡Devolveme la plata!")
	notify.emit("Recuperaste $%d" % thief.loot, Color(0.6, 1.0, 0.6))

func thief_escaped(thief: Pedestrian) -> void:
	if thief.loot > 0:
		notify.emit("El chorro se escapó con $%d" % thief.loot, Color(1.0, 0.6, 0.5))

func _nearest_police(pos: Vector3) -> float:
	var best: float = 1e9
	for n in get_tree().get_nodes_in_group("pedestrian"):
		var p: Pedestrian = n
		if p.npc_type == "policia":
			best = minf(best, p.global_position.distance_to(pos))
	return best

func try_snatch() -> void:
	if player.get("vehicle") != null or _snatch_cd > 0.0:
		return
	var victim: Pedestrian = null
	var best: float = 2.4
	for n in get_tree().get_nodes_in_group("pedestrian"):
		var p: Pedestrian = n
		if p.is_civil() and p.mode == "walk":
			var d: float = p.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				victim = p
	if victim == null:
		player.message.emit("Vos: Acá no hay nadie a quien arrebatarle nada.")
		return
	_snatch_cd = 1.5
	var amt: int = randi_range(80, 420)
	player.add_money(amt)
	victim.scare()
	player.message.emit("Vos: Dame la plata, rápido.")
	report_crime(player.global_position)

## Un delito: testigos cercanos o policía a la vista elevan el nivel de búsqueda.
func report_crime(pos: Vector3) -> void:
	_since_crime = 0.0
	var witness: bool = false
	for n in get_tree().get_nodes_in_group("pedestrian"):
		var p: Pedestrian = n
		if p.global_position.distance_to(pos) < 15.0 and p.npc_type != "chorro":
			witness = true
			if p.is_civil():
				p.scare()
	var cop: float = _nearest_police(pos)
	if cop < 40.0:
		set_wanted(wanted + 1)
		notify.emit("¡La policía te vio!", Color(0.6, 0.75, 1.0))
	elif witness and wanted == 0:
		set_wanted(1)
		notify.emit("Alguien llamó a la policía", Color(0.6, 0.75, 1.0))

func set_wanted(level: int) -> void:
	var lv: int = clampi(level, 0, 3)
	if lv == wanted:
		return
	var up: bool = lv > wanted
	wanted = lv
	_far_t = 0.0
	wanted_changed.emit(wanted)
	if up and crowd != null:
		for i in 2:
			crowd.call("spawn_police", player.global_position)

func arrest() -> void:
	if wanted == 0:
		return
	var fine: int = mini(player.money, mini(1500, int(player.money * 0.2)))
	player.add_money(-fine)
	set_wanted(0)
	player.call("teleport_to", spawn_point)
	banner.emit("DETENIDO", Color(0.55, 0.75, 1.0))
	player.message.emit("Policía: Quedás detenido. Pagaste $%d de fianza." % fine)

func _process(delta: float) -> void:
	_snatch_cd = maxf(0.0, _snatch_cd - delta)
	_since_crime += delta
	if wanted == 0:
		return
	var cop: float = _nearest_police(player.global_position)
	if cop > 45.0:
		_far_t += delta
	else:
		_far_t = 0.0
	if _far_t > 8.0 or _since_crime > 50.0:
		_far_t = 0.0
		_since_crime = 0.0
		set_wanted(wanted - 1)
		notify.emit("Despistaste a la policía" if wanted == 0 else "Bajó el nivel de búsqueda", Color(0.7, 1.0, 0.7))
