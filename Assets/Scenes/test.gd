extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var health: HealthModule

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        if event.is_action_pressed("ui_right"):
            health.heal(10.0)
        if event.is_action_pressed("ui_left"):
            health.take_damage(10)

func _on_health_damaged(amount: float, current_health: float) -> void:
    print("Health depleted by: ", amount, ". Health is now: ", current_health)


func _on_health_died() -> void:
    print("dead")


func _on_health_healed(amount: float, current_health: float) -> void:
    print("Healed by: ", amount, ". Health is now: ", current_health)
