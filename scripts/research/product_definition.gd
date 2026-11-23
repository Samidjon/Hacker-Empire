class_name ProductDefinition
extends RefCounted
## One software product from data/products/products.json.

const KIND_ONE_TIME: String = "one_time"         ## Sold once: software sales.
const KIND_SUBSCRIPTION: String = "subscription" ## Paid for every day.

var id: String = ""
var title: String = ""
var description: String = ""
var kind: String = KIND_ONE_TIME
## Research project that makes the product possible.
var required_research: String = ""
var development_cost: int = 0
## Development points needed before release.
var development_points: int = 1

# One-time products.
## Sales on the day of release.
var daily_revenue: int = 0
## Each later day sells this share of the day before.
var decay: float = 0.9
var minimum_daily_revenue: int = 0

# Subscriptions.
var price_per_subscriber: int = 0
## Subscribers gained per day until the cap.
var subscriber_growth: int = 0
var subscriber_cap: int = 0
## Server cost per day while the service runs.
var maintenance_cost: int = 0


func is_subscription() -> bool:
	return kind == KIND_SUBSCRIPTION


static func from_dictionary(data: Dictionary) -> ProductDefinition:
	var product := ProductDefinition.new()
	product.id = SaveDataReader.get_string(data, "id")
	if product.id.is_empty():
		push_warning("ProductDefinition: skipped a product without an id.")
		return null
	product.title = SaveDataReader.get_string(data, "name", product.id)
	product.description = SaveDataReader.get_string(data, "description")
	if SaveDataReader.get_string(data, "kind") == KIND_SUBSCRIPTION:
		product.kind = KIND_SUBSCRIPTION
	product.required_research = SaveDataReader.get_string(data, "required_research")
	product.development_cost = maxi(0, SaveDataReader.get_int(data, "development_cost"))
	product.development_points = maxi(1, SaveDataReader.get_int(data, "development_points", 1))
	product.daily_revenue = maxi(0, SaveDataReader.get_int(data, "daily_revenue"))
	product.decay = clampf(SaveDataReader.get_float(data, "decay", 0.9), 0.0, 1.0)
	product.minimum_daily_revenue = maxi(0, SaveDataReader.get_int(data, "minimum_daily_revenue"))
	product.price_per_subscriber = maxi(0, SaveDataReader.get_int(data, "price_per_subscriber"))
	product.subscriber_growth = maxi(0, SaveDataReader.get_int(data, "subscriber_growth"))
	product.subscriber_cap = maxi(0, SaveDataReader.get_int(data, "subscriber_cap"))
	product.maintenance_cost = maxi(0, SaveDataReader.get_int(data, "maintenance_cost"))
	return product
