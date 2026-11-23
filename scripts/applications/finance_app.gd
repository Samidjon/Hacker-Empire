extends VBoxContainer
## Finance application: balance, lifetime income and expenses by category,
## and the transaction history. Read-only view of EconomyManager.

const CELL_PADDING: Rect2 = Rect2(0.0, 2.0, 28.0, 2.0)

@onready var _balance_card: StatCard = %FinanceBalanceCard
@onready var _income_card: StatCard = %FinanceIncomeCard
@onready var _expense_card: StatCard = %FinanceExpenseCard
@onready var _net_card: StatCard = %FinanceNetCard
@onready var _income_table: RichTextLabel = %IncomeTable
@onready var _expense_table: RichTextLabel = %ExpenseTable
@onready var _history_title: Label = %HistoryTitle
@onready var _history_table: RichTextLabel = %HistoryTable


func _ready() -> void:
	EconomyManager.money_changed.connect(func(_balance: int, _delta: int) -> void: refresh())
	refresh()


func refresh() -> void:
	var net: int = EconomyManager.total_earned - EconomyManager.total_spent
	_balance_card.set_value(FormatUtils.money(EconomyManager.money), UIPalette.ACCENT)
	_income_card.set_value(FormatUtils.money(EconomyManager.total_earned))
	_expense_card.set_value(FormatUtils.money(EconomyManager.total_spent))
	_net_card.set_value(
		FormatUtils.signed_money(net), UIPalette.ACCENT if net >= 0 else UIPalette.DANGER
	)
	_fill_category_table(_income_table, EconomyManager.get_income_by_category(), UIPalette.ACCENT)
	_fill_category_table(_expense_table, EconomyManager.get_expenses_by_category(), UIPalette.DANGER)
	_fill_history()


func get_income_text() -> String:
	return _income_table.get_parsed_text()


func get_expense_text() -> String:
	return _expense_table.get_parsed_text()


func get_history_text() -> String:
	return _history_table.get_parsed_text()


## Largest category first.
func _fill_category_table(table: RichTextLabel, totals: Dictionary, amount_color: Color) -> void:
	table.clear()
	if totals.is_empty():
		_add_dim_text(table, "Nothing yet.")
		return
	var categories: Array = totals.keys()
	categories.sort_custom(func(a: String, b: String) -> bool: return totals[a] > totals[b])
	table.push_table(2)
	for category: String in categories:
		_add_cell(table, TransactionCategory.get_display_name(category), UIPalette.TEXT)
		_add_cell(table, FormatUtils.money(totals[category]), amount_color)
	table.pop()


func _fill_history() -> void:
	var transactions: Array[Dictionary] = EconomyManager.get_recent_transactions(
		EconomyManager.CONFIG.max_transaction_history
	)
	_history_title.text = "TRANSACTION HISTORY  (%d)" % transactions.size()
	_history_table.clear()
	if transactions.is_empty():
		_add_dim_text(_history_table, "No transactions yet.")
		return
	_history_table.push_table(5)
	for transaction: Dictionary in transactions:
		var amount: int = SaveDataReader.get_int(transaction, "amount")
		_add_cell(
			_history_table, FormatUtils.local_timestamp(SaveDataReader.get_int(transaction, "timestamp")),
			UIPalette.TEXT_DIM
		)
		_add_cell(
			_history_table, FormatUtils.signed_money(amount),
			UIPalette.ACCENT if amount >= 0 else UIPalette.DANGER
		)
		_add_cell(
			_history_table,
			TransactionCategory.get_display_name(SaveDataReader.get_string(transaction, "category")),
			UIPalette.TEXT
		)
		_add_cell(_history_table, SaveDataReader.get_string(transaction, "description"), UIPalette.TEXT_DIM)
		_add_cell(
			_history_table, FormatUtils.money(SaveDataReader.get_int(transaction, "balance_after")),
			UIPalette.TEXT
		)
	_history_table.pop()


func _add_cell(table: RichTextLabel, text: String, color: Color) -> void:
	table.push_cell()
	table.set_cell_padding(CELL_PADDING)
	table.push_color(color)
	table.add_text(text)
	table.pop()
	table.pop()


func _add_dim_text(table: RichTextLabel, text: String) -> void:
	table.push_color(UIPalette.TEXT_DIM)
	table.add_text(text)
	table.pop()
