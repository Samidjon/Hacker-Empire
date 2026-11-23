class_name EconomyConfig
extends Resource
## Tunable economy values.

## Money granted when a new game starts.
@export_range(0, 1000000) var starting_money: int = 1500
## How many transactions are kept (and saved) for the finance history.
@export_range(10, 1000) var max_transaction_history: int = 100
