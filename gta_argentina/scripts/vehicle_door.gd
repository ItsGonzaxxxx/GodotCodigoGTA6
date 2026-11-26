class_name VehicleDoor
extends Node3D
## Punto de interacción para subir a un vehículo (lado del conductor).

var vehicle: Node
var prompt: String = "Subir"

func _ready() -> void:
	add_to_group("interactable")

func interact(player: Node) -> void:
	if vehicle.get("driver") == null:
		player.call("enter_vehicle", vehicle)
	else:
		player.message.emit("Ya hay alguien conduciendo.")
