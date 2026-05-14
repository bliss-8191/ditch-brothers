extends CharacterBody3D

@export_group("Camera")
## Field of view.
@export_range(75, 110, 0.1) var fov: float = 75
## Field of view when moving at fov_speed_end in look direction.
@export_range(75, 110, 0.1) var sprint_fov: float = 90
## The speed at which the FOV animation matches the target FOV.
@export_range(1, 10, 0.01) var fov_animation_speed: float = 60
## Speed to start increasing FOV toward sprint_fov.
@export_range(1, 10, 0.1) var fov_speed_start: float = 4
## Speed to stop increasing FOV toward sprint_fov.
@export_range(1, 10, 0.1) var fov_speed_end: float = 8

@export_group("Movement")
## Mouse input sensitivity.
@export_range(0.001, 0.01, 0.001) var look_sensitivity: float = 0.001
## Movement speed when walking.
@export_range(1, 10, 0.1) var walk_speed: float = 4
## Movement speed when sprinting.
@export_range(1, 10, 0.1) var sprint_speed: float = 6
## Movement speed when crouching (based on current crouch height).
@export_range(1, 10, 0.1) var crouch_speed: float = 2
## Movement acceleration when walking.
@export_range(1, 100, 0.1) var walk_accel: float = 15
## Movement acceleration when accelerating past walking speed (toward sprint speed).
@export_range(1, 100, 0.1) var sprint_accel: float = 7.5

## Height of player when crouching.
@export_range(0.5, 1.5, 0.01) var crouch_height: float = 1
## How quickly the player crouches.
@export_range(1, 20, 0.01) var crouch_state_speed: float = 8

## How much "character controlled" acceleration effects movement when not grounded.
## This also acts as air resistance because the player controller tries to stop moving by default.
@export_range(0.0, 1.0, 0.01) var player_control_in_air: float = 0.1

## Expected to send 0-1 to 0-1.
## Determines how quickly the player changes crouch state at each given height.
@export var crouch_curve: Curve

## The force in which the player jumps.
@export_range(1, 10, 0.1) var jump_velocity: float = 4.5
## The force in which the player jumps when crouching (based on current crouch height).
@export_range(0, 10, 0.1) var crouch_jump_velocity: float = 2.5

@export_group("Physics")
## Number of physics updates for player input and soft collision forces.
## This reduces bounciness and other unwanted artifacts of the difference equations used to calculate position.
@export_range(1, 10) var update_rate_multiplier: int = 16
## How strongly the player is pushed away from surfaces when they get close.
## The force is proportional to the intersection depth into the soft shape cast.
@export_range(10, 1000, 1) var soft_collision_push_force_multiplier: float = 128
## Accleration damping when pushing up against or away from a surface.
## The damping force is proportional to the intersection depth into the soft shape cast.
## It is also projected onto the direction of the soft collision force
## (so the player can still slide along the surface undamped).
@export_range(1, 100, 0.1) var soft_collision_damping: float = 200

@onready var head := $Head as Node3D
@onready var camera := $Head/Camera3D as Camera3D
@onready var soft_collision_shape := $SoftShapeCast as ShapeCast3D
@onready var hard_collision_shape := $MainCollisionShape as CollisionShape3D
@onready var uncrouch_collision_shape := $UncrouchShapeCast as ShapeCast3D

## Amount player is currently crouched.
## 1 means standing.
var crouch_amount = 1.0
@onready var initial_head_height = head.position.y
# distance from camera to top of hard collision shape
@onready var head_padding = hard_collision_shape.shape.height - initial_head_height
@onready var initial_soft_collision_height = soft_collision_shape.shape.height
@onready var initial_soft_collision_position = soft_collision_shape.position.y

## Target FOV.
var fov_target = fov
## Smoother FOV.
var fov_smooth = fov

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	print(fov_target, " ", fov_smooth)
	# fov sprint effect
	var look = -camera.get_global_transform().basis.z.normalized()
	# speed only in the look direction
	var look_only_speed = velocity.dot(look)
	# use inverse lerp to go from speed to 0-1 range
	var effect_amount = clamp(inverse_lerp(fov_speed_start, fov_speed_end, look_only_speed), 0, 1)
	print(" ", fov_speed_start, " ", fov_speed_end, " ", look_only_speed)
	print(" ", effect_amount)
	fov_target = lerp(fov, sprint_fov, effect_amount)
	# animate fov change so it is smoother
	var dfov = fov_target - fov_smooth
	fov_smooth = clamp(fov_smooth + fov_animation_speed * dfov * delta, fov, sprint_fov)
	camera.fov = fov_smooth

	if Input.is_action_just_pressed("back"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_pressed("enter"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * look_sensitivity
		head.rotation.x = clampf(head.rotation.x - event.relative.y * look_sensitivity, PI/-2, PI/2)

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# crouch
	_update_crouch_state(delta)

	# jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = lerp(crouch_jump_velocity, jump_velocity, crouch_amount)

	# calculate more physics updates for some player physics
	var sub_delta = delta / update_rate_multiplier
	for i in range(update_rate_multiplier):
		_substep_physics_process(sub_delta)

func _substep_physics_process(delta: float) -> void:
	# acceleration from player input
	velocity += _get_horizontal_acceleration_with_delta(delta)

	# soft collision force
	var sf = get_soft_collision_force()
	if is_on_floor():
		velocity += soft_collision_push_force_multiplier * sf * delta
		if sf != Vector3():
			velocity -= soft_collision_damping * delta * velocity.project(sf) * sf.length()

	_substep_move_and_slide()

func _substep_move_and_slide() -> void:
	# move_and_slide does not take in its own time delta
	# scale velocity to compensate
	velocity /= update_rate_multiplier
	move_and_slide()
	velocity *= update_rate_multiplier

func _get_attempted_xz_velocity() -> Vector2:
	# get direction the player is attempting to move
	var v = Vector2()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		v.x = direction.x
		v.y = direction.z

	# walk or sprint
	var move_speed = 0
	if Input.is_action_pressed("sprint") and Input.is_action_pressed("move_forward") and not Input.is_action_pressed("move_back"):
		move_speed = sprint_speed
	else:
		move_speed = walk_speed
	# move slower when crouching
	move_speed = lerp(crouch_speed, move_speed, crouch_amount)

	return v * move_speed

func _get_horizontal_acceleration_with_delta(delta) -> Vector3:
	# current horizontal velocity
	var v = Vector2(velocity.x, velocity.z)
	# horizontal velocity player is attempting
	var iv = _get_attempted_xz_velocity()
	# dv is the value needed to go from current velocity to target velocity
	var dv = iv - v
	# seperate acceleration when already moving fast
	var accel_rate = 0
	if velocity.length() > walk_speed:
		accel_rate = sprint_accel
	else:
		accel_rate = walk_accel
	# scale down dv based on acceleration settings
	dv *= clamp(accel_rate * delta, 0, 1) # clamp to prevent overshoot
	# only let the player control movement when grounded
	if not is_on_floor():
		dv = player_control_in_air * dv
	# update with new horizontal velocity
	return Vector3(dv.x, 0.0, dv.y)

## Get force to push player away from surfaces when they are very close.
## This is not the main mechanism for preventing the player from walking through walls.
func get_soft_collision_force() -> Vector3:
	soft_collision_shape.force_shapecast_update()
	var f = Vector3()
	for i in range(soft_collision_shape.get_collision_count()):
		var n = soft_collision_shape.global_position - soft_collision_shape.get_collision_point(i)
		# how far into the collision shape the player is
		var n_len = Vector2(n.x, n.z).length()
		# convert to 0-1
		var depth_fraction = inverse_lerp(soft_collision_shape.shape.radius, hard_collision_shape.shape.radius, n_len)
		# custom acceleration curve
		if n_len > 0.001:
			n = n * depth_fraction / n_len
		else:
			n = Vector3()
		f.x += n.x
		f.z += n.z
	return f

## Get the amount the player is trying to crouch to.
func _get_next_attempted_crouch_amount(delta) -> float:
	var next_crouch_amount = 0
	if Input.is_action_pressed("crouch"):
		next_crouch_amount = crouch_amount - delta * crouch_state_speed * crouch_curve.sample(crouch_amount)
	else:
		next_crouch_amount = crouch_amount + delta * crouch_state_speed * crouch_curve.sample(crouch_amount)
	next_crouch_amount = clamp(next_crouch_amount, 0, 1)
	return next_crouch_amount

## Check head hit, and determine correct crouch amount to avoid collision.
func _check_head_hit(next_crouch_amount: float) -> float:
	# only check if un-crouching and can hit head
	if next_crouch_amount <= crouch_amount:
		return 1.0
	# calculate start and end positions for shape cast
	var start_head_height = lerp(crouch_height, initial_head_height, crouch_amount)
	var end_head_height = lerp(crouch_height, initial_head_height, next_crouch_amount)
	# make sweep shape slightly smaller so the main collision shape does not stick on sides
	uncrouch_collision_shape.shape.radius = hard_collision_shape.shape.radius - hard_collision_shape.shape.margin
	var start = start_head_height + head_padding - uncrouch_collision_shape.shape.radius
	var end = end_head_height + head_padding - uncrouch_collision_shape.shape.radius
	# set start position for cast
	uncrouch_collision_shape.position.y = start
	# set target position for cast
	uncrouch_collision_shape.set_target_position(Vector3(0.0, end - start, 0.0))
	# perform shape cast
	uncrouch_collision_shape.force_shapecast_update()
	return uncrouch_collision_shape.get_closest_collision_safe_fraction()

## Get the next crouch amount based on the two preceding functions.
func _get_next_crouch_amount(delta) -> float:
	var next_crouch_amount = _get_next_attempted_crouch_amount(delta)
	return lerp(crouch_amount, next_crouch_amount, _check_head_hit(next_crouch_amount))

## Update player crouch state.
## This scales collision shapes and moves the camera.
## Also changes vertical player position if in mid air.
func _update_crouch_state(delta: float) -> void:
	var next_crouch_amount = _get_next_crouch_amount(delta)
	if crouch_amount == next_crouch_amount:
		return

	# how far crouch changed this update
	var crouch_moved = next_crouch_amount - crouch_amount
	crouch_amount = next_crouch_amount
	# how far the camera is from feet
	var head_height = lerp(crouch_height, initial_head_height, crouch_amount)
	# how much player is scaled down for crouch
	var crouch_scaling = head_height / initial_head_height

	# move camera
	head.position.y = head_height
	# move and scale main collision shape (or equivalently just scale relative to player origin)
	hard_collision_shape.shape.height = head.position.y + head_padding
	hard_collision_shape.position.y = 0.5 * hard_collision_shape.shape.height
	# move and scale soft collision shape (or equivalently just scale relative to player origin)
	soft_collision_shape.shape.height = crouch_scaling * initial_soft_collision_height
	soft_collision_shape.position.y = crouch_scaling * initial_soft_collision_position

	# roughly conserve momentum
	if not is_on_floor():
		position.y -= 0.5 * crouch_moved
