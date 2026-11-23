extends Node
## EconomyManager (autoload)
##
## The single authority over the player's money. Every income and expense in
## the game must go through add_money() / spend_money() so the balance can
## never go negative and every change is recorded.

signal money_changed(new_balance: int, delta: int)
signal transaction_recorded(transaction: Dictionary)
signal transaction_failed(amount: int, category: String, reason: String)

const CONFIG: EconomyConfig = preload("res://resources/configurations/economy_config.tres")
const SAVE_SECTION: String = "economy"
const FAILURE_INSUFFICIENT_FUNDS: String = "insufficient_funds"
const FAILURE_INVALID_AMOUNT: String = "invalid_amount"

var money: int = 0
var total_earned: int = 0
var total_spent: int = 0

## Oldest first. Each entry: id, amount (signed), category, description,
## balance_after, timestamp (unix seconds).
var _transactions: Array[Dictionary] = []
var _next_transaction_id: int = 1
## Lifetime totals per TransactionCategory. Unlike the history these are
## never trimmed, so reports stay correct in long games.
var _income_by_category: Dictionary = {}
var _expenses_by_category: Dictionary = {}


func _ready() -> void:
	SaveManager.register_section(SAVE_SECTION, self)


func can_afford(amount: int) -> bool:
	return amount >= 0 and money >= amount


func add_money(amount: int, category: String, description: String = "") -> bool:
	if amount <= 0:
		transaction_failed.emit(amount, category, FAILURE_INVALID_AMOUNT)
		return false
	money += amount
	total_earned += amount
	_record_transaction(amount, category, description)
	money_changed.emit(money, amount)
	return true


## Fails (and changes nothing) when the balance is too low.
func spend_money(amount: int, category: String, description: String = "") -> bool:
	if amount <= 0:
		transaction_failed.emit(amount, category, FAILURE_INVALID_AMOUNT)
		return false
	if not can_afford(amount):
		transaction_failed.emit(amount, category, FAILURE_INSUFFICIENT_FUNDS)
		return false
	money -= amount
	total_spent += amount
	_record_transaction(-amount, category, description)
	money_changed.emit(money, -amount)
	return true


func grant_starting_funds() -> void:
	if CONFIG.starting_money > 0:
		add_money(CONFIG.starting_money, TransactionCategory.STARTING_FUNDS, "Initial savings")


## Newest first.
func get_recent_transactions(count: int) -> Array[Dictionary]:
	var recent: Array[Dictionary] = []
	var index: int = _transactions.size() - 1
	while index >= 0 and recent.size() < count:
		recent.append(_transactions[index])
		index -= 1
	return recent


func get_transaction_count() -> int:
	return _transactions.size()


## Category id -> lifetime income (positive amounts).
func get_income_by_category() -> Dictionary:
	return _income_by_category.duplicate()


## Category id -> lifetime expenses (positive amounts).
func get_expenses_by_category() -> Dictionary:
	return _expenses_by_category.duplicate()


# --- Save section -----------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"money": money,
		"total_earned": total_earned,
		"total_spent": total_spent,
		"next_transaction_id": _next_transaction_id,
		"transactions": _transactions.duplicate(true),
		"income_by_category": _income_by_category.duplicate(),
		"expenses_by_category": _expenses_by_category.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	money = maxi(0, SaveDataReader.get_int(data, "money"))
	total_earned = maxi(0, SaveDataReader.get_int(data, "total_earned"))
	total_spent = maxi(0, SaveDataReader.get_int(data, "total_spent"))

	_transactions.clear()
	var highest_id: int = 0
	for entry: Variant in SaveDataReader.get_array(data, "transactions"):
		if not entry is Dictionary:
			continue
		var raw: Dictionary = entry
		var transaction: Dictionary = {
			"id": SaveDataReader.get_int(raw, "id"),
			"amount": SaveDataReader.get_int(raw, "amount"),
			"category": SaveDataReader.get_string(raw, "category", TransactionCategory.OTHER),
			"description": SaveDataReader.get_string(raw, "description"),
			"balance_after": SaveDataReader.get_int(raw, "balance_after"),
			"timestamp": SaveDataReader.get_int(raw, "timestamp"),
		}
		highest_id = maxi(highest_id, transaction["id"])
		_transactions.append(transaction)
	_trim_history()
	_next_transaction_id = maxi(
		SaveDataReader.get_int(data, "next_transaction_id", 1), highest_id + 1
	)

	if data.get("income_by_category") is Dictionary and data.get("expenses_by_category") is Dictionary:
		_income_by_category = _sanitize_totals(data["income_by_category"])
		_expenses_by_category = _sanitize_totals(data["expenses_by_category"])
	else:
		# Saves from before category totals existed: rebuild from the history.
		_income_by_category.clear()
		_expenses_by_category.clear()
		for transaction: Dictionary in _transactions:
			_add_to_category_totals(transaction["amount"], transaction["category"])
	money_changed.emit(money, 0)


func reset_to_defaults() -> void:
	money = 0
	total_earned = 0
	total_spent = 0
	_transactions.clear()
	_next_transaction_id = 1
	_income_by_category.clear()
	_expenses_by_category.clear()
	money_changed.emit(money, 0)


# --- Internals --------------------------------------------------------------

func _record_transaction(signed_amount: int, category: String, description: String) -> void:
	var transaction: Dictionary = {
		"id": _next_transaction_id,
		"amount": signed_amount,
		"category": category,
		"description": description,
		"balance_after": money,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	_next_transaction_id += 1
	_transactions.append(transaction)
	_trim_history()
	_add_to_category_totals(signed_amount, category)
	transaction_recorded.emit(transaction)


func _add_to_category_totals(signed_amount: int, category: String) -> void:
	if signed_amount > 0:
		_income_by_category[category] = int(_income_by_category.get(category, 0)) + signed_amount
	elif signed_amount < 0:
		_expenses_by_category[category] = int(_expenses_by_category.get(category, 0)) - signed_amount


## Keeps only string keys with non-negative whole amounts.
func _sanitize_totals(raw: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	for key: Variant in raw:
		if key is String and not String(key).is_empty():
			totals[key] = maxi(0, SaveDataReader.get_int(raw, key))
	return totals


func _trim_history() -> void:
	var overflow: int = _transactions.size() - CONFIG.max_transaction_history
	if overflow > 0:
		_transactions = _transactions.slice(overflow)
