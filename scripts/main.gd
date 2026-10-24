extends Node3D
## Goblin Ages — first PC test scene. No external assets required.

var goblin: Node3D
var camera: Camera3D
var goblin_speed := 5.0
var orbit_yaw := 0.0
var orbit_pitch := 0.08
var orbit_distance := 2.8
var inspecting := false
var key_light: OmniLight3D
var fill_light: OmniLight3D

func _ready() -> void:
    _create_environment()
    _create_floor()
    _create_goblin()
    _create_camera()
    _create_character_light()
    _create_ui()

func _create_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("#528bd6")
    sky_mat.sky_horizon_color = Color("#c2dcf5")
    sky_mat.ground_bottom_color = Color("#394a42")
    sky_mat.ground_horizon_color = Color("#9db49c")
    sky.sky_material = sky_mat
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    # Consistent daylight even on the Compatibility renderer.
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#d4dff0")
    env.ambient_light_energy = 1.15
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.name = "DaylightSun"
    sun.rotation_degrees = Vector3(-50, -25, 0)
    sun.light_color = Color("#fff0d7")
    sun.light_energy = 1.8
    sun.shadow_enabled = false
    add_child(sun)

func _create_floor() -> void:
    var ground := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(50, 50)
    ground.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#456853")
    ground.material_override = mat
    add_child(ground)

const GRIBNOK_MODEL := "res://assets/characters/gribnok/Gribnok_Final.glb"
const GRIBNOK_OLD_MODEL := "res://assets/characters/gribnok/Gribnok_GoblinAges_sculpt_v0_2.glb"

func _create_goblin() -> void:
    goblin = Node3D.new()
    goblin.name = "Gribnok"
    add_child(goblin)
    var selected_path := GRIBNOK_MODEL if ResourceLoader.exists(GRIBNOK_MODEL) else GRIBNOK_OLD_MODEL
    if ResourceLoader.exists(selected_path):
        var model_scene := load(selected_path) as PackedScene
        if model_scene != null:
            var model := model_scene.instantiate() as Node3D
            if model != null:
                model.name = "GribnokModel"
                goblin.add_child(model)
                var bounds := _model_bounds(model)
                if bounds.size.y > 0.001:
                    var factor := 1.5 / bounds.size.y
                    model.scale = Vector3.ONE * factor
                    model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
                if selected_path == GRIBNOK_OLD_MODEL:
                    _fix_gribnok_materials(model)
                    push_warning("Old Gribnok v0.2 active. Place new GLB at " + GRIBNOK_MODEL)
                else:
                    print("Gribnok detailed textured GLB loaded: ", selected_path)
                return
    push_warning("No Gribnok GLB found. Expected " + GRIBNOK_MODEL)
    _create_placeholder_goblin()

# The v0.2 GLB stores its part colors in vertex attributes, with no PBR materials.
# Godot's default importer shows these unlit/white on some rendering paths.
# Create a distinct StandardMaterial3D for each mesh using its vertex color.
func _fix_gribnok_materials(root: Node3D) -> void:
    var queue: Array[Node] = [root]
    var colored := 0
    while not queue.is_empty():
        var item: Node = queue.pop_back()
        queue.append_array(item.get_children())
        if not item is MeshInstance3D:
            continue
        var mesh_node := item as MeshInstance3D
        if mesh_node.mesh == null:
            continue
        var color := _fallback_part_color(mesh_node.name)
        if mesh_node.mesh.get_surface_count() > 0:
            var arrays := mesh_node.mesh.surface_get_arrays(0)
            if arrays.size() > Mesh.ARRAY_COLOR and arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
                var vertex_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
                if not vertex_colors.is_empty():
                    color = vertex_colors[0]
        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.roughness = 0.88
        if "metal" in mesh_node.name or "buckle" in mesh_node.name or "rivet" in mesh_node.name or "ring" in mesh_node.name:
            material.metallic = 0.35
        material.vertex_color_use_as_albedo = false
        mesh_node.material_override = material
        colored += 1
    print("Gribnok materials applied to ", colored, " mesh parts.")

func _fallback_part_color(part: String) -> Color:
    var n := part.to_lower()
    if "eye_socket" in n or "chin" in n or "brow_ridge" in n or "jaw_" in n or "nostril" in n or "under_eye" in n or "upper_lid" in n:
        return Color("#657f2d")
    if "eye_" in n:
        return Color("#f6d35c")
    if "pupil" in n or "mouth_dark" in n:
        return Color("#171617")
    if "nose" in n or "cheek" in n or "knuckle" in n or "ear_lobe" in n:
        return Color("#a1ba53")
    if "inner_ear" in n:
        return Color("#bd7862")
    if "tusk" in n:
        return Color("#e4d4a3")
    if "hair" in n or "brow_" in n:
        return Color("#201b1b")
    if "boot_toecap" in n or "iron_rim" in n:
        return Color("#4e514c")
    if "boot_buckle" in n or "belt_buckle" in n or "ear_ring" in n or "rivet" in n or "amulet" in n:
        return Color("#a77b43")
    if "boot" in n:
        return Color("#403028")
    if "scarf" in n or "tabard" in n:
        return Color("#a02f26")
    if "pants" in n or "shin" in n:
        return Color("#302b2b")
    if "tunic" in n or "wrap_" in n or "bandage" in n:
        return Color("#c2ae86")
    if "vest" in n or "leather" in n or "pouch" in n or "satchel" in n or "belt" in n:
        return Color("#754a32")
    return Color("#87a93e")

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
    camera.current = true
    camera.fov = 55.0
    add_child(camera)
    _update_camera(1.0)

func _create_character_light() -> void:
    key_light = OmniLight3D.new()
    key_light.name = "GribnokWarmKey"
    key_light.light_color = Color("#ffead5")
    key_light.light_energy = 1.6
    key_light.omni_range = 4.5
    key_light.shadow_enabled = false
    add_child(key_light)

    fill_light = OmniLight3D.new()
    fill_light.name = "CameraFacingSoftFill"
    fill_light.light_color = Color("#f3f6ff")
    fill_light.light_energy = 2.0
    fill_light.omni_range = 4.2
    fill_light.shadow_enabled = false
    add_child(fill_light)

func _update_camera(delta: float) -> void:
    if camera == null or goblin == null:
        return
    var focus := goblin.global_position + Vector3(0, 0.85, 0)
    var horizontal := orbit_distance * cos(orbit_pitch)
    var offset := Vector3(sin(orbit_yaw) * horizontal, sin(orbit_pitch) * orbit_distance + 0.15, cos(orbit_yaw) * horizontal)
    camera.global_position = camera.global_position.lerp(focus + offset, minf(1.0, delta * 8.0))
    camera.look_at(focus)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            inspecting = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            orbit_distance = maxf(1.4, orbit_distance - 0.25)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            orbit_distance = minf(7.0, orbit_distance + 0.25)
    elif event is InputEventMouseMotion and inspecting:
        orbit_yaw -= event.relative.x * 0.007
        orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.005, -0.35, 0.95)

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var label := Label.new()
    label.text = "GOBLIN AGES  |  GRIBNOK GUN ISIGI v0.4  |  WASD hareket  |  Sag tik + fare: dondur  |  Tekerlek: yakinlas"
    label.position = Vector2(24, 20)
    label.add_theme_font_size_override("font_size", 19)
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
    _update_camera(delta)
    if camera != null and goblin != null:
        var focus := goblin.global_position + Vector3(0, 0.95, 0)
        var toward_camera := (camera.global_position - focus).normalized()
        if key_light != null:
            key_light.global_position = focus + toward_camera * 1.8 + Vector3(-0.8, 0.65, 0)
        if fill_light != null:
            fill_light.global_position = focus + toward_camera * 1.55 + camera.global_transform.basis.x * 0.7 + Vector3(0, 0.2, 0)
