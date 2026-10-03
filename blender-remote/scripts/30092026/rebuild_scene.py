"""Полная реконструкция сцены: пол, камера, свет, 15 объектов + домик.
Запускать через: python3 /home/voron/blender_send.py /tmp/rebuild_scene.py
"""
import bpy, bmesh, random
from mathutils import Vector

# === Очистка ===
for obj in list(bpy.data.objects):
    name = obj.name
    if obj.type == 'MESH':
        bpy.data.objects.remove(obj, do_unlink=True)

# Удалить старые меши без владельцев
for m in list(bpy.data.meshes):
    if not m.users:
        bpy.data.meshes.remove(m)

# === Пол ===
mesh_floor = bpy.data.meshes.new("Пол")
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=10, y_segments=10, size=8)
bm.to_mesh(mesh_floor)
bm.free()
floor = bpy.data.objects.new("Пол", mesh_floor)
bpy.context.collection.objects.link(floor)

# === Камера ===
cam_data = bpy.data.cameras.new("Камера")
camera = bpy.data.objects.new("Камера", cam_data)
bpy.context.collection.objects.link(camera)
camera.location = (0, -14, 8)
camera.rotation_euler = (1.25, 0, 0)  # смотрит чуть вниз на сцену

# === Солнце ===
sun_data = bpy.data.lights.new("Солнце", type='SUN')
sun_data.energy = 3.0
sun = bpy.data.objects.new("Солнце", sun_data)
bpy.context.collection.objects.link(sun)
sun.rotation_euler = (1.0, 0.3, 0.5)

# === 14 случайных объектов (не перекрывая домик на x=2.5) ===
random.seed(42)
for i in range(2, 16):  # Объект_2 .. Объект_15
    mesh = bpy.data.meshes.new(f"Объект_{i}")
    bm = bmesh.new()
    kind = random.choice(['cube', 'uv_sphere', 'cone'])
    if kind == 'cube':
        bmesh.ops.create_cube(bm, size=random.uniform(0.3, 1.2))
    elif kind == 'uv_sphere':
        bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=random.uniform(0.3, 0.8))
    else:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=random.uniform(0.2, 0.5), depth=random.uniform(0.5, 1.5))
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(f"Объект_{i}", mesh)
    bpy.context.collection.objects.link(obj)
    # Разбросать по полу, избегая зоны домика (x=2.5±3, y=0±3)
    while True:
        x = random.uniform(-7, 7)
        y = random.uniform(-7, 7)
        if not (-0.5 < x - 2.5 < 5.5 and -3 < y < 3):
            break
    obj.location = (x, y, 0)

# === Домик: стены + крыша-пирамида + окно ===
mesh_house = bpy.data.meshes.new("Домик")
bm = bmesh.new()

# Стены: коробка 4x3x2.5
bmesh.ops.create_cube(bm, size=1)
for v in bm.verts:
    v.co.x *= 4
    v.co.y *= 3
    v.co.z *= 2.5
    v.co.z += 1.25

# Крыша: пирамида
top_face = max(bm.faces, key=lambda f: f.calc_center_median().z)
res = bmesh.ops.extrude_face_region(bm, geom=[top_face])
new_verts = [g for g in res['geom'] if isinstance(g, bmesh.types.BMVert)]
for v in new_verts:
    v.co = Vector((0, 0, 4.2))

# Окно: inset на передней стене (-Y), удалить внутреннюю грань
try:
    front_face = None
    for f in bm.faces:
        c = f.calc_center_median()
        if abs(f.normal.y) > 0.9 and -2 < c.z < 2.5 and f.calc_area() > 4:
            front_face = f
            break
    if front_face:
        bmesh.ops.inset_individual(bm, faces=[front_face], thickness=0.7, depth=0)
        for f in bm.faces:
            c = f.calc_center_median()
            if abs(f.normal.y) > 0.9 and f.calc_area() < 2 and -1.5 < c.y < 0:
                bmesh.ops.delete(bm, geom=[f], context='FACES')
except Exception as e:
    print(f"Window skipped: {e}")

bm.to_mesh(mesh_house)
bm.free()

house = bpy.data.objects.new("Домик", mesh_house)
bpy.context.collection.objects.link(house)
house.location = (2.5, 0, 0)

# === Настройки рендера ===
scene = bpy.context.scene
scene.camera = camera
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.fps = 24

print(f"Scene rebuilt: {len(bpy.data.objects)} objects, house verts={len(mesh_house.vertices)}, faces={len(mesh_house.polygons)}")
