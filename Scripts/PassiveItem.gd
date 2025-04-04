extends Node

class_name PassiveItem

@export var item_name: String = "Passive Item"
@export var description: String = "A passive item"
@export var icon: Texture

func _ready():
    if not icon:
        # Create default icon
        var img = Image.new()
        img.create(64, 64, false, Image.FORMAT_RGBA8)
        img.fill(Color(0, 1, 0))
        icon = ImageTexture.create_from_image(img)

# Override in subclasses
func apply_effect(player):
    print("Applying effect of " + item_name)

# Override in subclasses if needed
func remove_effect(player):
    print("Removing effect of " + item_name)

func get_display_info() -> Dictionary:
    return {
        "name": item_name,
        "description": description,
        "icon": icon
    }