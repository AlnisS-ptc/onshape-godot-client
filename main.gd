extends Node3D

const ALPHANUMERIC_CHARACTERS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const HTTP_METHODS = ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "CONNECT", "PATCH"]

@onready var faces_node = $Faces
@onready var edges_node = $Edges

var face_material = preload("res://materials/face_material.material")
var last_mouse_position = Vector2.ZERO
var materials := Dictionary()
var crypto = Crypto.new()

var edge_thread
var face_thread

func _ready():
	randomize()
	_on_LoadButton_pressed()


func _process(delta):
	if Engine.is_editor_hint():
		return
	
#	print(Engine.get_frames_per_second())
	
	var mouse_delta = get_viewport().get_mouse_position() - last_mouse_position
	
	if Input.is_action_pressed("rotate"):
		$CameraBase.rotate($CameraBase/Camera3D.get_global_transform().basis.y, mouse_delta.x * -0.01)
		$CameraBase.rotate($CameraBase/Camera3D.get_global_transform().basis.x, mouse_delta.y * -0.01)
	
	if Input.is_action_pressed("pan"):
		$CameraBase.global_translate($CameraBase/Camera3D.get_global_transform().basis.y * mouse_delta.y * 0.005)
		$CameraBase.global_translate($CameraBase/Camera3D.get_global_transform().basis.x * mouse_delta.x * -0.005)
	
	last_mouse_position = get_viewport().get_mouse_position()


func load_edges(did, wvm, wvmid, eid):
	print("loading edges")
	onshape_request($EdgeHTTPRequest,
			"https://cad.onshape.com/api/partstudios/d/%s/%s/%s/e/%s/tessellatededges?rollbackBarIndex=-1" %
			[did, wvm, wvmid, eid])


func load_faces(did, wvm, wvmid, eid):
	print("loading faces")
	onshape_request($FaceHTTPRequest,
			"https://cad.onshape.com/api/partstudios/d/%s/%s/%s/e/%s/tessellatedfaces?rollbackBarIndex=-1&outputFaceAppearances=true&outputVertexNormals=true&outputFacetNormals=false&outputTextureCoordinates=false&outputIndexTable=false&outputErrorFaces=false&combineCompositePartConstituents=false" %
			[did, wvm, wvmid, eid])
	onshape_request($DocumentsHTTPRequest, 'https://cad.onshape.com/api/v6/documents?ownerType=1&sortColumn=createdAt&sortOrder=desc&offset=0&limit=20')


func onshape_request(http_request: HTTPRequest, url, method = HTTPClient.METHOD_GET,
		request_data = "", content_type = "application/json"):
	var time = Time.get_datetime_dict_from_system(true)
	var date = "%s, %02d %s %d %02d:%02d:%02d GMT" % [WEEKDAYS[time.weekday], time.day,
			MONTHS[time.month-1], time.year, time.hour, time.minute, time.second]

	var nonce = '%010d%010d' % [randi(), randi()]
	
	var signature = create_signature(HTTP_METHODS[method], url, nonce, date,
			content_type, Creds.access_key, Creds.secret_key)
	
	var error = http_request.request(url, [
		"Content-Type: " + content_type,
		"Date: " + date,
		"On-Nonce: " + nonce,
		"Authorization: " + signature
	], method, request_data)
	
	if error != OK:
		push_error("HTTP request error: %s" % error)


func _edge_request_completed(result, response_code, headers, body):
	print("edges received")
	edge_thread = Thread.new()
	edge_thread.start(Callable(self,"generate_edges_from_response").bind(body))

func _face_request_completed(result, response_code, headers, body):
	print("faces received")
	face_thread = Thread.new()
	face_thread.start(Callable(self,"generate_faces_from_response").bind(body))

func generate_edges_from_response(body):
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	generate_edges(test_json_conv.get_data())

func generate_faces_from_response(body):
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	generate_faces(test_json_conv.get_data())


func create_signature(method, url, nonce, auth_date, content_type, access_key, secret_key):
	var path_start = url.find('/api/')
	var parameters_start = url.find('?')
	
	var url_path = url.substr(path_start, parameters_start - path_start)
	var url_query = url.substr(parameters_start + 1) if parameters_start != -1 else ''
	
	var combined = ("%s\n%s\n%s\n%s\n%s\n%s\n" % [method, nonce, auth_date,
			content_type, url_path, url_query]).to_lower()
	
	var hmac = Marshalls.raw_to_base64(crypto.hmac_digest(
			HashingContext.HASH_SHA256, secret_key.to_ascii_buffer(), combined.to_ascii_buffer()))
	
	return 'On %s:HmacSHA256:%s' % [access_key, hmac]

# Generates edge mesh from JSON dictionary and puts it in edges_node
func generate_edges(edge_json):
	print("generating edges")
	var edge_verts = PackedVector3Array()
	
	for body in edge_json:
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
	
	edges_node.mesh.clear_surfaces()
	edges_node.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	
	print("finished generating edges")
#	print(edge_verts)

# Generates face mesh from JSON dictionary and puts it in faces_node
func generate_faces(face_json):
	faces_node.mesh.clear_surfaces()
	
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	
	var face_index = 0
	for body in face_json:
		for face in body.faces:
			
			var color_base64 = body.color
			if "color" in face:
				color_base64 = face.color
			var cd = Marshalls.base64_to_raw(color_base64)
			var color = Color8(cd[0], cd[1], cd[2], cd[3])
			
			for facet in face.facets:
				for i in [0, 2, 1]:
					var vertex = facet.vertices[i]
					var n = facet.vertexNormals[i]
					normals.append(Vector3(n[0], n[1], n[2]))
					verts.append(Vector3(vertex[0], vertex[1], vertex[2]) * 39.3700787)
					colors.append(color)
			
			face_index += 1
	
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	
	faces_node.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


func _on_LoadButton_pressed():
	var text = $TopBar/HBoxContainer/URLLineEdit.text
#	var did = "bd3e28cca10081e0a5ad3ef8"
#	var wvm = "w"
#	var wvmid = "f254fe7c4889c85a6841547f"
#	var eid = "f73186e750b795fdac6fbae0"
	var did = text.substr(text.find("/documents/") + 11, 24)
	var wvm = "w"
	var wvmid = text.substr(text.find("/w/") + 3, 24)
	var eid = text.substr(text.find("/e/") + 3, 24)
	print(did)
	print(wvm)
	print(wvmid)
	print(eid)
	load_edges(did, wvm, wvmid, eid)
	load_faces(did, wvm, wvmid, eid)


func _on_documents_http_request_request_completed(result, response_code, headers, body):
	print(result, response_code, headers, body)
