import bpy
import bmesh
import random
import math
from mathutils import Vector

# --- Удалить все объекты (без bpy.ops) ---
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

# --- Пол ---
mesh = bpy.data.meshes.new("FloorMesh")
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=10)
bm.to_mesh(mesh)
bm.free()
floor = bpy.data.objects.new("Пол", mesh)
bpy.context.collection.objects.link(floor)

mat_floor = bpy.data.materials.new("Mat_Пол")
mat_floor.use_nodes = True
bsdf = next(n for n in mat_floor.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bsdf.inputs["Base Color"].default_value = (0.3, 0.3, 0.35, 1)
floor.data.materials.append(mat_floor)

# --- Камера ---
cam_data = bpy.data.cameras.new("CamData")
camera = bpy.data.objects.new("Камера", cam_data)
bpy.context.collection.objects.link(camera)
camera.location = (8, -8, 5)
direction = Vector((0, 0, 1)) - camera.location
rot_quat = direction.to_track_quat('-Z', 'Y')
camera.rotation_euler = rot_quat.to_euler()
bpy.context.scene.camera = camera

# --- Свет ---
light_data = bpy.data.lights.new("Солнце", type='SUN')
light_data.energy = 3.0
sun = bpy.data.objects.new("Солнце", light_data)
bpy.context.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), math.radians(20), math.radians(-45))

# --- Случайные объекты ---
colors = [
    (0.9, 0.2, 0.2, 1),
    (0.2, 0.6, 0.9, 1),
    (0.3, 0.8, 0.3, 1),
    (0.9, 0.7, 0.2, 1),
    (0.6, 0.3, 0.8, 1),
]

def make_cube(size):
    mesh = bpy.data.meshes.new("CubeMesh")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=size)
    bm.to_mesh(mesh); bm.free()
    return mesh

def make_sphere(radius):
    mesh = bpy.data.meshes.new("SphereMesh")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=radius)
    bm.to_mesh(mesh); bm.free()
    return mesh

def make_cylinder(radius, depth):
    mesh = bpy.data.meshes.new("CylMesh")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=radius, radius2=radius, depth=depth)
    bm.to_mesh(mesh); bm.free()
    return mesh

def make_cone(radius, depth):
    mesh = bpy.data.meshes.new("ConeMesh")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=radius, radius2=0, depth=depth)
    bm.to_mesh(mesh); bm.free()
    return mesh

makers = [make_cube, make_sphere, make_cylinder, make_cone]

count = 15
for i in range(count):
    x = random.uniform(-7, 7)
    y = random.uniform(-7, 7)
    
    maker = random.choice(makers)
    size = random.uniform(0.6, 1.2)
    
    if maker == make_cube:
        mesh = maker(size)
        z = size / 2
    elif maker == make_sphere:
        mesh = maker(size / 2)
        z = size / 2
    elif maker == make_cylinder:
        mesh = maker(size / 3, size)
        z = size / 2
    else:  # cone
        mesh = maker(size / 2, size)
        z = size / 2

    obj = bpy.data.objects.new(f"Объект_{i+1}", mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = (x, y, z)
    obj.rotation_euler = (
        random.uniform(0, math.pi),
        random.uniform(0, math.pi),
        random.uniform(0, math.pi),
    )

    mat = bpy.data.materials.new(f"Mat_{i+1}")
    mat.use_nodes = True
    b = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs["Base Color"].default_value = random.choice(colors)
    obj.data.materials.append(mat)

# --- Рендер настройки ---
bpy.context.scene.render.resolution_x = 1920
bpy.context.scene.render.resolution_y = 1080
bpy.context.scene.render.resolution_percentage = 50

"Сцена готова: пол, камера, свет, 15 объектов (без bpy.ops)"
