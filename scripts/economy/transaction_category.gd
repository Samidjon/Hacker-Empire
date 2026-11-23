class_name TransactionCategory
extends RefCounted
## Category ids for EconomyManager transactions.
## Always use these constants instead of string literals.

# Income
const STARTING_FUNDS: String = "starting_funds"
const CONTRACT: String = "contract"
const SOFTWARE_SALES: String = "software_sales"
const SUBSCRIPTION: String = "subscription"
const RESEARCH_REWARD: String = "research_reward"
const MAINTENANCE_CONTRACT: String = "maintenance_contract"

# Expenses
const HARDWARE: String = "hardware"
const SALARY: String = "salary"
const OFFICE_RENT: String = "office_rent"
const SERVER_MAINTENANCE: String = "server_maintenance"
const RESEARCH_COST: String = "research_cost"
const ELECTRICITY: String = "electricity"

# Other
const DEBUG: String = "debug"
const OTHER: String = "other"

const DISPLAY_NAMES: Dictionary = {
	STARTING_FUNDS: "Starting Funds",
	CONTRACT: "Contract",
	SOFTWARE_SALES: "Software Sales",
	SUBSCRIPTION: "Subscription",
	RESEARCH_REWARD: "Research Reward",
	MAINTENANCE_CONTRACT: "Maintenance Contract",
	HARDWARE: "Hardware",
	SALARY: "Salary",
	OFFICE_RENT: "Office Rent",
	SERVER_MAINTENANCE: "Server Maintenance",
	RESEARCH_COST: "Research",
	ELECTRICITY: "Electricity",
	DEBUG: "Dev Tools",
	OTHER: "Other",
}


static func get_display_name(category: String) -> String:
	return DISPLAY_NAMES.get(category, category.capitalize())
