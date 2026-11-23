class_name OrganizationConfig
extends Resource
## Tunable rules for the player's company.

@export_group("Founding")
@export_range(0, 1000000) var founding_cost: int = 1500
## Player level needed to found a company.
@export_range(1, 50) var required_level: int = 3
@export_range(1, 32) var min_name_length: int = 3
@export_range(1, 64) var max_name_length: int = 24

@export_group("Time")
## Seconds of play in one business day (rent, salaries and work are daily).
@export_range(5.0, 3600.0, 1.0) var day_length_seconds: float = 120.0
## How many daily reports are kept.
@export_range(1, 60) var report_history: int = 14

@export_group("Company level")
@export_range(1, 50) var max_company_level: int = 10
## Company XP for level 1 -> 2. Later levels cost base * level ^ exponent.
@export_range(1, 100000) var xp_base: int = 150
@export_range(1.0, 3.0, 0.01) var xp_exponent: float = 1.5
## Percent of extra pay on all the player's contracts per company level above 1.
@export_range(0.0, 20.0, 0.1) var reward_percent_per_level: float = 2.0
## Share of a completed contract's XP that also goes to the company.
@export_range(0.0, 2.0, 0.05) var contract_xp_share: float = 0.5
## Company reputation for each contract the player completes.
@export_range(0, 100) var contract_reputation: int = 1
## Company reputation lost each day the rent cannot be paid.
@export_range(0, 100) var unpaid_rent_reputation_penalty: int = 3
