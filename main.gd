tool

extends Spatial

var face_material = preload("res://materials/face_material.material")

var last_mouse_position = Vector2.ZERO


func _ready():
	generate_bwh_edges()
	generate_bwh_faces()
#	generate_cube()
#	generate_sphere()


func _process(delta):
	if Engine.is_editor_hint():
		return
	
	var mouse_delta = get_viewport().get_mouse_position() - last_mouse_position
	
	if Input.is_action_pressed("rotate"):
		$CameraBase.rotate($CameraBase/Camera.get_global_transform().basis.y, mouse_delta.x * -0.005)
		$CameraBase.rotate($CameraBase/Camera.get_global_transform().basis.x, mouse_delta.y * -0.005)
	
	last_mouse_position = get_viewport().get_mouse_position()


func generate_bwh_edges():
	var edge_verts = PoolVector3Array()
	
	var file = File.new()
	file.open("res://data/bwh_edges.json", File.READ)
	var edges = parse_json(file.get_as_text())
	
	for body in edges.bodies:
		for edge in body.edges:
			var last = null
			for vertex in edge.vertices:
				var next = Vector3(vertex.x, vertex.y, vertex.z) * 39.3700787
				if last:
					edge_verts.append(last)
					edge_verts.append(next)
				last = next
	
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = edge_verts
	
	$Faces.mesh.clear_surfaces()
	$Edges.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)


func generate_bwh_faces():
	var file = File.new()
	file.open("res://data/bwh_faces.json", File.READ)
	var faces = parse_json(file.get_as_text())
	
	$Faces.mesh.clear_surfaces()
	
	var face_index = 0
	for body in faces.bodies:
		for face in body.faces:
			
			var verts = PoolVector3Array()
			var normals = PoolVector3Array()
			
			for facet in face.facets:
				var normal = Vector3(facet.normal.x, facet.normal.y, facet.normal.z)
				for vertex in [facet.vertices[0], facet.vertices[2], facet.vertices[1]]:
					normals.append(normal)
					verts.append(Vector3(vertex.x, vertex.y, vertex.z) * 39.3700787)
			
			var arr = []
			arr.resize(Mesh.ARRAY_MAX)
			
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = normals
			
			$Faces.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			$Faces.set_surface_material(face_index, face_material)
			face_index += 1
	


func generate_cube():
	return
	var verts = PoolVector3Array()
	
	var p1 = Vector3(1, 1, 1)
	var p2 = Vector3(1, -1, 1)
	var p3 = Vector3(1, -1, -1)
	var p4 = Vector3(1, 1, -1)
	var p5 = Vector3(-1, 1, 1)
	var p6 = Vector3(-1, -1, 1)
	var p7 = Vector3(-1, -1, -1)
	var p8 = Vector3(-1, 1, -1)
	
	
	verts.append_array([
		p1, p2,   p2, p3,   p3, p4,   p4, p1,
		p1, p5,   p2, p6,   p3, p7,   p4, p8,
		p5, p6,   p6, p7,   p7, p8,   p8, p5
	])
	
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	
	$Edges.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)


func generate_sphere():
	var rings = 50
	var radial_segments = 50
	var height = 1
	var radius = 1
	
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	
	var verts = PoolVector3Array()
	var uvs = PoolVector2Array()
	var normals = PoolVector3Array()
	var indices = PoolIntArray()
	
	
	var thisrow = 0
	var prevrow = 0
	var point = 0

	# Loop over rings.
	for i in range(rings + 1):
		var v = float(i) / rings
		var w = sin(PI * v)
		var y = cos(PI * v)

		# Loop over segments in ring.
		for j in range(radial_segments):
			var u = float(j) / radial_segments
			var x = sin(u * PI * 2.0)
			var z = cos(u * PI * 2.0)
			var vert = Vector3(x * radius * w, y, z * radius * w)
			verts.append(vert)
			normals.append(vert.normalized())
			uvs.append(Vector2(u, v))
			point += 1

			# Create triangles in ring using indices.
			if i > 0 and j > 0:
				indices.append(prevrow + j - 1)
				indices.append(prevrow + j)
				indices.append(thisrow + j - 1)

				indices.append(prevrow + j)
				indices.append(thisrow + j)
				indices.append(thisrow + j - 1)

		if i > 0:
			indices.append(prevrow + radial_segments - 1)
			indices.append(prevrow)
			indices.append(thisrow + radial_segments - 1)

			indices.append(prevrow)
			indices.append(prevrow + radial_segments)
			indices.append(thisrow + radial_segments - 1)

		prevrow = thisrow
		thisrow = point
	
	
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = indices
	
	$MeshInstance.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
