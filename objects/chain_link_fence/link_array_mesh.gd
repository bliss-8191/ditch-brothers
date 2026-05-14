extends MeshInstance3D

@export var input: Mesh
@export var width: int = 15
@export var height: int = 15

@export var link_width: float = 0.1610117142857143
@export var link_height: float = 0.1610117142857143

var surface_array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(width):
		for j in range(height):
			st.append_from(input, 0, Transform3D(Basis(), Vector3(i*link_width, j*link_height, 0.0)))
	mesh = st.commit()
