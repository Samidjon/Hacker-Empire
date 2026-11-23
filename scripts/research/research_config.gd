class_name ResearchConfig
extends Resource
## Tunable rules for research and product development.

@export_group("Research")
## Research points per minute the player produces alone.
@export_range(0.0, 1000.0, 0.5) var base_research_power: float = 8.0

@export_group("Products")
## Development points per business day the founder contributes alone.
@export_range(0.0, 1000.0, 0.5) var base_development_power: float = 10.0
## Extra product revenue per company level above 1 (0.05 = +5%).
@export_range(0.0, 1.0, 0.01) var revenue_bonus_per_company_level: float = 0.05
## Company XP per unit of product revenue.
@export_range(0.0, 5.0, 0.01) var company_xp_per_revenue: float = 0.1
