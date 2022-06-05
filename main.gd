tool

extends Spatial

var face_material = preload("res://materials/face_material.material")
var last_mouse_position = Vector2.ZERO
var materials := Dictionary()

func _ready():
	generate_edges("res://data/camera_edges.json")
	generate_faces("res://data/camera_faces.json")


func _process(delta):
	if Engine.is_editor_hint():
		return
	
	var mouse_delta = get_viewport().get_mouse_position() - last_mouse_position
	
	if Input.is_action_pressed("rotate"):
		$CameraBase.rotate($CameraBase/Camera.get_global_transform().basis.y, mouse_delta.x * -0.01)
		$CameraBase.rotate($CameraBase/Camera.get_global_transform().basis.x, mouse_delta.y * -0.01)
	
	last_mouse_position = get_viewport().get_mouse_position()

# https://cad.onshape.com/api/partstudios/d/bd3e28cca10081e0a5ad3ef8/w/f254fe7c4889c85a6841547f/e/f73186e750b795fdac6fbae0/tessellatededges?rollbackBarIndex=-1
func generate_edges(file_path):
	var edge_verts = PoolVector3Array()
	
	var file = File.new()
	file.open(file_path, File.READ)
	var edge_bodies = parse_json(file.get_as_text())
	
	for body in edge_bodies:
		for edge in body.edges:
			var last = null
			for vertex in edge.vertices:
				var next = Vector3(vertex[0], vertex[1], vertex[2]) * 39.3700787
				if last:
					edge_verts.append(last)
					edge_verts.append(next)
				last = next
	
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = edge_verts
	
	$Edges.mesh.clear_surfaces()
	$Edges.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)


func generate_faces(file_path):
	var file = File.new()
	file.open(file_path, File.READ)
	var face_bodies = parse_json(file.get_as_text())
	
	$Faces.mesh.clear_surfaces()
	
	var verts = PoolVector3Array()
	var normals = PoolVector3Array()
	var colors = PoolColorArray()
	
	var face_index = 0
	for body in face_bodies:
		for face in body.faces:
			
			var color_base64 = body.color
			if "color" in face:
				color_base64 = face.color
			var cd = Marshalls.base64_to_raw(color_base64)
			var color = Color8(cd[0], cd[1], cd[2], cd[3])
			
			for facet in face.facets:
				var normal = Vector3(facet.normal[0], facet.normal[1], facet.normal[2])
				for vertex in [facet.vertices[0], facet.vertices[2], facet.vertices[1]]:
					normals.append(normal)
					verts.append(Vector3(vertex[0], vertex[1], vertex[2]) * 39.3700787)
					colors.append(color)
			
			face_index += 1
	
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	
	$Faces.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
