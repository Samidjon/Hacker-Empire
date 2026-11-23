class_name EmployeeConfig
extends Resource
## Tunable rules for staff.

@export_group("Recruitment")
## Candidates on offer at any time. The list is renewed every business day.
@export_range(1, 12) var candidate_count: int = 4
## Hiring costs this many days of the candidate's salary up front.
@export_range(0, 30) var signing_fee_days: int = 2

@export_group("Growth")
@export_range(1, 20) var max_skill: int = 10
## XP for level 1 -> 2. Level n -> n + 1 costs n times this.
@export_range(1, 10000) var xp_per_level: int = 100
## Daily salary added with every employee level.
@export_range(0, 1000) var salary_per_level: int = 6

@export_group("Wellbeing")
## Morale lost on a day the salary cannot be paid.
@export_range(0.0, 100.0, 1.0) var unpaid_morale_penalty: float = 25.0
## At or below this energy, working costs extra morale.
@export_range(0.0, 100.0, 1.0) var low_energy_threshold: float = 20.0
@export_range(0.0, 100.0, 1.0) var overwork_morale_penalty: float = 8.0
## An employee whose morale reaches this resigns.
@export_range(0.0, 100.0, 1.0) var resignation_morale: float = 0.0

@export_group("Company")
## Company XP earned per unit of money staff bring in.
@export_range(0.0, 5.0, 0.01) var company_xp_per_income: float = 0.15
