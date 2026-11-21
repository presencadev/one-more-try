extends CharacterBody2D

signal landed(surface: StaticBody2D)
signal fell_out

const SPEED := 245.0
const GRAVITY := 1250.0
const JUMP_SPEED := 365.0
const SPRING_SPEED := 670.0

var floor_surface: StaticBody2D


func _physics_process(delta: float) -> void:
	velocity.x = Input.get_axis("move_left", "move_right") * SPEED
	if velocity.x != 0.0:
		$Art.flip_h = velocity.x < 0.0
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = -JUMP_SPEED
		$JumpSound.play()

	move_and_slide()
	if position.y > 635:
		fell_out.emit()
		return

	var surface := _surface_below()
	if surface != floor_surface:
		floor_surface = surface
		if surface != null:
			landed.emit(surface)


func _surface_below() -> StaticBody2D:
	if is_on_floor():
		for index in get_slide_collision_count():
			var hit := get_slide_collision(index)
			if hit.get_normal().y < -0.7:
				return hit.get_collider() as StaticBody2D
	return null


func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	floor_surface = null
	$Art.flip_h = false


func spring_up() -> void:
	velocity.y = -SPRING_SPEED
