extends Area2D

const SHOOT_TIME_DELAY := 0.1
const FRICTION := 0.05;
const ACCELERATION := 15;
const BACKWARDS_ACCELERATION := 30;
const MAX_SPEED := 600;
const MAX_SHOT_SPREAD = 60;
const MAX_CONTINUES_SHOOTING_TIME = 1.5;
const MAX_BULLET_SPEED = 2000;

var isOverheating = false;

signal shot_fired(percentage);
signal overheat(timer);
signal health_depleted(health)

var health := 5 setget _set_health

var max_border_y: int;
var max_border_x: int;

const min_border_x = 32;
var min_border_y;

var shoot_time := 0.0

var overheatPercentage = 0;
var motion := Vector2();
var current_shooting_time := 0.0;

func _ready():
	max_border_y = get_viewport_rect().size.y - 32;
	min_border_y = (get_viewport_rect().size.y / 1.5) - 32;
	max_border_x = get_viewport_rect().size.x - 32;

func _physics_process(delta):
	var right = Input.is_action_pressed("ui_right");
	var left =  Input.is_action_pressed("ui_left");
	var down = Input.is_action_pressed("ui_down");
	var up = Input.is_action_pressed("ui_up");
	var shoot = Input.is_action_pressed("shoot");

	shoot_time += delta

	$AnimatedSprite.modulate = Color(1, 1 - overheatPercentage, 1 - overheatPercentage);
	if shoot and shoot_time > SHOOT_TIME_DELAY:
		shoot_time = 0.0
		if current_shooting_time < MAX_CONTINUES_SHOOTING_TIME:
			if !isOverheating:
				shoot(delta);
			else:
				$AnimatedSprite.modulate = Color(0, 0, 0);
				if !$OverheatShootSound.playing:
					$OverheatShootSound.play();
		else:
			isOverheating = true;
			$OverheatCooldown.start(1);
			$CPUParticles2D.emitting = true;
			emit_signal("overheat", $OverheatCooldown.wait_time);
	else:
		calc_heat_percentage();
		current_shooting_time = max(0, current_shooting_time - delta);
	if right:
		if motion.x < -ACCELERATION:
			motion.x = min(motion.x + BACKWARDS_ACCELERATION, MAX_SPEED);
			# $FrictionParticle.emit_for_motion(lastFrameMotion);
		else:
			motion.x = min(motion.x + ACCELERATION, MAX_SPEED);
	elif left:
		if motion.x > ACCELERATION:
			motion.x = max(motion.x - BACKWARDS_ACCELERATION, -MAX_SPEED);
			# $FrictionParticle.emit_for_motion(lastFrameMotion);
		else:
			motion.x = max(motion.x - ACCELERATION, -MAX_SPEED);
	else:
		# $FrictionParticle.set_emitting(false);
		motion.x = lerp(motion.x, 0, FRICTION);

	if down:
		if motion.y < -ACCELERATION:
			motion.y = min(motion.y + BACKWARDS_ACCELERATION, MAX_SPEED);
		else:
			motion.y = min(motion.y + ACCELERATION, MAX_SPEED);
	elif up:
		if motion.y > ACCELERATION:
			motion.y = max(motion.y - BACKWARDS_ACCELERATION, -MAX_SPEED);
		else:
			motion.y = max(motion.y - ACCELERATION, -MAX_SPEED);
	else:
		motion.y = lerp(motion.y, 0, FRICTION);

	var newPos = get_global_position() + Vector2(motion.x * delta, motion.y * delta);
	if newPos.y >= max_border_y || newPos.y <= min_border_y:
		motion.y = 0;
		newPos.y = min(newPos.y, max_border_y);
		newPos.y = max(min_border_y, newPos.y);
	if newPos.x >= max_border_x || newPos.x < min_border_x:
		motion.x = 0;
		newPos.x = min(newPos.x, max_border_x);
		newPos.x = max(min_border_x, newPos.x);

	if newPos.x > get_viewport_rect().size.x:
		newPos.x = get_viewport_rect().size.x;
	elif newPos.x <= 0:
		newPos.x = 0

	set_global_position(newPos);

var can_shoot = true;
var shot_spread = 0;

func shoot(delta):
	current_shooting_time += delta * 12;
	calc_heat_percentage();
	if can_shoot:
		emit_signal("shot_fired", overheatPercentage);
		can_shoot = false;
		$BetweenShotsCooldown.wait_time = 0.1 - (0.1 * overheatPercentage);
		shot_spread = lerp(0, MAX_SHOT_SPREAD * overheatPercentage, 0.2);
		var bullet = Instance.Bullet(global_position, rotation_degrees, MAX_BULLET_SPEED * overheatPercentage, shot_spread);
		motion.y += 100;
		bullet.shooter = self
		get_parent().bullets.add_child(bullet);

func calc_heat_percentage():
	overheatPercentage = current_shooting_time / MAX_CONTINUES_SHOOTING_TIME;

func queue_free():
	var explosion = Instance.Explosion()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
	.queue_free()

func _set_health(value):
	health = value

	emit_signal("health_depleted", health)

	if health < 1:
		queue_free()

func _on_BetweenShotsCooldown_timeout():
	can_shoot = true;

func _on_OverheatCooldown_timeout():
	isOverheating = false;
	overheatPercentage = 0;
	shot_spread = 0;
