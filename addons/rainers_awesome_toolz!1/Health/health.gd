extends Node
class_name HealthModule

signal damaged(amount: float, current_health: float)
signal healed(amount: float, current_health: float)
signal died()
signal resurrected(current_health: float)

@export var max_health: float = 100.0
@export var starting_health: float = 0.0
@export var clamp_health: bool = true

var current_health: float = 0.0
var is_dead: bool = false

func _ready() -> void:
    if starting_health <= 0.0:
        current_health = max_health
    else:
        current_health = starting_health


func take_damage(amount: float) -> float:
    if is_dead:
        return 0.0
    if amount <= 0.0:
        return 0.0

    return _apply_damage(amount)


func _apply_damage(amount: float) -> float:
    if is_dead:
        return 0.0

    var previous_health := current_health
    current_health -= amount

    if clamp_health:
        current_health = maxf(current_health, 0.0)

    var actual_damage := previous_health - current_health
    damaged.emit(actual_damage, current_health)

    if current_health <= 0.0:
        _die()

    return actual_damage

## Returns true when this Health belongs to a player.
func _is_player_health() -> bool: 
    var entity := get_parent()
    if entity:
        return true 
    return false


func heal(amount: float) -> float:
    if is_dead:
        return 0.0

    if amount <= 0.0:
        return 0.0

    var previous_health := current_health
    current_health += amount

    if clamp_health:
        current_health = minf(current_health, max_health)

    var actual_heal := current_health - previous_health
    healed.emit(actual_heal, current_health)

    return actual_heal


func resurrect(health_after: float = 0.0) -> void:
    if not is_dead:
        return

    is_dead = false

    if health_after <= 0.0:
        current_health = max_health
    else:
        current_health = health_after

    if clamp_health:
        current_health = minf(current_health, max_health)

    resurrected.emit(current_health)


## Returns health as a ratio between 0.0 and 1.0.
func get_health_percent() -> float:
    if max_health <= 0.0:
        return 0.0
    return current_health / max_health


func _die() -> void:
    is_dead = true
    current_health = 0.0
    died.emit()
