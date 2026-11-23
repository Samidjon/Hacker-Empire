class_name OfficeDefinition
extends RefCounted
## One office tier from data/organization/offices.json. The list is ordered:
## expanding always moves to the next entry.

var id: String = ""
var title: String = ""
var description: String = ""
## Employees it has desks for (the player does not need one).
var capacity: int = 1
## Rent per business day.
var rent: int = 0
## One-time cost of moving in.
var cost: int = 0
var required_company_level: int = 1


static func from_dictionary(data: Dictionary) -> OfficeDefinition:
	var office := OfficeDefinition.new()
	office.id = SaveDataReader.get_string(data, "id")
	if office.id.is_empty():
		push_warning("OfficeDefinition: skipped an office without an id.")
		return null
	office.title = SaveDataReader.get_string(data, "name", office.id)
	office.description = SaveDataReader.get_string(data, "description")
	office.capacity = maxi(0, SaveDataReader.get_int(data, "capacity", 1))
	office.rent = maxi(0, SaveDataReader.get_int(data, "rent"))
	office.cost = maxi(0, SaveDataReader.get_int(data, "cost"))
	office.required_company_level = maxi(1, SaveDataReader.get_int(data, "required_company_level", 1))
	return office
