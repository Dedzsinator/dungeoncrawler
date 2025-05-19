extends Node3D

@export var reflection_probe: ReflectionProbe
@export var update_interval: float = 5.0
@export var enable_realtime_reflections: bool = true

var timer: float = 0.0

func _ready():
    if reflection_probe == null:
        print("Warning: No reflection probe assigned to RTXReflectionManager")
        return
        
    # Configure the reflection probe for quality reflections
    reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
    reflection_probe.interior = true
    reflection_probe.max_distance = 50.0
    reflection_probe.origin_offset = Vector3(0, 0, 0)
    reflection_probe.enable_shadows = true

func _process(delta):
    if not enable_realtime_reflections or reflection_probe == null:
        return
        
    timer += delta
    if timer >= update_interval:
        reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
        timer = 0.0