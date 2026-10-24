extends Node3D
## Goblin Ages — first PC test scene. No external assets required.

var goblin: Node3D
var camera: Camera3D
var goblin_speed := 5.0

func _ready() -> void:
    _create_environment()
    _create_floor()
    _create_goblin()
    _create_camera()
    _create_ui()

func _create_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("182333")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b2c5cd")
    env.ambient_light_energy = 0.65
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -35, 0)
    sun.light_energy = 1.7
    add_child(sun)

func _create_floor() -> void:
    var ground := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(50, 50)
    ground.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("365447")
    ground.material_override = mat
    add_child(ground)

const GRIBNOK_MODEL := "res://assets/characters/gribnok/Gribnok_GoblinAges_sculpt_v0_2.glb"

func _create_goblin() -> void:
    goblin = Node3D.new()
    goblin.name = "Gribnok"
    add_child(goblin)
    if ResourceLoader.exists(GRIBNOK_MODEL):
        var model_scene := load(GRIBNOK_MODEL) as PackedScene
        if model_scene != null:
            var model := model_scene.instantiate() as Node3D
            if model != null:
                model.name = "GribnokModel"
                goblin.add_child(model)
                # Normalize the full imported model to 1.5 meters tall.
                var bounds := _model_bounds(model)
                if bounds.size.y > 0.001:
                    model.scale = Vector3.ONE * (1.5 / bounds.size.y)
                    model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * model.scale.x
                print("Gribnok v0.2 model loaded.")
                return
    push_warning("Gribnok GLB missing; copy it to: " + GRIBNOK_MODEL)
    _create_placeholder_goblin()

func _model_bounds(root: Node3D) -> AABB:
    var combined := AABB()
    var initialized := false
    var nodes: Array[Node] = [root]
    while not nodes.is_empty():
        var current: Node = nodes.pop_back()
        if current is MeshInstance3D:
            var mesh_node := current as MeshInstance3D
            if mesh_node.mesh != null:
                var local_aabb := mesh_node.get_aabb()
                var xform := root.global_transform.affine_inverse() * mesh_node.global_transform
                var converted := xform * local_aabb
                if initialized:
                    combined = combined.merge(converted)
                else:
                    combined = converted
                    initialized = true
        nodes.append_array(current.get_children())
    return combined

func _create_placeholder_goblin() -> void:
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.45
    capsule.height = 1.5
    body.mesh = capsule
    body.position.y = 0.75
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("79b95e")
    body.material_override = mat
    goblin.add_child(body)

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 5.5, 9.0)
    camera.current = true
    add_child(camera)
    camera.look_at(Vector3(0, 0.9, 0))

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var label := Label.new()
    label.text = "GOBLIN AGES  |  İlk PC testi  |  Hareket: W A S D / Ok tuşları"
    label.position = Vector2(24, 20)
    label.add_theme_font_size_override("font_size", 22)
    layer.add_child(label)

func _physics_process(delta: float) -> void:
    var input_dir := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        input_dir.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        input_dir.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        input_dir.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        input_dir.y += 1.0
    if input_dir.length_squared() > 0.0:
        input_dir = input_dir.normalized()
        goblin.position += Vector3(input_dir.x, 0, input_dir.y) * goblin_speed * delta
        goblin.rotation.y = atan2(-input_dir.x, -input_dir.y)
    if camera != null:
        var target := goblin.position + Vector3(0, 5.5, 9.0)
        camera.position = camera.position.lerp(target, minf(1.0, delta * 4.0))
        camera.look_at(goblin.position + Vector3(0, 0.9, 0))
