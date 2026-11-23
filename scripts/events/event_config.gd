class_name EventConfig
extends Resource
## Tunable rules for random world events.

## Seconds of play between rolls for an event.
@export_range(5.0, 3600.0, 1.0) var check_interval_seconds: float = 150.0
## Chance (0-1) that a roll produces an event.
@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 0.5
## No events during the first seconds of a new game.
@export_range(0.0, 3600.0, 1.0) var grace_period_seconds: float = 180.0
## Resolved events kept in the history.
@export_range(1, 100) var max_history: int = 12
