extends Area3D

## Respawns players who fall into the void.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var player := body as PlayerController
		var minigame := _find_minigame()
		if minigame:
			minigame.respawn_player(player)


func _find_minigame() -> MinigameBase:
	var node: Node = self
	while node:
		if node is MinigameBase:
			return node as MinigameBase
		node = node.get_parent()
	return null
