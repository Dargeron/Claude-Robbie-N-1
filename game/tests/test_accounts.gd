extends TestCase
## The pay and the hangar's stock (docs/design/lab-parts-and-pay.md): the survey fee by tries, paid
## once; lost beacons paid once; parts bought only with the money, fitted one per socket.


func _accounts() -> Accounts:
	var s := GameState.new()
	s.persist = false
	return Accounts.new(s)


func test_fee_by_tries() -> void:
	var clean := Accounts.fee_for(0, 1, false)
	eq(clean["total"], 3000, "Sector 1, one Robbie lost: the full fee")
	var first := Accounts.fee_for(0, 0, true)
	eq(first["total"], 4000, "a first-try success adds the commendation")
	var many := Accounts.fee_for(0, 5, false)
	eq(many["deductions"], 3 * 250, "three Robbies beyond the two allowed")
	var awful := Accounts.fee_for(0, 100, false)
	eq(awful["total"], 3000 * 40 / 100, "never below the floor")


func test_paid_once() -> void:
	var a := _accounts()
	var slip := a.pay_sector("dark", 0, 1, false)
	eq(a.wage(), 3000, "the fee lands in hand")
	check(not slip.is_empty(), "a payslip")
	check(a.pay_sector("dark", 0, 1, false).is_empty(), "and only once")
	eq(a.wage(), 3000, "still 3,000")
	check(a.pay_bonus("dark", 0, 1500), "a lost beacon pays")
	check(not a.pay_bonus("dark", 0, 1500), "once")
	eq(a.wage(), 4500, "fee and beacon")


func test_buy_and_fit() -> void:
	var a := _accounts()
	check(not a.buy("plating", 4000), "no money, no plating")
	a.pay_sector("dark", 0, 0, true)
	check(a.buy("plating", 4000), "4,000 buys it")
	eq(a.wage(), 0, "and spends it")
	a.fit("hull", "plating")
	eq(a.kit().hp, 5, "fitted, he has five knocks")
	a.fit("hull", "")
	eq(a.kit().hp, 3, "taken off, three again")
	a.fit("lamp", "spotlight")
	check(a.kit().is_stock(), "a part not owned can't be fitted")


func test_part_plates_come_with_the_part() -> void:
	var a := _accounts()
	a.state.extra["wage"] = 20000
	check(a.buy("flares", 5000), "buy the flare launcher")
	check(not a.plates().has("flare"), "DROP FLARE only while it's fitted")
	a.fit("tool", "flares")
	check(a.plates().has("flare"), "fitted: DROP FLARE on the press")
	check(not a.kit().laser, "and the laser comes off")
	check(a.buy("beacon_seen", 2500), "a plate can be bought")
	check(a.plates().has("beacon_seen"), "and is on the press")


func test_slots() -> void:
	var a := _accounts()
	a.state.extra["wage"] = 100000
	eq(a.next_slot_price(2), 6000, "the third slot")
	check(a.buy_slot(2), "bought")
	eq(a.slots_bought(), 1, "one more slot")
	for i in 3:
		a.buy_slot(2)
	eq(a.next_slot_price(2), -1, "six is the most")


func test_paying_in() -> void:
	var a := _accounts()
	a.state.extra["wage"] = 2500
	eq(a.pay_debt(1000, 48000), 1000, "1,000 in")
	eq(a.paid_in(), 1000, "counted against the debt")
	eq(a.pay_debt(5000, 48000), 1500, "no more than is in hand")
	eq(a.wage(), 0, "hand empty")
