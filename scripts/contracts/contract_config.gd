class_name ContractConfig
extends Resource
## Tunable rules of the contract system.

## Number of offers kept on the contract board.
@export_range(1, 12) var board_size: int = 4
## A contract fails when this many mistakes have been made.
@export_range(1, 10) var max_mistakes: int = 3
## Time limit = a contract's estimated duration x this factor.
@export_range(1.0, 10.0, 0.1) var time_limit_factor: float = 3.0
## Extra pay for finishing without a single mistake (0.1 = +10%).
@export_range(0.0, 1.0, 0.01) var flawless_bonus_ratio: float = 0.1
## Offers pay the listed reward plus or minus this share.
@export_range(0.0, 0.5, 0.01) var reward_variance: float = 0.15
## Reputation lost on the contract's own track when it fails.
@export_range(0, 100) var failure_reputation_penalty: int = 2
## Heat gained when an underground contract fails.
@export_range(0.0, 100.0, 0.5) var failure_heat: float = 4.0
## Seconds of play before the board can be refreshed again.
@export_range(0.0, 3600.0, 1.0) var refresh_cooldown_seconds: float = 45.0
@export_range(5, 500) var max_history: int = 50
