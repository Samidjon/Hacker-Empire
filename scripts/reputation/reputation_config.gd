class_name ReputationConfig
extends Resource
## Limits for reputation tracks and heat.

@export_range(1, 1000000) var max_reputation: int = 10000
@export_range(1.0, 1000.0) var max_heat: float = 100.0
