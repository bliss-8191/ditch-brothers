extends CharacterBody3D

@export_group("Camera")
@export_range(75, 110, 0.1) var fov: float = 75
@export_range(75, 110, 0.1) var sprint_fov: float = 90
@export_range(1, 10, 0.1) var fov_speed_start: float = 4
@export_range(1, 10, 0.1) var fov_speed_end: float = 8

@export_group("Movement")
@export_range(0.001, 0.01, 0.001) var look_sensitivity: float = 0.001
@export_range(1, 10, 0.1) var walk_speed: float = 4
@export_range(1, 10, 0.1) var sprint_speed: float = 6
@export_range(1, 100, 0.1) var walk_accel: float = 30
@export_range(1, 100, 0.1) var sprint_accel: float = 15

@export_group("Physics")
@export_range(1, 10) var update_rate_multiplier: int = 4
@export_range(10, 1000, 1) var soft_collision_push_force_multiplier: float = 128

@onready var head := $Head as Node3D
@onready var camera := $Head/Camera3D as Camera3D
@onready var soft_collision_shape := $ShapeCast3D as ShapeCast3D
@onready var hard_collision_shape := $CollisionShape3D as CollisionShape3D

const JUMP_VELOCITY = 4.5

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float):
	# fov sprint effect
	var look = -camera.get_global_transform().basis.z.normalized()
	var look_dir_speed = inverse_lerp(fov_speed_start, fov_speed_end, velocity.dot(look))
	camera.fov = lerp(fov, sprint_fov, clamp(look_dir_speed, 0, 1))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * look_sensitivity
		head.rotation.x = clampf(head.rotation.x - event.relative.y * look_sensitivity,  PI/-2, PI/2)

func _physics_process(delta: float) -> void:
	var sub_delta = delta / update_rate_multiplier
	for i in range(update_rate_multiplier):
		substep_physics_process(sub_delta)

func substep_physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var move_speed = 0
	if Input.is_action_pressed("sprint"):
		move_speed = sprint_speed
	else:
		move_speed = walk_speed

	# target input velocity
	var vxz = Vector2(velocity.x, velocity.z)
	var iv = get_target_xz_velocity()
	var dv = move_speed * iv - vxz
	var accel = 0
	if velocity.length() > walk_speed:
		accel = sprint_accel
	else:
		accel = walk_accel
	vxz += dv * clamp(accel * delta, 0, 1)
	velocity.x = vxz.x
	velocity.z = vxz.y

	# soft collision force
	var sf = get_soft_collision_force()
	velocity += soft_collision_push_force_multiplier * sf * delta

	substep_move_and_slide()

func substep_move_and_slide() -> void:
	velocity /= update_rate_multiplier
	move_and_slide()
	velocity *= update_rate_multiplier

func get_target_xz_velocity() -> Vector2:
	var v = Vector2()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		v.x = direction.x
		v.y = direction.z
	return v

func get_soft_collision_force() -> Vector3:
	# Soft Collision
	soft_collision_shape.force_shapecast_update()
	var f = Vector3()
	for i in range(soft_collision_shape.get_collision_count()):
		var n = soft_collision_shape.global_position - soft_collision_shape.get_collision_point(i)
		var n_len = Vector2(n.x, n.z).length()
		var depth_fraction = inverse_lerp(soft_collision_shape.shape.radius, hard_collision_shape.shape.radius, n_len)
		if n_len > 0.001:
			n = n * pow(depth_fraction, 1) / n_len
		else:
			n = 0
		print(depth_fraction, " ", pow(depth_fraction, 1))
		f.x += n.x
		f.z += n.z
	return f
