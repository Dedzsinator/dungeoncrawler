extends Area3D

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        get_tree().paused = true
        GameManager.shopping = true
        
        # Try multiple possible paths to find the Shop node
        var shop_node = null
        
        # Common possible paths for the Shop UI
        var possible_paths = [
            "../../GUI/Shop", # Original path
            "../../../GUI/Shop", # One level up
            "/root/GUI/Shop", # From root
            "/root/Main/GUI/Shop", # Main scene with GUI
            "/root/ProceduralLevel/GUI/Shop", # Procedural level with GUI
            "../../../../GUI/Shop", # Two levels up
            get_tree().get_first_node_in_group("shop") # Find by group
        ]
        
        # Try each path until we find the shop
        for path in possible_paths:
            if path is Node: # If it's already a node (from group search)
                shop_node = path
                break
            elif has_node(path):
                shop_node = get_node(path)
                break
        
        # If we still can't find it, search the entire scene tree
        if shop_node == null:
            shop_node = find_shop_in_tree(get_tree().root)
        
        if shop_node:
            shop_node.show()
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            print("Shop opened successfully")
        else:
            print("Error: Could not find Shop node in scene tree")
            print("Current scene structure around mage:")
            print_scene_structure(self, 3)

# Helper function to recursively search for the shop node
func find_shop_in_tree(node: Node) -> Node:
    if node.name == "Shop":
        return node
    
    for child in node.get_children():
        var result = find_shop_in_tree(child)
        if result:
            return result
    
    return null

# Debug function to print scene structure
func print_scene_structure(node: Node, depth: int = 2, current_depth: int = 0) -> void:
    if current_depth > depth:
        return
    
    var indent = "  ".repeat(current_depth)
    print(indent + node.name + " (" + node.get_class() + ")")
    
    for child in node.get_children():
        print_scene_structure(child, depth, current_depth + 1)