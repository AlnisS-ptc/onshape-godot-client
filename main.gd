tool

extends Spatial

var face_material = preload("res://materials/face_material.material")
var last_mouse_position = Vector2.ZERO
var materials := Dictionary()

func _ready():
	generate_edges("res://data/camera_edges.json")
	generate_faces("res://data/camera_faces.json")
	request_edges()


func _process(delta):
	if Engine.is_editor_hint():
		return
	
	var mouse_delta = get_viewport().get_mouse_position() - last_mouse_position
	
	if Input.is_action_pressed("rotate"):
		$CameraBase.rotate($CameraBase/Camera.get_global_transform().basis.y, mouse_delta.x * -0.01)
		$CameraBase.rotate($CameraBase/Camera.get_global_transform().basis.x, mouse_delta.y * -0.01)
	
	last_mouse_position = get_viewport().get_mouse_position()

func request_edges():
	var access_key = Creds.access_key
	var secret_key = Creds.secret_key
	
	var url = "https://cad.onshape.com/api/partstudios/d/bd3e28cca10081e0a5ad3ef8/w/f254fe7c4889c85a6841547f/e/f73186e750b795fdac6fbae0/tessellatededges?rollbackBarIndex=-1"
	var content_type = 'application/json'
	
	# https://godotengine.org/qa/19077/how-to-get-the-date-as-per-rfc-1123-date-format-in-game
	var time = OS.get_datetime(true)
	var nameweekday= ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	var namemonth= ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var dayofweek = time["weekday"]   # from 0 to 6 --> Sunday to Saturday
	var day = time["day"]                         #   1-31
	var month= time["month"]               #   1-12
	var year= time["year"]             
	var hour= time["hour"]                     #   0-23
	var minute= time["minute"]             #   0-59
	var second= time["second"]             #   0-59

	var dateRFC1123 = str(nameweekday[dayofweek]) + ", " + str("%02d" % [day]) + " " + str(namemonth[month-1]) + " " + str(year) + " " + str("%02d" % [hour]) + ":" + str("%02d" % [minute]) + ":" + str("%02d" % [second]) + " GMT"
	
#	print(dateRFC1123)

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var nonce = ''
	for i in range(16):
		nonce += str(rng.randi() % 10)
	
	var signature = create_signature('GET', url, nonce, dateRFC1123, content_type, access_key, secret_key)
	print(dateRFC1123)
	print(nonce)
	print(signature)
	
	var error = $HTTPRequest.request(url, ["Content-Type: " + content_type, "Date: " + dateRFC1123, "On-Nonce: " + nonce, "Authorization: " + signature])
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		print(error)

func _http_request_completed(result, response_code, headers, body):
	var response = parse_json(body.get_string_from_utf8())
	print(response)


func create_signature(method, url, nonce, auth_date, content_type, access_key, secret_key):
	var path_start = url.find('/api/')
	var parameters_start = url.find('?')
	
	var url_path = url.substr(path_start, parameters_start - path_start)
	var url_query = url.substr(parameters_start + 1) if parameters_start != -1 else ''
	
	var combined = ("%s\n%s\n%s\n%s\n%s\n%s\n" % [method, nonce, auth_date,
			content_type, url_path, url_query]).to_lower()
	
#	var hmac = HMACSHA256.hmac_base64(combined.to_ascii(), secret_key.to_ascii())
	var hmac = Marshalls.raw_to_base64(Crypto.new().hmac_digest(
			HashingContext.HASH_SHA256, secret_key.to_ascii(), combined.to_ascii()))
	
	return 'On %s:HmacSHA256:%s' % [access_key, hmac]

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

# https://cad.onshape.com/api/partstudios/d/bd3e28cca10081e0a5ad3ef8/w/f254fe7c4889c85a6841547f/e/f73186e750b795fdac6fbae0/tessellatedfaces?rollbackBarIndex=-1&outputFaceAppearances=false&outputVertexNormals=false&outputFacetNormals=true&outputTextureCoordinates=false&outputIndexTable=false&outputErrorFaces=false&combineCompositePartConstituents=false
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
