extends Node

## Vertical resolution where the LOD distances were created.
@export var finetuned_resolution: float = 1080
## Vertical FOV where the LOD distances were created.
@export var finetuned_fov: float = 75

## Objects whose visibility ranges to correct.
@export var geometries: Array[GeometryInstance3D]

class VisibilityRangeUpdater:
	var geometry: GeometryInstance3D
	var begin: float
	var begin_margin: float
	var end: float
	var end_margin: float
	func _init(geom: GeometryInstance3D):
		geometry = geom
		begin = geometry.visibility_range_begin
		begin_margin = geometry.visibility_range_begin_margin
		end = geometry.visibility_range_end
		end_margin = geometry.visibility_range_end_margin
	func update_ranges(factor):
		geometry.visibility_range_begin = factor * begin
		geometry.visibility_range_begin_margin = factor * begin_margin
		geometry.visibility_range_end = factor * end
		geometry.visibility_range_end_margin = factor * end_margin

@onready var range_updaters = geometries.map(VisibilityRangeUpdater.new)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var res = get_viewport().size.y
	var fov = get_viewport().get_camera_3d().fov
	for updater in range_updaters:
		updater.update_ranges((res / fov) / (finetuned_resolution / finetuned_fov))
