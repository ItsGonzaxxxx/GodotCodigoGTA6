extends Node3D
## Objeto interactuable genérico. `action` define qué hace.

@export var prompt: String = "Interactuar"
@export var action: String = ""
@export var price: int = 0

func _ready() -> void:
	add_to_group("interactable")

func interact(player: Node) -> void:
	match action:
		"kiosco":
			if player.add_money(-price):
				player.message.emit("Compraste un alfajor y una Coca por $%d. ¡Qué rico!" % price)
			else:
				player.message.emit("No te alcanza la plata para el kiosco.")
		"mate":
			player.message.emit("Te sentás en el banco y te tomás unos mates. Tranquilidad total.")
		_:
			player.message.emit("No pasa nada.")
