class_name HardwareConfig
extends Resource
## How hardware stats turn into gameplay bonuses.

## Percent of extra contract time per point of Speed.
@export_range(0.0, 10.0, 0.05) var time_percent_per_speed: float = 1.0
## Points of Capacity needed for each extra offer on the contract board.
@export_range(1.0, 1000.0, 1.0) var capacity_per_offer: float = 60.0
@export_range(0, 12) var max_extra_offers: int = 4
## Percent off the board refresh cooldown per point of Network.
@export_range(0.0, 10.0, 0.05) var cooldown_percent_per_network: float = 1.0
## Electricity per business day for each tier of every installed part.
@export_range(0, 1000) var power_cost_per_tier: int = 4
## The electricity bill can never be reduced by more than this many percent.
@export_range(0.0, 100.0, 1.0) var max_electricity_reduction: float = 90.0
## Research power per point of Research.
@export_range(0.0, 10.0, 0.05) var research_power_per_point: float = 1.0
