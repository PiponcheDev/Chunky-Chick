extends Node
class_name GameResources

var cardboard: int = 0

func add_cardboard(amount := 1):
	cardboard += amount
	print("Cardboard:", cardboard)

func spend_cardboard(amount: int) -> bool:
	if cardboard >= amount:
		cardboard -= amount
		return true
	return false
