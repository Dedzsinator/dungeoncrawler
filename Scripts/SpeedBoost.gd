extends PassiveItem

@export var speed_increase: float = 1.5

func _ready():
    super._ready()
    item_name = "Speed Boost"
    description = "Increases movement speed by " + str(speed_increase)

func apply_effect(player):
    player.speed += speed_increase
    print("Applied speed boost: +" + str(speed_increase))

func remove_effect(player):
    player.speed -= speed_increase
    print("Removed speed boost")