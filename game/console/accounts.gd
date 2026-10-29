class_name Accounts
extends RefCounted
## The operator's money and the hangar's stock, kept in the console's save (GameState.extra):
## the wage IN HAND, what has been paid in against the debt, what each sector and each lost
## beacon paid, the parts and type plates owned, what is fitted, and the card-reader slots bought.
## Prices and words: content/lab/parts.json. The design: docs/design/lab-parts-and-pay.md.

const MAX_SLOTS := 6

static var _cat: Dictionary = {}

var state: GameState


func _init(s: GameState) -> void:
	state = s


## 12,500 (thousands with commas), as the Company types its sums.
static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func catalogue() -> Dictionary:
	if _cat.is_empty():
		_cat = JSON.parse_string(FileAccess.get_file_as_string("res://content/lab/parts.json"))
	return _cat


static func part_info(id: String) -> Dictionary:
	for p: Dictionary in catalogue()["parts"]:
		if p["id"] == id:
			return p
	return {}


static func plate_info(id: String) -> Dictionary:
	for p: Dictionary in catalogue()["plates"]:
		if p["id"] == id:
			return p
	return {}


## Every part for one socket, in the catalogue's order (the stock one is not listed: it is "").
static func parts_for(socket: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in catalogue()["parts"]:
		if p["socket"] == socket:
			out.append(p)
	return out


func _val(key: String, default_value: Variant) -> Variant:
	return state.extra.get(key, default_value)


func _put(key: String, value: Variant) -> void:
	state.extra[key] = value
	state.save()


# ---------------------------------------------------------------- money

func wage() -> int:
	return int(_val("wage", 0))


func paid_in() -> int:
	return int(_val("paid_in", 0))


func _add_wage(n: int) -> void:
	_put("wage", wage() + n)


## Push scrip through the Company's slot against the debt. Returns what went in.
func pay_debt(n: int, owing: int) -> int:
	var amount := mini(mini(n, wage()), maxi(owing, 0))
	if amount <= 0:
		return 0
	state.extra["wage"] = wage() - amount
	_put("paid_in", paid_in() + amount)
	return amount


## The survey fee for a sector: less a little for every Robbie lost after the first two, never
## below the floor; and a bonus if the very first Robbie got through.
static func fee_for(sector: int, losses: int, first_try: bool) -> Dictionary:
	var pay: Dictionary = catalogue()["pay"]
	var fees: Array = pay["fee"]
	var per: Array = pay["per_loss"]
	var i := clampi(sector, 0, fees.size() - 1)
	var base := int(fees[i])
	var over := maxi(0, losses - int(pay["free_losses"]))
	var deductions := mini(over * int(per[i]), base - base * int(pay["floor_pct"]) / 100)
	var bonus := int(pay["first_try"]) if first_try else 0
	return {"fee": base, "over": over, "per_loss": int(per[i]), "deductions": deductions, "first_try": bonus,
		"total": base - deductions + bonus}


func paid_for(room_id: String) -> Dictionary:
	return (_val("paid", {}) as Dictionary).get(room_id, {})


## Pay a newly certified sector, once. Returns the payslip ({} if it was paid already).
func pay_sector(room_id: String, sector: int, losses: int, first_try: bool) -> Dictionary:
	var paid: Dictionary = _val("paid", {})
	if paid.has(room_id):
		return {}
	var slip := fee_for(sector, losses, first_try)
	paid[room_id] = slip
	state.extra["paid"] = paid
	_add_wage(int(slip["total"]))
	return slip


func found(room_id: String) -> Array:
	return (_val("found", {}) as Dictionary).get(room_id, [])


## A lost beacon recovered: paid once. Returns true when it is new.
func pay_bonus(room_id: String, i: int, amount: int) -> bool:
	var f: Dictionary = _val("found", {})
	var list: Array = f.get(room_id, [])
	if list.has(i):
		return false
	list.append(i)
	f[room_id] = list
	state.extra["found"] = f
	_add_wage(amount)
	return true


# ---------------------------------------------------------------- the hangar's stock

func owned(id: String) -> bool:
	return (_val("owned", []) as Array).has(id)


## Buy a part or a plate. Returns false if it's already owned or there isn't the money.
func buy(id: String, price: int) -> bool:
	if owned(id) or wage() < price:
		return false
	var o: Array = _val("owned", [])
	o.append(id)
	state.extra["owned"] = o
	_put("wage", wage() - price)
	return true


func fitted() -> Dictionary:
	return _val("fitted", {})


## Fit an owned part (it takes its socket's place), or "" to put the stock one back.
func fit(socket: String, id: String) -> void:
	var f: Dictionary = fitted().duplicate()
	if id == "":
		f.erase(socket)
	elif owned(id):
		f[socket] = id
	_put("fitted", f)


func fitted_in(socket: String) -> String:
	return str(fitted().get(socket, ""))


func kit() -> Kit:
	return Kit.from_parts(fitted().values())


func slots_bought() -> int:
	return int(_val("slots", 0))


func next_slot_price(base_slots: int) -> int:
	var prices: Array = catalogue()["slots"]
	var n := slots_bought()
	if base_slots + n >= MAX_SLOTS or n >= prices.size():
		return -1
	return int(prices[n])


func buy_slot(base_slots: int) -> bool:
	var price := next_slot_price(base_slots)
	if price < 0 or wage() < price:
		return false
	state.extra["wage"] = wage() - price
	_put("slots", slots_bought() + 1)
	return true


## Type plates the operator owns, and those that come with a fitted part (the flare launcher's
## DROP FLARE, the hydrophone's IF HEARD).
func plates() -> Array:
	var out: Array = []
	for p: Dictionary in catalogue()["plates"]:
		if owned(str(p["id"])):
			out.append(p["id"])
	for id: Variant in fitted().values():
		for pl: Variant in part_info(str(id)).get("plates", []):
			out.append(pl)
	return out
