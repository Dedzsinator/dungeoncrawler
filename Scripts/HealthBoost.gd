extends PassiveItem

@export var health_increase: float = 20.0

func _ready():
    super._ready()
    item_name = "Health Boost"
    description = "Increases maximum health by " + str(health_increase)

func apply_effect(player):
    if player.has_method("change_max_health"):
        player.change_max_health(health_increase)
        print("Applied health boost: +" + str(health_increase))

func remove_effect(player):
    if player.has_method("change_max_health"):
        player.change_max_health(-health_increase)
        print("Removed health boost")