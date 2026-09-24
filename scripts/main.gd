extends Node3D

var wagon: CharacterBody3D
var wagon_speed := 0.0
var gear := 1
const GEAR_MAX_SPEED := [0.0, 7.0, 12.0, 18.0, 25.0, 34.0]
const GEAR_ENGINE_FORCE := [0.0, 13.0, 12.0, 11.0, 9.0, 7.0]
var aircrafts: Array[Node3D] = []
var bullets: Array[Node3D] = []
var rng := RandomNumberGenerator.new()

func material(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    return m

func box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var b := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    b.mesh = mesh
    b.position = pos
    b.material_override = material(color)
    parent.add_child(b)
    return b

func make_tree(parent: Node, pos: Vector3) -> void:
    var t := Node3D.new()
    t.position = pos
    parent.add_child(t)
    box(t, Vector3(0,1.1,0), Vector3(.45,2.2,.45), Color("#5b4636"))
    var crown := MeshInstance3D.new()
    var cm := SphereMesh.new()
    cm.radius = 1.1
    cm.height = 2.1
    crown.mesh = cm
    crown.position = Vector3(0,2.5,0)
    crown.material_override = material(Color("#24452e"))
    t.add_child(crown)

func make_aircraft(pos: Vector3) -> void:
    var a := Node3D.new()
    a.position = pos
    add_child(a)
    box(a, Vector3(0,0,0), Vector3(3.4,.65,1.0), Color("#3b4b39"))
    box(a, Vector3(0,0,-1.25), Vector3(.45,.2,2.6), Color("#4d5c45"))
    box(a, Vector3(0,0,1.25), Vector3(.45,.2,2.6), Color("#4d5c45"))
    box(a, Vector3(0,.1,1.65), Vector3(.5,.35,.6), Color("#1e261d"))
    aircrafts.append(a)

func _ready() -> void:
    rng.randomize()

    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("#9fb5c8")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("#b9c9d4")
    e.ambient_light_energy = 0.8
    env.environment = e
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-25,0)
    sun.light_energy = 1.2
    add_child(sun)

    # snowy ground
    box(self, Vector3(0,-.35,0), Vector3(180,.7,180), Color("#d8d2bd"))

    # snowy mountain masses
    for p in [Vector3(-55,15,-25), Vector3(50,20,-35), Vector3(-45,11,50), Vector3(55,14,45)]:
        var m := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 18
        sm.height = 32
        m.mesh = sm
        m.position = p
        m.scale = Vector3(1.6,1,1.3)
        m.material_override = material(Color("#eef3f5"))
        add_child(m)

    # two village roads
    box(self, Vector3(0,0,-7), Vector3(150,.12,7), Color("#3e4245"))
    box(self, Vector3(0,.01,10), Vector3(150,.1,5), Color("#8b6748"))

    # village houses
    for p in [Vector3(-28,2,-17),Vector3(-10,2,-18),Vector3(16,2,-18),Vector3(35,2,-17),
              Vector3(-25,2,20),Vector3(5,2,20),Vector3(28,2,20)]:
        var h := Node3D.new()
        h.position = p
        add_child(h)
        box(h,Vector3(0,2,0),Vector3(7,4.2,6),Color("#b9a98d"))
        box(h,Vector3(0,4.8,0),Vector3(7.5,1.5,6.5),Color("#54483e"))

    for i in range(22):
        make_tree(self, Vector3(rng.randf_range(-65,65),0,rng.randf_range(-55,55)))

    # controllable wagon
    wagon = CharacterBody3D.new()
    wagon.position = Vector3(-50,1,-7)
    add_child(wagon)
    box(wagon,Vector3(0,0,0),Vector3(4,1.2,2),Color("#4a4d48"))
    box(wagon,Vector3(0,.9,0),Vector3(2.7,.8,1.6),Color("#6b6e67"))

    for x in [-1.35,1.35]:
        var wheel := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = .55
        cm.bottom_radius = .55
        cm.height = .35
        wheel.mesh = cm
        wheel.rotation_degrees = Vector3(90,0,0)
        wheel.position = Vector3(x,-.5,0)
        wheel.material_override = material(Color("#252525"))
        wagon.add_child(wheel)

    # hostile aircraft overhead
    make_aircraft(Vector3(-20,28,-2))
    make_aircraft(Vector3(15,34,-2))
    make_aircraft(Vector3(45,30,-2))

    var cam := Camera3D.new()
    cam.position = Vector3(-48,20,28)
    cam.look_at_from_position(cam.position,wagon.position)
    add_child(cam)
    cam.current = true

    var label := Label.new()
    label.text = "واگن | W/S گاز/ترمز | A/D گردش | دنده 1-5 با کلیدهای 1 تا 5 | دنده: " + str(gear)
    label.position = Vector2(25,25)
    label.add_theme_font_size_override("font_size",22)
    add_child(label)

func _physics_process(delta: float) -> void:
    if wagon == null:
        return

    # ۵ دنده واقعیِ آزمایشی: سرعت فقط از میزان گاز + دنده تعیین می‌شود.
    # نگه داشتن گاز به خودی خود سرعت را بی‌نهایت زیاد نمی‌کند؛
    # هر دنده سقف سرعت مشخص دارد.
    for g in range(1, 6):
        if Input.is_key_pressed(KEY_1 + g - 1):
            gear = g

    var throttle := Input.get_axis("back","forward")
    var max_speed := GEAR_MAX_SPEED[gear]
    var engine_force := GEAR_ENGINE_FORCE[gear]

    if throttle > 0.0:
        var target_speed := max_speed * throttle
        wagon_speed = move_toward(wagon_speed, target_speed, engine_force * delta)
    elif throttle < 0.0:
        # ترمز/حرکت معکوس با سرعت محدود
        wagon_speed = move_toward(wagon_speed, -max_speed * 0.35, engine_force * 0.8 * delta)
    else:
        # بدون گاز، افزایش سرعت نداریم؛ فقط مقاومت خودرو سرعت را کم می‌کند.
        wagon_speed = move_toward(wagon_speed, 0.0, 3.0 * delta)

    wagon.rotate_y(Input.get_axis("left","right")*1.2*delta)
    wagon.velocity = wagon.transform.basis.z * -wagon_speed
    wagon.move_and_slide()

    # aircraft continuously follow the wagon from above
    var ui := get_node_or_null("Label")
    if ui:
        ui.text = "واگن | W/S گاز/ترمز | A/D گردش | دنده 1-5 | دنده فعلی: " + str(gear)

    for i in aircrafts.size():
        var a := aircrafts[i]
        var target := wagon.global_position + Vector3((i-1)*18,28,0)
        a.global_position = a.global_position.lerp(target,0.65*delta)
        a.look_at(wagon.global_position,Vector3.UP)

        # simple hostile fire
        if rng.randf() < 0.006:
            var b := MeshInstance3D.new()
            var sp := SphereMesh.new()
            sp.radius = .16
            sp.height = .32
            b.mesh = sp
            b.material_override = material(Color("#e04a32"))
            b.global_position = a.global_position
            add_child(b)
            bullets.append(b)

    for b in bullets:
        if is_instance_valid(b):
            b.global_position = b.global_position.lerp(wagon.global_position,0.018)
            if b.global_position.distance_to(wagon.global_position) < 1.2:
                b.queue_free()

    var cam := get_viewport().get_camera_3d()
    if cam:
        var desired := wagon.global_position + Vector3(-18,14,22)
        cam.global_position = cam.global_position.lerp(desired,3.0*delta)
        cam.look_at(wagon.global_position,Vector3.UP)
